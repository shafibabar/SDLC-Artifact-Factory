# Sources of Power — Prompts for the Guiding Policy

Self-contained. Read this while choosing a strategy kernel's **guiding policy**: when the draft policy relies on no advantage, when it spreads effort evenly, or when you cannot decide between two approaches. Each source below comes from the second part of Rumelt's *Good Strategy / Bad Strategy*, where he explains where a good strategy gets its force. They are prompts, not a checklist: a good policy usually draws on one or two.

Rumelt's cases are companies, armies and governments, not software products. The product questions below are this plugin's reading of his ideas, not his words.

---

## The sources

| Source | Rumelt's idea | Ask of the product | A policy that uses it sounds like |
|---|---|---|---|
| **Leverage** | Concentrate effort on a pivot point where a small, well-chosen action has a large effect | Is there one moment, user or integration where a small change unlocks most of the value? | "Win the month-end close, the moment every firm feels the pain, before anything else" |
| **Proximate objectives** | Set targets close enough to be feasible, which remove ambiguity so people know what to do next | What is the next position we can surely reach, from which the rest becomes clearer? | "First prove classification accuracy on one storage type, then widen" |
| **Chain-link systems** | When performance is capped by the weakest link, improving any other link adds nothing | Is there one capability whose weakness caps everything else (trust, accuracy, latency, a data boundary)? | "Fix the export reliability before any new feature; nothing else matters while users don't trust it" |
| **Design** | Advantage from parts fitted together, coordinated in time and space, that only work as a whole | Do our actions only make sense together? Could a rival copy one part and get nothing? | "Templates, the import tool and the onboarding call are one system: each fails alone" |
| **Focus** | Concentrate on one segment, job or advantage instead of serving everyone a little | Which one segment or job do we serve first, and who do we say no to? | "Serve accounting firms of 5–50 staff only; no in-house finance teams this year" |
| **Using advantage** | An advantage is a narrow, situational asymmetry; the work is to deepen it, widen where it applies, or make it harder to copy | What can we do that the real alternatives (including doing nothing) cannot, and that the customer values? | "Exploit that our processing never leaves the customer's region; build every feature on it" |
| **Using dynamics** | Ride a wave of change (technology, regulation, cost, behaviour) by seeing early what it changes and what it leaves alone | What shift makes today's positions unstable, and what does it *not* change? | "A new reporting rule forces every firm to change tools this year; be the easy switch" |
| **Inertia and entropy** | Organisations resist change (inertia) and drift into disorder (entropy) unless managed | Is a rival or our own team stuck? Is the backlog drifting away from the policy? | "Incumbents can't drop their on-prem installs; we never build one" |

Rumelt is sceptical of **growth** as a source of power in itself: healthy growth is the result of an advantage that keeps being renewed. A policy whose only content is "grow" is a goal, not a policy.

---

## Using the advantage honestly

Where an advantage is claimed, it has to come from evidence, not assertion. Dunford's positioning method (*Obviously Awesome*) gives the test, and `competitive-analysis` holds its output:

1. **Name the competitive alternatives**: what the customer would do if the product did not exist, including a spreadsheet, a consultant or tolerating the pain.
2. **Name the unique attributes** the alternatives lack.
3. **Keep only the attributes that are both real and valued** by the best-fit customer.

What survives is the advantage the guiding policy may rely on. An empty result is an honest finding: the policy should then rely on focus, leverage or dynamics rather than claim an advantage it does not have. (Maurya's Lean Canvas treats an empty Unfair Advantage block the same way, as a truthful admission; see `business-model-canvas`.)

---

## Ruling things out

Every source above implies a "no". Write each exclusion with its reason, traced to the diagnosis:

> **Rules out:** an on-premises edition — *because* the crux is onboarding speed, and every install adds weeks.

An exclusion without a reason is a mission-style scope line: it can only be repeated, not argued with. An exclusion with a reason can be revisited when the diagnosis changes.
