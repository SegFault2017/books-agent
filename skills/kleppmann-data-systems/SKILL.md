---
name: kleppmann-data-systems
description: "Knowledge base from \"Designing Data-Intensive Applications\" by Martin Kleppmann. Use when applying Kleppmann's frameworks for replication, partitioning, transactions, consensus, and stream processing, studying the book, or referencing its concepts."
---

<!-- argument-hint: [topic, framework name, or chapter number] -->

# Designing Data-Intensive Applications
**Author**: Martin Kleppmann | **Pages**: ~613 | **Chapters**: 12 | **Generated**: 2026-09-16

## How to Use This Skill

- **Without arguments** — load core frameworks for reference
- **With a topic** — ask about `replication`, `consensus`, `write skew`, or another indexed topic; I find and read the relevant chapter
- **With chapter** — ask for `ch09`; I load that specific chapter
- **Browse** — ask "what chapters do you have?" to see the full index

When you ask about a topic not covered in Core Frameworks below, I will read
the relevant chapter file before answering.

---

## Core Frameworks & Mental Models

**The Three Concerns**: evaluate every data system on reliability (works correctly despite faults), scalability (copes with growth in a specific load parameter), and maintainability (operability, simplicity, evolvability) — independently; one does not imply another.

**Load parameters over "is it scalable?"**: scalability is meaningless as an unqualified label. Identify the specific number that characterizes your load (RPS, read:write ratio, fan-out) and ask "what happens if this doubles?" Use percentiles (p50/p95/p99), never averages, for performance — and never average percentiles across machines/windows; add histograms instead.

**Data model selection by relationship shape**: one-to-many/tree data → document model (schema-on-read, best locality). Many-to-many, moderate → relational (cheap joins, schema-on-write). Many-to-many, highly interconnected → graph (property graph / triple-store). Watch for many-to-many relationships creeping into a document-modeled app — that's the signal to migrate.

**Storage engine philosophies**: log-structured (LSM-trees: memtable → sorted immutable SSTables → background compaction) favors write throughput via sequential I/O. Update-in-place (B-trees: fixed pages + write-ahead log) favors predictable read latency. OLTP (small-key lookups, seek-bound) and OLAP (full-column scans, bandwidth-bound → column-oriented storage) have fundamentally different bottlenecks — never run heavy analytics against a production OLTP store.

**Backward/forward compatibility**: every encoding format is a bet on schema evolution. Backward compatible = new code reads old data. Forward compatible = old code reads new data. Thrift/Protobuf use numeric field tags (never reuse); Avro resolves by field name between writer's and reader's schema. Data outlives code — databases need both directions; rolling upgrades need both directions for any concurrently-deployed service.

**Replication topologies**: single-leader (default, no conflicts, but failover can lose acknowledged writes under async replication) vs. multi-leader (multi-DC, offline clients, needs conflict resolution — never default to Last-Write-Wins, it silently drops writes) vs. leaderless (Dynamo-style, quorum reads/writes `w+r>n` — overlap is not linearizability). Detect concurrency via happens-before/version vectors, never wall-clock time.

**Partitioning trade-offs**: key-range partitioning preserves range-query efficiency but risks hot spots (never partition by a bare timestamp prefix alone). Hash partitioning spreads load evenly but destroys sort order (recover per-entity ranges via a compound hash-prefix + sorted-suffix key). Never use `hash(key) mod N` — use a fixed number of hash-range partitions so node-count changes don't reshuffle most keys. Secondary indexes: document-partitioned (cheap writes, scatter/gather reads) vs. term-partitioned (expensive writes, cheap reads).

**Transaction isolation ladder**: Read Committed (blocks dirty reads/writes only) → Snapshot Isolation/MVCC (adds read-skew protection, readers never block writers) → Serializable (2PL: pessimistic, mutual blocking, deadlock risk; SSI: optimistic, abort-on-conflict, near-snapshot-isolation speed). Write skew (two transactions read overlapping data, each writes a *different* object, jointly violating a shared invariant) is invisible to same-row conflict detection — only serializable isolation or explicit locks catch it.

**Distributed systems fault model**: a node can never distinguish "message lost," "peer dead," and "response lost" from the outside. Model timing as partially synchronous (usually fine, occasionally arbitrarily bad) and node faults as crash-recovery (non-Byzantine, for a single trust domain). Distinguish safety properties (must hold unconditionally) from liveness properties (may have caveats like "assuming a majority survive"). Never trust a lock/lease without a fencing token enforced by the resource itself, not the client's self-belief.

**Linearizability vs. serializability**: easily confused, structurally different. Serializability = transactions behave as if run in some serial order (isolation property, Ch 7). Linearizability = a single register appears to have exactly one up-to-date copy (recency property, Ch 9). CAP theorem, properly scoped: during an actual network partition, choose consistency (linearizability) or availability — not a general "pick 2 of 3" menu.

**Consensus = total order broadcast = linearizable compare-and-set**: these three problems are mathematically equivalent. Real algorithms (Viewstamped Replication, Paxos, Raft, Zab) all use the same trick — monotonic epoch/term numbers plus overlapping election/proposal quorums — to break the "need a leader to elect a leader" circularity. Never hand-roll consensus; use ZooKeeper/etcd.

