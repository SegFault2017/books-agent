# Chapter 5: Replication

## Core Idea
Replication — keeping copies of the same data on multiple machines — looks simple, but nearly all of its difficulty comes from handling *changes* to that data over time; the three replication algorithms (single-leader, multi-leader, leaderless) are really three different answers to "who is allowed to accept writes, and how do replicas agree on an order?"

## Frameworks Introduced
- **Leader-based (single-leader) replication**: one designated leader accepts all writes and streams a replication log to followers; reads may go to any replica.
  - When to use: default choice — simplest to reason about, no conflict resolution needed.
  - How: leader writes locally, forwards change stream to followers in the order it processed them; followers apply changes in that same order.
- **Multi-leader replication**: more than one node accepts writes, each acting as leader to the others.
  - When to use: multi-datacenter deployments (hide inter-datacenter latency), offline-capable clients (each device is a "leader"), real-time collaborative editing.
  - How: each leader forwards its writes to every other leader; conflicting concurrent writes must be detected and resolved.
- **Leaderless replication (Dynamo-style)**: any replica accepts writes directly from clients; no leader, no fixed write order.
  - When to use: high availability + low latency workloads that can tolerate eventual consistency and occasional stale reads (Riak, Cassandra, Voldemort).
  - How: client (or coordinator) writes to all n replicas in parallel, requires w acks; reads query r replicas in parallel and reconcile via version numbers.
- **Quorum condition (w + r > n)**: guarantees at least one read replica overlaps with at least one up-to-date write replica.
  - When to use: tuning leaderless systems for latency vs. consistency trade-offs.
  - How: choose n replicas, require w acks per write and r responses per read such that w + r > n (commonly majority quorums).

## Key Concepts
- **Replication log** — the ordered stream of data changes a leader sends to followers.
- **Failover** — promoting a follower to leader after the old leader fails; fraught with data-loss and split-brain risk.
- **Split brain** — two nodes both believe they are the leader and both accept writes; dangerous without conflict resolution.
- **Eventual consistency** — the guarantee that replicas *will* converge given enough time and no new writes, with unbounded "eventually."
- **Read-after-write (read-your-writes) consistency** — a user always sees their own submitted updates.
- **Monotonic reads** — a user never sees data go "backward in time" across sequential reads.
- **Consistent prefix reads** — causally related writes are seen in the same order by all readers (no "hearing the answer before the question").
- **Sloppy quorum / hinted handoff** — accepting writes on non-"home" nodes during a network partition, then forwarding them once connectivity is restored; trades strict quorum guarantees for write availability.
- **Version vector** — a per-replica, per-key version number set used to distinguish overwrites from concurrent (conflicting) writes across multiple replicas.

## Mental Models
- Use "replication lag is a knob, not a bug" — synchronous replication buys durability at the cost of availability (one slow follower blocks all writes); asynchronous buys availability at the cost of possibly losing recent writes on failover. Pick per follower, not system-wide (semi-synchronous).
- Use "concurrent means neither knows about the other," not "happened at the same wall-clock time" — this is the actual definition needed to build correct conflict-detection algorithms (happens-before relationship), and it sidesteps unreliable clocks entirely.
- Think of sloppy quorums as "crashing on your neighbor's couch": durability is preserved (data lives somewhere among w nodes) but the traditional quorum overlap guarantee (w + r > n implies freshness) is broken, because reads may not hit the "temporary" nodes.

## Anti-patterns
- **Assuming synchronous replication to all followers is safe at scale**: any single follower outage blocks all writes system-wide; in practice at most one follower is made synchronous (semi-synchronous), the rest asynchronous.
- **Last-write-wins (LWW) as your default conflict resolution**: silently discards concurrently-written data — even writes explicitly acknowledged as successful to the client. Only safe when a key is written once and treated as immutable thereafter.
- **Automatic failover without a human in the loop for ambiguous cases**: a transient slow node can be mistaken for a dead one, triggering an unnecessary failover that adds load to an already-struggling system — potentially cascading into a bigger outage (see the GitHub primary-key-reuse incident).
- **Taking the union of sibling values to "merge" conflicts**: works for adding items (e.g., shopping cart) but silently resurrects deleted items unless you track removals with an explicit tombstone.

## Reference Tables

