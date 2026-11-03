# Notation and the Three Formats

The detail behind `SKILL.md` § 2–5 and § 7: each element, how to name it, and the entry and exit criteria for each format. Grounded in Brandolini (*Introducing EventStorming*), with the aggregate rules from Vernon (*Implementing DDD*, Ch. 10) and the boundary distinction from Khononov (*Learning DDD*). Colours are the plugin's house legend; Brandolini cares more about one consistent legend than about specific colours, and his own colours have varied.

## 1. The elements

| Element | Colour (house) | Is | Naming rule | Example |
|---|---|---|---|---|
| **Domain Event** | Orange | A fact that matters to the business, in the past tense | Noun + past-tense verb, business words | `PreorderPlaced`, `PayoutReleased` |
| **Hotspot** | Magenta, turned 45° | Missing knowledge, disagreement, pain or risk | A question or a statement of the problem | "Who decides a refund after pickup?" |
| **Actor** | Small yellow | A person or role who decides something | A role from the personas | Truck Owner, Renter |
| **External system** | Large pink | A system outside the domain that causes or receives events | Its role, or its product name if fixed | Payment Provider |
| **Opportunity** | Green, marked "+" | An idea or upside, often the flip side of a hotspot | A short proposal | "+ Text when the order is ready" |
| **Command** | Blue | A decision or intent that causes an event | Imperative verb + noun | `PlacePreorder`, `ReleasePayout` |
| **Policy** | Lilac | A reaction: whenever an event happens, issue a command, automatically or by a person's routine | "Whenever [event], then [command]" | "Whenever `ReturnInspected` with no damage, then `ReleaseDeposit`" |
| **Read Model** | Green | The information a person looks at before deciding | What it shows | Today's Pickup List |
| **Aggregate** (consistency unit) | Large pale yellow | The unit that accepts commands, holds one true invariant and emits events | A domain noun | Rental, Claim |

Two colours (green for opportunity and read model) differ by format and the "+" mark; transcripts record the type, never just the colour.

**Events are business facts.** `RowInserted`, `MessagePublished` and `ApiCalled` describe the technology. Ask what happened in the business, then name that.

## 2. Big Picture

**Entry:** the scope (the line of business or product) is named. Human session: the people with questions and answers are invited. Agent-run: the input artifacts are listed.

**Exit, all of:**
- The timeline reads as one story left to right, with no unexplained gap; the reverse narrative found nothing missing.
- Every event is a past-tense business fact.
- Pivotal events and swimlanes are marked, each with its reason.
- Boundary hints are recorded as candidates with evidence (pivotal event or swimlane, actor change, word that shifts meaning).
- Every disagreement is a hotspot; hotspots are ranked.
- Agent-run: every card has a source or is labelled *assumed*.

**Hands on to:** `subdomain-distillation` (D047-14), then `bounded-context-mapping`; the top hotspots and pivotal events choose the processes for Process Modelling.

## 3. Process Modelling

**Entry:** the Big Picture's exit holds; one process is chosen, usually between two pivotal events.

**The chain:**

```
Read Model → Actor → Command → System → Domain Event → Policy → Command → …   (until a stable end)
```

The *system* is the software or the external system that handles the command. At this format it is not yet an aggregate; aggregates replace it in Software Design.

**Exit, all of:**
- Every event traces back to a command, issued by an actor or a policy. No orphan events.
- Every path reaches a stable end, including the unhappy ones.
- Every policy reads "whenever …, then …".
- Every external system interaction is on the wall.
- Every break in the chain is a hotspot, not a guess.

## 4. Software Design

**Entry:** at least one process meets the Process Modelling exit.

**Aggregates.** For each command, ask which rule must hold *at every instant*, not just eventually (Vernon's test: would even a momentary violation cause real harm that a later correction couldn't fix?). Cluster the commands and events that share such a rule into one consistency unit, kept as small as the rule allows. Other units are referenced by identity and updated through Domain Events. One command changes one unit.

**Bounded Contexts.** Group the units by language: a context's boundary sits where a term's meaning changes (Khononov). Pivotal events and swimlanes from the Big Picture are often where the line falls. One context usually holds several aggregates.

**Exit, all of:**
- Every command is handled by exactly one named aggregate.
- Every aggregate states the invariant that justifies it.
- Every Bounded Context candidate states the language change that justifies it.
- No "one aggregate per context" or "one context per table" without that evidence.

**Hands on to:** `aggregate-design`, `bounded-context-mapping`, `domain-event-catalog`, `command-catalog`, `read-model-design`.
