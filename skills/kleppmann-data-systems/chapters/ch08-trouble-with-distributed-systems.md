# Chapter 8: The Trouble with Distributed Systems

## Core Idea
Distributed systems must be designed on the assumption that networks, clocks, and processes are all unreliable in ways that are indistinguishable from each other from the outside — a node can never know for certain whether a remote peer is slow, dead, or unreachable, so every fault-tolerance mechanism has to work without that certainty.

## Frameworks Introduced
- **Partial failure vs. total failure**: a single computer is designed to fail totally (crash) rather than silently corrupt results; a distributed system's defining hardship is that *some* parts can be broken while others work fine, and this brokenness is nondeterministic.
  - When to use: as the framing for why distributed systems engineering is qualitatively harder than single-node engineering, not just "the same thing at bigger scale."
- **The three system models (timing)**: Synchronous (bounded delay/pause/clock error — unrealistic), Partially synchronous (usually well-behaved, occasionally arbitrarily bad — the realistic default), Asynchronous (no timing assumptions at all, not even a clock).
  - When to use: to state precisely what an algorithm assumes before trusting a correctness proof about it.
- **The three system models (node faults)**: Crash-stop (dies once, never returns), Crash-recovery (dies, may return, stable storage survives), Byzantine (may actively lie or behave arbitrarily).
  - How: for most datacenter software, model as partially synchronous + crash-recovery; reserve Byzantine fault tolerance for environments with mutually distrusting parties (blockchains) or radiation-prone hardware (aerospace).
- **Safety vs. liveness properties**: safety = "nothing bad ever happens," violated at an identifiable instant and never un-violated once broken; liveness = "something good eventually happens," always has hope of being satisfied later.
  - How to apply: require safety to hold unconditionally in *all* situations of your system model; liveness is allowed a caveat ("...provided a majority of nodes are up and the network eventually recovers").
- **Fencing tokens**: a monotonically increasing number issued every time a lock/lease is granted; the protected resource itself rejects any write carrying an older token than one it has already seen.
  - When to use: any time a lock or lease is used to protect a resource across a network — a node's own belief that it holds the lock is not sufficient, because process pauses (GC, VM suspension) can make it wrong.

