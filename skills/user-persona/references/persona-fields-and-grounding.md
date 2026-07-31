# Persona Fields, Grounding, and the Proto→Research Lifecycle

Reference material for the `user-persona` skill. This file defines every persona field, states the
evidence-based grounding requirement, walks the proto-persona → research-persona lifecycle, and lists
exactly what to leave out. It is self-contained: an agent applying `user-persona` can produce a
complete, correctly-grounded persona from this file plus the template in
`persona-template-and-examples.md`.

---

## 1. Why grounding is the whole point

A persona is only worth building if its attributes are *true of a real type of person*. The failure
mode this skill guards against is a persona assembled from imagination — plausible-sounding goals and
frustrations that no real user ever expressed — because such a persona will confidently generate
requirements for problems nobody has. The discipline that prevents this is **evidence-based grounding**:
every load-bearing attribute traces to something a real person actually said or did, gathered in a way
that could not have been satisfied by politeness.

The grounding standard is Rob Fitzpatrick's *The Mom Test*: good discovery data is a report of a
**specific past event**, not an opinion about the future or a compliment. The three rules:

1. **Talk about their life, not your idea.** The conversation is about how the person works today, not
   a pitch or a request to validate your product.
2. **Ask about specifics in the past, not generics or hypotheticals.** "What did you do the last time
   this happened?" beats "what do you usually do?" beats "what would you do if?"
3. **Talk less, listen more.** The interviewer extracts facts; they do not explain, defend, or sell.

Three kinds of data feel like validation but carry no signal, and none of them may ground a persona
attribute:

| Bad data | What it sounds like | Why it is worthless | Fix |
|---|---|---|---|
| **Compliment** | "That's a great idea," "I'd definitely use that" | Politeness, unconnected to any behavior | Deflect into a specific-instance question |
| **Fluff** | "I always…", "I usually…", "I would…" | An imagined average or future, phrased as fact | Press for the last actual occurrence |
| **Idea** | "You should build a dashboard for that" | A proposed solution, not a validated need | Dig behind it for the motivating problem |

An attribute grounded in any of these is not grounded at all. A design partner rating a need 9/10 out
of goodwill toward a founder they like is a compliment wearing a number.

---

## 2. Proto-persona vs research-persona — the two kinds

Every persona is exactly one of two kinds and **must be labeled** at the top of the artifact.

### Proto-persona (`PROTO — assumption-based`)

An archetype built from the team's existing knowledge, informed guesses, and assumptions — **before**
any customer interviews exist. It is a hypothesis about who the user is. Proto-personas are legitimate
and valuable: they let discovery start, they seed `jtbd-analysis`, and they give the team a concrete
target to test against. What makes a proto-persona *honest* is that it is clearly marked as
assumption-based, so no one mistakes a guess for a finding. Every attribute in a proto-persona is
implicitly prefixed "we believe…".

### Research-persona (`RESEARCH — interview-grounded`)

The same archetype after its attributes have been confirmed, corrected, or replaced by evidence from
real conversations conducted to the Mom-Test standard. A research-persona's attributes are prefixed "we
observed…". Each one traces to a specific person's specific past behavior.

### The lifecycle: start proto, validate to research

```
Draft proto-persona ──► Run design-partner conversations ──► Upgrade each attribute
   (assumptions)          (Mom-Test-compliant)                 to research grounding
        │                                                            │
        └────────────── attributes contradicted by evidence ◄───────┘
                        are corrected or deleted, not defended
```

The persona is never "finished as proto." A proto-persona that is still driving requirements months
later, unvalidated, is the honesty-rule violation this skill exists to catch. Track grounding
**per attribute**, not per persona — a single persona commonly has some fields validated to research
and others still proto at any given moment. Mark each field so a reviewer can see the seam.

| Dimension | Proto-persona | Research-persona |
|---|---|---|
| Source | Team assumptions, prior knowledge | Real interviews, specific past behavior |
| Attribute prefix | "We believe…" | "We observed…" |
| Confidence | Hypothesis to be tested | Evidence to be acted on |
| Risk if unlabeled | Guess mistaken for fact | — |
| Required label | `PROTO — assumption-based` | `RESEARCH — interview-grounded` |
| Repo timing | Before Stage 1 closed beta | During/after Stage 1 design-partner conversations |

At this repo's actual scale — 3-5 named design partners in `gtm-strategy`'s closed-beta motion — there
is no large sample to average away one badly-elicited answer. That makes Mom-Test discipline *more*
important, not less: at n=3-5 a single politeness-driven attribute can define the whole persona.

---

## 3. Every field defined, with its elicitation question

Each persona field below is defined, told what design decision it drives (its load-bearing use), and
paired with the Mom-Test-compliant question that surfaces it for a research-persona. If a field cannot
be tied to a downstream use, it does not belong in the persona.

### Segment / role
- **Definition:** the *type* of user and the company profile they sit in — size, industry, regulatory
  exposure — consistent with the ICP from `gtm-strategy`. The ICP is the company; the persona is the
  person inside it.
- **Drives:** which requirements apply at all; scopes every other attribute.
- **Elicitation:** established from the ICP and from who the design partner actually is, not asked.

