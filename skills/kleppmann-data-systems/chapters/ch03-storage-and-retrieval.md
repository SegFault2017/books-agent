# Chapter 3: Storage and Retrieval

## Core Idea
Storage engines split into two schools — log-structured (append-only, e.g., LSM-trees) and update-in-place (fixed-size pages, e.g., B-trees) — with a fundamental write-vs-read trade-off between them, and a completely different set of trade-offs apply once you shift from OLTP (small-key lookups) to OLAP (full-column scans, where column-oriented storage dominates).

## Frameworks Introduced
- **Log-Structured vs. Update-in-Place**: the two fundamental storage engine philosophies.
  - When to use: Choosing/tuning a storage engine for a given write/read workload.
  - How: Log-structured (LSM-trees: Bitcask, LevelDB, RocksDB, Cassandra, HBase) favors write throughput via sequential writes; update-in-place (B-trees) favors predictable read latency and is more mature/ingrained in relational databases.
- **The Index Trade-off Rule**: "well-chosen indexes speed up reads, but every index slows down writes" — because each index is additional structure that must be maintained on every write.
  - When to use: Deciding which columns to index.
  - How: Index based on actual query patterns, not defensively; unindexed appends are the fastest possible write operation.
- **OLTP vs. OLAP Access Pattern Framework**: distinguishes systems by read/write pattern, not by "SQL vs. NoSQL."
  - When to use: Deciding whether a workload belongs on the operational database or a separate analytics store (data warehouse).
  - How: Small-number-of-records-by-key + low-latency + user-facing → OLTP. Aggregate-over-millions-of-rows + few columns + analyst-facing → OLAP → column-oriented storage.

## Key Concepts
- **Log**: an append-only sequence of records (not to be confused with application/debug logs) — the foundational primitive behind nearly every storage engine discussed in this book.
- **Hash index**: in-memory hash map from key → byte offset in an append-only file; requires all keys to fit in RAM (Bitcask).
- **Compaction**: discarding all but the most recent value for each key within a segment.
- **Segment merging**: combining multiple compacted segments into one, mergesort-style.
- **SSTable (Sorted String Table)**: a log segment sorted by key, enabling sparse in-memory indexes and efficient range queries.
- **Memtable**: the in-memory sorted structure (e.g., red-black tree) that buffers writes before they're flushed to an SSTable on disk.
- **LSM-tree (Log-Structured Merge-Tree)**: the overall algorithm of memtable + cascading, background-merged SSTables. Powers LevelDB, RocksDB, Cassandra, HBase.
- **Write amplification**: one logical write resulting in multiple physical disk writes over the database's lifetime (from WAL + page writes, or from repeated SSTable compaction).
- **B-tree**: fixed-size page/block index (traditionally 4 KB) forming a balanced tree of depth O(log n); the standard index in nearly all relational databases.
- **Write-ahead log (WAL / redo log)**: append-only file that every B-tree modification is written to before being applied, for crash recovery.
- **Clustered index / covering index**: storing row data (or select columns) directly in the index rather than a separate heap file, trading write overhead for avoiding an extra lookup hop.
- **Star schema / snowflake schema**: dimensional modeling patterns for data warehouses — a central fact table (events) referencing dimension tables (who/what/where/when).
- **Column-oriented storage**: storing each column in its own file so a query only reads the columns it needs; enables strong compression (bitmap encoding, run-length encoding) and vectorized processing.
- **Data cube / OLAP cube / materialized view**: precomputed aggregates along dimension combinations, trading flexibility for query speed.

## Mental Models
- Think of an index as "a signpost, not the primary data" — you can add/remove indexes freely without changing the database's logical contents, only its query performance.
- Use "sequential writes are fast, random writes are slow" as the single physical fact that explains why LSM-trees exist and why B-trees need a WAL for crash safety.
- Think of column-oriented storage as "the OLTP question (find matching rows) is not the OLAP question (aggregate over columns)" — OLTP is disk-seek-bound (index to a few rows), OLAP is disk-bandwidth-bound (scan many rows, few columns).

## Anti-patterns
- **Using a plain on-disk hash map for large keyspaces**: hash indexes require the full key set to fit in memory and don't support range queries — a fundamental ceiling, not a tuning problem.
- **Row-oriented storage for analytic (OLAP) queries**: forces the engine to load all 100+ columns of a row even when a query needs only 3-5, wasting I/O bandwidth — the direct motivation for column stores.
- **Averaging/expecting update-in-place semantics from compressed column stores**: inserting into the middle of a sorted, compressed column table would require rewriting entire column files — this is why column stores borrow the LSM-tree write pattern (buffer in memory, merge on flush) rather than updating in place.
- **Ad hoc analytics directly against OLTP production databases**: expensive full-scan analytic queries competing with low-latency transactional queries harms both — the reason data warehouses exist as a separate, ETL-fed copy.

