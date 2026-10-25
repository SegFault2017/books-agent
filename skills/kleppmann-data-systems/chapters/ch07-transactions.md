# Chapter 7: Transactions

## Core Idea
A transaction groups multiple reads/writes into one logical unit with an all-or-nothing outcome (commit or abort), so applications can ignore certain classes of partial failure and concurrency bugs — but the safety guarantees you actually get depend entirely on the isolation level, and most "ACID" databases default to something much weaker than serializable.

## Frameworks Introduced
- **ACID (Atomicity, Consistency, Isolation, Durability)**: Kleppmann's precise reading — Atomicity is really "abortability" (a fault mid-transaction discards all its writes, so a client can safely retry); Consistency is an *application*-level invariant the database cannot enforce on your behalf (the "C" doesn't really belong in ACID); Isolation is about concurrent transactions not seeing each other's partial effects; Durability means committed data survives a crash (never perfect — no durability technique alone is enough; combine disk, replication, and backups).
  - When to use: as a checklist for what a vendor's "ACID compliant" claim actually promises — always ask what isolation level backs it.
- **Isolation level ladder**: Read Committed → Snapshot Isolation → Serializable. Each level rules out specific race conditions; weaker levels are faster but leave the rest for the application to handle.
  - How: pick the weakest level that provably prevents the race conditions your access pattern can trigger; don't reach for serializable by default given its cost.
- **Two-Phase Locking (2PL)**: pessimistic concurrency control — readers and writers mutually block each other via shared/exclusive locks held until commit/abort.
  - When to use: when you need true serializability and can tolerate lower throughput/unstable tail latency from lock contention and deadlocks.
- **Serializable Snapshot Isolation (SSI)**: optimistic concurrency control built on top of snapshot isolation — transactions proceed without blocking, and the database aborts on commit if it detects a stale-read or write-affects-prior-read conflict.
  - When to use: when you want full serializability with snapshot-isolation-like performance and low contention (PostgreSQL 9.1+, FoundationDB).

## Key Concepts
- **Dirty read/write**: seeing or overwriting another transaction's uncommitted data — prevented starting at Read Committed.
- **Read skew (nonrepeatable read)**: a transaction sees the database at inconsistent points in time across multiple reads — prevented by Snapshot Isolation.
- **Lost update**: a read-modify-write cycle from one transaction is silently clobbered by a concurrent one (e.g., two counter increments landing as one).
- **Write skew**: two transactions read overlapping data, then each writes to a *different* object, and each write individually looks fine but the combination violates an invariant that spans both objects (e.g., two on-call doctors both going off-call).
- **Phantom**: a write changes the result of another transaction's *search* query — write skew's generalization to conditions rather than fixed rows.
- **MVCC (multi-version concurrency control)**: the mechanism most snapshot-isolation databases use — each row carries `created_by`/`deleted_by` transaction IDs, and visibility rules pick the right version per reader.
- **Predicate lock / index-range lock**: a lock on "all rows matching a condition," including rows that don't exist yet — needed to stop phantoms; index-range locks are the cheap approximation actually used in practice.

## Mental Models
- Think of atomicity as *abortability*, not concurrency control — it's entirely about what happens when a fault interrupts a multi-write operation, unrelated to isolation.
- Think of write skew as "lost update, generalized": lost update is the special case where the concurrent writes target the *same* object; write skew is when they target *different* objects but share an invariant.
- Use the "outdated premise" model for diagnosing snapshot-isolation bugs: a transaction reads a fact, decides an action based on it, then commits — if that fact could have changed between read and commit, you have a write-skew hazard, full stop, regardless of how the code looks.
- 2PL vs SSI is pessimistic-vs-optimistic: 2PL assumes conflict and blocks first; SSI assumes no conflict, runs freely, and pays the cost (an abort+retry) only when a conflict is actually detected.

## Anti-patterns
- **Trusting "ACID compliant" or "serializable" labels at face value**: Oracle's "serializable" is actually snapshot isolation; MySQL/PostgreSQL's "repeatable read" is snapshot isolation, not the SQL standard's weaker definition — always verify what isolation level a vendor's isolation *name* maps to.
- **Relying on snapshot isolation's automatic lost-update detection to catch write skew**: it doesn't — automatic detection (PostgreSQL repeatable read, Oracle serializable, SQL Server snapshot) catches same-object lost updates but not cross-object write skew.
- **Using compare-and-set as a drop-in mutex under snapshot isolation**: if the `WHERE` clause reads from a stale snapshot, the "conditional" update can still race — verify your database evaluates the condition against the *latest* committed state, not the transaction's snapshot.
- **Assuming ORMs use atomic operations**: frameworks make it easy to accidentally write unsafe read-modify-write cycles in application code instead of using the database's atomic increment/compare-and-set.

