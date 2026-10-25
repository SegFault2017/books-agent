# Chapter 4: Encoding and Evolution

## Core Idea
Applications change over time, and because old and new code/data formats coexist during rolling upgrades, every encoding format you pick is really a bet on how well it supports **backward compatibility** (new code reads old data) and **forward compatibility** (old code reads new data).

## Frameworks Introduced
- **Backward/Forward Compatibility**: the two directions of schema evolution.
  - When to use: any time data outlives the code that wrote it (databases) or code is deployed incrementally (rolling upgrades, mobile clients).
  - How: backward compatibility is usually easy (you know the old format); forward compatibility requires old code to explicitly ignore fields it doesn't recognize.
- **Rolling Upgrade**: deploy new code to a few nodes at a time rather than all at once.
  - When to use: server-side deployments where you want zero-downtime releases.
  - How: requires the data encoding to tolerate old and new code reading/writing concurrently — this is the practical reason schema evolution rules matter.
- **Writer's Schema vs. Reader's Schema (Avro)**: the schema used to encode data need not match the schema used to decode it — only be *compatible*.
  - When to use: whenever you want schema evolution without embedding tag numbers or full schemas in every record.
  - How: Avro resolves differences by matching fields by *name*; unmatched writer fields are ignored, unmatched reader fields get their default.

## Key Concepts
- **Encoding (serialization/marshalling)** — translating in-memory data structures to a byte sequence.
- **Decoding (deserialization/unmarshalling)** — the reverse translation.
- **Field tag** — a number (not a name) identifying a field in Thrift/Protocol Buffers; the tag, not the name, is what's encoded.
- **Schema evolution** — the practice/rules for changing a schema over time without breaking compatibility.
- **Data outlives code** — a database's five-year-old rows may sit next to five-millisecond-old rows, all in different historical schema versions.
- **REST** — an HTTP-based design philosophy (not a protocol) emphasizing URLs-as-resources and standard HTTP verbs/caching.
- **RPC (remote procedure call)** — an API style that tries to make a network call look like a local function call; fundamentally leaky because networks fail in ways local calls don't.
- **Message broker** — an intermediary (queue/topic) that buffers and routes asynchronous messages between producers and consumers.

## Mental Models
- Think of encoding formats on a spectrum from "no schema" (JSON/XML/CSV — flexible, but ambiguous types, no compatibility guardrails) to "schema-driven binary" (Thrift/Protobuf/Avro — compact, precise compatibility rules, requires decoding to be human-readable).
- Use "data outlives code" when reasoning about databases: a database is like sending a message to your future self — backward compatibility is *always* required, forward compatibility is required whenever multiple app versions run concurrently against it.
- Use "location transparency is a leaky abstraction" when evaluating RPC frameworks: a network call can partially fail, time out with unknown outcome, and has wildly variable latency — none of which a local function call does. Don't design APIs that pretend otherwise.

## Anti-patterns
- **Language-specific serialization (Java Serializable, Python pickle) for anything but transient use**: ties you to one language, is a common remote-code-execution vector (arbitrary class instantiation), and neglects versioning and efficiency.
- **Treating RPC as "just like a local call"**: ignores that network calls can time out with an unknown outcome (did it execute or not?), need idempotence for safe retries, and require explicit data-type translation across languages.
- **Adding a required field to an existing schema (Thrift/Protobuf)**: breaks backward compatibility immediately — old data won't have the field, so the runtime check fails. New fields must be optional or have a default.
- **Losing unknown fields on round-trip**: if code decodes a record into model objects and later re-encodes it, an unrecognized field can silently disappear — you must explicitly preserve it (see Figure 4-7 in the book).

## Code Examples

```thrift
struct Person {
  1: required string       userName,
  2: optional i64          favoriteNumber,
  3: optional list<string> interests
}
```
- **What it demonstrates**: Thrift IDL — note the explicit numeric field tags (1, 2, 3). These tags, not the field names, are what gets encoded; renaming a field is safe, renumbering it is not.

```protobuf
message Person {
    required string user_name      = 1;
    optional int64 favorite_number = 2;
    repeated string interests      = 3;
}
```
- **What it demonstrates**: Protocol Buffers' equivalent schema. `repeated` replaces a dedicated list type — this lets you evolve an `optional` field into a `repeated` one without breaking compatibility (old code reading new data just sees the last element).

