# Chapter 9: Consistency and Consensus

## Core Idea
Consensus — getting all nodes to durably agree on one value — is the fundamental abstraction underlying leader election, atomic commit, and linearizable storage; it is provably impossible to guarantee in a purely asynchronous model (FLP result), but achievable in practice once you allow timeouts, and linearizability, total order broadcast, and consensus turn out to be different faces of the same problem.

## Frameworks Introduced
- **Linearizability**: makes a replicated system behave as if there were only one copy of the data, with every operation appearing to take effect atomically at some single instant between its start and end — it is a *recency* guarantee, not an isolation guarantee.
  - When to use: locking/leader election, uniqueness constraints (usernames, seat bookings), and any time two independent communication channels could otherwise race (e.g., a message queue and a file store).
  - How: implementable via single-leader replication (reads from the leader or synchronous followers), or natively via consensus algorithms (ZooKeeper, etcd) — generally NOT achievable with multi-leader or leaderless replication, even with strict quorums (`w + r > n` is not sufficient, see Worked Example).
- **CAP ("Consistent or Available when Partitioned")**: Kleppmann's corrected framing — you don't get to "pick 2 of 3"; network partitions *will* happen, so the real choice is binary and only arises during an actual partition: be linearizable and refuse requests from cut-off replicas, or stay available and give up linearizability. He calls the "pick 2 of 3" framing unhelpful and recommends avoiding CAP terminology altogether in favor of precise language.
  - How to apply: use to explain *why* a design must choose, not as a design taxonomy — CAP only formalizes one consistency model (linearizability) and one fault type (partitions); it says nothing about latency trade-offs, which usually matter more.
- **Total order broadcast**: a messaging discipline guaranteeing reliable delivery (no message lost) and totally ordered delivery (every node sees messages in the same order) — proven equivalent to consensus and to a linearizable compare-and-set register.
  - When to use: database replication (state machine replication), implementing serializable transactions via deterministic stored procedures, and building a linearizable lock service with fencing tokens.
- **Epoch numbering + quorum voting** (the shared mechanism behind Viewstamped Replication, Paxos, Raft, Zab): each leader election increments a monotonic epoch/ballot/term number; a leader may only act after collecting a quorum of votes, and the two quorums (election quorum, proposal quorum) are guaranteed to overlap by at least one node, which prevents two leaders from ever both believing they're valid in the same epoch.
  - How: this is the mechanism that breaks the circularity "electing a leader requires consensus, but total order broadcast requires a leader" — a weaker guarantee ("leader is unique *per epoch*, and higher epoch always wins") is sufficient.

## Key Concepts
- **Eventual consistency**: the weakest guarantee — replicas converge *eventually*, with no bound on when, and no guarantee about what stale reads return in the meantime; better named "convergence."
- **Register**: the abstract unit of linearizability analysis — one key, row, or document, evaluated via `read(x) ⇒ v` / `write(x, v) ⇒ r` / `cas(x, vold, vnew) ⇒ r` operations plotted on a timeline.
- **Causal consistency**: a *partial* order (cause before effect) as opposed to linearizability's *total* order; strictly weaker than linearizability but the strongest model that remains available under network partitions and doesn't pay linearizability's latency tax.
- **Lamport timestamp**: a `(counter, node ID)` pair where every node/client tracks the max counter it has seen and fast-forwards its own counter past it on every message — produces a total order consistent with causality, but cannot tell you whether two operations were concurrent (unlike version vectors), and cannot solve uniqueness constraints alone (see Anti-patterns).
- **In-doubt / uncertain transaction**: a 2PC participant that has voted "yes" but hasn't heard the coordinator's final decision — it cannot unilaterally commit or abort and must block until the coordinator recovers.
- **Attiya–Welch result**: proves linearizable read/write response time is inevitably proportional to network delay uncertainty — there is no way to make linearizability both correct and fast on a high-variance network; this is why it's dropped for *performance*, not just fault tolerance.

## Mental Models
- Serializability (Ch 7) and linearizability are easily conflated because both mean "can be arranged in sequential order" — but serializability is about *transactions* (multi-object, isolation), linearizability is about *individual registers* (recency). A database can offer both together (strict serializability) or either alone.
- Think of the causal order as a version-control graph (like Git): mostly a straight line, occasionally branching (concurrent operations) and merging — incomparable branches are truly concurrent, with no causal link.
- Total order broadcast is "consensus, run repeatedly": each message delivery is one consensus round deciding "what's the next message," so anything reducible to total order broadcast (database replication, serializable transactions, linearizable locks) is reducible to consensus.
- When you feel the urge to reach for a physical timestamp to decide "which write really happened first" across nodes, that urge is almost always a sign you actually need consensus (or at minimum a logical clock), because physical clocks cannot be trusted to reflect causality (Ch 8).

