# Chapter 11: Stream Processing

## Core Idea
Stream processing applies batch processing's derived-data philosophy to unbounded, never-ending event data; a database's replication log and a message broker's log are the same underlying abstraction, and treating database writes themselves as an event stream (change data capture, event sourcing) is what lets you keep search indexes, caches, and other derived systems reliably in sync without distributed transactions.

## Frameworks Introduced
- **Change Data Capture (CDC)**: observing all writes made to a database and extracting them as a stream so other systems (search index, cache, warehouse) can be kept as *followers* of the database *leader*.
  - When to use: whenever you need multiple derived data stores to stay consistent with a system of record without dual writes.
  - How: parse the replication log/binlog (Debezium, Maxwell, Bottled Water) or use DB-native triggers; take an initial consistent snapshot, then apply the change stream from that snapshot's offset onward; use log compaction to avoid keeping unbounded history.
- **Event Sourcing**: application state is derived entirely from an append-only, immutable log of events representing things that happened at the *application* level (not low-level row mutations).
  - When to use: domains where auditability, debuggability, and the ability to add new derived views later matter more than write-time complexity.
  - How: distinguish **commands** (may fail, not yet durable) from **events** (validated, immutable, cannot be rejected by consumers); derive current state and any number of read-optimized views by replaying the log with a deterministic transformation.
- **Log-based message brokers** (Kafka, Kinesis): combine a database's durability with a messaging system's low-latency notification by using a partitioned, append-only, replayable log instead of destructive-delete queues.
  - When to use: high message throughput, ordering matters, need to replay history or add late-joining consumers.
  - How: producers append to a topic-partition; consumers track a monotonically increasing **offset** per partition (analogous to a replication log sequence number); log segments age out after a retention window instead of on acknowledgment.
- **Lambda architecture**: run the same computation through both a batch layer (slow, exact, reprocesses everything) and a stream layer (fast, approximate) and merge the results.
  - Kleppmann's verdict: influential but flawed — maintaining duplicate logic in two frameworks and merging two outputs is expensive; prefer unifying batch and stream in one engine (Flink/Beam-style) with replayable input, exactly-once semantics, and event-time windowing.

## Key Concepts
- **Event**: a small, immutable, timestamped record of something that happened — the streaming equivalent of a batch record.
- **Topic / partition / offset**: a topic groups related events; partitions enable parallelism; the offset is a consumer's bookmark, functionally identical to a database replication log sequence number.
- **Log compaction**: retaining only the latest value per key (discarding older overwritten values), enabling a compacted topic to serve as a full database snapshot without unbounded storage growth.
- **Backpressure vs. buffering vs. dropping**: the three responses a system can have when producers outpace consumers; log-based brokers effectively use large, disk-backed, fixed-size buffering.
- **Event time vs. processing time**: the timestamp when something actually happened vs. when the stream processor observed it — confusing the two produces spurious spikes/dips when reprocessing backlogs.
- **Stragglers**: late-arriving events whose window has already been declared "complete"; handled by dropping, publishing corrections, or explicit low-watermark messages.
- **CQRS (Command Query Responsibility Segregation)**: separating the write-optimized form (event log) from one or more read-optimized derived views, so denormalization in the read view is safe because it's mechanically re-derivable.

## Mental Models
- **State is the integral of a stream; a changelog is the derivative of state** — mutable state and an append-only event log "are two sides of the same coin" (Kleppmann, echoing Pat Helland: "the log is the truth; the database is a cache of the latest values in the log").
- Use **dual writes → race condition** as the default failure mode to watch for: if two systems (DB + search index) are each written to independently, concurrent writers can leave them permanently, silently inconsistent — CDC/event sourcing fixes this by making exactly one system the leader.
- Think of **windows as a knob between write-path and read-path work**: no index = expensive reads (scan everything); precomputed index/cache/materialized view = cheap reads, expensive writes. Search indexes, caches, and read replicas are all instances of the same write/read boundary trade-off introduced with Twitter's timeline example in Ch 1.

