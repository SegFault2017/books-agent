# Chapter 10: Batch Processing

## Core Idea
Batch processing reads bounded, immutable input and produces derived output without side effects; the same design principles that make Unix pipelines composable (uniform interfaces, separation of logic from wiring, immutability) scale up to MapReduce and modern dataflow engines operating on distributed filesystems.

## Frameworks Introduced
- **The Unix Philosophy** (McIlroy, 1978): "make each program do one thing well," expect output to become another program's input, avoid premature interactivity, prefer tools over unskilled labor.
  - When to use: designing any pipeline of composable processing stages, not just shell scripts.
  - How: give every stage a uniform interface (Unix: byte streams over files/pipes; MapReduce: files on a distributed filesystem), keep inputs immutable, separate I/O wiring (stdin/stdout, or job input/output directories) from the processing logic itself.
- **MapReduce**: a programming model of `mapper` (extract key/value from each record, no state across records) → implicit sort by key → `reducer` (iterate over all values for one key, emit output).
  - When to use: full-table-scan style bulk transformations over huge bounded datasets where per-record indexed lookups would be too slow (Google's original use: building search indexes).
  - How: implement two callbacks; the framework partitions input by file block, runs mappers near the data ("putting the computation near the data"), shuffles (partitions + sorts + copies) mapper output to reducers by hash of key.
- **Sort-merge join** (reduce-side join): both join inputs are mapped to `(join_key, value)`, partitioned/sorted so all records for a key land at the same reducer; the reducer merges them. Works with no assumptions about input structure, at the cost of a full shuffle.
- **Broadcast hash join** (map-side): when one input is small enough to fit in memory, load it into a hash table in every mapper and stream the large input past it — no shuffle, no reducer needed.
- **Partitioned hash join**: like broadcast, but works on the large small input too, if both inputs are already partitioned identically by the join key — each mapper only loads its own partition's hash table.
- **Dataflow engines** (Spark, Tez, Flink): generalize MapReduce's map/reduce into arbitrary **operators** connected by a DAG, avoiding full materialization of intermediate state to the distributed filesystem between every stage.

## Key Concepts
- **Full table scan**: MapReduce's only access pattern — no indexes; reasonable when you must touch all/most records anyway (aggregates), wasteful for point lookups.
- **Shuffle**: the process of partitioning, sorting, and copying mapper output to reducers; the expensive core of stateful MapReduce execution.
- **Skew / hot keys / linchpin objects**: a small number of keys (e.g., celebrities) receiving disproportionate data, creating a straggler reducer that delays the whole job.
- **Materialization of intermediate state**: writing a job's full output to the distributed filesystem before the next job starts — durable and simple, but slow and redundant.
- **Dataflow operators**: generalized map/reduce stages in engines like Spark/Flink/Tez that can be composed without forcing every step through a shuffle.
- **Sushi principle / schema-on-read**: "raw data is better" — dump data into a distributed filesystem in raw form and defer schema decisions to read time, shifting interpretation burden to consumers.
- **Pregel / bulk synchronous parallel (BSP)**: an iterative, vertex-centric graph processing model where vertices "send messages" along edges and iterations proceed in synchronized rounds.

## Mental Models
- Think of a MapReduce job as **one Unix process** running at cluster scale: bounded input in, bounded output out, no side effects, safe to rerun.
- Think of the mapper's key as a **destination address** — the shuffle is mappers "sending messages" to reducers, decoupling network routing from application logic.
- Use the **write path vs. batch philosophy** lens: if your output can be rebuilt bit-for-bit by rerunning the job on the same input, you get "human fault tolerance" (bad deploy → roll back code, rerun, done) that read-write transactional systems don't give you for free.
- MapReduce's frequent disk writes and per-task retry aren't about hardware being unreliable — they're a deliberate trade-off for surviving **preemption** in a shared, priority-based multi-tenant cluster (Google's ~5%/hour task-kill rate at the time).

## Anti-patterns
- **Random-access remote queries inside a mapper/reducer**: querying a live database per-record inside a batch job kills throughput and makes the job nondeterministic (the DB may change mid-run) — copy the data into the distributed filesystem first and join locally instead.
- **Writing job output directly to an external database from mappers/reducers**: concurrent writers can overwhelm the database, and MapReduce's all-or-nothing output guarantee is lost once side effects escape the framework — build a batch-loadable, immutable output file instead (e.g., Voldemort/Terrapin-style bulk load).
- **Ignoring skew**: routing every record for a hot key to one reducer creates a straggler that blocks the whole job — use randomized/sampled skewed-join techniques (Pig's skewed join, Hive's skewed join optimization) instead.
- **Treating MapReduce output as final without considering nondeterminism**: hash-table iteration order, random numbers, or system-clock reads inside an operator break deterministic recomputation, which dataflow engines rely on for fault tolerance.