## Anti-patterns
- **Treating Lamport timestamps as sufficient for uniqueness constraints**: totally ordering after the fact tells you who "won" retroactively, but a node deciding *right now* whether to accept a username claim cannot know if another node is concurrently creating a lower-timestamped claim — this requires total order broadcast (know when the order is *finalized*), not just a total order.
- **Assuming Dynamo-style strict quorums (`w + r > n`) give you linearizability**: they don't, even under a strict quorum — variable network delays let one reader see the new value while a concurrent reader (starting later) sees the old value, violating the recency guarantee (see Worked Example).
- **Using "CAP: pick 2 of 3" as a design framework**: partitions are not optional to "not pick" — they will occur; the real, narrower trade-off only activates *during* a partition, and CAP's formal scope (one consistency model, one fault type) makes it a poor general design tool.
- **Building a real distributed consensus algorithm from scratch**: "probably not advisable — it's hard;" use battle-tested implementations (ZooKeeper/Zab, etcd/Raft) instead of re-deriving Paxos/Raft/VSR yourself.
- **Using ZooKeeper/etcd as a general-purpose application database**: they're designed for small, slow-changing coordination data (leader pointers, config) replicated via consensus, not high-frequency application state — use a dedicated store (e.g., Apache BookKeeper) for that.

## Code Examples

```
# The linearizable-compare-and-set-from-total-order-broadcast recipe:
1. append("claim: alice wants username 'alice123'") to the log
2. wait for your own appended message to be delivered back to you
3. read all messages claiming that username in delivery order;
   if YOUR message is first for that username -> commit the claim, ack success
   else -> abort
```
- **What it demonstrates**: how a linearizable atomic compare-and-set can be built purely from total order broadcast's ordering + reliable-delivery guarantees — all nodes agree on delivery order, so all nodes agree on who "won" the race, with no extra coordination round needed.

## Reference Tables

| Guarantee | Order type | Survives network partition? | Coordination cost |
|---|---|---|---|
| Linearizability | total | no (must sacrifice availability or consistency) | high — proportional to network delay uncertainty |
| Sequential consistency | total (but not real-time-recent) | better than linearizable | moderate |
| Causal consistency | partial | yes — strongest partition-tolerant model | low |
| Eventual consistency | none (convergence only) | yes | lowest |

| Consensus algorithm | Epoch name | Notes |
|---|---|---|
| Viewstamped Replication (VSR) | view number | earliest of the group |
| Paxos / Multi-Paxos | ballot number | Multi-Paxos = repeated rounds optimized like total order broadcast |
| Raft | term number | known edge case: one flaky link can cause perpetual leader churn |
| Zab (ZooKeeper) | epoch (zxid high bits) | zxid doubles as a global fencing token |

| System model for consensus | Byzantine tolerance | Fault assumption |
|---|---|---|
| Standard (this chapter's algorithms) | none assumed | crash-recovery, non-Byzantine nodes |
| Byzantine-tolerant variants | up to <1/3 nodes faulty | needed for adversarial / untrusted-party settings only |

## Worked Example
**Nonlinearizable execution despite a strict quorum (Figure 9-6):** `n=3` replicas, initial `x=0`. A writer sends `write(x,1)` to all three (`w=3`). Concurrently, Client A reads from a quorum of two nodes (`r=2`) and happens to see the new value `1` on one of them (the write raced ahead on that replica). Client B's read *begins after A's read has already completed*, and reads from a different quorum of two nodes — both of which still show the old value `0`. The quorum condition `w + r > n` (3+2>3) is satisfied, yet this is **not linearizable**: B's request starts strictly after A's completes, so a linearizable system must guarantee B sees at least what A saw — but B got the stale value. The fix (used partially by Cassandra) is synchronous read repair before returning results, plus writers reading the latest quorum state first — at a real performance cost, and even then a linearizable *compare-and-set* on Dynamo-style storage is impossible without a full consensus algorithm underneath.

## Key Takeaways
1. Linearizability is a recency guarantee on individual registers, not an isolation guarantee on transactions — don't conflate it with serializability (Ch 7).
2. CAP is best understood narrowly ("during an actual partition, choose consistency or availability") rather than as a general 3-way design menu — Kleppmann recommends avoiding the term.
3. Causal consistency is the strongest model that survives network partitions without linearizability's latency cost — reach for it before reaching for full linearizability if your problem doesn't strictly require total ordering.
4. Lamport timestamps give you a total order consistent with causality, but not knowledge of when that order is *finalized* — that requires total order broadcast, which is why uniqueness constraints need more than logical clocks.
5. Total order broadcast, linearizable compare-and-set, and consensus are all mathematically equivalent — solving one solves the others.
6. Real consensus algorithms (VSR, Paxos, Raft, Zab) all rely on the same core trick: monotonic epoch numbers plus overlapping election/proposal quorums, which resolves the "need a leader to elect a leader" circularity.
7. Don't hand-roll a consensus algorithm — use ZooKeeper, etcd, or a database that embeds one; the failure modes (like Raft's pathological single-flaky-link case) are subtle and well-documented only in mature implementations.

## Connects To
- **Ch 7 (Transactions)**: serializability vs. linearizability distinction; strict serializability combines both.
- **Ch 8 (Trouble with Distributed Systems)**: the majority/quorum "truth" concept and fencing tokens introduced there are formalized into epoch numbering and consensus safety properties here.
- **Ch 5 (Replication)**: single-leader replication is "consensus of the dictatorial variety" until you add automatic failover, at which point you need real consensus to avoid split brain.
- **Ch 11 (Stream Processing)**: state machine replication via total order broadcast connects directly to how event logs (Kafka-style) are used for replication.
- **2PC (this chapter, "Atomic Commit")**: shown to be a consensus algorithm — but "not a very good one," since it blocks indefinitely on coordinator failure and requires unanimous rather than majority agreement.
