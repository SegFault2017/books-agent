# Chapter 12: The Future of Data Systems

## Core Idea
No single data system can serve every access pattern, so complex applications inevitably become "one huge database" spread across specialized tools connected by derived-data pipelines (batch and stream processing); when this "unbundling" is done right — funneling writes through an ordered log and treating idempotence/end-to-end checks as the source of integrity rather than distributed transactions — you get systems that are both more robust and more scalable than the traditional distributed-transaction approach, but engineers must also own the ethical consequences of the surveillance infrastructure this technology enables.

## Frameworks Introduced
- **Unbundling databases**: decompose a database's internal features (secondary indexes, materialized views, replication logs, caches) into independently operated tools connected by event streams, mirroring how a database maintains those features internally via `CREATE INDEX`-style reprocessing.
  - When to use: when no single integrated product satisfies all your workloads (breadth over depth) — not as a default, since "if there is a single technology that does everything you need, use that."
  - How: pick **federation** (unify reads across heterogeneous stores, e.g., polystores/foreign data wrappers) for querying, and **unbundling via log-based CDC/event sourcing** (unify writes) for keeping them in sync — Kleppmann argues the write side is the harder problem and that an asynchronous event log with idempotent consumers beats distributed transactions across heterogeneous technology.
- **The end-to-end argument** (Saltzer, Reed, Clark, 1984): a function (duplicate suppression, integrity checking, encryption) can only be *completely and correctly* implemented with the knowledge of the application at the endpoints — lower-level mechanisms (TCP dedup, Ethernet checksums, WiFi encryption) reduce the probability of problems but cannot substitute for an end-to-end solution.
  - How to apply: pass a client-generated, unique **request/operation ID** all the way from the true endpoint (e.g., a web form) through every hop (app server, message broker, database) so retries at any layer can be deduplicated.
