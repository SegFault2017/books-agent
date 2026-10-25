# Chapter 2: Data Models and Query Languages

## Core Idea
Every data model (relational, document, graph) embodies assumptions about access patterns — some operations become natural and fast, others awkward and slow — so the choice of data model should be driven by the shape of your data's relationships (one-to-many vs. many-to-many), not by trend-following.

## Frameworks Introduced
- **The Layering Model of Data Representation**: application objects → general-purpose data model (JSON/relational/graph) → bytes on disk/network → electrical signals. Each layer hides the complexity of the layer below via a clean interface.
  - When to use: When reasoning about where a translation/impedance mismatch is occurring in your stack.
  - How: Identify which layer boundary is causing friction (e.g., ORM impedance mismatch = layer 1↔2 boundary).
- **Schema-on-Write vs. Schema-on-Read**: the traditional relational approach enforces structure at write time; document databases interpret structure only when data is read (an implicit schema still exists — "schemaless" is a misnomer).
  - When to use: Choosing between relational/document storage for heterogeneous or evolving data.
  - How: Use schema-on-read when data is heterogeneous, comes from external systems you don't control, or its structure isn't known in advance. Use schema-on-write when uniform structure should be enforced and documented.
- **Normalization via IDs (Many-to-One)**: replacing human-meaningful strings with IDs referencing a single authoritative record, to avoid duplicating data that could change.
  - When to use: Any field with a bounded set of values that might need renaming/localization (region, industry, category).
  - How: Store the ID everywhere; store the human-meaningful string in exactly one place; resolve via join or application-side lookup.
- **The Document-vs-Relational-vs-Graph Decision Rule**: driven by relationship density, not by "NoSQL vs. SQL" branding.
  - When to use: Initial data-model selection for a new subsystem.
  - How: One-to-many, tree-shaped, usually-loaded-together data → document model. Many-to-many, simple → relational model (joins are cheap). Many-to-many, highly interconnected/heterogeneous → graph model (property graph or triple-store).

## Key Concepts
- **Impedance mismatch**: the awkward translation layer between OO application code and relational tables/rows/columns.
- **Shredding**: splitting a document-like structure into multiple normalized relational tables.
- **Polyglot persistence**: using different data stores for different parts of an application based on access pattern.
- **Property graph model**: vertices (ID + outgoing/incoming edges + properties) and edges (ID + tail vertex + head vertex + label + properties). Implemented by Neo4j, Titan, InfiniteGraph.
- **Triple-store model**: data as (subject, predicate, object) triples; predicate is either a property (object = literal) or an edge (object = another vertex). Implemented by Datomic, AllegroGraph.
- **Declarative vs. imperative query language**: declarative (SQL, Cypher, SPARQL, CSS) specifies the desired result pattern and leaves execution strategy to the optimizer; imperative specifies exact steps.
- **Access path** (CODASYL/network model term): the only way to reach a record was to traverse a predetermined chain of pointers — the opposite of a query optimizer's automatic path selection.
- **Data locality**: storing related data contiguously (e.g., a whole JSON document) so one query/disk-seek retrieves it, vs. scattering it across normalized tables.

## Mental Models
- Think of the relational vs. hierarchical/CODASYL "great debate" of the 1970s as the same debate NoSQL reopened in the 2010s — document databases are structurally similar to IMS's 1960s hierarchical model, and the many-to-many limitations are the same ones the relational model solved.
- Think of a query optimizer as "you only need to build it once, and every application benefits" — this is the deep reason declarative languages win over imperative access-path code in the long run, even though hand-coded access paths can be faster for any *one* query at the time.
- Use "the query specifies the pattern, not the algorithm" as the reason declarative languages parallelize better than imperative code — imperative code embeds ordering assumptions that block parallel/optimized execution.

## Anti-patterns
- **Treating "schemaless" as literally schema-free**: the application code that reads the data still assumes a structure; the schema is just implicit and unenforced, which shifts the burden but doesn't eliminate it.
- **Choosing document databases by default for interconnected data**: as features accumulate (e.g., adding "organizations as entities" or "recommendations" to a résumé app), many-to-many relationships creep in even where the original model was tree-shaped — the document model degrades badly here, requiring the application to emulate joins.
- **CODASYL-style manual access-path navigation**: even committee members admitted this was like "navigating an n-dimensional data space" — inflexible to schema changes and unnecessary given modern query optimizers.

