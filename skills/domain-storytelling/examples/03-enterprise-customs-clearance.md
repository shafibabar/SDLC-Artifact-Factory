# Example 3 — Enterprise: several organisations, a group per party, and boundaries left as candidates (hardest case)

Self-contained. **Portline** clears imported freight for a logistics group across three ports, at the **enterprise** profile. Five organisations take part in one clearance: the importer, the freight forwarder, the customs broker, the port operator and the customs authority. The product owner arranged a session with a broker and a forwarder; the importer and the port operator couldn't attend.

## Input

> **User:** "Do one big story with everyone in it, and turn each organisation into a Bounded Context so we can start the services."

## Working it

- **Scope:** coarse-grained / as-is / pure for the whole clearance, because the question is orientation across organisations.
- **One story, told in parts.** The broker and the forwarder each tell the part they do; several storytellers is fine. The importer's and the port operator's parts are drafted from documents and marked *assumed* (a mixed story: `run: workshop`, with those sentences' sources saying *assumed*), and their questions go to the product owner.
- **Groups per party, with hints, not contexts.** The hand-over at each organisation is a hint, and so is the word change: the forwarder's "consignment" is the broker's "entry" and the authority's "declaration". But an organisation isn't automatically a Bounded Context. The broker and the forwarder might share one model; the authority is external and will be integrated with, not built. The groups go to `bounded-context-mapping` as candidates.
- **Variants:** "customs holds the goods for inspection" is its own story; "a document is missing" is its own story too, because the forwarder said it causes half the delays.

## Output — the reply, and extracts of `coarse-clearance-as-is.md`

> One coarse story covers the whole clearance. The broker and the forwarder told their parts; the importer's and the port operator's parts are drafted from your documents and marked as assumptions, with questions for you. The story shows five groups, one per organisation, and the biggest clue is the word: the same shipment is a "consignment", an "entry" and a "declaration" depending on who's handling it. Those are candidate boundaries for the next step, not decided contexts. Two organisations may share one model, and the customs authority is outside: we'll integrate with it, not build it. Two variant stories follow: an inspection hold, and the missing-document case the forwarder said causes half the delays.

```markdown
| # | Actor | Activity | Work object | To (recipient) | Annotation | Source |
|---|---|---|---|---|---|---|
| 1 | Importer | sends | purchase details | Freight Forwarder | Invoice and packing list | *assumed* |
| 2 | Freight Forwarder | books | the consignment | Port Operator | — | session 2026-07-14 (forwarder) |
| 3 | Freight Forwarder | sends | the consignment papers | Customs Broker | — | session 2026-07-14 (forwarder) |
| 4 | Customs Broker | prepares | the entry | — | Tariff codes per line | session 2026-07-14 (broker) |
| 5 | Customs Broker | lodges | the declaration | Customs Authority | — | session 2026-07-14 (broker) |
| 6 | Customs Authority | releases | the declaration | Customs Broker | Most within hours | session 2026-07-14 (broker) |
| 7 | Customs Broker | tells | release notice | Freight Forwarder | — | session 2026-07-14 (broker) |
| 8 | Port Operator | releases | the container | Haulier | Once fees are paid | *assumed* |

## Groups (candidate boundaries)

| Group | Sentences | Hint |
|---|---|---|
| Importer | 1 | Hand-over to the forwarder |
| Forwarding | 2–3 | Role takes over; "consignment" |
| Brokerage | 4–5, 7 | Role takes over; "consignment" becomes "entry" |
| Customs Authority | 5–6 | External organisation; "declaration"; runs on its own clock |
| Port | 8 | Role takes over; "container"; triggered by fees, not by the declaration |
```

## Why this is right

- Several storytellers each told their own part; the missing parties' sentences are drafted, labelled and questioned, not presented as told.
- An organisation per group is evidence, not a context. The reply says why some may merge and why one is external.
- The variant that matters most to the business got its own story, chosen because the people doing the work said it hurts.