## Code Examples

```sql
-- Explicit locking to prevent lost updates (Example 7-1)
BEGIN TRANSACTION;
SELECT * FROM figures
  WHERE name = 'robot' AND game_id = 222
  FOR UPDATE;
-- check move validity, then:
UPDATE figures SET position = 'c4' WHERE id = 1234;
COMMIT;
```
- **What it demonstrates**: `FOR UPDATE` takes a lock on the selected rows so a concurrent read-modify-write cycle on the same object is serialized rather than silently clobbered.

```sql
-- Compare-and-set, with its caveat
UPDATE wiki_pages SET content = 'new content'
  WHERE id = 1234 AND content = 'old content';
```
- **What it demonstrates**: only safe if the `WHERE` clause is guaranteed to read the latest committed value rather than a transaction's snapshot — check this per database before relying on it.

## Reference Tables

| Isolation Level | Dirty Read | Dirty Write | Read Skew | Lost Update | Write Skew | Phantom |
|---|---|---|---|---|---|---|
| Read Committed | prevented | prevented | possible | possible | possible | possible |
| Snapshot Isolation | prevented | prevented | prevented | usually detected* | possible | possible |
| Serializable (2PL / SSI) | prevented | prevented | prevented | prevented | prevented | prevented |

*Lost-update auto-detection under snapshot isolation is implementation-dependent — MySQL/InnoDB's repeatable read does **not** detect it.

| Technique | Concurrency model | Throughput ceiling | Best fit |
|---|---|---|---|
| Actual serial execution | none (single thread) | single CPU core, or per-partition | small fast OLTP transactions, in-memory dataset, stored procedures only |
| Two-Phase Locking (2PL) | pessimistic | degrades under contention, unstable tail latency | need serializability, moderate contention tolerable |
| Serializable Snapshot Isolation (SSI) | optimistic | scales like snapshot isolation until abort rate rises | low-to-moderate contention, want serializability without lock waits |

## Worked Example
**Write skew — the on-call doctors bug (Figure 7-8):** A hospital requires at least one doctor on call per shift. Alice and Bob are both on call. Both feel sick and, at nearly the same instant, each runs:
1. `SELECT COUNT(*) FROM doctors WHERE on_call = true AND shift_id = 1234` → both transactions see `2`.
2. Application logic concludes "safe to go off call since ≥2 are on call."
3. Alice's transaction: `UPDATE doctors SET on_call = false WHERE name = 'Alice'`. Bob's transaction: same for Bob.
4. Both commit. Now zero doctors are on call — the invariant is violated, yet neither transaction touched the same row, so it's neither a dirty write nor a lost update.

Under snapshot isolation this passes silently because each transaction's read is valid *as of its own snapshot* — the premise ("2 doctors on call") was true when read, just not true anymore by commit time. Fixes, in order of robustness: (a) explicit `SELECT ... FOR UPDATE` on the shift's doctor rows to force serialization, (b) a real multi-object database constraint if your engine supports it, (c) full serializable isolation (2PL or SSI), which would detect the conflicting premise and abort one transaction.

## Key Takeaways
1. Atomicity means "abortability" — a fault mid-transaction discards everything, so retries are safe; it says nothing about concurrency.
2. Read Committed only stops dirty reads/writes — it does not protect against read skew, lost updates, or write skew; don't assume it's "safe enough" for anything beyond that.
3. Write skew is invisible to same-row conflict detection because it spans two different objects tied together by an application-level invariant — the database can't see the invariant unless you use serializable isolation or explicit locks.
4. Snapshot isolation's "readers never block writers, writers never block readers" (MVCC) is why it's the default sweet spot for read-heavy workloads with occasional writes.
5. 2PL buys serializability by making writers and readers mutually blocking, at the cost of throughput and tail-latency stability (deadlocks, one slow transaction stalling many).
6. SSI buys serializability at close to snapshot-isolation speed by staying optimistic and aborting only on detected conflicts — but the abort rate rises sharply under contention.
7. Always check what isolation level your database's "serializable" or "repeatable read" label actually implements — names are not standardized across vendors.

## Connects To
- **Ch 5 (Replication)**: replication lag produces the same read-skew-like anomalies at the cluster level that snapshot isolation solves within a single node.
- **Ch 9 (Consistency and Consensus)**: serializability (this chapter) is easily confused with linearizability (Ch 9) — they are different guarantees; a database can offer both (strict serializability) or neither.
- **Ch 8**: distributed transactions (multi-node atomic commit, 2PC) extend the single-node atomicity story from this chapter — see "Distributed Transactions and Consensus" in Ch 9.
- **MVCC**: the mechanism underlying both snapshot isolation (this chapter) and SSI's stale-read detection.
