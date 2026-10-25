# Patterns — System Design Interview (Alex Xu)

## Stateless Web Tier + Shared State Store
**When to use**: before horizontal autoscaling. (Ch 1)
**How**: move sessions to NoSQL/Redis; LB routes to any server.
**Trade-offs**: extra hop for state; removes sticky sessions.

## Read-Through Cache
**When to use**: read-heavy, rarely changed data. (Ch 1, 8, 11)
**How**: check cache → miss → DB → populate with TTL; LRU eviction; multiple nodes.
**Trade-offs**: staleness, cache/DB inconsistency; SPOF if single node.

## Master–Slave Replication
**When to use**: read scaling + failover. (Ch 1)
**How**: writes → master; reads → slaves; promote slave on master loss.
**Trade-offs**: promoted slave may be stale.

## Sharding
**When to use**: data or write load exceeds one DB. (Ch 1, 13, 15)
**How**: choose even-distributing key; hash or shard map manager.
**Trade-offs**: resharding, hotspots, no cross-shard joins (de-normalize).

## Consistent Hashing with Virtual Nodes
**When to use**: elastic clusters of caches/stores/crawlers. (Ch 5, 6, 9)
**How**: servers and keys on ring; clockwise lookup; 100–200 vnodes/server.
**Trade-offs**: vnode metadata; affected range must be migrated.

## Message Queue Decoupling
**When to use**: slow work, independent scaling, failure isolation. (Ch 1, 10, 14)
**How**: producers publish; worker pool consumes; scale workers on queue depth; one queue per channel.
**Trade-offs**: async complexity, at-least-once delivery → dedupe.

## Rate Limiting (Token Bucket / Sliding Window Counter)
**When to use**: protect APIs from abuse and cost. (Ch 4)
**How**: middleware + Redis counters (INCR/EXPIRE or Lua); 429 + X-Ratelimit headers.
**Trade-offs**: tuning parameters; races; cross-DC sync.

## Quorum Replication (N/W/R)
**When to use**: tunable consistency in a KV store. (Ch 6)
**How**: replicate to next N unique nodes; W+R>N strong; sloppy quorum + hinted handoff under failure.
**Trade-offs**: latency rises with W/R.

## Vector Clocks
**When to use**: detect concurrent writes in AP stores. (Ch 6)
**How**: per-item [server, version] list; siblings → client reconciles.
**Trade-offs**: client complexity; truncate long clocks.

## Gossip Failure Detection
**When to use**: large decentralized clusters. (Ch 6)
**How**: heartbeat counters gossiped to random peers; stale → down.
**Trade-offs**: detection delay.

## Merkle-Tree Anti-Entropy
**When to use**: repairing permanently diverged replicas. (Ch 6)
**How**: bucket keys, hash up to root; descend only on mismatches.
**Trade-offs**: tree maintenance.

## LSM Write / Read Path
**When to use**: write-heavy storage engines. (Ch 6)
**How**: commit log → memtable → flush to SSTable; reads memtable → Bloom filter → SSTables.
**Trade-offs**: compaction; read amplification.

## Snowflake IDs
**When to use**: unique, sortable 64-bit IDs without coordination. (Ch 7, 12)
**How**: timestamp | DC | machine | sequence.
**Trade-offs**: clock sync; 69-year horizon.

## Base-62 Short Codes
**When to use**: URL shortening. (Ch 8)
**How**: unique ID → base 62; 7 chars ≈ 3.5 T codes.
**Trade-offs**: guessable sequence.

## Hybrid Fanout
**When to use**: social feeds with celebrities. (Ch 11)
**How**: push IDs to followers' feed cache for normal users; pull celebrity posts at read; hydrate from caches.
**Trade-offs**: merge logic at read time.

## URL Frontier (Priority + Politeness)
**When to use**: web crawling. (Ch 9)
**How**: prioritizer → front queues; router → per-host back queues → one worker each with delay.
**Trade-offs**: memory/disk hybrid storage.

## Per-Recipient Inbox
**When to use**: small group chat. (Ch 12)
**How**: copy each message into each member's sync queue; devices track cur_max_message_id.
**Trade-offs**: write amplification — not for huge groups.

## Heartbeat Presence + Pub/Sub Fanout
**When to use**: online indicators. (Ch 12)
**How**: heartbeat every 5 s, offline after x s silence; channel per friend pair.
**Trade-offs**: O(friends) events; lazy fetch for big groups.

## Trie with Cached Top-K
**When to use**: autocomplete. (Ch 13)
**How**: cap prefix length; cache top k at every node; rebuild offline; serve from distributed cache.
**Trade-offs**: space; updates touch all ancestors.

## DAG Processing Pipeline
**When to use**: customizable media processing. (Ch 14)
**How**: preprocessor → DAG scheduler → resource manager (task/worker/running queues) → task workers.
**Trade-offs**: orchestration complexity.

## Chunked, Resumable, Delta Upload
**When to use**: large files over flaky networks. (Ch 14, 15)
**How**: split into GOPs/blocks (≤ 4 MB); upload in parallel; resume; send only changed blocks; dedupe by hash.
**Trade-offs**: block metadata bookkeeping.

## Pre-Signed Upload URL
**When to use**: clients upload directly to blob storage. (Ch 14)
**How**: API issues scoped URL; client uploads to storage.
**Trade-offs**: URL expiry handling.

## Popularity-Tiered CDN
**When to use**: CDN cost dominates. (Ch 14)
**How**: popular → CDN; long tail → origin video servers; on-demand encoding; regional distribution.
**Trade-offs**: needs viewing analytics.
