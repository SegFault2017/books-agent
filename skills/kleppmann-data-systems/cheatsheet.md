# Cheatsheet — Designing Data-Intensive Applications

## Decision rules

- **Choosing a data model**: one-to-many/tree, usually loaded together → document. Many-to-many, moderate complexity → relational (joins are cheap). Many-to-many, highly interconnected/heterogeneous → graph (property graph or triple-store). If many-to-many relationships are *creeping in* to a document-modeled app as features grow, that's your signal to migrate before it gets worse.
- **Choosing a storage engine**: write-heavy, throughput matters more than read tail latency → LSM-tree (Cassandra, RocksDB, HBase). Read-heavy or need predictable latency → B-tree (most relational DBs). Analyst-facing, full-column-scan aggregation → column-oriented store, not either of the above.
- **Choosing an encoding format**: schema evolves independently per side and comes from dynamic sources (e.g., DB-generated) → Avro (name-based resolution). Schema evolves via manual IDL edits, want maximum tooling/compactness → Thrift/Protobuf (tag-based; never reuse or require a new tag). Human-debuggability matters more than size → JSON (accept ambiguous number/binary types).
- **Choosing a replication topology**: default, single-region, no offline writes → single-leader. Multi-datacenter or offline-capable clients → multi-leader + conflict resolution (never LWW by default). Max write availability, tolerate eventual consistency → leaderless + quorums.
- **Choosing a partitioning key**: range queries over one dimension matter (time series, alphabetical) → key-range partitioning, but never a bare timestamp/monotonic prefix alone (hot spot) — compound with a spreading prefix. Even load matters more than range queries → hash partitioning; recover per-entity ranges via a compound key (hash prefix + sorted suffix, à la Cassandra).
- **Choosing secondary-index partitioning**: write-heavy → document-partitioned/local (pay at read time via scatter/gather). Read-heavy → term-partitioned/global (pay at write time via multi-partition, often async updates).
- **Choosing an isolation level**: know your race-condition exposure first (see Isolation matrix below) before defaulting to "the app doesn't need transactions" or "just use serializable."
- **Choosing consistency for cross-system integration**: need to keep two heterogeneous stores in sync → CDC/event log with idempotent consumers, not distributed transactions (2PC/XA) — Kleppmann explicitly argues XA's poor fault tolerance "severely limits its usefulness."
- **When you feel the urge to use a physical timestamp to order events across nodes**: stop — that's a sign you need a logical clock (Lamport timestamp) at minimum, or full consensus if you also need to know when the order is *finalized* (e.g., uniqueness constraints).

## Isolation-level anomaly matrix

| Isolation Level | Dirty Read | Dirty Write | Read Skew | Lost Update | Write Skew | Phantom |
|---|---|---|---|---|---|---|
| Read Committed | ✗ prevented | ✗ prevented | possible | possible | possible | possible |
| Snapshot Isolation | ✗ prevented | ✗ prevented | ✗ prevented | usually detected* | possible | possible |
| Serializable (2PL/SSI) | ✗ prevented | ✗ prevented | ✗ prevented | ✗ prevented | ✗ prevented | ✗ prevented |

\*MySQL/InnoDB's "repeatable read" does **not** auto-detect lost updates — verify per vendor.

## Consistency-model trade-off matrix

| Guarantee | Order type | Survives partition? | Coordination cost |
|---|---|---|---|
| Linearizability | total | no | high (∝ network delay uncertainty — Attiya-Welch) |
| Sequential consistency | total, not real-time-recent | better | moderate |
| Causal consistency | partial | yes (strongest that does) | low |
| Eventual consistency | none (convergence only) | yes | lowest |

## Replication trade-off matrix

| Approach | Writers | Conflict resolution | Best fit |
|---|---|---|---|
| Single-leader | one | none needed | default choice |
| Multi-leader | many (per region/device) | required | multi-DC, offline, collaborative editing |
| Leaderless | any replica | required (version vectors) | max availability, Dynamo-style |

## Thresholds & defaults

- **Consensus needs a strict majority**: 3 nodes tolerate 1 failure; 5 nodes tolerate 2. There is no way around this for safety.
- **Byzantine fault tolerance needs >2/3 correct nodes** (at most 1 of 4 may misbehave) — only worth the cost in adversarial multi-party settings, not inside one trust domain.
- **Percentiles, not averages, for SLAs**: track p50/p95/p99 (Amazon-style p999 usually has diminishing returns) — never average percentiles across machines/windows; add the underlying histograms instead.
- **Google's assumed clock drift**: ~200ppm — meaning ~6ms drift per 30s resync, ~17s drift per daily resync; don't trust clock precision beyond your actual resync interval implies.
- **NTP over the public internet**: best-case accuracy ~35ms, can spike to ~1s under congestion — never assume sub-second cross-node timestamp ordering without something like TrueTime.
- **VoltDB cross-partition transaction throughput**: reported ~1,000/sec ceiling, not improved by adding machines — a concrete illustration of "cross-partition transactions don't scale," independent of vendor.
- **Distributed transaction overhead**: MySQL distributed transactions reported >10x slower than single-node — treat this as the order of magnitude to expect from XA/2PC, not a MySQL-specific quirk.

## Tells & smells

- **"It's schemaless"** → the schema still exists, just implicitly, enforced by application code at read time instead of by the database at write time. Ask "what happens when a reader doesn't know about a new field?"
- **Feature request adds "linked entities" or "recommendations between records" to a document-modeled app** → many-to-many relationships are creeping in; the document model is starting to be the wrong fit.
- **A vendor calls their isolation level "serializable" or "repeatable read"** → verify what it actually implements; Oracle's "serializable" is snapshot isolation, PostgreSQL/MySQL's "repeatable read" is snapshot isolation, not the SQL standard's definition.
- **A hot partition/reducer that won't go away no matter how you rehash** → you likely have a single very popular key (celebrity, viral item), not general key skew; hashing can't fix this — split the key explicitly.
- **A distributed lock/lease-protected resource with no token check on the resource side** → vulnerable to a paused/stale client corrupting state; add fencing tokens.
- **Two systems (DB + search index, DB + cache) each written to independently by application code** → classic dual-write race condition; make one system the ordering authority (CDC) instead.
- **A transaction retried after a timeout with no idempotency key** → risk of double-execution (e.g., double money transfer) even under full ACID — the database can't protect you from this, only end-to-end request IDs can.
- **"We need CAP: pick 2 of 3" appearing in a design doc** → outdated framing per Kleppmann; ask instead "what do we do specifically during a partition — refuse writes, or risk staleness?"
- **A design assumes a global monotonic transaction ID or timestamp across partitions** → this is the "need consensus to avoid consensus" trap; check whether you actually need cross-partition ordering or just per-partition (much cheaper).
- **"In my experience, 99% of people don't need X"** used to reject a data-integration/consistency requirement → treat as a red flag for insufficient breadth of consideration in a large org, per Kleppmann's own callout.