**Batch → stream unification**: batch processing (bounded input, MapReduce shuffle = partition+sort+copy) and stream processing (unbounded input, log-based brokers like Kafka) share the same derived-data philosophy: rebuild deterministically from an immutable log rather than mutate in place. Change Data Capture and event sourcing both derive state from a log, avoiding the dual-write race condition (two independently-written systems silently diverging).

**Unbundling & the end-to-end argument**: no single database serves every access pattern — federate reads, synchronize writes via an ordered log with idempotent consumers, not distributed transactions (2PC/XA has poor fault tolerance and "severely limits its usefulness" per Kleppmann). Split "consistency" into timeliness (often relaxable) and integrity (usually non-negotiable, needs active auditing). Correctness-critical deduplication must use a request ID generated at the true application endpoint — no lower-layer mechanism (TCP, DB) can substitute.

---

## Chapter Index

| # | Title | Key Frameworks |
|---|-------|----------------|
| [ch01](chapters/ch01-reliable-scalable-maintainable.md) | Reliable, Scalable, and Maintainable Applications | Three Concerns, load parameters, percentiles |
| [ch02](chapters/ch02-data-models-query-languages.md) | Data Models and Query Languages | schema-on-read/write, document vs. relational vs. graph |
| [ch03](chapters/ch03-storage-and-retrieval.md) | Storage and Retrieval | LSM-trees, B-trees, OLTP vs. OLAP, column storage |
| [ch04](chapters/ch04-encoding-and-evolution.md) | Encoding and Evolution | backward/forward compatibility, Thrift/Protobuf/Avro |
| [ch05](chapters/ch05-replication.md) | Replication | single/multi-leader/leaderless, quorums, conflict resolution |
| [ch06](chapters/ch06-partitioning.md) | Partitioning | key-range vs. hash partitioning, secondary index partitioning |
| [ch07](chapters/ch07-transactions.md) | Transactions | ACID, isolation levels, write skew, 2PL, SSI |
| [ch08](chapters/ch08-trouble-with-distributed-systems.md) | The Trouble with Distributed Systems | partial failure, unreliable clocks, fencing tokens |
| [ch09](chapters/ch09-consistency-and-consensus.md) | Consistency and Consensus | linearizability, CAP, total order broadcast, consensus |
| [ch10](chapters/ch10-batch-processing.md) | Batch Processing | MapReduce, joins, Unix philosophy, dataflow engines |
| [ch11](chapters/ch11-stream-processing.md) | Stream Processing | CDC, event sourcing, log-based brokers, windowing |
| [ch12](chapters/ch12-future-of-data-systems.md) | The Future of Data Systems | unbundling, end-to-end argument, timeliness vs. integrity, ethics |

## Topic Index

- **2PC / Two-Phase Commit** → ch09
- **2PL / Two-Phase Locking** → ch07
- **B-trees** → ch03
- **Batch processing / MapReduce** → ch10
- **CAP theorem** → ch09
- **CDC (Change Data Capture)** → ch11, ch12
- **Column-oriented storage** → ch03
- **Consensus** → ch09
- **Data models (document/relational/graph)** → ch02
- **Encoding formats (JSON/Thrift/Protobuf/Avro)** → ch04
- **End-to-end argument** → ch12
- **Event sourcing** → ch11
- **Fencing tokens** → ch08, ch09
- **Isolation levels** → ch07
- **Lamport timestamps** → ch09
- **Linearizability** → ch09
- **LSM-trees** → ch03
- **Partitioning (sharding)** → ch06
- **Quorums (w+r>n)** → ch05, ch09
- **Rebalancing** → ch06
- **Replication (leader models)** → ch05
- **Secondary indexes** → ch06
- **Serializability** → ch07
- **Skew / hot spots** → ch06, ch10
- **Stream processing / Kafka** → ch11
- **Total order broadcast** → ch09
- **Transactions / ACID** → ch07
- **Unbundling databases** → ch12
- **Unreliable clocks / networks** → ch08
- **Write skew** → ch07

## Supporting Files

- [glossary.md](glossary.md) — all key terms with definitions
- [patterns.md](patterns.md) — all techniques and design patterns
- [cheatsheet.md](cheatsheet.md) — quick reference tables and decision guides
- Reader Notes (external, see below) — deeper Q&A-derived notes on ch01 and ch02

## Reader Notes (external)

Personal notes from Q&A sessions, kept alongside the source PDF rather than inside this skill folder:

- [ch01: Percentiles in Practice & Twitter fan-out worked example](/Users/rtan/Documents/_01_CS/_170_books/designing-data-intensive-applications/ch01-percentiles-and-worked-example.md) — forward decay/t-digest/HdrHistogram, Figures 1-1 through 1-3, read-time vs. write-time fan-out, the hybrid resolution
- [ch02: Many-to-many relationships & schema flexibility](/Users/rtan/Documents/_01_CS/_170_books/designing-data-intensive-applications/ch02-notes-many-to-many.md) — the relationship-type test, why nesting breaks for many-to-many, join emulation, the N+1 problem, the IMS/CODASYL/relational history, schema-on-read vs. schema-on-write

---

## Scope & Limits

This skill covers the book content only, extracted via technical-mode pdftotext parsing (docling was unavailable in the source environment — tables/figures were linearized to text, so exact figure/table formatting from the book is reconstructed rather than reproduced verbatim). For hands-on implementation in your codebase, combine with project-specific tools. For topics beyond this book, check related skills or ask the agent directly.
