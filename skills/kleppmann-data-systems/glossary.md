# Glossary — Designing Data-Intensive Applications

**Access path** — a predetermined pointer-chain route to a record in the CODASYL/network model; the opposite of automatic query optimization (Ch 2).
**Accidental complexity** — complexity from implementation choices, not the underlying problem; the target of good abstraction (Ch 1).
**ACID** — Atomicity, Consistency, Isolation, Durability; Kleppmann treats "Consistency" as really an application concern, not a database guarantee (Ch 7).
**Atomic commit** — getting all nodes in a distributed transaction to agree to all commit or all abort; an instance of consensus (Ch 9).
**Backward/forward compatibility** — new code can read old data (backward) / old code can read new data (forward) (Ch 4).
**Batch processing** — computation over bounded, immutable input producing derived output with no side effects (Ch 10).
**Bloom filter** — a probabilistic structure that cheaply rules out "key does not exist," short-circuiting expensive LSM-tree lookups (Ch 3).
**Byzantine fault** — a node that actively lies or behaves arbitrarily, not just crashes or slows down (Ch 8).
**CAP theorem** — narrowly: during an actual network partition, choose consistency (linearizability) or availability, not both (Ch 9).
**Change Data Capture (CDC)** — extracting a database's writes as an event stream so other systems can follow it as derived data (Ch 11).
**Clock confidence interval** — a clock reading is a range, not a point; most APIs hide this uncertainty (Ch 8).
**Column-oriented storage** — storing each column in its own file so OLAP queries load only the columns they need (Ch 3).
**Compaction** — discarding all but the most recent value per key within a log segment or changelog topic (Ch 3, 11).
**Consensus** — getting several nodes to durably agree on one value; equivalent to total order broadcast and linearizable compare-and-set (Ch 9).
**Consistent prefix reads** — causally related writes are seen in the same order by all readers (Ch 5).
**CQRS** — separating a write-optimized event log from one or more read-optimized derived views (Ch 11).
**Dirty read/write** — reading or overwriting another transaction's uncommitted data (Ch 7).
**Document-partitioned (local) secondary index** — each partition indexes only its own documents; cheap writes, scatter/gather reads (Ch 6).
**Elastic system** — automatically provisions resources in response to load, vs. manually scaled (Ch 1).
**End-to-end argument** — a correctness function (dedup, integrity) can only be fully implemented with application knowledge at the true endpoints (Ch 12).
**Epoch/ballot/term number** — a monotonically increasing counter that makes a consensus algorithm's leader unique per epoch (Ch 9).
**Eventual consistency** — replicas converge given enough time and no new writes, with no bound on "eventually" (Ch 5, 9).
**Event sourcing** — deriving application state entirely from an immutable log of intent-carrying events (Ch 11).
**Fencing token** — a monotonically increasing number issued with a lock/lease; the protected resource rejects writes with a stale token (Ch 8).
**FLP result** — proves reliable consensus is impossible in a purely asynchronous model with even one crash-prone node (Ch 9).
**Hash partitioning** — assigning partitions by hash of key for even load distribution, at the cost of range-query locality (Ch 6).
**Idempotence** — an operation that has the same effect whether performed once or many times (Ch 12).
**Impedance mismatch** — the awkward translation layer between OO application code and relational rows/tables (Ch 2).
**Integrity vs. timeliness** — integrity = no corruption/loss (non-negotiable); timeliness = up-to-date reads (often relaxable) (Ch 12).
**Lamport timestamp** — a (counter, node ID) pair giving a total order consistent with causality, but not concurrency detection (Ch 9).
**Last Write Wins (LWW)** — conflict resolution by physical-clock timestamp; silently drops causally-later writes under clock skew (Ch 5, 8).
**Linearizability** — a recency guarantee making replicated data appear as a single, atomically-updated copy (Ch 9).
**Load parameters** — the specific numbers (RPS, read:write ratio, fan-out) that characterize system load; scalability is only meaningful relative to one (Ch 1).
**Lost update** — a read-modify-write cycle silently clobbered by a concurrent one (Ch 7).
**LSM-tree** — memtable + cascading, background-merged sorted segments (SSTables); favors write throughput (Ch 3).
**Materialization of intermediate state** — writing a batch job's full output to disk before the next stage starts (Ch 10).
**MVCC** — multi-version concurrency control; each row keeps multiple versions tagged by creating/deleting transaction ID (Ch 7).
**Network partition (netsplit)** — part of the network cut off from the rest due to a fault (Ch 8).
**Normalization** — replacing human-meaningful strings with IDs referencing one authoritative record (Ch 2).
**OLTP vs. OLAP** — small-key-lookup, user-facing workloads vs. full-column-scan, analyst-facing aggregation (Ch 3).
**Partial failure** — some parts of a distributed system are broken while others work fine, nondeterministically (Ch 8).
**Percentile (p50/p95/p99)** — response-time distribution measure; preferred over averages for SLAs (Ch 1).
**Phantom** — a write changes the result of another transaction's search query (Ch 7).
**Quorum (w + r > n)** — write/read acknowledgment counts guaranteeing at least one overlapping up-to-date replica (Ch 5).
**Read skew (nonrepeatable read)** — a transaction observes the database at inconsistent points in time across reads (Ch 7).
**Rebalancing** — moving data/load between nodes as a cluster grows, shrinks, or fails (Ch 6).
**Replication log** — the ordered stream of changes a leader sends to followers (Ch 5).
**Safety vs. liveness** — safety = nothing bad ever happens (unconditional); liveness = something good eventually happens (may have caveats) (Ch 8).
**Schema-on-read/write** — structure interpreted at read time (document DBs) vs. enforced at write time (relational) (Ch 2).
**Serializability** — transactions behave as if executed in some serial order; an isolation property (Ch 7).
**Shuffle** — partitioning, sorting, and copying mapper output to reducers in MapReduce (Ch 10).
**Skew (hot spot)** — a single partition or key receiving disproportionate load (Ch 6, 10).
**Sloppy quorum / hinted handoff** — accepting writes on non-home nodes during a partition, forwarding later (Ch 5).
**Split brain** — two nodes both believe they are the leader (Ch 5, 8, 9).
**SSTable** — a log segment sorted by key, enabling sparse indexes and range queries (Ch 3).
**Term-partitioned (global) secondary index** — the index partitioned by indexed term, independent of primary-key partitioning; cheap reads, expensive writes (Ch 6).
**Total order broadcast** — reliable, totally-ordered message delivery to all nodes; equivalent to consensus (Ch 9).
**Two-Phase Commit (2PC)** — atomic commit protocol using a coordinator and a prepare/commit vote; blocks on coordinator failure (Ch 9).
**Two-Phase Locking (2PL)** — pessimistic concurrency control where readers and writers mutually block via shared/exclusive locks (Ch 7).
**Unbundling databases** — decomposing a database's internal features into independently operated tools connected by event streams (Ch 12).
**Write amplification** — one logical write causing multiple physical disk writes over a system's lifetime (Ch 3).
**Write skew** — two transactions read overlapping data and each write to a different object, jointly violating a shared invariant (Ch 7).