## Code Examples
```sql
-- Relational algebra selection expressed as SQL
SELECT * FROM animals WHERE family = 'Sharks';
```
```json
// Résumé as a self-contained JSON document (good locality, natural for a tree-shaped one-to-many structure)
{
  "user_id": 251,
  "first_name": "Bill",
  "positions": [{"job_title": "Co-chair", "organization": "Bill & Melinda Gates Foundation"}],
  "education": [{"school_name": "Harvard University", "start": 1973, "end": 1975}]
}
```
```cypher
// Cypher: find people who emigrated from the US to Europe (property graph)
MATCH
  (person) -[:BORN_IN]-> () -[:WITHIN*0..]-> (us:Location {name:'United States'}),
  (person) -[:LIVES_IN]-> () -[:WITHIN*0..]-> (eu:Location {name:'Europe'})
RETURN person.name
```
- **What it demonstrates**: declarative graph traversal of a variable-length path (`WITHIN*0..`), impossible to express this concisely in SQL (the equivalent recursive CTE version runs 29 lines vs. 4).

## Reference Tables
| Model | Best for | Joins | Schema | Example systems |
|---|---|---|---|---|
| Relational | Many-to-many, ad hoc queries | Cheap, built-in | Schema-on-write (mostly) | PostgreSQL, MySQL, Oracle |
| Document | One-to-many tree data, whole-doc access | Weak/absent | Schema-on-read | MongoDB, CouchDB, RethinkDB |
| Property graph | Highly interconnected, heterogeneous data | Traversal via edges | Schema-on-read | Neo4j, Titan |
| Triple-store | Same as property graph, RDF/semantic-web tooling | Traversal via predicates | Schema-on-read | Datomic, AllegroGraph |

## Worked Example
**LinkedIn résumé, three representations of the same data:**
- *Relational (normalized)*: `users` table + separate `positions`, `education`, `contact_info` tables joined by `user_id` foreign key. Requires a multi-way join or multiple queries to fetch one profile.
- *Document (JSON)*: the entire résumé as one nested document — `positions`, `education`, `contact_info` as arrays/objects inside a single record. One query fetches everything; the one-to-many tree structure is explicit.
- *Evolution problem*: once the app adds "organizations as entities" (so a company has its own page) and "recommendations" (user A writes about user B, showing B's current photo), the data stops being a clean tree — now there are many-to-many references across résumés. The relational model handles this natively via foreign keys/joins; the document model must either denormalize (accept staleness, e.g., outdated photos in old recommendations) or emulate joins in application code.
- **Why it works**: this progression is exactly why Kleppmann says relationship density — not "trendiness" — should drive model choice, and why document/relational are converging (both now support JSON columns and query-time joins to varying degrees).

## Key Takeaways
1. Pick your data model by relationship shape: one-to-many/tree → document; many-to-many/moderate → relational; many-to-many/highly interconnected → graph.
2. "Schemaless" document stores still have an implicit schema — it's enforced by application code at read time instead of by the database at write time.
3. Normalize (use IDs, not duplicated strings) whenever a value might change and is referenced from multiple places — the write/consistency cost of denormalization is the real trade-off, not aesthetics.
4. Declarative query languages beat imperative ones because they hide execution details, letting the engine optimize and parallelize without breaking client code.
5. Watch for many-to-many relationships creeping into a document-modeled application as features are added — this is the leading indicator that a document model is becoming the wrong fit.
6. Document databases and relational databases are converging (JSON columns, XML support, RethinkDB joins) — pick a hybrid where available rather than treating this as a binary choice.
7. MapReduce querying (MongoDB-style) sits between declarative and imperative — powerful but harder to write and optimize than a pure declarative query; prefer declarative aggregation pipelines/SQL when available.

## Connects To
- **Ch1**: Revisits the Twitter timeline example as a data-modeling case.
- **Ch3**: How these data models are actually implemented on disk (storage engines) — directly follows from this chapter's "layer 2 → layer 3" transition.
- **Ch4**: Schema evolution and encoding formats (JSON/XML/Avro/Protobuf) extend the schema-on-read/write discussion.
- **Ch10**: MapReduce is covered in full as a distributed batch-processing model, building on this chapter's brief introduction.
