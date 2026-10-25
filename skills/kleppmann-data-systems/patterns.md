# Patterns & Techniques — Designing Data-Intensive Applications

## Write-time fan-out vs. read-time fan-in
**When to use**: high read:write ratio with an expensive aggregation (timelines, feeds).
**How**: precompute per-reader caches at write time so reads become cheap lookups; fall back to read-time fan-in for extreme-fan-out writers (celebrities) to avoid write amplification blowup.
**Trade-offs**: moves cost from read path to write path; hybrid (most users fan out, outliers fan in) beats either pure strategy under skew. (Ch 1)

## LSM-tree write path (memtable + SSTable + compaction)
**When to use**: write-heavy workloads where read latency predictability matters less than write throughput.
**How**: buffer writes in an in-memory sorted structure (memtable) backed by a WAL; flush to sorted, immutable on-disk segments (SSTables); merge segments in the background (compaction), keeping only the latest value per key.
**Trade-offs**: much higher write throughput and better compression than B-trees; reads may need to check multiple segments, and compaction can spike tail latency. (Ch 3)

## B-tree update-in-place + write-ahead log
**When to use**: read-heavy or latency-predictable workloads; the default for most relational databases.
**How**: fixed-size pages form a balanced tree; every page modification is first appended to a WAL for crash recovery before being applied in place.
**Trade-offs**: predictable read latency, mature tooling; write amplification from WAL double-write and page splits/fragmentation. (Ch 3)

## Schema evolution via optional fields + tags/names
**When to use**: any encoding format that must support rolling upgrades or long-lived stored data.
**How**: Thrift/Protobuf — never reuse or require a new numeric field tag; Avro — rely on writer's/reader's schema resolution by field name with defaults for missing fields.
**Trade-offs**: correctly done, achieves both backward and forward compatibility with zero downtime; get it wrong (required new field, reused tag) and rolling upgrades break silently. (Ch 4)

## Leader-based (single-leader) replication
**When to use**: default replication choice when you don't need multi-region write locality or offline writes.
**How**: one leader accepts writes, streams an ordered replication log to followers; reads can go anywhere.
**Trade-offs**: no conflict resolution needed; single point of write availability, and failover risks lost writes (async) or availability loss (sync). (Ch 5)

## Multi-leader / leaderless replication with conflict resolution
**When to use**: multi-datacenter writes, offline-capable clients, collaborative editing (multi-leader); max write availability under partition (leaderless).
**How**: detect concurrency via version vectors / happens-before, not wall-clock time; resolve via LWW (risky), application-level merge, or CRDTs.
**Trade-offs**: higher write availability and lower write latency across regions, at the cost of needing explicit, correct conflict resolution. (Ch 5)

## Quorum reads/writes (w + r > n)
**When to use**: leaderless replication needing a tunable consistency/latency/availability trade-off.
**How**: require w acknowledgments per write and r responses per read from n replicas such that w+r>n, guaranteeing read/write set overlap.
**Trade-offs**: overlap ≠ linearizability — variable network delay and sloppy quorums still allow stale reads; read repair narrows but doesn't close the gap. (Ch 5, 9)

## Fixed-number-of-partitions rebalancing
**When to use**: want simple, predictable rebalancing without reshuffling most keys as the cluster grows.
**How**: create far more hash-range partitions than nodes up front; adding/removing a node moves whole partitions, never re-hashes individual keys.
**Trade-offs**: must estimate a reasonable partition count ahead of time; avoids the `hash(key) mod N` anti-pattern entirely. (Ch 6)

## Compound-key partitioning (hash prefix + sorted suffix)
**When to use**: need both even load distribution and efficient per-entity range queries (e.g., Cassandra-style time series).
**How**: hash the leading part of the key (e.g., sensor ID) for distribution, keep the trailing part (e.g., timestamp) sorted within each partition.
**Trade-offs**: per-entity ranges become efficient (single partition); cross-entity ranges still require scatter/gather. (Ch 6)