| Approach | Who can write | Conflict resolution needed? | Typical use case |
|---|---|---|---|
| Single-leader | Only the leader | No | Default; most relational DBs, MongoDB, Kafka partitions |
| Multi-leader | Any leader node | Yes (write-write conflicts) | Multi-datacenter, offline clients, collaborative editing |
| Leaderless | Any replica | Yes (via version vectors / quorums) | High-availability Dynamo-style stores (Riak, Cassandra, Voldemort) |

| Replication log implementation | Coupled to storage engine? | Cross-version leader/follower? |
|---|---|---|
| Statement-based | No | Risky — nondeterministic functions (`NOW()`, `RAND()`) break it |
| Write-ahead log (WAL) shipping | Yes (byte-level) | No — same storage engine version required |
| Logical (row-based) log | No | Yes — decoupled from engine internals; also used for change data capture |
| Trigger-based | No | Yes, but highest overhead / most bug-prone |

| Anomaly | Guarantee that prevents it |
|---|---|
| "My own write disappeared" | Read-after-write (read-your-writes) consistency |
| "Data appeared then vanished on refresh" | Monotonic reads |
| "I saw the answer before the question" | Consistent prefix reads |

## Worked Example
**Leader failover walkthrough, and where it breaks.** A 3-node single-leader cluster (Leader L, Followers F1, F2) using asynchronous replication:

1. Client writes `X=5` to L. L applies it locally and starts forwarding to F1/F2, but crashes immediately after acknowledging the client and before F1/F2 receive the change (asynchronous replication means L didn't wait for them).
2. The cluster detects L is unresponsive after a timeout (e.g., 30s) — no foolproof way to know *why* L stopped responding, so a heuristic is used.
3. An election (or an appointed controller) picks the follower with the most up-to-date data — say F1 — as the new leader. F1 never received `X=5`, so this write is **lost**, even though it was already acknowledged to the client. This is the well-known risk of asynchronous replication + failover.
4. Clients are reconfigured to send writes to F1. F2 starts replicating from F1 instead of the old L.
5. **Old L rejoins the cluster** after being rebooted. It still has `X=5` in its local log and might believe it's still the leader. The system must force it to recognize F1 as the new leader and discard/reconcile its unreplicated writes (`X=5` is simply thrown away in the common approach) — this is the exact mechanism that caused the GitHub incident where a stale MySQL follower's autoincrement counter reused primary keys already used by the old leader, leaking private data via a shared Redis store.

This example shows precisely why the chapter frames failover as "fraught with things that can go wrong": undetectable root cause, discarded writes, and split-brain risk all compound in the same 30-second window.

## Key Takeaways
1. All replication difficulty comes from handling *changes*, not from copying a static dataset — pick the leader model based on how you need writes distributed (one node, many nodes, or any node).
2. Synchronous replication trades availability for durability; make this trade-off per-follower (semi-synchronous), never system-wide.
3. Asynchronous replication + leader failover can silently lose acknowledged writes — evaluate whether your application can tolerate this before choosing it.
4. Eventual consistency is deliberately vague about *how* eventual — for operability, always monitor replication lag (or, for leaderless systems, replica staleness) rather than assume it's small.
5. Read-after-write, monotonic reads, and consistent prefix reads are the three named guarantees to reach for when "eventual consistency" causes visible bugs — pick the weakest one that solves your actual user-facing problem.
6. In leaderless (Dynamo-style) systems, w + r > n gives you overlap, not a hard consistency guarantee — sloppy quorums, concurrent writes, and partial failures all create edge cases where you still read stale data.
7. Merging concurrent writes (siblings) requires explicit application logic (or CRDTs) — plain "last write wins" is a data-loss trap outside of immutable-key use cases.

## Connects To
- **Ch 6 (Partitioning)**: replication and partitioning are combined in practice — each partition has its own leader/followers; this chapter deliberately ignored partitioning to isolate replication concerns.
- **Ch 7 (Transactions)**: single-object write conflict resolution here foreshadows multi-object transaction semantics; "single-leader replication with transactions" is literally invoked as the model for lock-based collaborative editing.
- **Ch 8 (Distributed Systems)**: failure detection via timeouts, and the impossibility of reliably distinguishing "dead" from "slow," are developed in much more depth here.
- **Ch 9 (Consistency and Consensus)**: leader election is a consensus problem; linearizability formalizes the "up-to-date" guarantee that quorums only approximate.
- **Ch 11 (Stream Processing)**: change data capture reuses the logical (row-based) log format introduced here as its extraction mechanism.
