# Elicitation and Evidence

Self-contained. This file covers how the requirements-analyst gathers requirements when it has no stakeholders in a room, and how every requirement shows where it came from. Read it before eliciting requirements, and whenever the user asks for interviews, workshops or "what the stakeholders want".

## The situation this plugin is in

Requirements texts assume an analyst with access to people: interviews, workshops, observation, focus groups. Karl Wiegers and Joy Beatty (*Software Requirements*) list those techniques and match them to the kind of project; Thomas and Angela Hathaway (*Getting and Writing IT Requirements in a Lean and Agile World*) pair each with the failure it guards against. The requirements-analyst is an agent working from written artifacts, plus whatever the user tells it. Techniques that need a person present do not transfer as-is. Pretending they happened is the worst outcome: the evidence looks real and is not.

Rob Fitzpatrick's *The Mom Test* gives the reason invented evidence is so harmful: an opinion about the future ("they would want…") is weak even when a real person says it. An agent writing it on that person's behalf has neither the person nor the past facts.

## Technique selection

Choose techniques by the situation, not in a fixed order.

| Technique | Use when | Output is labelled |
|---|---|---|
| **Document analysis** of the Strategy and Ideate artifacts (impact map, JTBD analysis, personas, OKRs, stakeholder map, competitive analysis) | Always | The artifact and ID it came from |
| **Interview snapshots** the user supplied (`ideate/interviews/snapshots/`) | Whenever they exist | The snapshot file |
| **Existing-system and data analysis**: the spreadsheet, legacy screens, exports, reports, the paper form | Something is being replaced, however small | The file or system examined. It surfaces fields, rules and transition requirements nobody mentions |
| **Asking the user** | Every gap, conflict or TBD. The user is the product champion for every user class unless a design partner is named | "Product owner, <date>" |
| **Prototype or walkthrough review** with the user | The user cannot judge a requirement from prose | The review date and what changed |
| **Interview guide for the user to run** | A user class has not been heard from and its needs matter to the selected path | Not evidence yet. The guide is written (`jtbd-analysis`); requirements wait on the snapshot or go in as assumptions |

**Never "simulate" an interview or workshop.** If a department, tenant role or stakeholder has not been heard from:

1. Write what you believe they need as an **assumption** (ASM-n), with the impact if it is false.
2. Write the **question** that would confirm it, in Fitzpatrick's form: about a specific past event, not a hypothetical ("Tell me about the last time a permit came back for missing documents. What happened next?", not "Would you want automatic checks?").
3. Mark any requirement that rests on it as depending on ASM-n, and put the question on the TBD list.

## Ideas, compliments and wants from real people

When a snapshot or the user reports a stakeholder's idea ("you should add a dashboard"), Fitzpatrick's advice is to treat it as evidence of a problem, not a spec. Run the why-chain (`./requirement-types-and-classification.md`, the wants section): record the problem, keep the idea as a design note. Praise ("they loved the demo") is not evidence of any requirement.

## Conflicting stakeholder needs

At enterprise scale different user classes want incompatible things (one department wants every field mandatory, another wants a two-minute form). The analyst does not resolve these privately. Record each as a **conflict**: the requirements involved, who wants what, the consequence of each choice, and a recommendation. The user decides, and the decision is recorded with the date. Lemay (*Product Management in Practice*) treats surfacing a trade-off to whoever has authority as part of the connective role, not a failure of it.

## Name the translation

Before drafting, write one line at the top of the FRD saying what is being translated into what, for whom. For example: "Translates the impact map's selected path (SOL-1, SOL-3) and job stories JS-1.1 to JS-1.3 into requirements `nfr-specification`, `epic-definition` and the Design phase can act on without asking again." Lemay's point is that the value of the document is the shared understanding it creates; naming the translation makes a missing input visible.

## Source labels

Every user requirement and every business rule names its source. Acceptable sources:

- an impact-map deliverable on the selected path (with the map path);
- a job statement and job story (J-n → JS-n.m), and through them the snapshot or the `[assumption]` tag the JTBD analysis gave them;
- a Key Result (KR-n.m);
- a stakeholder concern from the stakeholder map;
- a table-stakes capability from the competitive analysis;
- a regulation, contract or policy (for business rules and constraints);
- the product owner, with a date.

"Common sense", "best practice" and "competitors probably have it" are not sources. A requirement with no source is cut or moved to the waiting room.