## Explicit locking / atomic operations / SSI for lost updates and write skew
**When to use**: any read-modify-write cycle or multi-object invariant under concurrent access.
**How**: prefer database-native atomic operations (increment, compare-and-set) first; use explicit `SELECT ... FOR UPDATE` locks for cross-object invariants (write skew); use full serializable isolation (2PL or SSI) when correctness must be guaranteed without manual lock reasoning.
**Trade-offs**: atomic ops are cheapest but limited in expressiveness; explicit locks require careful application logic; serializable isolation is safest but costs throughput (2PL) or requires abort/retry handling (SSI). (Ch 7)

## Fencing tokens for locks/leases
**When to use**: any distributed lock or lease protecting a shared resource across a network.
**How**: the lock service issues a monotonically increasing token on every grant; the protected resource itself rejects any write carrying an older token than one it has already accepted.
**Trade-offs**: requires the resource to participate (can't be purely client-side); the only reliable defense against a paused/stale client acting on an expired lease. (Ch 8)

## Epoch numbering + overlapping quorums (consensus)
**When to use**: leader election and any decision requiring fault-tolerant agreement.
**How**: increment a monotonic epoch on every election; require a quorum for both the election and every subsequent proposal so the two quorums are guaranteed to overlap by at least one node.
**Trade-offs**: breaks the "need a leader to elect a leader" circularity; requires a strict majority of nodes to be reachable, and is sensitive to unreliable-network edge cases (e.g., Raft's flaky-link leadership churn). (Ch 9)

## Total-order-broadcast-backed linearizable compare-and-set
**When to use**: implementing a uniqueness constraint (usernames, seat booking) across nodes without ad hoc locking.
**How**: append a claim message to a totally-ordered log; wait for it to be delivered back; if your message is first for that key, commit; otherwise abort.
**Trade-offs**: gives linearizable writes cheaply on top of total order broadcast; reads need extra work (sync-point, quorum read, or synchronous replica) to also be linearizable. (Ch 9)

## Sort-merge / broadcast hash / partitioned hash joins
**When to use**: joining two large datasets in a batch job — pick based on size and existing partitioning of the inputs.
**How**: sort-merge (reduce-side) needs no assumptions but requires a full shuffle; broadcast hash (map-side) loads a small input into memory per mapper, no shuffle; partitioned hash requires both inputs pre-partitioned identically by key.
**Trade-offs**: broadcast/partitioned hash joins avoid the shuffle's network and sort cost but only apply under specific size/layout preconditions. (Ch 10)

## Change Data Capture (CDC)
**When to use**: keeping derived stores (search index, cache, warehouse) consistent with a system-of-record database without dual writes.
**How**: parse the database's replication log/binlog (Debezium, Maxwell) or use native logical replication; take an initial consistent snapshot, then apply the change stream from that offset onward; use log compaction to bound history.
**Trade-offs**: eliminates the dual-write race condition entirely by making exactly one system the ordering authority; downstream consumers only get eventual (not linearizable) consistency. (Ch 11)

## Event sourcing + CQRS
**When to use**: domains needing strong auditability, debuggability, or the ability to add new read views retroactively.
**How**: log immutable, intent-carrying events (not row mutations); derive current state and any number of read-optimized views by deterministically replaying the log.
**Trade-offs**: read views are cheaply rebuildable/discardable; write-side complexity increases (command validation, event schema evolution). (Ch 11)

## Request-ID-based idempotent multi-partition writes
**When to use**: an operation (e.g., a funds transfer) spans partitions and must apply exactly once despite retries/crashes.
**How**: client generates a unique request ID and appends a single-partition, single-object log entry; downstream stream processors derive per-partition debit/credit instructions carrying the same request ID; per-partition consumers deduplicate by request ID.
**Trade-offs**: achieves effectively-once, cross-partition atomicity without 2PC or distributed transactions, at the cost of asynchronous (not immediately consistent) settlement. (Ch 12)

## End-to-end request deduplication
**When to use**: any retryable operation crossing multiple network hops (client → app server → broker → database).
**How**: generate the deduplication ID at the true endpoint (e.g., in the browser/mobile client) and pass it through every layer, rather than relying on TCP- or database-level dedup alone.
**Trade-offs**: only a true end-to-end ID prevents duplicate execution when the client itself retries; lower-layer dedup only reduces (doesn't eliminate) the problem. (Ch 12)