### Primary goal
- **Definition:** the single outcome this person most wants to achieve in their work.
- **Drives:** the core job story's "so that" clause; the product's primary value proposition for them.
- **Elicitation:** "What are you ultimately trying to get done here? What does a good week look like?"

### Secondary goals
- **Definition:** 2-3 further outcomes they care about but rank below the primary.
- **Drives:** secondary requirements; the "Should/Could" tail in `moscow-prioritization`.
- **Elicitation:** "Besides that, what else are you on the hook for?"

### Success metric
- **Definition:** how this person judges whether they succeeded — what gets them recognized or promoted.
- **Drives:** which outcomes the product must make visible; often an NFR or a report requirement.
- **Elicitation:** "How is your work measured? What did the last review focus on?"

### Current approach
- **Definition:** how they accomplish the goal today, **without** your product — the workaround.
- **Drives:** the switching story. You cannot explain why someone adopts a product without knowing what
  they are switching *from*. This is the most load-bearing behavior field.
- **Elicitation:** "Walk me through the last time you had to do this. What did you actually do?"

### Primary frustration
- **Definition:** the single biggest pain with the current approach.
- **Drives:** the sharpest job story; the pain the value proposition must relieve.
- **Elicitation:** "What was the most annoying or costly part of that last time?"

### Secondary frustrations
- **Definition:** 2-3 additional recurring pains.
- **Drives:** the backlog of related problems the product can expand into.
- **Elicitation:** "What else about that process trips you up regularly?"

### Decision-making style
- **Definition:** analytical (data-driven) / relational (trusts referrals) / spontaneous (early
  adopter) / methodical (waits for proof).
- **Drives:** onboarding, trust-building, and evidence the product must surface to earn adoption.
- **Elicitation:** "Last time you adopted a new tool for work, what convinced you it was worth it?"

### Technical literacy
- **Definition:** how comfortable this person is with technology — self-serves vs needs guidance.
- **Drives:** usability NFRs, whether a CLI is acceptable, how much hand-holding onboarding needs.
- **Elicitation:** observed from how they describe their current tools, not asked directly.

### Information sources
- **Definition:** where they go to learn about new tools (peer communities, analyst reports, LinkedIn).
- **Drives:** GTM channel selection (feeds `gtm-strategy`), not the product itself.
- **Elicitation:** "Where did you first hear about the last tool you brought in?"

### Trigger
- **Definition:** the specific event that causes this person to start looking for a solution.
- **Drives:** the situational front of a JTBD job story ("When \<trigger\>…"); demand timing.
- **Elicitation:** "What actually happened right before you started looking for a fix last time?"

### Expected time to first value
- **Definition:** how quickly they must see value before they lose patience and revert.
- **Drives:** a usability/onboarding NFR — a hard constraint on first-run design.
- **Elicitation:** inferred from their described patience with the current workaround.

### Adoption barrier
- **Definition:** the most likely reason they abandon the product after trying it.
- **Drives:** onboarding constraints; what must never be required in the first session.
- **Elicitation:** "What made the last tool you dropped not stick?"

### Jobs to be done (the link out)
- **Definition:** the core job(s) this persona is hiring a solution for — the explicit handoff to
  `jtbd-analysis`. Every persona names at least one.
- **Drives:** the entire job-story set written against this persona.
- **Elicitation:** synthesized from the goal + current approach + trigger, once those are grounded.

---

## 4. What to leave out

The default temptation is to novelize the persona — a name, a face, a commute, a favorite coffee. Almost
all of it is decoration. Leave out anything that does not change a design decision:

| Leave out | Why |
|---|---|
| Age, gender, hometown, marital status | Do not predict product behavior; goals and pains do. |
| A stock photo / fictional backstory | Adds vividness, drives zero requirements. |
| Personality color (hobbies, "loves hiking") | Not traceable to any requirement, story, or NFR. |
| Exact salary, tenure, headcount reporting lines | Unless they gate a buying decision, they are noise. |
| Aspirational traits ("a visionary, forward-thinking leader") | Marketing language; model who they *are*, not who you wish. |
| Invented quotes not said by a real person | A fabricated quote reads as evidence but is imagination. |

The single test for every attribute: *can this be used to write or validate a requirement, a job story,
an onboarding decision, or an NFR?* If not, cut it. A short, fully load-bearing persona beats a rich,
mostly-decorative one every time.

Demographics are not banned outright — regulatory exposure, company size, and industry are demographic
facts that *do* drive requirements for a compliance product. The rule is narrower: leave out
demographics that do not drive a design decision. Include the ones that do; name the reason they do.

---

## 5. Grounding quality checklist

Before a persona is presented for review:

- [ ] Labeled `PROTO` or `RESEARCH` at the top; mixed personas mark grounding per attribute.
- [ ] Every load-bearing attribute (goals, current approach, frustrations, trigger) is present.
- [ ] For a research pass, each such attribute traces to a specific-past-event answer, not a
      compliment, fluff, or an unsolicited idea.
- [ ] No attribute is decoration — each maps to a requirement, job story, onboarding decision, or NFR.
- [ ] The persona links to at least one JTBD and can serve as an "As a \<persona\>" story role.
- [ ] Demographics present only where they drive a design decision, with the reason named.
