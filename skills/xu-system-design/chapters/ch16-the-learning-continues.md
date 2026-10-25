# Chapter 16: The Learning Continues

## Core Idea
Good design judgment comes from studying real architectures. Read how real companies solved problems, focusing on shared principles and on what problem each technology solves. Before interviewing at a company, read its engineering blog. (Thin chapter: a curated reading list plus the afterword.)

## Frameworks Introduced
- **Study method**: for each real-world system, extract (1) the shared principles and (2) the underlying technologies, and research what problem each technology solves.
- **Pre-interview prep**: read the target company's engineering blog to learn its stack and adopted systems.

## Key Concepts
Real-world reading list grouped by the chapter it reinforces:

| Topic | Papers / talks |
|---|---|
| News feed (Ch 11) | Facebook Timeline (denormalization) · Building Timeline · Serving Facebook Multifeed · Twitter Timelines at Scale |
| Chat (Ch 12) | Erlang at Facebook (Facebook Chat) · Facebook Chat · WhatsApp architecture |
| Caching (Ch 1) | Scaling Memcache at Facebook |
| KV store (Ch 6) | Dynamo (Amazon) · Bigtable · TAO (Facebook social graph) |
| Unique IDs (Ch 7) | Announcing Snowflake (Twitter) |
| Storage / Drive (Ch 15) | Google File System · Differential Synchronization (Google Docs) · How We've Scaled Dropbox · Haystack (Facebook photos) |
| Video (Ch 14) | YouTube Architecture · YouTube Scalability talk · 360° view of the Netflix stack |
| General scaling | Scale at Facebook · Amazon / Google / Instagram / Twitter / Uber / Pinterest / LinkedIn / Flickr architecture posts · Netflix experimentation (A/B) and recommendations |

Engineering blogs worth following: Airbnb, Amazon, Dropbox, Facebook, GitHub, Google, Instagram, LinkedIn, Netflix, Pinterest, Shopify, Slack, Stripe, Twitter, Uber, Highscalability, system-design-primer (and ~25 more listed in the book).

## Mental Models
- Treat every architecture write-up as a **worked example of the 4-step framework**: what were the requirements, the high-level design, and the deep-dive trade-offs?
- Map each new technology back to a **problem from Chapters 1–15** (Memcache → caching, Snowflake → ID generation, Dynamo → KV store).

## Anti-patterns
- **Memorizing designs** without understanding which problem each component solves.
- **Walking into an interview** without knowing the company's own systems.

## Key Takeaways
1. Real-world systems are the fastest way to build design intuition.
2. Read for principles and for the problem each technology solves, not for product trivia.
3. Read the target company's engineering blog before the interview.
4. Practice makes perfect.

## Connects To
- **Ch 1, 6, 7, 11, 12, 14, 15**: each has a source paper or post in the list above.
- **Ch 3**: use the 4-step framework to dissect each case study.
