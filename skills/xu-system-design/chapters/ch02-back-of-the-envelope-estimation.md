# Chapter 2: Back-of-the-Envelope Estimation

## Core Idea
Estimation (Jeff Dean: "thought experiments + common performance numbers") tells you which designs can meet requirements. The process matters more than the precise result: round aggressively, write assumptions down, label units.

## Frameworks Introduced
- **Three numbers to internalize**: power of two (data volume), latency numbers every programmer should know, availability numbers (nines).
- **Estimation recipe** (Twitter example):
  1. State assumptions (MAU, % daily, actions/user/day, % media, retention).
  2. DAU = MAU × daily %.
  3. QPS = DAU × actions / 86,400 s (≈ 10⁵ s); Peak QPS ≈ 2 × QPS.
  4. Storage/day = DAU × actions × % with payload × payload size; multiply by retention.
- **Interview tips**: round & approximate (`99987 / 9.1` → `100,000 / 10`) · write down assumptions · label units ("5 MB", not "5") · practice the common ones: QPS, peak QPS, storage, cache, number of servers.

## Key Concepts
- **QPS / Peak QPS**: average queries per second; peak commonly 2× average.
- **High availability**: % of time a service is operational; most services are 99–100%.
- **SLA**: formal uptime commitment to customers; AWS/Google/Azure set ≥ 99.9%.
- **Nines**: each extra 9 cuts downtime ~10×.
- **ns / µs / ms**: 1 ns = 10⁻⁹ s; 1 µs = 1,000 ns; 1 ms = 1,000 µs = 10⁶ ns.

## Mental Models
- Memory is fast, disk is slow — avoid disk seeks.
- Simple compression is cheap — compress before sending over the network.
- Cross-region round trips cost ~150 ms — data centers are far apart in time.
- Think "per day ÷ 10⁵ ≈ per second" for quick QPS.

## Anti-patterns
- **Chasing precision**: wastes interview time; nobody expects exact math.
- **Unlabeled numbers**: "5" — KB or MB? You'll confuse yourself.
- **Unstated assumptions**: you can't revisit or defend them later.

## Reference Tables

**Table 2-1 — Power of two**

| Power | Approx value | Full name | Short |
|---|---|---|---|
| 2¹⁰ | 1 Thousand | 1 Kilobyte | 1 KB |
| 2²⁰ | 1 Million | 1 Megabyte | 1 MB |
| 2³⁰ | 1 Billion | 1 Gigabyte | 1 GB |
| 2⁴⁰ | 1 Trillion | 1 Terabyte | 1 TB |
| 2⁵⁰ | 1 Quadrillion | 1 Petabyte | 1 PB |

**Table 2-2 — Latency numbers (Jeff Dean, 2010)**

| Operation | Time |
|---|---|
| L1 cache reference | 0.5 ns |
| Branch mispredict | 5 ns |
| L2 cache reference | 7 ns |
| Mutex lock/unlock | 100 ns |
| Main memory reference | 100 ns |
| Compress 1 KB with Zippy | 10 µs |
| Send 2 KB over 1 Gbps network | 20 µs |
| Read 1 MB sequentially from memory | 250 µs |
| Round trip within same datacenter | 500 µs |
| Disk seek | 10 ms |
| Read 1 MB sequentially from network | 10 ms |
| Read 1 MB sequentially from disk | 30 ms |
| Send packet CA → Netherlands → CA | 150 ms |

**Fig 2-1 — Visualized latency (2020 values)**: L1 1 ns · branch mispredict 3 ns · L2 4 ns · mutex 17 ns · main memory 100 ns · compress 1 KB (Zippy) 2 µs · send 2 KB over commodity network 44 ns · SSD random read 16 µs · read 1 MB from memory 3 µs · read 1 MB from SSD 49 µs · same-DC round trip 500 µs · disk seek 2 ms · read 1 MB from disk 825 µs · CA↔Netherlands 150 ms. (Hardware got faster; the network round-trip across the planet did not.)

**Table 2-3 — Availability**

| Availability | Downtime/day | Downtime/year |
|---|---|---|
| 99% | 14.40 min | 3.65 days |
| 99.9% | 1.44 min | 8.77 hours |
| 99.99% | 8.64 s | 52.60 min |
| 99.999% | 864 ms | 5.26 min |
| 99.9999% | 86.4 ms | 31.56 s |

## Worked Example
**Estimate Twitter QPS and storage** (exercise numbers, not real Twitter):
- Assumptions: 300 M MAU · 50% daily · 2 tweets/user/day · 10% contain media · stored 5 years.
- DAU = 300 M × 50% = **150 M**
- Tweet QPS = 150 M × 2 / 24 h / 3600 s ≈ **3,500**; Peak QPS = 2 × QPS ≈ **7,000**
- Avg tweet: tweet_id 64 B · text 140 B · media 1 MB
- Media storage/day = 150 M × 2 × 10% × 1 MB = **30 TB/day**
- 5-year media = 30 TB × 365 × 5 ≈ **55 PB**

## Key Takeaways
1. Memorize the three tables; they let you sanity-check any design in seconds.
2. Peak ≈ 2× average QPS unless told otherwise.
3. Seconds per day ≈ 10⁵ — use it.
4. Show the process: assumptions → formula → rounded number with units.
5. Media dominates storage; text/metadata is usually noise.

## Connects To
- **Ch 3**: estimation belongs in Step 2 (validate the blueprint against scale).
- **Ch 8, 9, 13, 14, 15**: every design chapter opens with this exact estimation pattern.
- **Ch 1**: estimation tells you which rung of the scaling ladder you need.
