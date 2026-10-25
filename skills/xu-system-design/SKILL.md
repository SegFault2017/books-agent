---
name: xu-system-design
description: "Knowledge base from \"System Design Interview: An Insider's Guide (2nd ed.)\" by Alex Xu. Use when applying Xu's 4-step interview framework, back-of-the-envelope estimation, scaling, rate limiting, consistent hashing, key-value stores, or designs for URL shortener, crawler, notifications, news feed, chat, autocomplete, YouTube, and Google Drive, studying the book, or referencing its concepts."
---

<!-- argument-hint: [topic, framework name, or chapter number] -->

# System Design Interview: An Insider's Guide (2nd edition)
**Author**: Alex Xu | **Pages**: ~269 | **Chapters**: 16 | **Generated**: 2026-10-25

## How to Use This Skill

- **Without arguments** — load core frameworks for reference
- **With a topic** — ask about `rate limiter`, `fanout`, `quorum`, or another indexed topic; I find and read the relevant chapter
- **With chapter** — ask for `ch12`; I load that specific chapter
- **Browse** — ask "what chapters do you have?" to see the full index

When you ask about a topic not covered in Core Frameworks below, I will read
the relevant chapter file before answering. Every chapter file includes the book's
figures redrawn as Mermaid/ASCII diagrams and tables.

---

## Core Frameworks & Mental Models

**The 4-Step Process** (45 min): (1) understand the problem and establish design scope, 3–10 min: ask about features, users, growth, and existing stack, and write assumptions down. "Don't be like Jimmy" (answering fast is a red flag). (2) propose a high-level design and get buy-in, 10–15 min: box diagram, back-of-envelope check, walk use cases, treat the interviewer as a teammate. (3) design deep dive, 10–25 min: go where the interviewer cares and manage time. (4) wrap up, 3–5 min: bottlenecks (never "it's perfect"), recap, error cases, operations, the next 10× scale, refinements. Over-engineering is a red flag; trade-offs are the signal.

**Back-of-the-envelope**: know powers of two, latency numbers, and availability nines. QPS = DAU × actions / 10⁵ s; peak ≈ 2×. Storage = writes/day × size × retention. Round aggressively, label units, state assumptions.

**The Scaling Ladder** (Ch 1): single server → split web/data tier → load balancer → master-slave replication → cache → CDN → stateless web tier → multi-DC (geoDNS) → message queues → logging/metrics/automation → sharding. Summary: keep web tier stateless · redundancy at every tier · cache as much as you can · multiple DCs · static assets on CDN · shard the data tier · split tiers into services · monitor and automate.

**Use X when Y**:
- Use a **read-through cache** for read-heavy, rarely-modified data; always set expiry; LRU eviction; avoid single cache node (SPOF).
- Use **NoSQL** when you need super-low latency, unstructured data, pure serialize/deserialize, or massive data; otherwise relational.
- Use **consistent hashing + virtual nodes** whenever cluster membership changes; `hash % N` remaps almost everything.
- Use **message queues** to decouple slow work and to isolate failures (one queue per channel in notifications).
- Use **WebSocket** for bidirectional real-time (chat); **long polling** for one-way infrequent pushes (Drive).
- Use **snowflake** (1|41|5|5|12 bits) for unique, numeric, time-sortable 64-bit IDs; local sequence IDs suffice per chat channel.
- Use **base 62 of a unique ID** for short URLs (7 chars ≥ 365 B URLs); 301 for load, 302 for analytics.

**Rate limiter**: server-side middleware/API gateway + Redis counters; five algorithms: token bucket (bursts; Amazon, Stripe) · leaking bucket (stable outflow; Shopify) · fixed window (edge spikes up to 2×) · sliding window log (exact, memory-heavy) · sliding window counter (smooth, approximate). Return 429 + X-Ratelimit-Remaining/Limit/Retry-After. Races → Lua script / sorted sets; multi-instance → centralized Redis, not sticky sessions.

**Distributed KV store** (Dynamo/Cassandra): CAP → choose CP or AP. Partition with consistent hashing; replicate to next N unique servers across DCs; quorum N/W/R with W+R>N for strong consistency (N=3, W=R=2). Vector clocks detect conflicts (client reconciles). Gossip for failure detection; sloppy quorum + hinted handoff for temporary failures; Merkle trees for permanent ones. Write: commit log → memtable → SSTable; read: memtable → Bloom filter → SSTables.

**Design heuristics from the case studies**:
- **Feeds**: hybrid fanout — push to followers' caches for normal users, pull for celebrities; cache IDs only, hydrate on read; 5 cache layers.
- **Crawler**: BFS with URL frontier — front queues (priority) + per-host back queues (politeness); dedupe content by hash and URLs by Bloom filter; robots.txt; spider-trap limits.
- **Notifications**: queue per channel → workers → APNs/FCM/SMS/email; persist + retry, dedupe by event ID (no exactly-once); opt-in settings, templates, per-user rate limits.
- **Chat**: stateless HTTP for auth/profile + stateful WebSocket chat servers via service discovery (Zookeeper); KV store for history; per-recipient inbox for small groups; heartbeat presence + pub/sub per friend pair.
- **Autocomplete**: trie with top-k cached per node and capped prefix → O(1); rebuild offline weekly from aggregated logs; Trie Cache + Trie DB; filter layer; shard by historical distribution.
- **YouTube**: cloud blob storage + CDN; upload pipeline with completion queue; DAG transcoding (preprocessor → scheduler → resource manager → workers); GOP-chunked parallel resumable upload; pre-signed URLs; serve only popular videos from CDN.
- **Google Drive**: block servers (≤ 4 MB blocks, compress, encrypt, delta sync); relational metadata for strong consistency; long-poll notifications + offline queue; first-processed-wins conflicts; dedupe, version limits, cold storage.