## Key Concepts
- **Network partition (netsplit)**: part of the network is cut off from the rest due to a fault; the book prefers the general term "network fault" to avoid confusion with data partitioning (sharding).
- **Timeout**: the only practical way to detect a possibly-dead node in an asynchronous network — but there is no value that's simultaneously fast (to detect real failures quickly) and safe (to avoid false positives under load spikes).
- **Time-of-day clock vs. monotonic clock**: time-of-day clocks (NTP-synced, can jump backward) answer "what time is it"; monotonic clocks (always move forward, meaningless in absolute terms) answer "how much time elapsed" — never use the former for measuring durations.
- **Clock confidence interval**: a clock reading is never a point in time, only a range (e.g., Google's TrueTime API in Spanner explicitly reports `[earliest, latest]`) — most APIs hide this uncertainty, which is dangerous.
- **Last Write Wins (LWW)**: a conflict-resolution strategy based on comparing physical clock timestamps — silently drops writes whenever clock skew makes a causally-later write appear "earlier."
- **Split brain**: two nodes both believe they are the leader — a symptom of failing to achieve consensus on leadership.
- **Byzantine fault**: a node actively lying or behaving arbitrarily (not just slow/dead) — distinct from and much harder to tolerate than ordinary crash faults.

## Mental Models
- Treat "I haven't heard a response" as meaning nothing: it could be a lost request, a lost response, a slow node, a dead node, or a delayed response — the sender fundamentally cannot distinguish these from the outside.
- Use dynamic-resource-partitioning as the lens for *why* networks and CPUs have variable delay: static allocation (telephone circuits) buys predictability at the cost of utilization; dynamic sharing (packet switching, multi-core scheduling) buys efficiency at the cost of queueing delay — variable delay is an economic trade-off, not a law of nature.
- Treat an unnoticed broken clock as more dangerous than an unnoticed broken CPU/network: hardware/network faults usually announce themselves loudly (total failure); clock drift silently produces wrong answers, so it demands active monitoring rather than reactive alerting.
- When reasoning about "is the leader still the leader," don't trust the node's own self-belief — trust only what a quorum currently agrees on (ties directly into Ch 9's consensus).

## Anti-patterns
- **Assuming synchronized clocks are precise because they're high-resolution**: a `clock_gettime()` call can return nanosecond precision while being wrong by 100+ ms — resolution is not accuracy.
- **Using LWW for conflict resolution without accepting its risk**: LWW can silently and permanently drop writes whenever a node with a lagging clock writes after (in wall-clock terms, "before") a node with a fast clock — this is invisible to the application, no error is raised.
- **Trusting a lock/lease without a fencing token**: a client that believes it holds a lease after a long GC/VM pause can corrupt shared storage by writing after another client has already taken over the lease — the resource itself, not the client, must reject stale-token writes.
- **Declaring a node dead based on a single node's own judgment**: use a quorum decision instead — any individual node's perception of "who is alive" can be wrong (a node with reversed outbound-message loss looks dead to everyone despite functioning perfectly).
- **Trying to make timeouts "correct" via more precise clock sync**: timeouts fundamentally must be tuned experimentally against your measured network's delay distribution — there is no theoretically correct value in an asynchronous network.

## Code Examples

```java
// Broken leader-lease renewal loop (illustrates the danger of process pauses)
while (true) {
    request = getIncomingRequest();
    if (lease.expiryTimeMillis - System.currentTimeMillis() < 10000) {
        lease = lease.renew();
    }
    if (lease.isValid()) {
        process(request);
    }
}
```
- **What it demonstrates**: this code is unsafe on two counts — (1) it compares a lease expiry set by a *different* machine's clock against the local clock, relying on clock sync; (2) it assumes negligible time passes between the check and `process(request)`, but a GC pause (or VM suspension) between those lines can let the lease expire mid-iteration with nothing to notice it happened. The fix requires fencing tokens on the protected resource, not a tighter loop.

## Reference Tables

| Timing model | Assumption | Realism |
|---|---|---|
| Synchronous | bounded network delay, process pause, clock error | unrealistic for real systems |
| Partially synchronous | usually bounded, occasionally unbounded | the practical default |
| Asynchronous | no timing assumptions, no clock at all | very restrictive, used for worst-case proofs |

| Node fault model | Assumption |
|---|---|
| Crash-stop | node fails once, never returns |
| Crash-recovery | node may fail and later recover; stable storage survives, memory does not |
| Byzantine | node may behave arbitrarily, including maliciously |

| Source of process pause | Typical cause |
|---|---|
| Stop-the-world GC | JVM/managed runtime garbage collection, can last minutes |
| VM suspension/migration | hypervisor pausing/moving a VM |
| OS context switch / hypervisor switch | scheduling, "steal time" under load |
| Synchronous disk I/O or page fault (swap) | slow disk, memory pressure/thrashing |
| SIGSTOP | manual or accidental process suspension |

## Worked Example
**Fencing tokens preventing storage corruption (Figure 8-4 → 8-5):** Client 1 acquires a file-storage lease with fencing token 33. It then stalls for an extended GC pause. While stalled, its lease expires; Client 2 acquires a new lease with token 34 and successfully writes to the file, including token 34 in its write request. Client 1 wakes up, still believing (incorrectly) it holds a valid lease, and sends its write carrying token 33. The storage service, remembering it has already accepted a write with the higher token 34, rejects Client 1's token-33 write outright. Without the token check on the storage side, Client 1's stale write would have silently corrupted the file — the fix works precisely because the *resource*, not the client, enforces monotonicity, and no amount of client-side "am I still the leader" checking could have caught this (that's exactly what the broken lease-loop code above illustrates).

## Key Takeaways
1. A node can never distinguish "message lost," "peer dead," and "response lost" from the outside — build every protocol assuming this ambiguity is permanent.
2. Timeouts are the only failure detector available, and there is no theoretically correct value — tune experimentally against your actual observed delay distribution, or use adaptive detectors (Phi Accrual).
3. Never use a time-of-day clock to measure elapsed durations; use a monotonic clock — time-of-day clocks can jump backward on NTP resync.
4. A clock reading is a confidence interval, not a point — treat sub-tens-of-milliseconds precision as meaningless unless your system (like Spanner's TrueTime) explicitly reports and waits out its uncertainty.
5. Fencing tokens, enforced by the resource being protected, are the only reliable defense against a node acting on a lock/lease it no longer actually holds.
6. Byzantine fault tolerance is usually not worth its cost inside a single trust domain (your own datacenter); reserve it for genuinely adversarial multi-party settings.
7. Distinguish safety properties (must hold always, unconditionally) from liveness properties (allowed to have conditions like "assuming a majority survive") when specifying what an algorithm guarantees.

## Connects To
- **Ch 9 (Consistency and Consensus)**: the majority-quorum idea for "truth" here becomes the formal basis of consensus algorithms; fencing tokens reappear as ZooKeeper's zxid.
- **Ch 5 (Replication)**: leader election and split-brain avoidance depend on the fault model established here.
- **Ch 7 (Transactions)**: process pauses and unreliable clocks are why distributed transaction coordinators (2PC, Ch 9) can't simply "wait a bit longer" to be sure.
- **CAP theorem** (Ch 9): built directly on the partial-synchrony/network-fault framing introduced here.
