# Example 3 — An enterprise multi-tenant platform: committees per tenant type, regulator salience, RAPID (hardest case)

Self-contained. The hardest common case, at the **enterprise** profile: a multi-tenant, multi-region platform (EU and US regions, per-tenant data-residency commitments, a 99.95% availability commitment) with two tenant types that buy through different groups, several internal teams, two audit firms piloting the product, and a banking supervisor whose attention arrives on a schedule. It shows what enterprise adds: a committee per tenant type with a collective-learning plan and consensus kit, salience for outside parties, influence links between teams, a pre-wiring order, and decision rights with a visible veto. Banks, residency and auditors appear because they are this product's facts, not general rules.

## Input

> A B2B platform for organisations accountable for sensitive data: 4,000 tenants (60 enterprise, the rest SMB). Lines: **Discover** (find and classify), **Govern** (policy and access reviews), **Prove** (audit evidence). Teams: three line teams, a platform / SRE team that runs both regions, an internal security and privacy office, legal, a two-person sales team, support.
>
> Vision (approved): organisations know what sensitive data they hold and can prove it, without sending it anywhere. Target segments: enterprise (EU banks first) and SMB self-serve.
>
> Facts: two audit firms are piloting Prove's evidence exports. Beta: six tenants; one US health system stalled when its CISO's team had not finished reviewing a new data processor.

## Working it

- **Two committees, not one.** An EU bank buys through compliance, security, data owners and procurement over months; an SMB tenant's IT generalist starts a free Discover trial and the owner approves a card payment. One table would give the SMB a procurement step it does not have, and the bank a self-serve path it will never use.
- **The audit firms are delivery, the bank's auditor is context.** The two firms piloting Prove are real organisations the product owner works with: delivery stakeholders (and a channel). "The auditor the bank will face" is part of the bank's buying context, recorded with salience.
- **The supervisor is dormant until a review is scheduled.** Power and legitimacy, no urgency: dominant. A scheduled supervisory data-inventory review makes it definitive, and moves the bank's head of compliance from interested to urgent. That is the buying trigger.
- **The internal security and privacy office can block releases** that touch residency. In the first draft it was "Consulted". It becomes an **Agree** on residency-affecting releases.
- **Influence runs through the SRE lead.** The security office trusts the platform / SRE lead's view of region isolation more than any line team's; the pre-wiring order follows that link.
- **The beta stall is a lesson for the committee, not a lost deal.** The health system's no decision started with a proposal sent before the security team had agreed on the problem. The collective-learning plan reverses the order.

## Output — the stakeholder map (abridged: SMB delivery rows and the re-score log shortened)