---

## Chapter Index

| # | Title | Key Frameworks |
|---|-------|----------------|
| [ch01](chapters/ch01-scale-from-zero-to-millions.md) | Scale From Zero to Millions of Users | Scaling ladder, cache, CDN, stateless tier, sharding |
| [ch02](chapters/ch02-back-of-the-envelope-estimation.md) | Back-of-the-Envelope Estimation | Powers of 2, latency numbers, nines, QPS/storage |
| [ch03](chapters/ch03-framework-for-system-design-interviews.md) | A Framework for System Design Interviews | 4-step process, dos/don'ts, time budget |
| [ch04](chapters/ch04-design-a-rate-limiter.md) | Design a Rate Limiter | 5 algorithms, Redis counters, 429 headers |
| [ch05](chapters/ch05-design-consistent-hashing.md) | Design Consistent Hashing | Hash ring, virtual nodes, affected range |
| [ch06](chapters/ch06-design-a-key-value-store.md) | Design a Key-Value Store | CAP, quorum, vector clocks, gossip, Merkle |
| [ch07](chapters/ch07-design-a-unique-id-generator.md) | Design a Unique ID Generator | Snowflake, UUID, ticket server |
| [ch08](chapters/ch08-design-a-url-shortener.md) | Design a URL Shortener | Base 62, 301 vs 302, hash + collision |
| [ch09](chapters/ch09-design-a-web-crawler.md) | Design a Web Crawler | URL frontier, politeness, dedup |
| [ch10](chapters/ch10-design-a-notification-system.md) | Design a Notification System | Channel queues, retry, dedupe, opt-in |
| [ch11](chapters/ch11-design-a-news-feed-system.md) | Design a News Feed System | Fanout push/pull/hybrid, cache layers |
| [ch12](chapters/ch12-design-a-chat-system.md) | Design a Chat System | WebSocket, service discovery, presence |
| [ch13](chapters/ch13-design-a-search-autocomplete-system.md) | Design a Search Autocomplete System | Trie top-k, offline build, sharding |
| [ch14](chapters/ch14-design-youtube.md) | Design YouTube | Transcoding DAG, CDN cost, pre-signed URL |
| [ch15](chapters/ch15-design-google-drive.md) | Design Google Drive | Block servers, delta sync, long polling |
| [ch16](chapters/ch16-the-learning-continues.md) | The Learning Continues | Reading list, engineering blogs |

## Topic Index

- **301 vs 302 redirect** → ch08
- **4-step framework** → ch03
- **ACID / strong consistency** → ch06, ch15
- **API gateway** → ch04
- **Availability numbers / SLA** → ch02
- **Base 62** → ch08
- **Block servers / delta sync** → ch15
- **Bloom filter** → ch06, ch08, ch09
- **CAP theorem** → ch06
- **Cache / cache layers** → ch01, ch11, ch13
- **CDN / CDN cost** → ch01, ch14
- **Celebrity / hotspot key** → ch01, ch05, ch11
- **Consistent hashing / virtual nodes** → ch05, ch06, ch09
- **DAG transcoding** → ch14
- **Estimation (QPS, storage)** → ch02, ch08, ch09, ch13, ch14, ch15
- **Fanout on write / read** → ch11
- **Gossip protocol / heartbeat** → ch06, ch12
- **Latency numbers** → ch02
- **Load balancer / failover** → ch01, ch15
- **Long polling / WebSocket** → ch12, ch15
- **Merkle tree / anti-entropy** → ch06
- **Message queue** → ch01, ch10, ch12, ch14
- **Multi-data center / geoDNS** → ch01
- **Notification (push, SMS, email)** → ch10
- **Politeness / URL frontier / robots.txt** → ch09
- **Pre-signed URL / DRM** → ch14
- **Presence / online status** → ch12
- **Quorum (N, W, R) / sloppy quorum / hinted handoff** → ch06
- **Rate limiting algorithms** → ch04
- **Replication (master-slave)** → ch01, ch06
- **Service discovery (Zookeeper)** → ch12
- **Sharding / shard map manager** → ch01, ch13, ch15
- **Snowflake / unique IDs** → ch07, ch08, ch12
- **SSTable / commit log / memtable** → ch06
- **Stateless web tier** → ch01
- **Sync conflicts / versioning** → ch06, ch15
- **Trie** → ch13
- **Vector clocks** → ch06

## Supporting Files

- [glossary.md](glossary.md) — all key terms with definitions
- [patterns.md](patterns.md) — all techniques and design patterns
- [cheatsheet.md](cheatsheet.md) — quick reference tables and decision guides

---

## Scope & Limits

This skill covers the book content only. For hands-on implementation in your codebase,
combine with project-specific tools. For topics beyond this book, check related skills
(e.g. `kleppmann-data-systems` for deeper data-system theory) or ask the agent directly.
Text was extracted with pdftotext; all 225 figures were read visually and redrawn as
Mermaid/ASCII/tables. Diagram reconstructions are faithful but simplified.
