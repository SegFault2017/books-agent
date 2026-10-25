# Chapter 1: Reliable, Scalable, and Maintainable Applications

## Core Idea
Data-intensive applications should be evaluated against three independent axes — reliability, scalability, and maintainability — and there is no single "magic" architecture that satisfies all three; the right design depends on your specific load parameters and failure modes.

## Frameworks Introduced
- **The Three Concerns (Reliability / Scalability / Maintainability)**: Kleppmann's organizing framework for the entire book.
  - When to use: Any time you're evaluating or designing a data system's architecture.
  - How: Ask (1) does it keep working correctly under hardware/software/human faults? (2) can it cope with growth in data, traffic, or complexity? (3) can many different engineers work on it productively over time?
- **Fault vs. Failure**: A *fault* is one component deviating from spec; a *failure* is the whole system stopping service to the user.
  - When to use: When designing fault-tolerance — the goal is to design mechanisms that keep faults from cascading into failures, not to eliminate faults (impossible).
  - How: Add redundancy/isolation at the boundary where a fault could propagate; deliberately induce faults (Chaos Monkey-style) to verify the boundary holds.
- **Describing Load with Load Parameters**: Scalability is meaningless as a single label ("X is scalable"); it's only meaningful relative to a specific load parameter and growth pattern.
  - When to use: Before any scaling discussion or capacity planning.
  - How: Pick the parameter that matches your bottleneck (requests/sec, read:write ratio, concurrent users, cache hit rate, fan-out) and ask "what happens if this doubles?"
- **Percentiles over Averages for Performance**: Use response-time percentiles (p50/p95/p99/p999), not the mean, to describe performance.
  - When to use: Any SLA/SLO definition or performance-tuning discussion.
  - How: Sort response times; median = p50; tail latencies (p99, p999) matter because they hit your most valuable/heaviest users and because of tail latency amplification across parallel backend calls.

## Key Concepts
- **Data-intensive vs. compute-intensive**: applications bottlenecked by data volume/complexity/velocity, not raw CPU.
- **Fault-tolerant / resilient**: system anticipates certain classes of faults and copes with them (never all classes).
- **Load parameters**: the small set of numbers that characterize system load (RPS, read/write ratio, fan-out, etc.).
- **Throughput**: records processed per second (batch systems).
- **Response time vs. latency**: response time = what the client observes (service time + network + queueing delay); latency = time a request spends waiting to be handled.
- **Tail latency amplification**: if an end-user request requires multiple parallel backend calls, the probability that at least one is slow rises, so the overall request is slow more often than any individual backend call.
- **Scaling up vs. scaling out**: vertical (bigger machine) vs. horizontal (shared-nothing, more machines).
- **Elastic vs. manually scaled systems**: automatic resource provisioning vs. human-driven capacity decisions.
- **Operability, Simplicity, Evolvability**: the three components of maintainability.
- **Accidental complexity**: complexity that arises from implementation, not from the problem itself (Moseley & Marks) — the target for removal via abstraction.
- **Composite/composed data system** (Figure 1-1): a service built by stitching together several specialized tools (e.g., a main database plus a separately maintained cache and full-text search index, kept in sync by application code) behind one API. You are no longer just an application developer — you're the designer of a new, special-purpose data system, responsible for guarantees like "the cache is correctly invalidated on writes." This theme resurfaces as Change Data Capture and derived data in Ch 11–12.

## Mental Models
- Think of a "big ball of mud" as the failure mode of ignoring simplicity — treat abstraction as your primary tool against accidental complexity.
- Use "if I do X, Y will happen" as the litmus test for good operability — a system with unpredictable behavior is hard to operate no matter how good its uptime looks today.
- Think of evolvability as agility applied at the scale of an entire data system (possibly many services), not just a single codebase — traditional Agile/TDD techniques operate at too small a scope for this book's concerns.

## Anti-patterns
- **Designing for a single, generic "magic scaling sauce"**: there is no one-size-fits-all scalable architecture; an architecture built on assumptions about which operations are common becomes actively counterproductive if those assumptions are wrong.
- **Over-engineering scalability in an early-stage product**: premature investment in scaling wastes effort that should go toward iterating on product-market fit.
- **Restrictive interfaces meant to prevent human error**: if abstractions/APIs are too restrictive, operators will work around them, negating the safety benefit — balance is required.
- **Averaging percentiles directly** (e.g., across time windows or machines) — mathematically meaningless; the correct approach is to add the underlying histograms.

## Reference Tables
| Percentile | Meaning | Typical use |
|---|---|---|
| p50 (median) | Half of requests are faster | "Typical" user experience |
| p95 | 95% of requests are faster | General SLA target |
| p99 | 99% of requests are faster | Tail latency for high-value/heavy users (Amazon's stated SLA metric) |
| p999 | 99.9% of requests are faster | Usually too expensive to optimize for — diminishing returns |

## Percentiles in Practice & Worked Example
See [ch01-percentiles-and-worked-example.md](ch01-percentiles-and-worked-example.md) for the full write-up: how to compute percentiles cheaply at scale (forward decay, t-digest, HdrHistogram) and the Twitter home-timeline fan-out case study (Figures 1-1 through 1-3, both read-time and write-time approaches, and the hybrid resolution).

## Key Takeaways
1. Reliability, scalability, and maintainability are independent axes — optimize each deliberately, don't assume one implies another.
2. Identify your load parameters before discussing "scalability" — the question is always "what happens if X grows?", never "is this scalable?" in the abstract.
3. Use percentiles (not averages) for performance SLAs; tail latency compounds when requests fan out to multiple backend calls.
4. Prefer tolerating faults over preventing them, except where prevention is the only option (e.g., irreversible security breaches).
5. Architect for your current, evidence-based load parameters — not hypothetical future scale, especially pre-product-market-fit.
6. Reduce accidental complexity through good abstractions; this is the primary lever for long-term maintainability.
7. A hybrid architecture (mix of two strategies by segment) often beats either pure strategy when load is heavily skewed (e.g., celebrity accounts).

## Connects To
- **Ch2**: The Twitter fan-out example returns as a data-modeling illustration; Ch12 revisits it after covering derived data/stream processing.
- **Ch4**: Rolling upgrades (mentioned re: hardware fault tolerance) connect to schema evolution and compatibility.
- **Ch5**: Replication lag directly extends the reliability discussion to distributed systems.
- **Percentile aggregation**: connects to monitoring/observability practices used throughout Part II and III.