- **Timeliness vs. Integrity** (Kleppmann's proposed split of "consistency"): timeliness = users see up-to-date state (temporary violations self-heal by waiting/retrying); integrity = absence of corruption, no lost/contradictory/false data (permanent violations require explicit repair).
  - How to apply: most applications need strong integrity but can tolerate weak timeliness — design for "eventual consistency" on timeliness while enforcing integrity through idempotence, deterministic derivation, and end-to-end request IDs, not linearizability.
- **Coordination-avoiding data systems**: dataflow systems can preserve integrity without atomic commit or synchronous cross-partition coordination, and many real constraints (unique usernames, inventory counts, overbooking) can be checked *after* the fact with a compensating "apology," avoiding the availability/performance cost of synchronous coordination.
- **Trust, but verify / auditing**: since hardware and software both fail in rare but real ways (bit-flips, MySQL/PostgreSQL isolation bugs Kleppmann personally observed), build continual self-auditing into data systems rather than blindly trusting transactional guarantees.

## Key Concepts
- **Data integration**: the problem of getting the same or related data into the right form in every system that needs it (search index, cache, warehouse, ML feature store).
- **Total order broadcast**: equivalent to consensus; feasible at the scale of a single partition/leader but fundamentally limited across partitions, datacenters, or offline clients — causing genuine ordering ambiguity that logical timestamps or explicit causal references can only partially resolve.
- **Write path vs. read path**: the write path is eager precomputation (as data arrives, before anyone asks); the read path is lazy computation (only when queried) — indexes, caches, and materialized views all just move the boundary between the two.
- **Idempotence**: an operation that has the same effect whether performed once or many times; the primary tool (alongside distributed transactions) for achieving exactly-once/effectively-once semantics across retries.
- **Application code as a derivation function**: any derived dataset (secondary index, ML model, cache, search index) is the output of applying some transformation function to a base dataset — some transformations are generic enough to be built into databases (`CREATE INDEX`); others (feature engineering, NLP) require custom application code.
- **Uniqueness constraints require consensus**: enforcing "only one X" (username, seat) across concurrent, possibly cross-partition writers is fundamentally a consensus problem — solvable at partition granularity by routing conflicting writes to the same log partition and letting a single-threaded stream processor decide deterministically.
- **Algorithmic bias/discrimination**: predictive systems trained on discriminatory historical data will codify and amplify that discrimination, especially via proxy variables (postal code standing in for race) even when protected traits are excluded.
- **Surveillance vs. service**: when tracking serves the advertiser rather than the user, the relationship between a company and its users functions as surveillance, not service — a reframing Kleppmann uses deliberately to sharpen the ethical stakes.

## Mental Models
- **"The database is a cache of the log"**: think of any derived data system — index, cache, warehouse, even a client-side UI's model objects — as a materialized, read-optimized cache of an underlying immutable event log; if it's corrupted or needs to change shape, throw it away and rederive it.
- **Apologies as a design parameter**: model the acceptable cost of a compensating action (apology, refund, discount) against the cost of the coordination needed to prevent the violation in the first place — many businesses already run apology workflows (overbooking, stockouts) regardless of your software, so don't pay for linearizability you don't need.
- **Reads-as-events**: treat a query itself as an event flowing through the same stream-processing infrastructure as writes (a persistent stream-table join is a subscription; a one-off read is a join that's immediately forgotten) — this unifies serving and joining as the same underlying operation.
- **Data as pollution, privacy as environmental protection** (Bruce Schneier, quoted at length): data collection has real externalities and needs regulatory/cultural safeguards analogous to those the Industrial Revolution eventually required for physical pollution.

## Anti-patterns
- **Reaching for distributed transactions (XA/2PC) across heterogeneous technologies**: Kleppmann argues XA has poor fault-tolerance and performance characteristics that "severely limit its usefulness" — prefer log-based derived data with idempotent consumers for cross-system consistency.
- **Assuming ACID transactions guarantee application correctness**: a transaction with a logic bug, or a nonidempotent multi-statement operation replayed after a network timeout (Example 12-1: transferring money twice), corrupts data even under full serializability — correctness requires end-to-end thinking, not just strong database guarantees.
- **Blind trust without auditing**: assuming disks, networks, and application code are always correct just because they usually are; mature large-scale systems (HDFS, S3) instead run continual background integrity checks and expect rare corruption.
- **"In my experience, 99% of people don't need X"**: dismissing a data-integration or feature requirement based on personal experience rather than recognizing the genuinely wide range of legitimate use cases across an organization.
- **Blind trust in data-driven decisions ("machine learning is like money laundering for bias")**: treating statistical/probabilistic outputs as if they were certain or unbiased at the individual level, ignoring that predictive systems only extrapolate the past, including its discrimination.

## Reference Tables
| Approach to cross-system consistency | Mechanism | Coordination cost | Failure mode |
|---|---|---|---|
| Distributed transactions (XA/2PC) | Locks + atomic commit | High, escalates local faults into system-wide aborts | Poor fault tolerance across heterogeneous tech |
| Federated database / polystore | Unified query interface over multiple engines | Low (read-only) | No answer for write synchronization |
| Log-based derived data (CDC / event sourcing) | Ordered log + idempotent consumers | Low, asynchronous | Timeliness (staleness), not integrity, if done right |

| Concept | Timeliness | Integrity |
|---|---|---|
| Definition | Users see up-to-date state | No corruption, loss, or contradiction |
| CAP-theorem "C" | Yes (linearizability) | No |
| Violation is | Temporary ("eventual consistency") | Permanent ("perpetual inconsistency") until repaired |
| Typical fix | Wait and retry | Explicit checking + repair (auditing) |
| Priority for most apps | Often relaxable | Usually non-negotiable |

## Worked Example
**Multi-partition money transfer without distributed transactions** (Example 12-1/12-2, "Multi-partition request processing"): transferring $11 from account A to account B, where the request ID, payer account, and payee account may all live in different partitions.
1. The client generates a unique `request_id` (e.g., a UUID) and submits a single message — `{request_id, from_account: A, to_account: B, amount: 11.00}` — appended to a log partitioned by `request_id`. This append is a single-object write, atomic in virtually any data store, so no cross-partition atomicity is needed yet.
2. A stream processor reads this request log and, for each request, emits two derived messages: a debit instruction to a stream partitioned by `A`, and a credit instruction to a stream partitioned by `B` — both carrying the original `request_id`.
3. Two further (independently scalable) stream processors consume the debit and credit streams respectively, apply the balance change, and use the `request_id` to deduplicate — so if step 2's processor crashes and reprocesses the request log from its last checkpoint, the same debit/credit instructions are simply re-emitted and safely ignored the second time by the deduplicating consumer.
4. Optionally, an account-balance-partitioned validator stream processor checks for sufficient funds *before* the request is even written to the log in step 1, enforcing the "don't overdraw" constraint without a cross-partition lock.
Result: exactly-once application of the transfer to both accounts, achieved entirely through partitioning + idempotent deduplication by request ID — no two-phase commit anywhere.

## Key Takeaways
1. When no single database serves all your access patterns, unbundle deliberately: federate reads, and synchronize writes via an ordered log with idempotent consumers rather than distributed transactions.
2. Apply the end-to-end argument explicitly: pass a client-generated request ID through every layer to make retries idempotent — TCP/database-level deduplication alone cannot prevent duplicate execution once a request crosses the true application boundary (e.g., a browser retry).
3. Split "consistency" into timeliness (usually relaxable, self-healing) and integrity (usually non-negotiable, needs active checking) — this reframing clarifies which guarantees you actually need to pay for.
4. Uniqueness and similar constraints can often be enforced by routing conflicting writes to the same log partition and validating deterministically in a single-threaded consumer, avoiding cross-partition consensus for the common case.
5. Build for "trust, but verify": periodic end-to-end auditing (checksums, re-derivation, Merkle-tree-style integrity checks) catches the rare-but-real corruption that hardware and software bugs cause, even in mature systems.
6. Engineers bear ethical responsibility for the systems they build: predictive analytics can encode and amplify discrimination, and behavioral tracking that primarily serves advertisers rather than users is surveillance — Kleppmann explicitly argues for treating personal data as a liability to be minimized ("purge it as soon as it is no longer needed"), not an asset to be maximized.

## Connects To
- **Ch 7 (Transactions)**: distributed transactions, 2PC, and serializability are the baseline this chapter argues against for cross-system integration, while still endorsing them at small, single-system scope.
- **Ch 9 (Consistency and Consensus)**: total order broadcast and consensus are shown to be the same underlying problem as uniqueness constraints and log-based ordering.
- **Ch 10 & 11 (Batch/Stream Processing)**: this chapter is the synthesis — CDC, event sourcing, and log-based messaging from Ch 11 become the concrete mechanism for "unbundling" described here.
- **Ch 5 (Replication)**: "setting up a new follower" and CDC's "initial snapshot" are explicitly identified as the same operation as `CREATE INDEX`'s backfill-then-catch-up process.