## Anti-patterns
- **Dual writes without a single ordering authority**: writing to a database and a search index as two independent operations invites the interleaving race shown in Fig. 11-4 — neither system is "in charge," so they can silently diverge with no error raised.
- **Windowing by processing time when correctness matters**: redeploys or backlogs create fake traffic spikes in metrics; use event-time timestamps embedded in the record instead.
- **Trusting device clocks for event time without correction**: client clocks can be wrong or manipulated — log device-time-at-event, device-time-at-send, and server-time-at-receive, and use the offset between the latter two to correct the first.
- **Load-balancing consumers across a partition while relying on ordering**: acknowledgment-based redelivery under load balancing (AMQP/JMS-style) can reorder messages (Fig. 11-2); if causal order matters, don't combine load balancing with per-message redelivery — use log-based partition assignment instead.

## Code Examples
No first-class code listings in this chapter (it's architecture/protocol-focused); the closest is the SQL sketch of a materialized timeline view below.

## Reference Tables
| | AMQP/JMS-style broker | Log-based broker (Kafka, Kinesis) |
|---|---|---|
| Delivery unit | Individual message, deleted on ack | Partition, tracked by consumer offset |
| Replay old messages | No — gone once acknowledged | Yes — read from any offset, bounded by retention |
| Fan-out to multiple consumers | Requires separate queues per consumer group | Free — reading doesn't delete |
| Ordering under load balancing | Broken by redelivery (Fig. 11-2) | Preserved per-partition |
| Best for | Expensive per-message tasks, order doesn't matter | High throughput, order matters, need replay |

| Join type | Inputs | Window semantics |
|---|---|---|
| Stream-stream (window join) | Two event streams | Bounded time window (e.g., search→click within 1 hour) |
| Stream-table (enrichment) | Activity stream + changelog | Changelog side uses an unbounded ("beginning of time") window; latest value wins |
| Table-table (materialized view) | Two changelogs | Every change on either side re-joins with the current state of the other |

## Worked Example
**Keeping a search index in sync with a database via change data capture** (Fig. 11-5, "Databases and Streams"): instead of the application dual-writing to the database and the search index (which risks the Fig. 11-4 race), make the database the single leader.
1. A CDC tool (e.g., Debezium for MySQL, Bottled Water for Postgres) parses the database's write-ahead log/binlog and emits a change event for every insert/update/delete, preserving the exact order they were committed.
2. These change events are published to a log-based message broker topic, partitioned by primary key so all changes to one record stay in order.
3. A consumer (itself a simple stream processor) reads this topic and applies each change to the search index in the same order.
4. Because the changelog preserves commit order and the search index only ever consumes from this one stream, the index converges to match the database — no application code needs to know CDC is happening, and adding a *second* derived system (e.g., a cache) just means adding a second independent consumer of the same topic.
5. To bootstrap the index for the first time, take a consistent snapshot of the database at a known log position/offset, load it, then start consuming the changelog from that offset onward.

## Key Takeaways
1. A log-based message broker is structurally the same idea as a database's replication log — both are the streaming equivalent of a "leader" whose ordered writes downstream followers apply.
2. Change data capture and event sourcing both derive state from an immutable event log, but at different abstraction levels: CDC captures low-level row mutations after the fact; event sourcing designs the application around explicit, intent-carrying events from the start.
3. Never do dual writes to keep two data stores in sync — pick one system as the ordering authority (via CDC or event sourcing) and derive the rest asynchronously.
4. Distinguish event time from processing time explicitly; conflating them silently corrupts windowed aggregations whenever there's lag, redeployment, or reprocessing.
5. Exactly-once ("effectively-once") semantics in streaming is achieved via microbatching/checkpointing internally, plus idempotent writes or distributed transactions for any output that escapes the stream processor.
6. Stream-stream, stream-table, and table-table joins all reduce to the same mechanism (bring related data together, keyed) but differ in what "current" means for each side — get this wrong and joins become nondeterministic (see slowly changing dimensions).

## Connects To
- **Ch 5 (Replication)**: replication logs and log sequence numbers are the direct ancestor of stream offsets and log-based broker semantics.
- **Ch 3**: log compaction is the same mechanism as in log-structured storage engines (SSTables/LSM-trees), reused here for changelog topics.
- **Ch 10 (Batch Processing)**: stream processing is explicitly framed as batch processing generalized to unbounded input; partitioning and join algorithms carry over directly.
- **Ch 12 (The Future of Data Systems)**: change data capture and event sourcing become the foundation for "unbundling the database" and unbundled derived-data architectures.