## Code Examples
```bash
cat /var/log/nginx/access.log |
  awk '{print $7}' |
  sort             |
  uniq -c          |
  sort -r -n       |
  head -n 5
```
- **What it demonstrates**: the canonical Unix log-analysis pipeline — extract field (map), sort (implicit shuffle), count adjacent duplicates (reduce), re-sort and truncate (a second reduce stage) — structurally identical to a two-stage MapReduce workflow, and the direct ancestor of the MapReduce model described later in the chapter.

## Reference Tables
| Join type | Requires | Shuffle needed? | Best when |
|---|---|---|---|
| Sort-merge (reduce-side) | Nothing about input structure | Yes (full shuffle + sort) | General case, no size/partition assumptions |
| Broadcast hash | One input small enough for memory | No | Large input joined with small lookup table |
| Partitioned hash (bucketed map join) | Both inputs partitioned identically by key | No | Both inputs already produced by prior jobs with matching partitioning |
| Map-side merge | Both inputs partitioned *and* sorted identically | No | Same as above, plus sort already done upstream |

| Dimension | MapReduce | MPP databases | Dataflow engines (Spark/Tez/Flink) |
|---|---|---|---|
| Storage | Any format, any file, schema-on-read | Proprietary format, schema-on-write | Same as MapReduce (HDFS-based) |
| Processing model | Callback functions (map/reduce) | Declarative SQL | Callbacks + declarative operators |
| Fault tolerance | Task-level retry, writes to disk | Abort & rerun whole query | Recompute lost data from lineage (RDDs) or checkpoints |
| Fault frequency assumption | Frequent (preemption-heavy clusters) | Rare | Rare-to-moderate |

## Worked Example
**Sort-merge join of user activity events with a user profile database** (the running example, Figures 10-2/10-3): you have a log of clickstream events (each with a `user_id`) and a user database (each row keyed by `user_id`, holding e.g. date of birth). Goal: find which pages are popular with which age groups.
1. One set of mappers scans the activity log, emitting `(user_id, activity_event)`.
2. Another set of mappers scans the user database, emitting `(user_id, date_of_birth)`.
3. The framework partitions and sorts all mapper output by `user_id`, arranging (via **secondary sort**) that each reducer sees the user-database record *first*, then that user's activity events in timestamp order.
4. The reducer is called once per `user_id`: it stores the date of birth in a local variable, then iterates over the activity events, emitting `(viewed_url, viewer_age_in_years)` pairs.
5. A second MapReduce job then aggregates these pairs into age-group distributions per URL.
This works because the reducer never needs a network round-trip — all the data it needs for one `user_id` arrives already colocated, thanks to the shuffle.

## Key Takeaways
1. MapReduce is the distributed, fault-tolerant generalization of the Unix pipeline pattern — the shuffle (partition + sort + copy) is what brings related records together for joins and grouping.
2. Choosing a join algorithm (sort-merge vs. broadcast hash vs. partitioned hash) is a physical-layout decision: know the size, partitioning, and sort order of your inputs before picking one.
3. Materializing every stage's output to the distributed filesystem (classic MapReduce) trades speed for simple, disk-backed fault tolerance; dataflow engines trade some of that durability for speed by keeping intermediate state in memory and recomputing on failure.
4. Design for frequent faults if your cluster preempts low-priority jobs; design for rare faults (MPP-style abort-and-retry) if it doesn't — know which environment you're in.
5. Batch jobs derive output from input without mutating it — this immutability is what makes buggy deploys recoverable by simply rolling back and rerunning ("human fault tolerance").
6. Higher-level declarative APIs (Hive, Pig, Spark SQL) let the query optimizer pick join algorithms and exploit columnar storage — but the underlying callback model still gives you an escape hatch to arbitrary code (ML, NLP, image processing) that pure SQL can't express.

## Connects To
- **Ch 2**: joins were introduced conceptually here (relational/document/graph models); this chapter shows how they're actually implemented at scale.
- **Ch 3**: SSTable/LSM-tree sorting techniques reappear as the mechanism behind mapper-side sort-merge partitioning.
- **Ch 6**: partitioning strategies (by key range, by hash) are reused directly for MapReduce's shuffle and for map-side joins.
- **Ch 11 (Stream Processing)**: framed explicitly as the next step — batch processing's bounded-input assumption is dropped, but partitioning, fault-tolerance-via-determinism, and the derived-data mindset all carry over.