## Code Examples
```bash
# The world's simplest database (two Bash functions) — illustrates the append-only log + O(n) lookup baseline
db_set () {
    echo "$1,$2" >> database
}
db_get () {
    grep "^$1," database | sed -e "s/^$1,//" | tail -n 1
}
```
- **What it demonstrates**: `db_set` is O(1) (pure append — the fastest possible write); `db_get` is O(n) (full scan) — motivating every indexing structure that follows in the chapter.

```sql
-- Multi-dimensional range query that a single B-tree/LSM-tree index cannot answer efficiently
SELECT * FROM restaurants WHERE latitude > 51.4946 AND latitude < 51.5079
                            AND longitude > -0.1162 AND longitude < -0.1004;
```
- **What it demonstrates**: motivates specialized multi-dimensional indexes (R-trees, space-filling curves) — a standard B-tree can only efficiently range-query on one dimension at a time.

## Reference Tables
| Property | LSM-trees (log-structured) | B-trees (update-in-place) |
|---|---|---|
| Write pattern | Sequential (append + background merge) | In-place page overwrite + WAL |
| Write throughput | Higher (lower write amplification typical) | Lower (page writes + WAL double-write) |
| Read latency | Less predictable (check memtable + multiple SSTables) | More predictable |
| Compaction interference | Can spike tail latency during merges | N/A |
| Compression / disk usage | Better (no page fragmentation) | Worse (fragmentation from page splits) |
| Transactional locking | Harder (multiple copies of a key across segments) | Easier (one location per key, locks attach directly) |
| Example systems | LevelDB, RocksDB, Cassandra, HBase, Lucene | Nearly all relational DBs, most non-relational too |

| Property | OLTP | OLAP |
|---|---|---|
| Main read pattern | Small number of records by key | Aggregate over large number of records |
| Main write pattern | Random-access, low-latency, user input | Bulk import (ETL) or event stream |
| Used by | End user, via application | Internal analyst |
| Data represents | Latest state | History of events over time |
| Dataset size | GB–TB | TB–PB |
| Bottleneck | Disk seek time | Disk bandwidth |

## Worked Example
**LSM-tree write + compaction cycle:**
1. A write comes in → appended to an on-disk WAL (for crash recovery) → inserted into the in-memory **memtable** (a red-black tree, sorted by key).
2. When the memtable exceeds a size threshold (a few MB), it is flushed to disk as a new **SSTable** (already sorted, since the memtable was a sorted tree) — writes continue to a fresh memtable while this happens.
3. A read first checks the memtable, then the most recent on-disk SSTable, then progressively older ones, until the key is found (a **Bloom filter** short-circuits this for keys that don't exist, avoiding needless disk reads).
4. In the background, a merge process combines old SSTable segments mergesort-style: read the segments side by side, always output the lowest key, and when the same key appears in multiple segments, keep only the value from the most recent segment (this is **compaction**).
5. Once merging is complete, reads switch to the new merged segment and the old segment files are deleted.
- **Why it works**: every disk write in this cycle (WAL append, memtable flush, segment merge) is sequential, which is dramatically faster than random writes on both spinning disks and (to a lesser extent) SSDs — this sequential-write property is the entire reason LSM-trees can sustain much higher write throughput than B-trees, at the cost of read paths that may need to check several structures and occasional latency spikes when compaction competes with foreground I/O.

## Key Takeaways
1. LSM-trees favor write throughput via sequential I/O; B-trees favor predictable read latency via direct page addressing — pick based on your read/write ratio, not by default/familiarity.
2. Every index accelerates specific reads at the cost of every write — index deliberately, based on real query patterns.
3. A Bloom filter is the standard trick for making "key does not exist" checks in an LSM-tree cheap, since that case would otherwise require scanning all segments.
4. B-trees require a write-ahead log for crash safety because a page-split can leave several pages half-written if the system crashes mid-operation; LSM-trees avoid this because segments are immutable once written.
5. OLTP and OLAP have fundamentally different bottlenecks (seek time vs. bandwidth) — don't run heavy analytics directly against a production OLTP database; use a separate warehouse fed by ETL.
6. Column-oriented storage wins for OLAP because typical analytic queries touch only 3-5 columns out of 100+, and column-major layout lets the engine skip loading irrelevant columns entirely, while also enabling much stronger compression (bitmap/run-length encoding) and vectorized CPU execution.
7. Materialized views and data cubes trade query flexibility for speed — useful only for the small set of aggregates queried repeatedly; keep raw data as the source of truth.

## Connects To
- **Ch2**: Directly implements the data models discussed there — this chapter is explicitly framed as "how are these models actually stored" (layer 3 of the layering model from Ch2).
- **Ch7**: B-tree page-level locks connect to transaction isolation implementation; copy-on-write B-trees connect to snapshot isolation.
- **Ch10**: Column-oriented storage and star schemas connect to the batch-processing / data-warehouse pipeline discussed in Part III.
- **Ch4**: Compact binary encoding formats (used in SSTable segment files) connect to the encoding/schema-evolution discussion.
