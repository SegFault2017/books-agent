# Chapter 5: Design Consistent Hashing

## Core Idea
`hash(key) % N` remaps almost every key when N changes, causing a cache-miss storm. Consistent hashing places servers and keys on a hash ring and assigns each key to the first server clockwise, so adding/removing a server remaps only ~k/n keys. Virtual nodes fix uneven partitions and key skew.

## Frameworks Introduced
- **The rehashing problem**: `serverIndex = hash(key) % N` works only while N is fixed and data is even.
- **Consistent hashing (Karger et al., MIT)** — basic steps:
  1. Map servers and keys onto the ring with a uniformly distributed hash function (no modulo).
  2. To find a key's server, walk clockwise from the key's position to the first server.
- **Virtual nodes (replicas)**: each real server appears as many points (s0_0, s0_1, …) on the ring; each owns multiple small partitions.
- **Find affected keys**:
  - *Add* server sN: affected range = from sN **anticlockwise** to the previous server; those keys move to sN.
  - *Remove* server sN: affected range = from sN anticlockwise to the previous server; those keys move to the next server clockwise.

## Key Concepts
- **Hash space**: SHA-1 outputs 0 … 2¹⁶⁰ − 1 (x0 … xn).
- **Hash ring**: hash space with both ends joined.
- **Partition**: hash space between adjacent servers on the ring.
- **k/n remapping**: on resize only k/n keys move on average (k keys, n slots).
- **Standard deviation of load**: with 100 vnodes ≈ 10% of mean; with 200 vnodes ≈ 5%.

## Mental Models
- Think of the ring as a **clock**: keys roll clockwise until they hit a server.
- More virtual nodes → smoother distribution, but more metadata to store. Tune the count.
- Consistent hashing also **mitigates hotspot keys** by spreading data more evenly.

## Anti-patterns
- **Modulo hashing for elastic clusters**: one server change → most keys remapped → cache-miss storm.
- **One position per server**: partitions become uneven after add/remove; keys may cluster on one server while others are empty.

## Reference Tables

**Table 5-1 / 5-2 — Modulo hashing remap when server 1 goes offline**

| key | hash | hash % 4 | hash % 3 |
|---|---|---|---|
| key0 | 18358617 | 1 | 0 |
| key1 | 26143584 | 0 | 0 |
| key2 | 18131146 | 2 | 1 |
| key3 | 35863496 | 0 | 2 |
| key4 | 34085809 | 1 | 1 |
| key5 | 27581703 | 3 | 0 |
| key6 | 38164978 | 2 | 1 |
| key7 | 22530351 | 3 | 0 |

Fig 5-1 (N=4): s0 {key1, key3} · s1 {key0, key4} · s2 {key2, key6} · s3 {key5, key7}.
Fig 5-2 (N=3, server 1 gone): s0 {**key0**, key1, **key5**, **key7**} · s2 {key2, **key4**, key6} · s3 {**key3**} — bold keys moved; 5 of 8 keys remapped, not just server 1's two.

**Real-world users**: Amazon Dynamo partitioning · Apache Cassandra · Discord · Akamai CDN · Google Maglev load balancer.

## Diagrams

**Fig 5-3/5-4 — Hash space → ring**: linear space x0…xn; join the ends so xn wraps to x0.

**Fig 5-5 to 5-7 — Ring and clockwise lookup** (positions listed clockwise from top):
```text
        k0 ──► s0
   s3              k1 ──► s1
   ▲
   k3                  k2 ──► s2
Clockwise order: k0, s0, k1, s1, k2, s2, k3, s3
Lookup: key0→server0, key1→server1, key2→server2, key3→server3
```

**Fig 5-8 / 5-14 — Add server 4** (placed between k0 and s0):
```text
Clockwise: k0, s4, s0, k1, s1, k2, s2, k3, s3
key0: s0 ✗ → s4 ✓   (only key0 moves)
Affected range: s3 → s4 (anticlockwise from s4 until s3)
```

**Fig 5-9 / 5-15 — Remove server 1**:
```text
Clockwise: k0, s0, k1, [s1 ✗], k2, s2, k3, s3
key1 → s2   (only key1 moves)
Affected range: s0 → s1; keys there move to s2
```

**Fig 5-10 — Uneven partitions**: after s1 is removed, s2's partition spans s0→s2 — twice the size of s0's and s3's.

**Fig 5-11 — Non-uniform keys**: servers s3, s0, s1, s2 bunched in one arc; most keys fall in the long gap and land on s2; s1 and s3 hold nothing.

**Fig 5-12/5-13 — Virtual nodes**
```text
Clockwise: s1_0, s0_0, s1_1, s0_1, s1_2, s0_2  (3 vnodes per server; real systems use far more)
Partition ending at an s0_* vnode → server 0; ending at s1_* → server 1
k0 (between s0_0 and s1_1) → walks clockwise → s1_1 → server 1
```

## Worked Example
Trace a cluster change end-to-end:
1. 4 cache servers with modulo hashing (Table 5-1). Server 1 dies → N = 3 → recompute (Table 5-2): key0, key3, key4, key5, key7 all move. Clients now miss on most keys.
2. Same cluster on a ring: server 1 dies → only key1 (between s0 and s1) moves to s2. Every other key keeps its server and cache stays warm.
3. Server 4 added between k0 and s0: only keys in (s3, s4] move to s4 — here, key0.
4. Load is lumpy because each server has one point → give each server ~100–200 vnodes → per-server load std-dev drops to ~5–10% of mean.

## Key Takeaways
1. Never use `hash % N` for a cluster whose size changes.
2. Ring + clockwise lookup remaps ~k/n keys on membership change.
3. Use virtual nodes to balance partitions and data; trade more vnodes for more metadata.
4. Affected range on add/remove = anticlockwise from the changed node to its predecessor.
5. Consistent hashing underpins Dynamo, Cassandra, CDNs, and L4 load balancers.

## Connects To
- **Ch 1**: solves sharding's resharding and celebrity/hotspot problems.
- **Ch 6**: key-value store uses the ring for partitioning and for picking N replicas.
- **Ch 12**: chat — service discovery and server assignment echo the same idea.
