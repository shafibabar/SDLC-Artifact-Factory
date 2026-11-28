# Chaos Engineering Method from Primary Sources: steady state, blast radius, abort, and verifying resilience patterns
**Authors:** The Principles of Chaos Engineering page (principlesofchaos.org, no authors named on the page); Ali Basiri, Lorin Hochstein, Nora Jones, Haley Tucker, "Automating chaos experiments in production" (ICSE 2019, posted by the authors to arXiv); Betsy Beyer, Chris Jones, Jennifer Petoff, Niall Richard Murphy (eds.), *Site Reliability Engineering* (O'Reilly, 2016), as published free by Google at sre.google
**Domain:** Testing (chaos and resilience method)

Accessed 2026-11-28. principlesofchaos.org shows "Last Update: 2019 March"; no version, authors or licence are stated on the page. The ChAP paper is arXiv:1905.04648 v1 (12 May 2019), arXiv non-exclusive distribution licence 1.0. The SRE book carries no version; pages read as served that day.

Sources:
- [POC] Principles of Chaos Engineering, https://principlesofchaos.org/
- [CHAP] Basiri, Hochstein, Jones, Tucker, "Automating chaos experiments in production", https://arxiv.org/abs/1905.04648 (full text read through arXiv's ar5iv rendering, https://ar5iv.labs.arxiv.org/html/1905.04648)
- [TR] SRE book ch. 17 "Testing for Reliability", https://sre.google/sre-book/testing-reliability/
- [HO] SRE book ch. 21 "Handling Overload", https://sre.google/sre-book/handling-overload/
- [CF] SRE book ch. 22 "Addressing Cascading Failures", https://sre.google/sre-book/addressing-cascading-failures/

## Core Concepts

**The experiment**
- Definition: "the discipline of experimenting on a system in order to build confidence in the system's capability to withstand turbulent conditions in production" [POC].
- Four steps: define "steady state" as "some measurable output of a system that indicates normal behavior"; hypothesise it continues in both a control and an experimental group; introduce variables "that reflect real world events like servers that crash" (also malfunctioning drives, severed network connections); "try to disprove the hypothesis by looking for a difference in steady state" between the groups [POC].
- Steady state is defined on outputs: "Focus on the measurable output of a system, rather than internal attributes of the system" [POC]. Netflix's worked example uses stream starts per second (SPS), "a count of the number of successful video stream starts", and states the hypothesis as "users should still be able to stream video when the bookmarks service fails" [CHAP].
- Vary real-world events, prioritised "either by potential impact or estimated frequency" [POC].

**Production, controlled environments, automation**
- "Chaos strongly prefers to experiment directly on production traffic" [POC]; ChAP's experiments "run directly against our production environment" [CHAP].
- Starting in a controlled environment first: not stated by [POC] or [CHAP]. The SRE book's nearest guidance is to "start with testing that delivers the most impact with the least effort" rather than insisting on hermetic environments, and to run failure tests "in a small slice of production" [TR] [CF].
- When a production experiment is justified: not stated as a rule. ChAP excludes "unsafe" experiments, such as failing a dependency that has no fallback, before running anything [CHAP].
- "Automate experiments and run them continuously" [POC]. ChAP's Monocle discovers dependencies, timeouts and fallbacks and generates experiments ranked by a criticality score and a safety score [CHAP].

**Blast radius, abort and rollback**
- Minimise blast radius: the Chaos Engineer must "ensure the fallout from experiments" is contained; some short-term negative impact is accepted [POC].
- ChAP's numbers: 1% of users in the experiment group, a matching 1% control group, baseline and canary clusters at 1% of the original cluster, and all concurrent experiments together capped at "5% of the total traffic" in a region [CHAP].
- Abort: "If ChAP detects excessive customer impact during an experiment, then it will stop the experiment early" [CHAP]. No threshold value is published; the paper calls this check "a cruder test" than its statistical comparison, and says the error-count threshold had to be "substantially" raised because of noise [CHAP].
- Rollback: at completion "ChAP unpublishes the experiment event to stop Zuul from re-routing traffic and injecting faults"; the paper does not say explicitly that the same happens on an early stop [CHAP].
- Other guards: experiments run only in business hours, and never during a regional failover [CHAP].

**What a result means**
- "Passing a test or a series of tests doesn't necessarily prove reliability. However, tests that are failing generally prove the absence of reliability" [TR].
- Rerunning a statistical fault test such as Chaos Monkey after a fix "doesn't definitively prove that the observed fault is fixed" [TR].
- ChAP does not claim experiments prove resilience; they "identify weaknesses that could lead to outages if left unchecked", and a flagged result needs an engineer to confirm it is a real vulnerability [CHAP].
- Limits named: FIT "can only cause one type of error per injection point"; small sub-populations (one device type) can hide inside aggregate SPS [CHAP].
- Reporting: results go to dashboards with a statistical baseline-versus-canary comparison (Kayenta); low false positives matter or "the service teams would lose confidence in the results" [CHAP]. Results are "best given to the engineer before he or she switches context" [TR]. No report template is published by any source read.

**Fault injection mechanics (Netflix)**
- Faults are scoped per request: requests are annotated "with metadata that indicate that a call should be failed", and the metadata travels with the request; all requests of a selected user are annotated [CHAP].
- Two fault kinds: "failure - throw an exception instead of executing the call" and "latency - add latency before executing the call" [CHAP].

## Actionable Techniques

How each resilience pattern is verified, as far as the sources say:

- **Circuit breaker.** The sources describe no experiment for open, fail-fast, half-open and close transitions. [CF] does not mention circuit breakers. [CHAP] reports a Hystrix case where thread-pool rejections made the command "unconditionally serve fallbacks for a period of time", fixed by lowering the timeout: the evidence is the customer metric plus the breaker's behaviour, not the breaker alone [CHAP]. The transition checks belong to the library's documented contract (see `go-resilience-fault-injection-official-docs.md`).
- **Retries.** "Always use randomized exponential backoff"; "Limit retries per request"; a per-process retry budget (example: 60 per minute) beyond which "don't retry; just fail the request"; retry only retriable errors [CF]. Google's budgets: up to three attempts per request, and retries only while they are under 10% of a client's requests; only "the layer immediately above" a rejecting layer retries [HO]. Stacked retries multiply to "the product of the number of attempts at each layer" [CF]. An experiment asserts attempt counts and budget against these bounds (using them as assertions is this note's inference).
- **Timeouts and deadline propagation.** Set a deadline; "servers should employ deadline propagation" so the RPC tree shares one absolute deadline; check the time left before each stage; propagate cancellation through the stack [CF]. Inject latency longer than the deadline and assert the caller returns by its deadline and downstream work stops (inference from [CF] and [CHAP]'s latency fault).
- **Bulkheads.** Not named in the sources. [CF] describes limiting "25% of your threads" to any one client for fairness; [CHAP]'s Hystrix finding concerns thread-pool rejection. A test that one pool's exhaustion leaves another pool serving is not described.
- **Graceful degradation.** Serve reduced work; it "shouldn't trigger very often", must be exercised because "the code path you never use is the code path that (often) doesn't work", and should alert when many servers degrade [CF]. A failing noncritical backend must not make the frontend start "rejecting lots of requests"; blackholing a backend is a suggested test [CF]. [CHAP]'s bookmarks example is exactly this check.
- **Load shedding.** Overloaded servers "fail early and cheaply", e.g. HTTP 503 once in-flight requests pass a threshold; LIFO or CoDel queues drop likely-abandoned work [CF]. "Load test components until they break"; a good component "will instead be able to reject a few requests and survive" [CF]. A backend should "reject requests quickly" rather than collapse [HO].

## Applies To

| Skill/Agent | Gap | What the source adds |
|---|---|---|
| go-chaos-test, python-chaos-test | Hypothesis on internals, or none | Steady state on an output metric; control versus experiment group; hypothesis worded as "users can still X when Y fails" |
| go-chaos-test, python-chaos-test | No abort, unbounded blast radius | 1% groups, 5% cap, early stop on customer impact, business-hours and no-failover guards |
| go-chaos-test, python-chaos-test | A pass read as proof | "Passing ... doesn't necessarily prove reliability"; failing tests prove its absence |
| go-chaos-test, python-chaos-test | Pattern checks that cannot fail | Retry budgets (3 attempts, 10%), deadline propagation, cheap rejection, degradation exercised and alerted |

## Caveats

- Nothing was run. No experiment, fault or service was executed.
- All pages were read through a fetch tool that summarises and quotes in short segments, not end to end; the ChAP PDF was not readable directly and was read via arXiv's ar5iv HTML rendering.
- Rosenthal and Jones: their O'Reilly book *Chaos Engineering* (2020) and the 2017 O'Reilly report were not openly available to the fetch (oreilly.com returned 403), so nothing here is drawn from them. The 2016 IEEE Software paper by Basiri et al. with Rosenthal (arXiv:1702.05843) could only be read as an abstract, which covers none of the questions.
- Not stated in any source read: a rule for when to start in a staging environment before production; numeric abort thresholds; a report template; an experiment design for circuit-breaker state transitions or for bulkhead isolation; jitter formula or backoff constants (see the Go note for library defaults).
- The pattern-to-experiment mapping in Actionable Techniques is this note's inference where marked; the sources state the patterns, not test procedures for each.
