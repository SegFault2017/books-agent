# Cheatsheet — System Design Interview (Alex Xu)

## The 45-minute clock
| Step | Minutes | Exit criterion |
|---|---|---|
| 1. Scope | 3–10 | Features, users/DAU, growth, stack written down |
| 2. High level + buy-in | 10–15 | Box diagram + estimate agreed |
| 3. Deep dive | 10–25 | Interviewer's chosen components done |
| 4. Wrap up | 3–5 | Bottlenecks, failures, ops, next 10× named |

## Numbers to carry
- 1 day ≈ 10⁵ s; peak ≈ 2× avg QPS. 2¹⁰ ≈ KB … 2⁵⁰ ≈ PB.
- Memory ref 100 ns · same-DC RTT 0.5 ms · disk seek 10 ms · cross-continent 150 ms.
- 99.9% = 8.77 h/yr · 99.99% = 52.6 min/yr · 99.999% = 5.26 min/yr.
- 62⁷ ≈ 3.5 T · snowflake 4,096 IDs/ms/machine, 69 years · block ≤ 4 MB · 100–200 vnodes → 5–10% std-dev.

## Decision rules
- **State on a web server?** Move it out first; then autoscale.
- **Read-heavy, rarely changes?** Cache with TTL + LRU; never sole copy.
- **Static asset?** CDN; version URLs to invalidate.
- **Slow or bursty work?** Queue + workers; scale on queue depth.
- **Cluster size changes?** Consistent hashing, not `% N`.
- **One DB too small?** Replicate for reads first; shard when writes/data outgrow it.
- **Must never show stale data?** CP / relational ACID / invalidate cache on write. **Can tolerate staleness?** AP + eventual consistency.
- **Need IDs: 64-bit, numeric, time-sorted?** Snowflake. **Ordering only within a chat?** Local sequence.
- **Server must push to client?** Bidirectional + frequent → WebSocket; one-way + infrequent → long polling.
- **Feed fanout?** Push for normal users, pull for celebrities.
- **Delivery semantics?** Assume at-least-once; dedupe by event ID; persist + retry.
- **Big uploads?** Chunk, resume, parallelize, delta-sync; pre-signed URLs.
- **CDN bill too big?** Serve only popular content from CDN.

## Rate-limit algorithm picker
| Need | Pick |
|---|---|
| Allow bursts (flash sales) | Token bucket |
| Stable outflow | Leaking bucket |
| Simple quota reset at boundaries | Fixed window |
| Exact rolling limit, memory OK | Sliding window log |
| Default: smooth + cheap | Sliding window counter |

## Quorum dial (N = 3)
| W, R | Effect |
|---|---|
| W=2, R=2 | strong consistency |
| W=3, R=1 | fast reads |
| W=1, R=3 | fast writes |
| W+R ≤ 3 | eventual only |

## Failure → response
| Failure | Response |
|---|---|
| Web/API server | stateless → LB reroutes |
| DB master | promote slave (may need recovery scripts) |
| Cache node | replicated; replace |
| Replica temporarily down | sloppy quorum + hinted handoff |
| Replica permanently diverged | Merkle-tree anti-entropy |
| Data center | geoDNS to healthy DC |
| Third-party provider | retry from queue; alert; pluggable alternatives |
| Chat/notification server | service discovery reassigns; clients reconnect |

## Tells & smells
- "Everything on one server" as the final answer → SPOF red flag.
- `hash % N` with autoscaling → cache-miss storm.
- Sticky sessions → you skipped the stateless step.
- Unbounded feed/version/log storage → add limits, IDs only, cold tiers.
- Fixed-window limiter and edge spikes → up to 2× quota.
- Answering before asking → "Don't be like Jimmy."
- Claiming the design is perfect in wrap-up → name a bottleneck.