```
record Person {
    string               userName;
    union { null, long } favoriteNumber = null;
    array<string>        interests;
}
```
- **What it demonstrates**: Avro IDL — no field tags at all. Fields are matched by *name* during schema resolution, which is what makes Avro friendly to schemas generated dynamically (e.g., from a database table).

## Reference Tables

| Format | Requires schema? | Field identified by | Compact? | Human-readable? | Notable trait |
|---|---|---|---|---|---|
| JSON / XML / CSV | No (schema optional) | Field name | No | Yes | Ambiguous number types; no binary string support natively |
| Thrift / Protobuf | Yes | Numeric tag | Yes | No | Field renaming safe; tag renumbering breaks compatibility |
| Avro | Yes (writer's + reader's) | Field name (schema-resolved) | Yes (most compact) | No | No tag numbers; best fit for dynamically generated schemas |

| Encoding of example record (Ch 4's `{userName, favoriteNumber, interests}`) | Size |
|---|---|
| JSON (whitespace removed) | 81 bytes |
| MessagePack (binary JSON) | 66 bytes |
| Thrift BinaryProtocol | 59 bytes |
| Thrift CompactProtocol | 34 bytes |
| Protocol Buffers | 33 bytes |
| Avro | 32 bytes |

| Dataflow mode | Who encodes / who decodes | Compatibility requirement |
|---|---|---|
| Database | Writer process encodes; any future reader (including your future self) decodes | Backward always; forward if multiple app versions run concurrently |
| REST / RPC | Client encodes request, server decodes+encodes response, client decodes | Backward on requests, forward on responses (assuming servers upgrade first) |
| Message queues / actors | Sender encodes, consumer(s) decode | Both directions, since publishers/consumers deploy independently |

## Worked Example
**Rolling upgrade with schema evolution, Avro-style.** Suppose a `Person` service is deployed across 5 nodes, and you need to add a `phoneNumber` field.

1. **Before the change**: writer's schema = reader's schema = `{userName, favoriteNumber, interests}`. All 5 nodes read/write this format.
2. **Deploy new code to node 1**: its writer's schema now includes `phoneNumber` with a default value of `null` (a `union { null, string }` — required for Avro since `null` must be a valid branch of a union to serve as default). Node 1 starts writing records with `phoneNumber` populated.
3. **Nodes 2–5 are still on old code** (old reader's schema, no `phoneNumber`). When they read a record written by node 1, Avro's schema resolution simply ignores the extra field — **forward compatibility** achieved because the field has a default.
4. **A record written by an old node** (no `phoneNumber`) is read by node 1 (new reader's schema): Avro fills in the default (`null`) for the missing field — **backward compatibility** achieved.
5. **Rollout completes**: all 5 nodes now share the new schema. No data was lost, no downtime occurred, and at every point in the rollout old and new code coexisted safely.

Contrast with Protocol Buffers: the same rollout works, but compatibility hinges on manually managing tag numbers rather than field names — if two developers independently add fields and pick colliding tag numbers, the schema is silently corrupted for both.

## Key Takeaways
1. Every encoding decision is really a bet on how gracefully you can add/remove/rename fields later — evaluate formats by their compatibility rules, not just their size or human-readability.
2. In Thrift/Protobuf, tag numbers (not field names) are the compatibility contract: never reuse a tag number, and new fields must be optional/have a default.
3. In Avro, field names (not tag numbers) are the compatibility contract, resolved between the writer's and reader's schema — this makes Avro the best fit for schemas generated automatically from external sources (e.g., a database table).
4. "Data outlives code" — for databases specifically, always assume backward *and* forward compatibility are both required, since old and new app versions routinely coexist against the same data.
5. RPC is fundamentally different from a local function call (partial failure, unknown timeout outcomes, no shared memory) — don't design APIs that hide this difference; REST's popularity partly reflects not pretending otherwise.
6. Message brokers (Kafka, RabbitMQ) decouple publishers from consumers and require encodings that are both backward and forward compatible, since the two sides deploy independently.

## Connects To
- **Ch 2**: schema-on-write (relational) vs. schema-on-read (document) models — encoding formats are the concrete mechanism by which schema flexibility is implemented at the byte level.
- **Ch 10 (Batch Processing)**: Avro object container files are the standard format for large batch datasets (e.g., Hadoop) because the schema travels with the file.
- **Ch 11 (Stream Processing)**: message-passing dataflow and change data capture both depend on the encoding compatibility rules established here.
- **Consistent hashing / partitioning (Ch 6)**: unrelated mechanism, but both chapters share the theme of "independently evolving/deploying parts of a distributed system."