```markdown
---
name: stakeholder-map
product: data-accountability-platform
version: 2.0.0
phase: strategy
owner: product-strategist
created: 2026-10-23
summary: Two committees (EU banks sales-led, SMB self-serve); the bank's CISO team is the no-decision risk; the security office holds a veto on residency releases.
profile: enterprise
traces_to: strategy/vision-statement.md
---

# Stakeholder Map

## 1. Delivery Stakeholders

### Register

Scale: scored 1–5, where 3 and above is High.

| Stakeholder | Power | Interest | Quadrant | Salience | Engagement need |
|---|---|---|---|---|---|
| The product owner | 5 — approves every gate | 5 — owns the outcome | Manage Closely | Definitive | Options with a recommendation |
| Security and privacy office | 5 — can block residency-affecting releases | 2 — sees the product as one more system | Keep Satisfied | Dominant → definitive on any residency change | Region-isolation evidence before each such release |
| Platform / SRE team (both regions) | 4 — owns the 99.95% commitment | 4 — paged when it breaks | Manage Closely | Definitive | Capacity and failover impact of each theme, early |
| Line teams (Discover, Govern, Prove) | 3 — own their roadmaps | 5 — build it | Manage Closely | Dependent | Cross-line dependencies before planning |
| Audit firms piloting Prove (2) | 4 — their acceptance is the bank's proof | 4 — a new service line for them | Manage Closely | Dominant | Evidence-format changes reviewed before release |
| Legal | 3 — signs the data-processing terms | 2 — engaged per contract | Keep Satisfied | Discretionary → definitive per contract | Standard DPA and residency clauses ready before sales asks |
| Sales (2) | 2 — no product decision rights | 5 — quota | Keep Informed | Demanding | Which committee proof exists, per role |
| Support | 2 | 4 | Keep Informed | Discretionary | Known issues per region |

### Grid

    High power │ Keep Satisfied                     │ Manage Closely
               │ · Security and privacy office (→)  │ · The product owner · Platform / SRE
               │ · Legal                            │ · Line teams · Audit firms (2)
               │────────────────────────────────────│──────────────────────────────────
    Low power  │ Monitor                            │ Keep Informed
               │ (none)                             │ · Sales · Support
                  Low interest                         High interest

### Engagement Plan

| Stakeholder | What they need from us | Channel | Cadence | Owner (a person) | Re-score trigger |
|---|---|---|---|---|---|
| Security and privacy office | Region-isolation test results and data-flow diagram for the release | Review meeting | Before each residency-affecting release; quarterly otherwise | The product owner | Any residency incident or new region |
| Platform / SRE team | Each theme's capacity and failover impact | Planning session | Monthly | Platform lead | An availability miss |
| Audit firms | Evidence-format changes, sample exports | Working session | Bi-weekly during the Prove pilot | The product owner | A firm's methodology update |
| Line teams | Cross-line dependency list | Planning session | Monthly | The product owner | A dependency slips |
| Legal | DPA and residency clause changes | Written brief | Per contract template change | The product owner | A new jurisdiction |
| Sales, support | Proof per committee role; known issues | Shared doc | Each release | The product owner | — |

### Pre-wiring Order

Before the Strategy gate review: 1. platform / SRE lead (region isolation, so the next meeting starts from their view) · 2. security and privacy office (the veto holder, with the SRE lead's evidence) · 3. the two audit firms, one at a time (evidence formats) · 4. line leads, one at a time · then the group review.

### Influence Links

- Platform / SRE lead → security and privacy office: their region-isolation evidence is what the office trusts.
- Audit firms → bank heads of compliance: an audit firm's acceptance is the proof the bank's buyer needs.
- Sales → line teams: deal feedback reaches the roadmap only through the product owner's win/loss review.

### Decision Rights

| Decision | Responsible | Accountable | Agree (veto) | Consulted | Informed |
|---|---|---|---|---|---|
| Product direction and segments | product-strategist agent | The product owner | — | Line leads, sales | All teams |
| Release touching residency or a new region | platform-engineer agent; platform / SRE team | The product owner | Security and privacy office | Legal | Sales, support, audit firms |
| Evidence-export format | requirements-analyst agent; Prove team | The product owner | — | Audit firms | Bank tenants |
| Availability commitment changes | Platform / SRE team | The product owner | Legal | Security and privacy office | Sales |
| Phase gates | Governance hooks; test-strategist agent | The product owner | — | Line leads | All teams |

## 2. Customer Buying Committee

Hypothesised roles, not people. No cadence. Profiles are likely until design partners confirm them.

### Segment: EU banks, 2,000+ staff, data in two or more regions (sales-led)

| Role | Must believe to say yes | Likely objection | Proof that answers it | Likely profile | Loses by staying put | Confirmed by |
|---|---|---|---|---|---|---|
| Head of compliance (economic buyer) | The evidence will satisfy the auditor and supervisor | "Another tool to defend" | Audit-firm pilot results | Teacher — likely; **Mobilizer hypothesis** | The next sampled audit, and the supervisor's review | Beta tenant 1 (held); tenant 4 pending |
| CISO's team | No new place data goes | "A new data processor" | In-region architecture pack; network-traffic verification during the proof of concept | Skeptic or Blocker — likely | Nothing: the status quo is safe for them (the no-decision risk) | Tenants 1 and 4 security reviews |
| Data owners (users) | Findings they need not re-check | "More false positives" | Each finding shown with its reason and evidence; beta confirm rates | Go-Getter — likely | Manual re-checking | Beta usage of the confirm step |
| Procurement | The 99.95% commitment is contractual | SLA terms | Contract schedule and region runbooks | Guide — likely | — | First contract |

**Mobilizer hypothesis:** the head of compliance, carrying the insight that a sampled audit shows only what someone happened to look at. Tested in tenant 4 by whether they take that to the CISO's team themselves.
**Blocker:** the CISO's team, handled by the Mobilizer bringing them the architecture pack **before** any proposal (the health-system stall began with a proposal).
**Cost of no decision:** the bank faces the supervisor's review on a sampled audit; the CISO's team loses nothing, which is why it stalls.
**Collective-learning plan:** a session the head of compliance convenes with security, data owners and internal audit on the cost of the last sampled audit, before any proof of concept or price.
**Consensus kit:** one page each: compliance (auditor acceptance), CISO's team (in-region architecture pack), data owners (explained findings), procurement (contract schedule).
**Outside parties:** banking supervisor — dominant (power, legitimacy), definitive once a data-inventory review is scheduled; the bank's external auditor — discretionary, becomes the proof the head of compliance needs.

### Segment: SMB tenants (self-serve, free Discover up to 3 sources)

| Role | Must believe to say yes | Likely objection | Proof that answers it | Likely profile | Loses by staying put | Confirmed by |
|---|---|---|---|---|---|---|
| IT generalist (user, starts the trial) | It finds real sensitive data in an afternoon | "No time to set it up" | Discover finds files on 3 sources in the trial | Go-Getter — likely; **Mobilizer hypothesis** | The next customer security questionnaire answered by guesswork | Trial-to-paid interviews |
| Owner or finance (pays) | It costs less than the questionnaire it answers | "We're too small for this" | A completed customer questionnaire from a similar tenant | Skeptic — likely | Lost deals with larger customers | Upgrade interviews |

**Blocker:** none likely; the risk is no decision when the trial ends unnoticed. **Cost of no decision:** the next questionnaire answered from memory.

## 3. Blocker Risk Register

| Stakeholder or role | Half | Concern (their words) | Kind of trust | Risk | Mitigation, delivered before the ask |
|---|---|---|---|---|---|
| Bank CISO's team | Committee | "A tool that reads all our files is our biggest data risk" | Security | High | Architecture pack: in-region processing, no data egress, mTLS, read-only scoped credentials; traffic verification offered in the proof of concept |
| Bank data owners | Committee | "I can't trust what it classifies" | Automated decisions | High | Every finding with its reason, evidence and a correct-this control; confirm rates published |
| Security and privacy office | Delivery | "Residency is a promise we can't take back" | Security | High | Region-isolation tests per release, reviewed with the SRE lead before the Agree is requested |
| Bank head of compliance | Committee | "My board won't fund another tool" | Change | Medium | A short story from beta tenant 1: the sampled audit that missed a share, and what changed once findings were continuous |

## 4. Re-score Log

| Date | Stakeholder | Change | Trigger |
|---|---|---|---|
| 2026-10-14 | Security and privacy office | Dominant → definitive | US-East region added to the roadmap |
```
