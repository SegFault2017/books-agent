# Chapter 6: Partitioning

## Core Idea
Partitioning (sharding) breaks a dataset into independent pieces spread across nodes so that both storage and query load scale beyond a single machine — but every partitioning scheme trades off even load distribution against the ability to do efficient range queries, and every partitioned secondary index trades off write cost against read cost.

## Frameworks Introduced
- **Key range partitioning**: assign each partition a contiguous range of keys (like encyclopedia volumes).
  - When to use: when range scans matter (e.g., time-series data queried by time window).
  - How: partition boundaries adapt to the data (often chosen dynamically); within a partition, keep keys sorted to make range scans and concatenated-index queries efficient.
- **Hash partitioning**: apply a hash function to the key, assign a range of hash values to each partition.
  - When to use: when even load distribution matters more than range queries.
  - How: a good hash function makes skewed data uniform; loses the sort order, so range queries typically require querying all partitions (except in compromise schemes like Cassandra's compound keys).
- **Document-partitioned (local) secondary index**: each partition indexes only its own documents.
  - When to use: when write cost matters most and you can tolerate scatter/gather reads.
  - How: writes touch a single partition; reads for a secondary-index value must query *all* partitions and merge results (scatter/gather).
- **Term-partitioned (global) secondary index**: the secondary index itself is partitioned by the indexed term, independent of the primary-key partitioning.
  - When to use: when read cost matters most and you can tolerate slower, more complex writes.
  - How: a single term (e.g., `color:red`) lives on one index partition; a write to one document may need to update several index partitions (ideally atomically, which is hard without distributed transactions).
- **Fixed number of partitions**: create far more partitions than nodes up front (e.g., 1,000 partitions across 10 nodes); rebalancing moves whole partitions, never re-hashes keys.
  - When to use: when you want simple, predictable rebalancing and can estimate a reasonable partition count up front.
  - How: adding a node steals a few whole partitions from each existing node; the partition-to-key mapping never changes, only the partition-to-node mapping.

## Key Concepts
- **Skew** — an unequal distribution of data or load across partitions.
- **Hot spot** — a single partition receiving disproportionately high load; hashing helps with *key* skew but not with a single, extremely popular key (e.g., a celebrity's ID).
- **Rebalancing** — the process of moving data/load between nodes as the cluster grows, shrinks, or fails.
- **Scatter/gather** — querying all partitions in parallel and combining results; the standard access pattern for document-partitioned secondary indexes; prone to tail-latency amplification.
- **Consistent hashing** (as originally defined by Karger et al.) — randomly chosen partition boundaries for CDN-style caching; the book notes this specific technique is *rarely used for databases in practice* despite the term being widely (and often inaccurately) applied to hash partitioning in general.
- **Request routing / service discovery** — the general problem of a client learning which node currently owns a given partition.

## Mental Models
- Think of "hash mod N" as an anti-pattern precisely because it recomputes almost every key's location whenever N changes — use range-based hash-bucket assignment (fixed number of partitions, or dynamic splitting) instead, so growing the cluster only moves whole partitions.
- Use "partitioning by key range vs. by hash" as a direct trade: range partitioning preserves the ability to scan ranges efficiently at the cost of hot-spot risk if access patterns cluster (e.g., all writes going to "today's" partition); hash partitioning spreads load evenly but destroys locality.
- Frame secondary-index partitioning as "pay at write time or pay at read time": local (document-partitioned) indexes make writes cheap and reads expensive (scatter/gather); global (term-partitioned) indexes make reads cheap and writes expensive (multi-partition updates, often asynchronous).

## Anti-patterns
- **Using `hash(key) mod N` to assign partitions**: changing the node count N reshuffles almost all keys, making rebalancing catastrophically expensive. Use a fixed number of hash-range partitions (independent of node count) instead.
- **Using a raw timestamp as the leading part of a partition key for time-series data**: all writes for "now" land on one partition while every other partition sits idle. Prefix with something else (e.g., sensor name) so writes spread across partitions, accepting that range queries now need one sub-query per prefix value.
- **Relying on hashing alone to fix a hot key**: hashing distributes *different* keys evenly, but it does nothing when a single key (e.g., a celebrity's user ID) receives disproportionate traffic — you must explicitly split that key (e.g., append a random suffix) and handle the read-side fan-in yourself.
- **Fully automatic rebalancing combined with automatic failure detection**: a temporarily overloaded/slow node can be misclassified as dead, triggering a rebalance that adds even more load to it and can cascade into a bigger failure. Prefer a human in the loop for rebalancing decisions.

## Reference Tables

| Partitioning strategy | Even load distribution | Efficient range queries | Rebalancing approach |
|---|---|---|---|
| Key range | Only if boundaries adapt to data | Yes | Dynamic split/merge (e.g., HBase splits at 10GB) |
| Hash of key | Yes (assuming good hash fn) | No (destroys sort order) | Fixed partitions (move whole partitions) or dynamic |
| Hash of compound key (Cassandra-style) | Yes, for the hashed part | Yes, within a fixed hashed prefix | Fixed or proportional-to-node |

| Rebalancing strategy | Partition count vs. dataset size | Partition count vs. node count | Used by |
|---|---|---|---|
| Fixed number of partitions | Proportional to dataset (fixed at setup) | Independent | Riak, Elasticsearch, Couchbase, Voldemort |
| Dynamic partitioning | Proportional to dataset (adapts automatically) | Independent | HBase, RethinkDB, MongoDB (v2.4+) |
| Partitions proportional to nodes | Proportional to dataset | Fixed count per node | Cassandra, Ketama |

| Secondary index partitioning | Write cost | Read cost | Used by |
|---|---|---|---|
| Document-partitioned (local) | Low (single partition) | High (scatter/gather across all partitions) | MongoDB, Riak, Cassandra, Elasticsearch, SolrCloud |
| Term-partitioned (global) | High (may touch multiple index partitions, often async) | Low (single partition) | Riak search, Oracle (optional), DynamoDB global secondary indexes |

## Worked Example
**Key-range vs. hash partitioning for a sensor time-series table, including the hot-spot fix.**

Setup: a table of sensor readings keyed by `(timestamp)`, one write per sensor per second, 100 sensors, 10 partitions.

1. **Naive key-range partitioning by timestamp alone**: partition 0 owns `[00:00, 02:24)`, partition 1 owns `[02:24, 04:48)`, etc. (24 hours / 10 partitions). Every write for "right now" — regardless of which of the 100 sensors sent it — lands on whichever single partition currently owns the present time range. Result: 1 partition absorbs 100% of write traffic while the other 9 sit idle. Classic hot spot.
2. **Fix — key-range partitioning by `(sensor_name, timestamp)`**: now partitioning is first by sensor name, then by time within a sensor. Writes spread across sensors → across partitions. The cost: fetching "all sensors in the last hour" now requires one range query per sensor and a client-side merge, instead of a single range scan.
3. **Alternative — hash partitioning by `sensor_id`**: `partition = hash(sensor_id) mod 10` (via hash-range buckets, not literal `mod`). Writes spread evenly across partitions regardless of time. But now a query for "sensor X's readings from the last hour" is efficient (single partition, if sorted by timestamp within the partition — Cassandra's compound-key trick), while "all sensors in the last hour" requires querying all 10 partitions and merging (scatter/gather) since sensors are hash-scattered.
4. **Rebalancing check**: if you later add a node (10 → 11), fixed-partition or dynamic-partition schemes move whole partitions (or split large ones) rather than reshuffling every key — avoid the `hash(key) mod N` anti-pattern, where growing to 11 nodes would relocate the vast majority of all data.

This mirrors the book's own example (celebrity hot spot / sensor prefixing) and shows why "partition by hash" and "partition by range" are not simply "one is better" — the right choice depends on whether your dominant query pattern is point lookups, per-entity ranges, or cross-entity ranges.

## Key Takeaways
1. Partitioning exists purely for scalability (data volume + query throughput) — evaluate any scheme by whether it spreads *both* storage and load evenly.
2. Key-range partitioning preserves range-query efficiency but risks hot spots if the access pattern clusters around the range boundary in use (classic failure: partitioning purely by timestamp).
3. Hash partitioning spreads load evenly but destroys key ordering — accept scatter/gather for range queries, or use a compound key (hash prefix + sorted suffix) to get both, à la Cassandra.
4. Never use `hash(key) mod N` for partition assignment — use a fixed number of hash-range partitions (or dynamic splitting) so the node count can change without reshuffling most keys.
5. Secondary indexes force an explicit choice: document-partitioned (cheap writes, scatter/gather reads) or term-partitioned (expensive multi-partition writes, cheap single-partition reads).
6. A single very hot key defeats hashing entirely — you must manually split it (e.g., random suffix) and handle read-side fan-in.
7. Prefer a human in the loop for rebalancing decisions; fully automatic rebalancing combined with automatic failure detection can cascade a transient slowdown into a bigger outage.

## Connects To
- **Ch 5 (Replication)**: partitioning and replication are orthogonal and combined in practice — each partition has its own leader/followers; this chapter deliberately set replication aside to isolate partitioning concerns.
- **Ch 3 (Storage and Retrieval)**: within-partition data structures (LSM-trees, B-trees) determine how efficiently a partition itself supports range scans, independent of the partitioning scheme.
- **Ch 9 (Consistency and Consensus)**: request routing (which node currently owns a partition) is typically solved via a coordination service (ZooKeeper) whose correctness depends on consensus.
- **Ch 7 (Transactions)**: writes that must touch multiple partitions atomically (e.g., updating a global secondary index) run into the same multi-partition atomicity problem that motivates distributed transactions.
- **Ch 10 (Batch Processing) / Ch 12**: parallel query execution across partitions in MPP databases builds directly on the partitioning schemes introduced here.
