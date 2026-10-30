# Wave 1 Findings: Strategy, Discovery and Validation Skills (issue #1293, parent #1292)

- **Scope:** 21 skills. Strategy (7): business-model-canvas, competitive-analysis, gtm-strategy, mission-statement, okr-authoring, roadmap-authoring, stakeholder-mapping. Discovery (9): epic-definition, impact-mapping, jtbd-analysis, moscow-prioritization, nfr-specification, requirements-analysis, story-mapping, user-persona, user-story-writing. Validation (5): acceptance-sign-off, beta-program-design, feedback-template, uat-plan, uat-scenario.
- **Read:** every file in each skill; the exemplar `skills/vision-statement/` and `evals/vision-statement/`; `skills/skill-authoring-standards/SKILL.md`; `discovery/fresh-eyes/README.md` and `01-dogfood.md`; `agents/product-strategist.md` and `agents/requirements-analyst.md`; every file in `research/product-strategy-and-gtm/`, `research/requirements-and-user-stories/`, `research/service-design/`, `research/storytelling-and-narrative/`, `research/human-ai-collaboration/`; and every other research file that names a Wave 1 skill (`testing/agile-testing-crispin-gregory.md`, `testing/explore-it-hendrickson.md`, `testing/testing-web-apis-winteringham.md`, `testing/specification-by-example-adzic.md`, `data-and-analytics/lean-analytics-croll-yoskovitz.md`, `devops-and-delivery/accelerate-forsgren-humble-kim.md`, `devops-and-delivery/platform-engineering-fournier-nowland.md`, `software-architecture/fundamentals-of-software-architecture-richards-ford.md`, `data-governance-and-mdm/simple-data-mdm-srinivasan.md`, plus the incidental mentions in the MDM, API-first and AI-engineering files).
- **Layout linter:** `python3 scripts/lint-skill-layout.py --skill <name>` reports **0 findings for all 21**. That is because every non-body file sits in `references/`, which the linter accepts. It does not catch mixed files (a template and a worked example in one file), so the folder work below is real even though the linter is green.
- **No edits outside `discovery/fresh-eyes/`.** Nothing committed.

---

## Narrative: what I found

**1. The skills are mostly sound prose with real research already folded in, but none of them declares it.** None of the 21 skills has a `sources:` field. Fifteen of them already name a book in their prose: Moore, Dunford, Cagan, Olsen, Lauchengco, Fitzpatrick, Blank, Cohn, Patton, Hathaway, Hendrickson, Crispin and Gregory, Forsgren, Fournier, Mollick. Several also name books that are **not** in `research/`: Osterwalder, Maurya, Adzic's *Impact Mapping*, the Google/Doerr OKR conventions, the DSDM MoSCoW rules and the JTBD originators. Under `skill-authoring-standards/SKILL.md:80` ("a framework cited from memory looks grounded and isn't"), those citations have to either trace to a research file or be dropped. The research files' own "Applies To" tables are also **out of date**. They describe the skills before the last refactor. For example, `crossing-the-chasm-moore.md:30` says gtm-strategy has no beachhead step, but `gtm-strategy/SKILL.md:47-60` now has one. And `four-steps-to-the-epiphany-blank.md:26` says beta-program-design lacks earlyvangelist screening, but `beta-program-design/SKILL.md:59-68` has it. So treat each research file's gap analysis as a starting point to check, not as a list of current findings.

**2. The pilot found "positioning taught as vision". Wave 1 has the same class of defect: one concept taught in two places with different answers, or in the wrong place.** The biggest:

- **Strategy-phase order loops back on itself.** `roadmap-authoring/SKILL.md:80` reads the OKR set first ("the roadmap is the delivery sequence that makes the OKRs achievable"). `okr-authoring/SKILL.md:89` reads the roadmap first ("Objectives translate roadmap themes"). The agent runs Roadmap at step 7 and OKRs at step 8 (`agents/product-strategist.md:163-164`), so the roadmap's first step reads an artifact that does not exist yet.
- **Three skills claim the North Star Metric.** The pilot made it part of the vision (`vision-statement/SKILL.md:65`). `okr-authoring/SKILL.md:95,137` and `agents/product-strategist.md:164,198` still have the OKR set name it. `mission-statement/SKILL.md:13` also triggers on "north star".
- **The mission skill copies the pilot's defect.** `mission-statement/SKILL.md:139-142` says the positioning statement "compresses the mission's verb, beneficiary, and differentiator". A mission has no differentiator: its own required components are what we do / for whom / to what end (`:73-77`). Positioning is derived from competitive alternatives (Dunford, `obviously-awesome-dunford.md:8`).
- **Personas, JTBD and impact maps are labelled Strategy-phase work.** `user-persona` (`:7,13`), `jtbd-analysis` (`:8,13,94`) and `impact-mapping` (`:8,11,136`) all say `phase: strategy` / "used during Strategy", and their output templates stamp `phase: strategy`. The agents now say these are written in Ideate (`agents/product-strategist.md:81-87`, `agents/requirements-analyst.md:179-183`). The skills' own descriptions are a direct cause of dogfood defect #1256: product-strategist wrote personas and JTBD into `strategy/`, then Ideate wrote a second personas artifact (`01-dogfood.md:25,49`).
- **MoSCoW priority is asked for six steps before MoSCoW runs.** `epic-definition/SKILL.md:151`, `requirements-analysis/SKILL.md:67,121` and `user-story-writing/SKILL.md:153,210` all require a MoSCoW priority. But `moscow-prioritization` is step 11 of 11 in Ideate (`agents/requirements-analyst.md:189`).
- **MoSCoW's 60% capacity rule cannot be computed in this pipeline.** It needs effort estimates in person-weeks (`moscow-prioritization/SKILL.md:126-127`, `references/moscow-rubric.md:89-90`). No Wave 1 skill produces story estimates, epic size is "relative, not story points" (`epic-definition/references/epic-format-and-criteria.md:81`), and AI agents do the building. The rule the requirements-analyst escalates on (`agents/requirements-analyst.md:314`) has no input.
- **Validation skills contradict each other.** `uat-plan/SKILL.md:104` requires zero open High defects to exit; `acceptance-sign-off/SKILL.md:46` allows open Highs on the conditional path. `uat-plan/SKILL.md:59` says no one both executes and signs off, but its proxy executor is the product owner (`:64`), who is also a signer (`:66`). For a solo operator that is always the case.
- **DORA thresholds disagree in three places.** `nfr-specification/SKILL.md:160-163`, `dora-metrics/SKILL.md:69-74` and `research/devops-and-delivery/accelerate-forsgren-humble-kim.md:8` give different values for medium change-failure rate and for low-performer recovery time (MTTR). The NFR skill also makes "high performer" DORA targets mandatory for every service (`:149`). That goes against the research file's own caution (`accelerate…md:49`: "don't treat them as hard thresholds").

**3. Every example is the same one product.** In 20 of the 21 skills, every supporting file is about the data-estate / SOC 2 / Maya Chen product. Some of that product detail has leaked into **trigger surfaces and hard rules**:

- `user-persona/SKILL.md:7-8,121-132` tells every product to model "at minimum" a Data Steward and a Compliance Officer.
- `uat-scenario/SKILL.md:13-14` triggers on "a Data Steward or Compliance Officer".
- `beta-program-design/scripts/validate-beta-program-design.sh:63-70` **fails** any beta record that does not name SOC 2 CC6/CC7/A1. The dogfood's lunch-order tracker would fail it.

The exemplar uses three different products at three scales (`vision-statement/examples/01-03`). None of the 21 does.

**4. Nothing reflects product scale.** No Wave 1 skill mentions the lean / standard / enterprise profiles in `skills/artifact-manifest/resources/phase-requirements.json`. That file says, for example, "lean: one page" for the roadmap and "lean: one objective" for OKRs. The dogfood produced 11 Strategy artifacts and about 1,590 lines for a 20-person lunch tool (`01-dogfood.md:29`).

**5. Five worked examples break the summary rule.** Their frontmatter has no `summary:` (competitive-analysis, gtm-strategy, roadmap-authoring, stakeholder-mapping, requirements-analysis worked examples), and `gtm-strategy/SKILL.md:220` lists output frontmatter without `summary`. This breaks CLAUDE.md § Artifact Standards item 1, which the side-task merged in dc5d07f made mandatory.

**6. Three research files must not become `sources:` entries.** `agile-ux-storytelling-baker.md:7`, `art-of-crafting-user-stories-lee.md:7` and `learn-product-management-with-stories.md:7` each say their author could not recall the book and wrote general practice instead. Listing them would make citations that look grounded and are not.

**Size counts:** S = 7, M = 13, L = 1.

---

## Findings table

| ID | Lens | Evidence (file:line) | Observation | Proposal | Kind | Impact H/M/L | Effort S/M/L | Confidence |
|---|---|---|---|---|---|---|---|---|
| W1-1 | depth | All 21 `SKILL.md` frontmatter (no `sources:`); e.g. `gtm-strategy/SKILL.md:1-21` cites Moore/Dunford/Lauchengco in prose | No skill declares `sources:`, though 15 name research-library books in prose | Add `sources:` per the per-skill lists below; drop or source every framework attribution that has no research file | docs | M | S | High |
| W1-2 | depth | `roadmap-authoring/SKILL.md:8-9,80`; `okr-authoring/SKILL.md:89`; `agents/product-strategist.md:163-164` | Roadmap reads OKRs first and OKRs read the roadmap first; the agent runs the roadmap first | Pick one order (Cagan: objectives before an outcome roadmap, `inspired-cagan.md:16-17`), fix both skills and the agent sequence | bug | H | S | High |
| W1-3 | depth | `vision-statement/SKILL.md:65`; `okr-authoring/SKILL.md:95,137`; `agents/product-strategist.md:164,198`; `mission-statement/SKILL.md:13` | Three skills own the North Star Metric | The vision derives it; OKRs consume and check it; drop "north star" from the mission trigger | bug | M | S | High |
| W1-4 | depth | `mission-statement/SKILL.md:73-77` vs `:139-142` | Claims positioning compresses "the mission's … differentiator"; a mission has no differentiator. Same family as the pilot defect | Rewrite the gtm link: mission supplies scope and beneficiary; positioning derives from competitive alternatives (Dunford) | bug | M | S | High |
| W1-5 | usage | `user-persona/SKILL.md:7,13`; `jtbd-analysis/SKILL.md:8,13,94,185`; `impact-mapping/SKILL.md:8,11,136`; `01-dogfood.md:25,49` | Skills label themselves Strategy-phase; the agents say Ideate; the dogfood produced duplicate personas | `phase: ideate` in frontmatter and output templates; descriptions say Ideate; MAJOR bump (trigger surface changes) | description-rewrite | H | S | High |
| W1-6 | usage | `user-persona/SKILL.md:7-8,121-132` | Every product is told to model a Data Steward and a Compliance Officer | Move those personas to `examples/`; describe the primary-persona rule generically | portability | H | S | High |
| W1-7 | usage | `beta-program-design/scripts/validate-beta-program-design.sh:63-70`; `SKILL.md:90-91,149,199-200` | Validator fails any beta record that does not name SOC 2 CC6/CC7/A1 | Make the data-handling check read the product's own compliance frameworks (`sdlc-config.json`), or check only for "no relaxation" wording; update `tests/scripts/validate-beta-program-design.test.sh` | bug | H | S | High |
| W1-8 | depth | `epic-definition/SKILL.md:151`; `requirements-analysis/SKILL.md:67,121`; `user-story-writing/SKILL.md:153,210`; `agents/requirements-analyst.md:189` | MoSCoW priority required 2–6 steps before MoSCoW runs | Replace with "priority: pending MoSCoW" (or a provisional Kano tag) and fill it at step 11 | bug | M | S | High |
| W1-9 | usage | `moscow-prioritization/SKILL.md:71-82,126-127`; `references/moscow-rubric.md:89-90`; `epic-definition/references/epic-format-and-criteria.md:81` | 60% rule needs person-week estimates nobody produces; humans don't build the product | Decide how capacity is measured for an agent-built product (relative size points from epic/story sizing, or a count-based ceiling); write the rule against that input | process | H | M | High |
| W1-10 | depth | `story-mapping/SKILL.md:90-91` vs `moscow-prioritization/SKILL.md:133,162` | Story map says "a slice ≠ a Must cut"; MoSCoW says "Musts equal the MVP slice" | Reconcile: Musts ⊆ walking skeleton (Patton, `user-story-mapping-patton-economy.md:41`), not equality | bug | M | S | High |
| W1-11 | depth | `nfr-specification/SKILL.md:160-163`; `dora-metrics/SKILL.md:69-74`; `research/devops-and-delivery/accelerate-forsgren-humble-kim.md:8` | Three different DORA cluster tables (medium change-failure rate 0–15% vs 16–30%; low-performer MTTR 1 week–1 month vs 1–6 months) | Delete the table from the NFR skill and point to `dora-metrics`; check that one table against the book (the 46–60% figure looks like 2019 DORA report data, not *Accelerate*) | bug | M | S | Medium |
| W1-12 | usage | `nfr-specification/SKILL.md:149,212`; `accelerate…md:49`; `phase-requirements.json` (profiles) | "High performer" DORA targets mandatory for every service; all 10 categories required at every scale | Scale delivery NFRs to the profile; targets from the product's context, with the clusters as calibration only | process | M | S | High |
| W1-13 | depth | `nfr-specification/SKILL.md:181-203`; `fundamentals-of-software-architecture-richards-ford.md:37` | No step cross-checks NFRs for conflicts before the architecture handoff | Add a conflict cross-check step (availability vs residency, latency vs encryption, …) feeding `enterprise-architect` | new-reference | M | S | High |
| W1-14 | depth | `uat-plan/SKILL.md:59,64,66,153` | The "roles separated" rule is broken by the plan's own proxy path; for a solo operator it is always broken | State the solo-operator case explicitly: proxy execution + same-person sign-off → capped at conditional, recorded as a known limitation | bug | H | S | High |
| W1-15 | depth | `uat-plan/SKILL.md:104` vs `acceptance-sign-off/SKILL.md:46,83,125` | UAT exit forbids open Highs; sign-off allows them (conditional). Sign-off also contradicts itself (`:46` vs `:83`) | One rule for High defects, stated once in `acceptance-sign-off`, referenced by `uat-plan` | bug | M | S | High |
| W1-16 | depth | `uat-plan/SKILL.md:49-51` vs `uat-scenario/SKILL.md:44-45` | Plan maps US-005 → UAT-002, UAT-003; scenario mandates the same ID root (AC-US-005 → UAT-005) | Use a 1:N ID convention (UAT-005a/b) in both | bug | L | S | High |
| W1-17 | maintainability | `uat-plan/references/exploratory-session-template.md:20-81`; `uat-scenario/references/exploratory-charter-link.md:20-60` | Charter template and heuristics written twice | Keep them in `uat-plan`; `uat-scenario` points to them | merge/delete | L | S | High |
| W1-18 | depth | `requirements-analysis/SKILL.md:53` vs `:151`; `the-mom-test-fitzpatrick.md:7` | "Stakeholder interview (simulated)" is listed as an elicitation technique, i.e. the agent invents interview evidence | Rename it to stakeholder-concern analysis over written artifacts; label its output as assumptions (Hathaway caveat, `it-requirements-lean-agile-hathaway.md:47`) | bug | M | S | High |
| W1-19 | depth | `requirements-analysis/SKILL.md:64` vs `:74-75`, `:147` | Format says "[Actor] must be able to…", but the example is "The system must scan … and classify … within 30 minutes" (system as actor, compound, a performance NFR inside an FR) | Replace the example; split it into an FR plus an NFR reference | bug | M | S | High |
| W1-20 | depth | `requirements-analysis/SKILL.md:30-40`; `it-requirements-lean-agile-hathaway.md:7,18,25` | No Stakeholder or Transition requirement types; no why-chain before drafting | Add Hathaway's four levels (Business / Stakeholder / Solution / Transition), the why-chain step and a transition checklist (data migration from the spreadsheet, cutover, training) | new-reference | M | M | High |
| W1-21 | depth | `jtbd-analysis/SKILL.md:41-47` vs `:126-127` | Section "Job Statement Format" shows the job-*story* template (Klement); step 1 uses Ulwick's job-*statement* syntax; the two rival schools are merged without saying so | Name both formats and when each is used; source them (no research file, see Coverage) | bug | M | S | Medium |
| W1-22 | depth | `jtbd-analysis/SKILL.md:55-58,145` | Worked "good" job story's motivation is "see a … prioritised list of compliance gaps", a product output (solution-space; `lean-product-playbook-olsen.md:8,22`) | Rewrite the example's motivation in problem-space terms | bug | L | S | Medium |
| W1-23 | depth | `jtbd-analysis/SKILL.md:129`; `user-persona/SKILL.md:138-142`; `the-mom-test-fitzpatrick.md:56` | "Gather real input via Mom-Test conversations", but the agent cannot hold one. Who interviews is not stated | State that the user (or a design partner session) is the interviewer; the agent writes the guide and labels unsupported jobs as assumptions | process | M | S | High |
| W1-24 | depth | `okr-authoring/SKILL.md:70-75`; `references/okr-rules-and-grading.md:91-101` | Applies the 0.7 target to every KR; Google's committed vs aspirational OKR split (committed ⇒ 1.0 expected) is missing; binary KRs (`:101`) are a symptom | Add committed vs aspirational; source it (Doerr is not in research) | new-reference | M | S | Medium |
| W1-25 | depth | `okr-authoring/references/okr-rules-and-grading.md:25,69`; `product-management-in-practice-lemay.md:14,22` | Attributes "an Objective is worth writing only if a different direction was possible" and the hypothesis KR template to "LeMay". The first is not in the research file; the template is the research file's own suggestion | Attribute correctly or drop; fix the "LeMay"/"Lemay" spelling | docs | L | S | High |
| W1-26 | depth | `agents/product-strategist.md:121-122` vs `roadmap-authoring/SKILL.md` (no "chasm" anywhere) | Behavioural directive cites roadmap-authoring for "chasm stage" sequencing it does not contain (a CLAUDE.md § Component Architecture defect) | Add bowling-alley / chasm sequencing to the roadmap (`crossing-the-chasm-moore.md:12,33`) or drop it from the directive | agent-change | M | S | High |
| W1-27 | depth | `stakeholder-mapping/SKILL.md:29-38,109-118`; `references/stakeholder-register-template.md:24,64-66` | One grid mixes the customer's buying committee (archetypes you cannot "update monthly") with the product team's own stakeholders; the "Product owner" row is where the owner's name leaked (`01-dogfood.md:24`) | Split into (a) buying-committee map (economic buyer, champion, blocker; Moore `crossing-the-chasm-moore.md:14`) and (b) delivery stakeholders with an engagement plan; drop the owner row from examples | new-reference | M | M | High |
| W1-28 | depth | `stakeholder-mapping/SKILL.md:78` vs `:109-116` | A 1–3 power/interest scale on a 2×2 grid; where 2 lands is never defined (the examples treat 2 as "low") | State the cut-off, or use a 2-point or 1–5 scale | bug | L | S | High |
| W1-29 | depth | `competitive-analysis/SKILL.md:67,120` vs `:129` | Asks you to pick axes where your product sits in blank space, which invites the "flattering matrix" it forbids | Choose the axes from the buyer's evaluation criteria (Dunford category criteria, `obviously-awesome-dunford.md:11`) before plotting | bug | M | S | Medium |
| W1-30 | usage | `competitive-analysis/SKILL.md:123`; `references/competitive-analysis-template.md:14-24`; CLAUDE.md § Component Frontmatter (tool set) | Requires research "dated within 6 months", but agents have no web-research tool, so vendor facts come from model memory as if verified | Add per-claim source/date columns and an "unverified (model knowledge)" label; ask the user for evidence | process | M | S | Medium |
| W1-31 | depth | `competitive-analysis/SKILL.md:55-57,90-92`; `obviously-awesome-dunford.md:9,18`; `loved-lauchengco.md:14,21` | Alternatives (including do-nothing) are an optional row, not step 1; competitive risks look forward only, with no win/loss log | Make competitive alternatives step 1; add a win/loss log that feeds the gtm Positioning Refresh Trigger | new-reference | M | S | High |
| W1-32 | depth | `business-model-canvas/SKILL.md:137-149`; `four-steps-to-the-epiphany-blank.md:10` | Canvas filled once as a plan; blocks not marked hypothesis vs validated | Add a per-block evidence status (hypothesis / tested / validated) with the test that would move it | new-reference | M | S | High |
| W1-33 | portability | `business-model-canvas/SKILL.md:56-58`; `references/canvas-blocks.md:155-159` | "For this repo's first product: use Lean Canvas in Stage 1…" is product-specific | State the rule generically (variant follows evidence state); move the product case to `examples/` | portability | L | S | High |
| W1-34 | depth | `gtm-strategy/SKILL.md:179`; `:156` | "benchmark: 15–25% for PLG B2B" trial-to-paid has no source; "exact price points are set in the commercial plan", but no skill produces a commercial plan | Drop or source the benchmark; either drop the commercial-plan reference or add pricing grounding (see Coverage) | docs | L | S | High |
| W1-35 | depth | `gtm-strategy/SKILL.md:160-170`; `the-mom-test-fitzpatrick.md:31` | Stage 1 exit ("ICP confirmed, core value delivered") has no check that the evidence came from Mom-Test-compliant conversations | Add the evidence check under Stage 1 exit criteria | new-reference | M | S | High |
| W1-36 | usage | `competitive-analysis/references/competitive-analysis-template.md:1-8`; `gtm-strategy/references/gtm-template.md:1-8`; `roadmap-authoring/references/roadmap-template.md:1-9`; `stakeholder-mapping/references/stakeholder-register-template.md:1-7`; `requirements-analysis/references/frd-template.md:1-9`; `gtm-strategy/SKILL.md:220` | Worked artifacts and one output spec omit the mandatory `summary:` field | Add `summary:` to all six | bug | M | S | High |
| W1-37 | usage | All 21 skills (no "lean"/"scale_profile" mention); `skills/artifact-manifest/resources/phase-requirements.json` (profile notes); `01-dogfood.md:29` | No skill scales its output to the lean / standard / enterprise profile | Each skill gets a short "At lean scale" rule (what to drop, length cap) matching phase-requirements.json | process | H | M | High |
| W1-38 | portability | All 21 skills: 20 have every support file tied to the data-estate product | Single-product examples; exemplar uses three products at three scales | Build `examples/01..03` per skill, simple → enterprise (ideas in each section) | new-reference | H | L | High |
| W1-39 | maintainability | `epic-definition/references/decomposition-techniques.md:31-75`; `user-story-writing/references/story-splitting-patterns.md` | SPIDR / CRUD / workflow splitting is taught twice | Keep the splitting catalogue in `user-story-writing`; epic-definition keeps only epic-level splits and points to it | merge/delete | L | S | High |
| W1-40 | depth | `epic-definition/SKILL.md:140-151`; `inspired-cagan.md:9,48` | No four-risk check (value / usability / feasibility / viability) before an epic enters the backlog | Add a 4-risk line per epic (Cagan) to the readiness checklist | new-reference | M | S | High |
| W1-41 | depth | `impact-mapping/SKILL.md:58-66`; `unleash-creativity-with-ai-bier.md:19` | Deliverables generated in one pass by an agent; no spread or constraint step | Add a "generate 2–3× candidates, one constrained second pass" step at WHAT | new-reference | L | S | Medium |
| W1-42 | depth | `beta-program-design/SKILL.md:59-66` vs `:148` | Selection table has 6 criteria (incl. 2 earlyvangelist); quality criteria check 4 | Align the quality criteria with the table | bug | L | S | High |
| W1-43 | depth | `beta-program-design/SKILL.md:48-49`; `acceptance-sign-off/SKILL.md:32-34`; `agents/requirements-analyst.md:286-289` | Open beta needs a (conditional) sign-off; GA needs a full sign-off; the agent produces one sign-off at the end. How many sign-offs per release slice is undefined | Define sign-off per stage transition, or a single sign-off at GA plus stage graduation records | process | M | S | Medium |
| W1-44 | depth | `acceptance-sign-off/SKILL.md:38-49`; `four-steps-to-the-epiphany-blank.md:20` | No repeatability check: were participants onboarded the same documented way, or did each need hand-holding? | Add a repeatability line to the checklist (Blank's Customer Validation test) | new-reference | M | S | High |
| W1-45 | usage | `uat-scenario/SKILL.md:13-14`; `feedback-template/SKILL.md:43`; `uat-plan/SKILL.md:49-51,64` | Persona names and product features in trigger surfaces and in a required capture field | Generic role wording; product cases into `examples/` | portability | M | S | High |
| W1-46 | depth | `feedback-template/SKILL.md:77` | "missing capability → product-strategist", but missing capabilities are requirements (requirements-analyst owns them), and Strategy is already approved | Route to requirements-analyst; escalate to product-strategist only when the gap challenges positioning/ICP | agent-change | L | S | Medium |
| W1-47 | maintainability | `acceptance-sign-off/assets/sign-off-template.md`; `references/output-format-template.md`; `beta-program-design/assets/beta-program-design-template.md` | Fill-in skeletons in `assets/` (spec: `templates/`); the sign-off template is kept in two copies | Move to `templates/`, delete the duplicate annotated copy or make it the only one; update the scaffold scripts and tests | merge/delete | L | S | High |
| W1-48 | process | `research/requirements-and-user-stories/agile-ux-storytelling-baker.md:7`; `art-of-crafting-user-stories-lee.md:7`; `learn-product-management-with-stories.md:2,7` | Three research files say the author could not recall the book | Never list them in `sources:`; cite the named practice's real origin instead (Jeffries' Three Cs via Cohn) | docs | M | S | High |
| W1-49 | maintainability | Research "Applies To" tables, e.g. `crossing-the-chasm-moore.md:30` vs `gtm-strategy/SKILL.md:47-60`; `four-steps-to-the-epiphany-blank.md:26` vs `beta-program-design/SKILL.md:59-68` | Research gap tables describe pre-refactor skills | Wave 1 implementers verify every research "gap" against the current skill; optionally stamp research tables with the skill version they read | process | L | S | High |
| W1-50 | depth | `uat-plan/SKILL.md:26-37` | Only UAT; no operational acceptance or regulatory/contractual acceptance, which a compliance-sold product needs | Add an acceptance-type selector (UAT / OAT / regulatory / contractual) with when-to-use; needs a source (see Coverage) | new-reference | M | M | Medium |

---

## Per-skill sections

Format for each: **1 Sources · 2 Gaps and errors · 3 Folder moves · 4 Examples · 5 Eval ideas · 6 Overlaps · 7 Size.**

### business-model-canvas

1. **Sources**
   - `research/product-strategy-and-gtm/four-steps-to-the-epiphany-blank.md`: canvas blocks as hypotheses that Customer Development tests (`:10`).
   - `research/product-strategy-and-gtm/lean-product-playbook-olsen.md`: value proposition traced to a scored underserved need; Opportunity Score (`:9,32`).
   - `research/product-strategy-and-gtm/obviously-awesome-dunford.md`: value themes as the step between attributes and the proposition (`:31`).
   - `research/product-strategy-and-gtm/crossing-the-chasm-moore.md`: beachhead criteria behind the "primary segment" ranking; bowling-alley order for secondary segments (`:31`).
   - `research/human-ai-collaboration/unleash-creativity-with-ai-bier.md`: generate several value propositions before choosing (`:20,29`).
   - Primary sources (Osterwalder, Maurya) are **missing**; see Coverage.
2. **Gaps and errors**
   - Osterwalder and Maurya cited (`references/canvas-blocks.md:4-7`) with no research file.
   - No per-block hypothesis/evidence status (W1-32).
   - Product-specific stage rule in the body (W1-33).
   - Lean Canvas block mapping checked: Key Partners→Problem, Key Activities→Solution, Key Resources→Key Metrics, Customer Relationships→Unfair Advantage (`canvas-blocks.md:143-148`). It is correct.
   - No Value Proposition Canvas (customer jobs / pains / gains), the usual companion to Block 2.
   - No "at lean scale" rule. The lean profile skips this artifact entirely (`phase-requirements.json`), and the skill should say so.
3. **Folder moves**
   - `references/canvas-template-and-example.md` is mixed. Split into `templates/bmc.md` + `templates/lean-canvas.md` and `examples/02-…`.
   - `references/canvas-blocks.md` stays (look-up depth).
   - The coherence check's seven questions → `resources/coherence-check.md` (output is checked against them).
4. **Examples**
   1. A lean side project (lunch-order tracker): one Lean Canvas, Unfair Advantage honestly blank.
   2. B2B SaaS seed-stage, Lean Canvas → BMC migration after design partners.
   3. A multi-tenant enterprise platform with two segments (SMB self-serve + enterprise sales-led): two value propositions, two channels, cost-to-serve per segment, partner channel.
5. **Eval ideas**
   - (a) Give a canvas whose revenue stream "per-seat licence for auditors" has no matching value proposition or segment. The grader checks that the response runs the coherence check and names the broken pair (Revenue ↔ Segment receiving the Value Proposition), not just "looks good".
   - (b) "We're pre-revenue with 3 design partners; fill in Key Partnerships and Key Resources." The grader checks that it recommends Lean Canvas, explains that those blocks project false certainty, and lists the four substitute blocks.
   - (c) After W1-32: the grader checks every block carries hypothesis/validated status.
6. **Overlaps**
   - `gtm-strategy` (segments, pricing, channels): the canvas should reference the GTM decisions, not restate them.
   - `competitive-analysis` (defensibility, coherence question 7).
   - Agent: product-strategist owns it (`agents/product-strategist.md:77`). Clean.
7. **Size:** M.

### competitive-analysis

1. **Sources**
   - `research/product-strategy-and-gtm/obviously-awesome-dunford.md`: alternatives first incl. do-nothing; "real + valued" attribute filter; market category as a lens on axes (`:9-11,18,29`).
   - `research/product-strategy-and-gtm/loved-lauchengco.md`: win/loss analysis as the loop that validates differentiation (`:14,21,33`).
   - `research/product-strategy-and-gtm/crossing-the-chasm-moore.md`: whole-product decomposition for "SMB fit"-style cells (`:31`).
2. **Gaps and errors**
   - No `related:` (prose names gtm-strategy, roadmap).
   - Axis choice invites flattery (W1-29).
   - Recency criterion cannot be met (W1-30).
   - Alternatives optional; no win/loss (W1-31).
   - Worked example has no `summary:` (W1-36).
   - The SWOT definition (`SKILL.md:73-80`) is fine.
   - Dimension examples are all compliance-product dimensions (`:44-53`).
3. **Folder moves**
   - `references/competitive-analysis-template.md` is a full worked artifact → `examples/02-b2b-compliance.md`.
   - The Output Format block (`SKILL.md:139-177`) → `templates/competitive-analysis.md`.
4. **Examples**
   1. Internal tool whose only alternatives are the spreadsheet and doing nothing.
   2. B2B SaaS vs named vendors with honest substitute scoring.
   3. Enterprise platform entering a crowded category: category choice changes the axes; future entrant (hyperscaler) risk; win/loss log after closed beta.
5. **Eval ideas**
   - (a) Give a capability matrix where the consultant-spreadsheet substitute scores ✗ on every row. The grader checks the "flattering matrix" diagnosis and that privacy/compliance-knowledge cells are re-scored honestly.
   - (b) "List our competitors" for a niche internal tool. The grader checks that do-nothing / spreadsheet are the first alternatives, not omitted.
   - (c) After W1-30: the grader checks vendor claims carry a source/date or an "unverified" label instead of confident invented figures.
6. **Overlaps**
   - `gtm-strategy` positioning (`gtm-strategy/references/positioning-and-segments.md:113-172` already runs Dunford's sequence). Decide which skill owns "competitive alternatives", or there will be two lists.
   - `business-model-canvas` coherence question 7.
7. **Size:** M.

### gtm-strategy

1. **Sources**
   - `research/product-strategy-and-gtm/crossing-the-chasm-moore.md`: beachhead criteria, whole product, bowling alley, chasm diagnostic (`:9-14,19-23`).
   - `research/product-strategy-and-gtm/obviously-awesome-dunford.md`: positioning sequence, category as a lever, best-fit customer, trends as garnish (`:8-13`).
   - `research/product-strategy-and-gtm/loved-lauchengco.md`: message house, positioning refresh, three-audience launch, enablement (`:9-13`).
   - `research/product-strategy-and-gtm/the-mom-test-fitzpatrick.md`: Stage 1 evidence discipline (`:31`).
   - `research/product-strategy-and-gtm/four-steps-to-the-epiphany-blank.md`: Stage 1 as a plan, beta as its execution (`:27`).
   - `research/storytelling-and-narrative/the-best-story-wins.md`: customer as hero in messaging (`:29`).
   - `research/storytelling-and-narrative/business-storytelling-for-dummies.md`: customer-story proof point (`:34,40`).
2. **Gaps and errors**
   - Well grounded in substance, but no `sources:`.
   - No `summary:` in output spec and example (W1-36).
   - Ungrounded benchmark; dangling "commercial plan" (W1-34).
   - No Mom-Test evidence check at Stage 1 (W1-35).
   - The pricing component (`:144-156`) has no research grounding at all.
   - The Messaging Framework has no customer-story proof-point subtype (Dietz `:34`).
   - The sales-motion default "self-serve with a guided POC" is product-specific (`:140`).
3. **Folder moves**
   - `references/gtm-template.md` → `examples/02-…` (it is a worked artifact).
   - A new `templates/gtm-strategy.md` from `SKILL.md:218-220`.
   - `references/positioning-and-segments.md` stays.
   - The beachhead six-criteria worksheet → `templates/beachhead-scorecard.md`.
4. **Examples**
   1. Internal tool: GTM collapses to rollout and adoption (one channel, no pricing). Says which components are skipped at lean scale.
   2. SMB B2B SaaS with PLG.
   3. Enterprise sales-led motion into a regulated vertical: buying committee, procurement path, whole-product gaps (certifications), bowling-alley next segment.
5. **Eval ideas**
   - (a) "We finished all three launch stages and every customer is a visionary early adopter; are we ready to scale?" The grader checks that launch stage and the chasm are different axes and that the chasm diagnostic questions are used.
   - (b) Two candidate segments, one bigger with an entrenched incumbent and no single channel. The grader checks the smaller beachhead is chosen against the six criteria.
   - (c) "Fill the [category] blank." The grader checks the fit / create / subcategory choice with evaluation criteria.
6. **Overlaps**
   - `competitive-analysis` (alternatives, differentiators).
   - `vision-statement` (pilot moved positioning here; consistent).
   - `beta-program-design` (Stage 1 plan vs execution, Blank `:27`).
   - `business-model-canvas` (channels / pricing restated).
7. **Size:** M.

### mission-statement

1. **Sources**
   - `research/product-strategy-and-gtm/inspired-cagan.md`: vision vs strategy distinction; outcome over output (`:15,17`). Cagan does not define a mission; say so.
   - `research/product-strategy-and-gtm/obviously-awesome-dunford.md`: only to say what the mission is *not* (positioning).
   - Mission as a distinct product artifact has **no** research grounding; see Coverage.
2. **Gaps and errors**
   - Positioning conflation (W1-4).
   - North-star trigger collision (W1-3).
   - "The mission's stated outcome is the source of the top-level Objective" (`:132-134`) is a third answer to "where do Objectives come from" (see W1-2).
   - "Scope constraint / out-of-scope list" (`:102-103`) duplicates the vision's new "rules out" list (`vision-statement/SKILL.md:64`). Decide which artifact owns scope exclusion.
   - Lean profile skips this artifact; the skill should say so.
3. **Folder moves**
   - `references/mission-examples-and-template.md` is mixed (template + checklist + four examples + worked product).
   - Split into `templates/mission-statement.md`, `resources/mission-checklist.md` (diagnostic tests, used before hand-off) and `examples/01-03`.
4. **Examples**
   1. Internal tool mission.
   2. B2B SaaS mission rewritten from a positioning-shaped draft.
   3. A platform company with a company mission and product-line missions: how they nest, and when a product line does not need its own (mirror the vision cascade rules).
5. **Eval ideas**
   - (a) Give a "mission" written as "For SMB compliance teams who…, X is a … Unlike BigID…". The grader checks it is rejected as positioning, with the we-do / for-whom / so-that rewrite.
   - (b) Give a vision and ask for the mission plus downstream links. The grader checks the mission does not introduce a north star or a competitor differentiator, and names its out-of-scope list (or defers to the vision's rules-out, per the fix).
6. **Overlaps**
   - `vision-statement` (rules-out vs scope constraint).
   - `okr-authoring` (Objective source).
   - `gtm-strategy` (positioning).
7. **Size:** M.

### okr-authoring

1. **Sources**
   - `research/product-strategy-and-gtm/inspired-cagan.md`: KR as the problem handed to an empowered team; roadmap anti-pattern (`:16-17`).
   - `research/product-strategy-and-gtm/product-management-in-practice-lemay.md`: hypothesis framing (`:14`). Attribute carefully (W1-25).
   - `research/data-and-analytics/lean-analytics-croll-yoskovitz.md`: four tests of a good metric; vanity metrics; North Star vs OMTM distinction (`:114,135`).
   - Doerr / Google grading conventions are **missing**; see Coverage.
2. **Gaps and errors**
   - Order loop with roadmap (W1-2).
   - North Star ownership (W1-3).
   - No committed vs aspirational split (W1-24).
   - Attribution errors (W1-25).
   - Cadence assumes a team with weekly check-ins (`SKILL.md:81-83`). For a solo operator plus agents, who runs the check-in and where confidence is recorded is unstated.
   - Lean profile is "one objective" (`phase-requirements.json`), but the skill says ≤3.
   - Lean Analytics' four metric tests (comparative, understandable, ratio/rate, changes behaviour) are not applied to KR metrics.
3. **Folder moves**
   - `references/okr-template-and-examples.md` → `templates/okr-set.md` + `examples/`.
   - `references/okr-rules-and-grading.md` stays.
   - The health check (`SKILL.md:102-110`) → `resources/okr-health-check.md`.
4. **Examples**
   1. Lean: one Objective, pre-launch KRs with `n/a (pre-launch)` baselines.
   2. B2B SaaS quarter with three Objectives, one committed (certification) and two aspirational.
   3. Enterprise cascade (company → product line → team) with alignment by reference, showing how the vision's north star feeds team KRs.
5. **Eval ideas**
   - (a) A KR set including "Achieve SOC 2 Type II by Q4" graded at 0.7. The grader checks it is treated as a committed / binary KR (1.0 or 0.0), not a 0.7 aspirational success.
   - (b) Pre-launch product: "set baselines". The grader checks it refuses to invent baselines and writes `n/a (pre-launch)` with first-run targets.
   - (c) "Write OKRs; our vision's north star is X." The grader checks the North Star is consumed, not re-invented.
6. **Overlaps**
   - `vision-statement` (north star).
   - `roadmap-authoring` (order).
   - `impact-mapping` (one map per KR).
   - `mission-statement` (Objective source).
7. **Size:** M.

### roadmap-authoring

1. **Sources**
   - `research/product-strategy-and-gtm/inspired-cagan.md`: outcome/objectives roadmap vs feature-and-date roadmap (`:17`).
   - `research/product-strategy-and-gtm/crossing-the-chasm-moore.md`: bowling-alley sequencing for Later themes (`:12,33`).
   - `research/requirements-and-user-stories/user-story-mapping-patton-economy.md`: release slices feeding horizons (`:33`). Note the order problem below.
   - `research/product-strategy-and-gtm/product-management-in-practice-lemay.md`: items as hypotheses (`:22`).
   - `research/storytelling-and-narrative/the-best-story-wins.md`: says explicitly that story-arc framing does **not** fit roadmaps (`:31`). Keep as a guard.
   - A dedicated roadmap book is **missing**; see Coverage.
2. **Gaps and errors**
   - Reads OKRs that do not exist yet (W1-2).
   - The agent's "chasm stage" directive has nothing behind it (W1-26).
   - No `related:` (prose names OKR, GTM, vision).
   - Confidence bands (>80% / 50–80% / <50%, `:51-53,88`) have no source.
   - The "Dashboard loads in under 2 seconds" outcome (`:104`) is an NFR, not an outcome.
   - Worked example has no `summary:` (W1-36).
   - `story-mapping/SKILL.md:124` says release slices seed the roadmap, but the map is written in Ideate after the roadmap, so the roadmap needs a revision trigger once the map exists.
3. **Folder moves**
   - Output Format (`:146-183`) → `templates/strategic-roadmap.md`.
   - `references/roadmap-template.md` (worked) → `examples/02-…`.
4. **Examples**
   1. Lean one-page Now/Next/Later.
   2. B2B SaaS quarterly themes linked to KRs.
   3. A multi-product platform roadmap where Later themes open the next bowling-alley segment and depend on platform work, with the explicit not-on-roadmap list.
5. **Eval ideas**
   - (a) A feature list with dates. The grader checks outcome rewrites, confidence decaying with horizon, no dates beyond Now, the preamble, and the "Explicitly Not On This Roadmap" section.
   - (b) "Every item is High confidence." The grader checks the uniform-confidence anti-pattern is named.
   - (c) After the fix: the grader checks every item links to a KR or the vision and that Later themes say which segment they unlock.
6. **Overlaps**
   - `okr-authoring` (order).
   - `story-mapping` (slices).
   - `gtm-strategy` (launch stages).
7. **Size:** M.

### stakeholder-mapping

1. **Sources**
   - `research/product-strategy-and-gtm/crossing-the-chasm-moore.md`: economic buyer vs technical champion (`:14,50`).
   - `research/storytelling-and-narrative/business-storytelling-for-dummies.md`: narrative mitigation for a high-power / low-interest blocker (`:35,41`).
   - `research/data-governance-and-mdm/simple-data-mdm-srinivasan.md`: trust-in-automated-decisions as a separate blocker concern (`:35`).
   - `research/service-design/this-is-service-design-doing-stickdorn.md`: an ecosystem map is a **different** artifact; must stay distinct (`:14,58`).
   - The Power/Interest grid and RACI have **no** research source; see Coverage.
2. **Gaps and errors**
   - Customer buying committee and delivery stakeholders on one grid (W1-27).
   - Undefined scale midpoint (W1-28).
   - No `related:`.
   - Worked example has no `summary:` (W1-36).
   - "Design partners" is an implicit category used by beta-program-design (`beta-program-design/SKILL.md:57`) but missing from the categories table (`SKILL.md:31-38`). It appears only in the worked register (`references/stakeholder-register-template.md:24`).
   - Lean profile skips this artifact.
3. **Folder moves**
   - Output Format (`:148-182`) → `templates/stakeholder-map.md`.
   - `references/stakeholder-register-template.md` (worked) → `examples/`.
4. **Examples**
   1. Internal tool: delivery stakeholders only (team lead, IT, finance approver).
   2. B2B SMB deal: buying committee with a CISO blocker and a design-partner cohort.
   3. An enterprise multi-tenant platform: buying committee per tenant type, a regulator / auditor as beneficiary, a channel partner, and internal platform teams; RACI with one A per decision.
5. **Eval ideas**
   - (a) A register with a RACI row that has two "A"s and a CISO at power 3 / interest 1 placed in Monitor. The grader checks one Accountable and Keep Satisfied with pre-emptive mitigation.
   - (b) After the split: "map the stakeholders for selling to a hospital". The grader checks buying-committee archetypes are not given monthly-newsletter engagement plans.
6. **Overlaps**
   - `user-persona` (secondary personas from stakeholders, `user-persona/SKILL.md:116-117`).
   - `beta-program-design` (design-partner cohort).
   - A possible future `service-ecosystem-mapping` (Stickdorn `:40`).
7. **Size:** M.

### epic-definition

1. **Sources**
   - `research/requirements-and-user-stories/user-stories-applied-cohn.md`: epic as an unsplit story, themes, splitting (`:11-12,32`).
   - `research/requirements-and-user-stories/user-story-mapping-patton-economy.md`: backbone tasks as pre-epics (`:30`).
   - `research/product-strategy-and-gtm/inspired-cagan.md`: four risks per epic (`:9,48`).
   - `research/requirements-and-user-stories/lean-agile-atdd-pugh.md`: not ready without a concrete example (`:12`).
   - SPIDR (`references/decomposition-techniques.md:52-75`) is Cohn's later Mountain Goat material, **not** *User Stories Applied*. Cite it as such or source it.
2. **Gaps and errors**
   - MoSCoW required before MoSCoW runs (W1-8).
   - No four-risk check (W1-40).
   - Splitting duplicated with user-story-writing (W1-39).
   - Sizing signals are in sprints and quarters (`SKILL.md:65-75`), but the pipeline has no sprints. Size for an agent-built product needs a definition (ties to W1-9).
3. **Folder moves**
   - `references/epic-format-and-criteria.md` is mixed (hierarchy + template + worked epic + output format + checklist).
   - Split into `templates/epic-list.md`, `resources/epic-readiness-checklist.md`, `examples/` and a slimmer reference.
4. **Examples**
   1. Internal tool epic with 3 stories.
   2. B2B SaaS onboarding epic with a hypothesis that can fail while the epic succeeds.
   3. A cross-Bounded-Context enterprise epic (tenant provisioning across identity, billing, data plane) that must be flagged to domain-modeler and split by outcome, not by service.
5. **Eval ideas**
   - (a) "Epic: Build the API layer, frontend, and database for reports." The grader checks the component-epic rejection, outcome rename, and split by outcome not layer.
   - (b) "Write the epic's acceptance criteria." The grader checks 3–5 high-level conditions, not Given/When/Then.
   - (c) An epic spanning three Bounded Contexts. The grader checks the domain-modeler flag.
6. **Overlaps**
   - `user-story-writing` (splitting).
   - `impact-mapping` (WHAT → epic).
   - `story-mapping` (backbone).
7. **Size:** S.

### impact-mapping

1. **Sources**
   - `research/product-strategy-and-gtm/inspired-cagan.md`: feature factory, outcome over output, four-risk annotation (`:38`).
   - `research/product-strategy-and-gtm/lean-product-playbook-olsen.md`: pyramid vs impact chain, different failure modes (`:33`).
   - `research/human-ai-collaboration/unleash-creativity-with-ai-bier.md`: candidate spread at WHAT (`:19,28`).
   - Adzic's *Impact Mapping* is **not** in research (only his *Specification by Example*); see Coverage.
2. **Gaps and errors**
   - Phase label (W1-5).
   - Primary source missing.
   - Output template's Priority column uses MoSCoW at step 5 (`:152-154`); see W1-8.
   - Agent-generation spread (W1-41).
   - "Each Key Result becomes its own impact map" (`:71`). At lean scale that means one map; at enterprise scale possibly dozens. Needs a scale rule.
3. **Folder moves**
   - Output Format (`:129-166`) → `templates/impact-map.md`.
   - `references/impact-map-example.md` → `examples/02-…`.
   - `references/impact-map-levels.md` stays.
4. **Examples**
   1. Internal tool, one KR, two actors.
   2. B2B SaaS activation KR with a blocker actor (IT security).
   3. A marketplace / multi-sided platform where the goal needs behaviour change on both sides (buyers and sellers) and an off-stage regulator.
5. **Eval ideas**
   - (a) "Goal: ship the compliance dashboard; impact: Maya uses the dashboard." The grader checks deliverable-as-goal and feature-usage-as-impact are both caught and rewritten.
   - (b) A map with no blocker actor and every deliverable marked required. The grader checks a blocker is added and an MVP cut is made.
6. **Overlaps**
   - `okr-authoring` (WHY).
   - `epic-definition` (WHAT → epics).
   - `story-mapping` (WHAT → backbone).
   - Agent: the strategy agent "applies" impact thinking but must not write the file (`agents/product-strategist.md:83-87`).
7. **Size:** S.

### jtbd-analysis

1. **Sources**
   - `research/product-strategy-and-gtm/the-mom-test-fitzpatrick.md`: interview discipline, bad-data taxonomy, rewriting counterfactual prompts (`:7-11,32`).
   - `research/product-strategy-and-gtm/lean-product-playbook-olsen.md`: Opportunity Score, problem vs solution space (`:9,30`).
   - `research/product-strategy-and-gtm/four-steps-to-the-epiphany-blank.md`: earlyvangelist screening of interviewees (`:9`).
   - `research/product-strategy-and-gtm/inspired-cagan.md`: problem discovery vs solution discovery boundary (`:36`).
   - `research/human-ai-collaboration/unleash-creativity-with-ai-bier.md`: adversarial reframing when no interviewee exists (`:21`).
   - Christensen / Ulwick / Klement / Moesta are **missing**; see Coverage.
2. **Gaps and errors**
   - Phase label (W1-5).
   - Two JTBD schools merged (W1-21).
   - Solution-shaped worked example (W1-22).
   - Who interviews is unclear (W1-23).
   - "Forces of progress" (description `:10`) is taught with no source.
   - The Opportunity Score at n = 3–5 design partners needs Olsen's own scaling caveat (`lean-product-playbook-olsen.md:58`) stated in the skill.
3. **Folder moves**
   - `references/job-statements-and-dimensions.md` is mixed (rules + examples + template `:198`). Split into `templates/jtbd-analysis.md` + `examples/` + the reference.
   - `references/jtbd-interviewing.md` → part `templates/interview-guide.md`, part reference.
4. **Examples**
   1. Consumer / internal job (ordering lunch) with emotional and social dimensions.
   2. B2B compliance job with an Opportunity Score at small n.
   3. An enterprise multi-persona case where the same job is ranked differently per segment (Olsen's blended-average trap) and a consumption job drives onboarding requirements.
5. **Eval ideas**
   - (a) "Draft our customer interview guide," with a seed list containing "Would you use a tool that…?" and "How much would you pay?". The grader checks every hypothetical is rewritten as a past-tense specific-instance question, and no product pitch precedes the questions.
   - (b) Give "When I open the dashboard, I want to export a CSV…". The grader checks the solution-shaped / task-altitude diagnosis and a problem-space rewrite.
   - (c) After W1-21: the grader checks the response distinguishes a job statement from a job story.
6. **Overlaps**
   - `user-persona` (JTBD field).
   - `feedback-template` (Mom Test check-ins). The Mom Test material is now written three times (jtbd, persona, feedback). Consider one canonical reference, or the candidate `customer-discovery-interviewing` skill (`the-mom-test-fitzpatrick.md:37`).
7. **Size:** M.

### moscow-prioritization

1. **Sources**
   - `research/requirements-and-user-stories/user-stories-applied-cohn.md`: MoSCoW is DSDM, not Cohn; value / cost / risk / knowledge factors; Kano (`:13,34,50`).
   - `research/product-strategy-and-gtm/lean-product-playbook-olsen.md`: Kano vs MoSCoW as different axes (`:12-13,31`).
   - `research/requirements-and-user-stories/it-requirements-lean-agile-hathaway.md`: necessity test (`:13`).
   - `research/requirements-and-user-stories/user-story-mapping-patton-economy.md`: slice ≠ Must cut (`:41`).
   - The DSDM handbook (60% rule) is **missing**; see Coverage.
2. **Gaps and errors**
   - Capacity rule has no input (W1-9).
   - Must = MVP contradiction (W1-10).
   - Cohn's four-factor tie-break is absent (grep found no "risk"/"knowledge" factors in `references/`).
   - The rubric attributes MoSCoW to DSDM / Clegg (`references/moscow-rubric.md:9-10`). That is correct but unsourced.
3. **Folder moves**
   - `references/moscow-rubric.md` holds the output template (`:160-205`) → `templates/moscow-prioritized-backlog.md`.
   - `references/moscow-and-kano.md` worked example → `examples/`.
   - Category tests → `resources/`.
4. **Examples**
   1. A lean MVP of 8 stories with a count-based ceiling.
   2. B2B SaaS release with a Kano-Delighter Should protected from cuts.
   3. An enterprise release with a regulatory Must, a contractual Must for one tenant, and a capacity overrun that forces a scope-cut escalation.
5. **Eval ideas**
   - (a) 10 stories all labelled Must for an "8-week MVP". The grader checks the 60% ceiling, the necessity test, and at least one Won't with rationale and target release.
   - (b) "Is SOC 2 control mapping a Delighter?" The grader checks MoSCoW-Must + Kano-Basic, with the axes explained as different.
   - (c) After W1-9: "We have no estimates; apply MoSCoW." The grader checks it asks for or derives the sizing input, not invented person-weeks.
6. **Overlaps**
   - `story-mapping` (MVP).
   - `user-story-writing`, `epic-definition`, `requirements-analysis` (early priority fields).
   - `uat-plan` (scope = Musts).
7. **Size:** M.

### nfr-specification

1. **Sources**
   - `research/devops-and-delivery/accelerate-forsgren-humble-kim.md`: delivery NFR category (`:30`); clusters as calibration only (`:49`).
   - `research/devops-and-delivery/platform-engineering-fournier-nowland.md`: platform DX NFRs (`:31`).
   - `research/software-architecture/fundamentals-of-software-architecture-richards-ford.md`: architecture characteristics trade off; conflict check; "architecture characteristic" term (`:8,37,43`).
   - `research/requirements-and-user-stories/it-requirements-lean-agile-hathaway.md`: NFR as the Solution-Non-functional tier; testability gate; cutover / transition NFRs (`:12,32`).
   - Quality-attribute scenario sources (Bass et al.) and ISO/IEC 25010 are **missing**; see Coverage.
2. **Gaps and errors**
   - DORA table contradictions (W1-11).
   - Elite targets mandated at every scale (W1-12).
   - No conflict check (W1-13).
   - No standard NFR format: SEI quality-attribute scenario (source / stimulus / environment / artifact / response / measure) is the industry norm and would remove the "targets without load context" anti-pattern by construction.
   - Example targets are product-specific and tech-stack specific ("mTLS via Linkerd", "Alertmanager", `:84,158`). Fine as defaults, but they read as universal.
   - Step 1 extracts "regulatory requirements identified in the stakeholder map" (`:183`), but the stakeholder map does not hold regulatory requirements.
   - Availability "Uptime SLO" (`:69`) overlaps `slo-definition` (platform-engineer, Deploy).
   - The body is the longest in the wave at 225 lines including frontmatter. The 10 category tables belong in references.
3. **Folder moves**
   - Category tables → `references/nfr-categories.md`.
   - `references/nfr-antipatterns-and-output.md` is mixed → `templates/nfr-specification.md` + `resources/nfr-checklist.md` + `examples/`.
4. **Examples**
   1. Lean internal tool: about 8 NFRs, most categories marked "no requirement" with a reason.
   2. B2B SaaS with SOC 2: compliance NFRs with control IDs, and the residency vs availability conflict made explicit.
   3. A multi-tenant, multi-region HA platform: noisy-neighbour isolation, RTO/RPO per tier, region failover vs data residency trade-off, delivery NFRs per service tier.
5. **Eval ideas**
   - (a) "Our dashboard should be fast and highly available." The grader checks percentile + load-context latency, an availability target with RTO/RPO, and a stated verification method for each.
   - (b) "Write delivery NFRs for a 20-person office lunch app." The grader checks scale-appropriate targets, not the high-performer cluster by default, and cites the clusters only as calibration.
   - (c) Give NFRs "data never leaves region X" and "99.99% with cross-region failover". The grader checks the conflict is surfaced for enterprise-architect.
6. **Overlaps**
   - `dora-metrics` and `slo-definition` (both platform-engineer, `phase: deploy`).
   - `requirements-analysis` (constraints).
   - Agent: enterprise-architect consumes the handoff.
7. **Size:** L.

### requirements-analysis

1. **Sources**
   - `research/requirements-and-user-stories/it-requirements-lean-agile-hathaway.md`: four-level hierarchy, wants vs requirements, why-chain, necessity test, transition requirements, elicitation selection (`:7-14,18-25,31`).
   - `research/requirements-and-user-stories/user-stories-applied-cohn.md`: FRD stays at "what"; don't pre-solve the conversation (`:35`).
   - `research/product-strategy-and-gtm/the-mom-test-fitzpatrick.md`: no invented interview evidence (`:7`).
   - `research/product-strategy-and-gtm/product-management-in-practice-lemay.md`: name the translation (input → audience) (`:20`).
   - A core BA text (Wiegers, Robertson) is **missing**; see Coverage.
2. **Gaps and errors**
   - Simulated interviews (W1-18).
   - Self-contradicting example (W1-19).
   - No Stakeholder / Transition types or why-chain (W1-20).
   - MoSCoW at FRD time (W1-8).
   - No `related:` (names nfr-specification, jtbd-analysis).
   - Worked FRD has no `summary:` (W1-36).
   - No elicitation-technique selection guidance (Hathaway `:14`); the order is fixed.
3. **Folder moves**
   - Output Format (`:159-204`) → `templates/functional-requirements-document.md`.
   - `references/frd-template.md` (worked) → `examples/`.
   - Gap-analysis questions → `resources/gap-analysis.md`.
4. **Examples**
   1. Internal tool replacing a spreadsheet: transition requirements (migrate history, train 20 people, run in parallel for one week).
   2. B2B SaaS FRD traced to KRs and job stories.
   3. An enterprise replacement of a legacy system: stakeholder requirements per department, conflicting stakeholder needs, decommissioning and data-migration transition requirements, regulatory business rules.
5. **Eval ideas**
   - (a) A stakeholder says "I want a dropdown that emails the report to my boss every Friday." The grader checks the why-chain to a capability, the solution removed from the requirement, and a necessity test.
   - (b) "We're replacing our shared spreadsheet; write the FRD outline." The grader checks transition requirements (data migration, cutover, training) appear. Plain Claude usually omits them.
   - (c) The grader checks requirements are not attributed to interviews that did not happen.
6. **Overlaps**
   - `nfr-specification` (constraints vs NFRs).
   - `user-story-writing` (dual track, Hathaway `:33`).
   - `jtbd-analysis` (source).
7. **Size:** M.

### story-mapping

1. **Sources**
   - `research/requirements-and-user-stories/user-story-mapping-patton-economy.md`: backbone, walking skeleton, learning vs release MVP, map as a conversation, re-cutting after release (`:7-14,18-23`).
   - `research/product-strategy-and-gtm/inspired-cagan.md`: learning-MVP techniques belong upstream (`:11-12`).
2. **Gaps and errors**
   - Contradiction with MoSCoW (W1-10).
   - Roadmap seeding comes in the wrong order (see roadmap).
   - When-to-use says stories must already exist (`:111`). Patton uses the map to *generate* the backbone and stories; the research file judges the current order acceptable (`user-story-mapping-patton-economy.md:34`). Flag it as a deliberate adaptation, not silent.
   - Quality criteria and output template are buried in a reference (`:142-144`).
3. **Folder moves**
   - From `references/slicing-and-walking-skeleton.md`, move the Output Format → `templates/user-story-map.md`, the Quality Criteria → back into the body or `resources/`, and the Data Steward map → `examples/`.
4. **Examples**
   1. A lunch-order map (5 activities) with a one-row walking skeleton.
   2. B2B onboarding map with two release slices.
   3. A multi-persona platform map (admin, end-user, auditor backbones) where the walking skeleton must cross tenant provisioning, and a vertical-slice temptation is rejected.
5. **Eval ideas**
   - (a) "MVP = all four connectors perfect; scanning and reports next quarter." The grader checks the vertical-slice anti-pattern and a thin horizontal slice across the backbone.
   - (b) "Our MVP is a fake-door test." The grader checks the learning MVP vs release MVP distinction.
   - (c) A backbone "Ingest → Process → Store → Serve". The grader checks the system-perspective spine is rejected.
6. **Overlaps**
   - `moscow-prioritization`, `roadmap-authoring`, `epic-definition`.
7. **Size:** S.

### user-persona

1. **Sources**
   - `research/product-strategy-and-gtm/the-mom-test-fitzpatrick.md`: attribute elicitation questions (`:33`).
   - `research/product-strategy-and-gtm/lean-product-playbook-olsen.md`: needs scored per persona, not pooled (`:29`).
   - `research/product-strategy-and-gtm/loved-lauchengco.md`: persona attributes drive message tailoring (`:35`).
   - `research/requirements-and-user-stories/user-stories-applied-cohn.md`: user-role brainstorming fallback (`:10,19`).
   - `research/data-governance-and-mdm/simple-data-mdm-srinivasan.md`: trust posture toward automated decisions as an attribute (`:21,34`).
   - Do **not** list `agile-ux-storytelling-baker.md` (low confidence, `:7`). If a day-in-the-life vignette is adopted, cite Cooper / Goodwin directly once sourced.
2. **Gaps and errors**
   - Phase label (W1-5).
   - Product-specific personas in the description and as mandatory (W1-6).
   - The worked examples are labelled `RESEARCH — interview-grounded … validated with 3 design partners` (`references/persona-template-and-examples.md:81-82,132`) for a product with no real interviews. That teaches the agent to write a research label. Mark examples as illustrative, or show a proto example first.
   - No trust-posture attribute.
   - Persona primary sources missing (Coverage).
3. **Folder moves**
   - `references/persona-template-and-examples.md` → `templates/user-persona.md` + `examples/01-03`.
   - `references/persona-fields-and-grounding.md` stays.
4. **Examples**
   1. A proto-persona for an internal tool (clearly labelled, two personas).
   2. B2B: primary user + economic buyer + champion, mixed grounding with per-line tags.
   3. Enterprise multi-tenant: tenant admin, end user, platform operator and auditor personas, plus when *not* to make a persona (beneficiary only).
5. **Eval ideas**
   - (a) "Create personas for our app; we haven't talked to any users yet." The grader checks the PROTO label, no age / gender / photo, and goals / pains / current approach present.
   - (b) "One persona for both the buyer and the daily user." The grader checks a split, with the reasons.
   - (c) After W1-6: a non-compliance product. The grader checks no Data Steward / Compliance Officer appear.
6. **Overlaps**
   - `jtbd-analysis`, `stakeholder-mapping`, `gtm-strategy` (ICP vs persona).
   - Agent boundary fixed in `agents/product-strategist.md:83-87`.
7. **Size:** M.

### user-story-writing

1. **Sources**
   - `research/requirements-and-user-stories/user-stories-applied-cohn.md`: Three Cs, INVEST, roles, splitting (`:7-11,31`).
   - `research/requirements-and-user-stories/lean-agile-atdd-pugh.md`: Confirmation leg; not ready without an example (`:9,12`).
   - `research/requirements-and-user-stories/it-requirements-lean-agile-hathaway.md`: FRD + stories dual track is intentional (`:33`).
   - Do **not** list `art-of-crafting-user-stories-lee.md` (`:7`). The "so what?" test and verb-before-noun ideas came from that low-confidence file; present them as house rules, not a citation.
2. **Gaps and errors**
   - MoSCoW priority at authoring time (W1-8).
   - "Small = completable within a single sprint" (`:93`) has no meaning in this pipeline.
   - Size column with no sizing method (`:197`).
   - Splitting duplicated with epic-definition (W1-39).
   - The worked example is good.
3. **Folder moves**
   - Output Format (`:181-213`) → `templates/user-story-backlog.md`.
   - Worked split in `references/story-splitting-patterns.md` → `examples/`.
4. **Examples**
   1. A lunch-order story set (CRUD split).
   2. B2B OAuth connector with a SPIDR paths split.
   3. An enterprise story for a role-based, multi-tenant admin capability, split by business rule (per-tenant policy) and by interface, with a spike for an unknown external API.
5. **Eval ideas**
   - (a) "As a user, I want the system to export a CSV so that I can export the data." The grader checks a named persona, a user action, a benefit that survives "so what?", and INVEST notes.
   - (b) An oversized "connect, configure and monitor any source" story. The grader checks verb split before data split and names SPIDR patterns.
6. **Overlaps**
   - `epic-definition` (splitting), `acceptance-criteria` (Confirmation), `moscow-prioritization`.
7. **Size:** S.

### acceptance-sign-off

1. **Sources**
   - `research/human-ai-collaboration/co-intelligence-mollick.md`: human as the point of final consent (`:9`). Already cited in prose at `SKILL.md:64`.
   - `research/product-strategy-and-gtm/four-steps-to-the-epiphany-blank.md`: repeatability check, Customer Validation semantics (`:12,20`).
   - `research/testing/agile-testing-crispin-gregory.md`: Q3 findings feed the decision (`:34`).
   - `research/testing/explore-it-hendrickson.md`: exploratory findings are evidence (`:87`).
2. **Gaps and errors**
   - High-defect rule contradicts uat-plan and itself (W1-15).
   - No repeatability check (W1-44).
   - Template in `assets/` plus a duplicate copy (W1-47).
   - `related:` lists `skill-authoring-standards` (`:25`), which is meta, not a product relation.
   - Pointers lack `./` (`:135,175-176,182`). The legacy bare form is tolerated by the linter but is against the spec.
   - The description names the scripts (`:12-15`), which pads the trigger surface.
   - The example names the persona "Maya Chen" as the customer signatory (`:60`). Use a real-role placeholder.
3. **Folder moves**
   - `assets/sign-off-template.md` → `templates/`.
   - `references/output-format-template.md` → merge or delete.
   - `references/worked-example.md` → `examples/`.
   - Checklist → `resources/sign-off-checklist.md` (the validator already checks it).
4. **Examples**
   1. Internal proxy only, conditional cap.
   2. Design-partner conditional with dated remediation.
   3. A multi-tenant staged rollout where one tenant cohort signs and another is no-go: per-cohort flag scope, partial widening.
5. **Eval ideas**
   - (a) Zero Critical, one High with a plan, and only the founder tested it as a proxy. The grader checks the outcome is at most conditional, the proxy limitation is stated, and the High condition has an owner and date.
   - (b) All checklist items green but the customer representative says it is unusable. The grader checks no-go and that re-attempt needs a new UAT pass.
6. **Overlaps**
   - `uat-plan` (exit criteria), `beta-program-design` (stage sign-offs, W1-43).
   - `canary-deployment` and `feature-flag-design` (platform-engineer) consume the decision.
7. **Size:** S.

### beta-program-design

1. **Sources**
   - `research/product-strategy-and-gtm/four-steps-to-the-epiphany-blank.md`: Customer Validation, earlyvangelists, pivot, outside-the-building check (`:9-12,16-20,26`).
   - `research/product-strategy-and-gtm/the-mom-test-fitzpatrick.md`: qualitative-bar evidence, advancement / commitment (`:12,23`).
   - `research/service-design/this-is-service-design-doing-stickdorn.md`: Minimum Viable Service, i.e. operational readiness as a separate risk (`:15,24`).
   - `research/product-strategy-and-gtm/crossing-the-chasm-moore.md`: chasm vs stage are different axes (`:57`).
2. **Gaps and errors**
   - SOC 2 hard-coded into the validator and the agreement (W1-7).
   - Quality criteria do not match the selection table (W1-42).
   - Stage sign-off count undefined (W1-43).
   - No `related:` (names nine skills).
   - Only a design-partner B2B model. No guidance for a consumer or high-volume open beta (waitlist, cohort size, opt-in telemetry).
   - "canary stage 1 (5%) within that tenant only" (`:46`) assumes per-tenant traffic splitting; state it as a platform-dependent choice.
   - Body is 213 lines including frontmatter.
3. **Folder moves**
   - `assets/beta-program-design-template.md` → `templates/`.
   - The worked record in `references/customer-development-and-graduation-discipline.md` → `examples/`.
   - The beta agreement block (`:78-103`) → `templates/beta-agreement.md`.
4. **Examples**
   1. Internal rollout to one team (alpha) then all staff.
   2. B2B closed beta with 3 design partners and a pivot decision.
   3. A consumer or enterprise open beta at scale with waitlist cohorts, a regional rollout, and SLO-gated graduation per region.
5. **Eval ideas**
   - (a) Four candidate partners, one of whom has never tried to solve the problem but "loves the idea". The grader checks the earlyvangelist screen rejects or downgrades them.
   - (b) Closed beta failed its qualitative bar because participants don't have the assumed pain. The grader checks "pivot", naming the problem hypothesis, not "extend".
   - (c) After W1-7: a non-SOC-2 product. The grader checks the data-handling statement uses that product's own frameworks.
6. **Overlaps**
   - `gtm-strategy` launch stages (plan vs execution), `uat-plan`, `acceptance-sign-off`.
   - `stakeholder-mapping` (design-partner cohort).
7. **Size:** M.

### feedback-template

1. **Sources**
   - `research/product-strategy-and-gtm/the-mom-test-fitzpatrick.md`: question design, compliments / fluff / ideas, commitment (`:7-15,19-25`).
   - `research/testing/agile-testing-crispin-gregory.md`: findings from Q3 sources (`:34`).
   - `research/testing/explore-it-hendrickson.md`: exploratory debriefs as a feedback source (`:87`).
   - `research/product-strategy-and-gtm/loved-lauchengco.md`: win/loss and positioning feedback loop (`:14`).
   - Severity rubric and feedback-ops practice have **no** grounding; see Coverage.
2. **Gaps and errors**
   - Persona-specific capture field (W1-45).
   - Routing of missing capabilities (W1-46).
   - The skill name "feedback-template" does not match what it is (a capture-and-triage skill producing `feedback-log`).
   - "bug → engineering" (`:77`) does not say which engineer (backend / frontend / platform).
   - No route from positioning-relevant feedback ("we chose a spreadsheet instead") back to `gtm-strategy`'s refresh trigger.
   - The severity rubric is restated in `uat-scenario`'s reference. Keep one copy.
3. **Folder moves**
   - From `references/feedback-capture-and-triage.md`, move the capture template → `templates/feedback-item.md`, the severity rubric and routing table → `resources/`, the worked examples → `examples/`.
4. **Examples**
   1. A single ad hoc report from an internal user.
   2. A design-partner check-in transcript turned into items, with a compliment discarded and an idea converted to a job.
   3. Multi-tenant aggregation: the same symptom with different causes across tenants (not deduped), and a confirmed pattern escalated to sign-off.
5. **Eval ideas**
   - (a) A check-in note: "They said it's great and we should add a dashboard; one user was furious about export." The grader checks the compliment is not logged as a positive signal of value without behaviour, the dashboard request is converted to an underlying problem, and one report is not a pattern.
   - (b) "Write the check-in questions." The grader checks there is no pitch first, questions are past-tense, and there are no "would you…" questions.
6. **Overlaps**
   - `jtbd-analysis` and `user-persona` (Mom Test written three times).
   - `uat-scenario` (severity).
   - `acceptance-sign-off` (blocking pattern).
7. **Size:** S.

### uat-plan

1. **Sources**
   - `research/testing/explore-it-hendrickson.md`: charter, session, heuristics, human-only exploration (`:8-21,87,105`).
   - `research/testing/agile-testing-crispin-gregory.md`: quadrants, checking vs testing, Q3 placement (`:7,11,33`).
   - `research/requirements-and-user-stories/lean-agile-atdd-pugh.md`: UAT is distinct from pre-code ATDD (`:33`).
   - `research/testing/testing-web-apis-winteringham.md`: API exploration is a different practice; keep separate (`:33,56`).
   - `research/product-strategy-and-gtm/four-steps-to-the-epiphany-blank.md`: repeatability (`:20`).
2. **Gaps and errors**
   - Solo-operator role contradiction (W1-14).
   - High-defect contradiction (W1-15).
   - ID mapping (W1-16).
   - Duplicated exploratory content (W1-17).
   - No acceptance-type selector (W1-50).
   - No `related:` (names nine skills).
   - Example table is product-specific (`:49-51`).
   - Default pass rate "100% of Must Have scenarios" (`:103`) is stated with no reason for allowing a lower threshold.
3. **Folder moves**
   - `references/output-format-template.md` → `templates/uat-plan.md`.
   - `references/exploratory-session-template.md` → `templates/exploratory-session.md`; SFDIPOT audit → `resources/`.
   - `references/worked-example.md` → `examples/`.
4. **Examples**
   1. Solo founder as the only proxy (conditional cap, honest limits).
   2. 3 design partners, 5-day window.
   3. A multi-tenant, multi-region release where UAT runs per tenant wave on the canary, with an OAT component (backup restore, failover drill) and a regulatory acceptance item.
5. **Eval ideas**
   - (a) "I'm the only person available; plan UAT." The grader checks the proxy is declared, the executor = signer conflict is named, the outcome is capped at conditional, and at least one exploratory charter is drafted for a human to run.
   - (b) "Add every Should Have story to UAT too." The grader checks it rejects the unbounded scope.
   - (c) "Can you, the agent, do the exploratory testing?" The grader checks the honesty rule.
6. **Overlaps**
   - `uat-scenario` (exploratory content), `acceptance-sign-off`, `beta-program-design`.
   - `test-strategist` (Quality-phase boundary, `SKILL.md:34-37`).
7. **Size:** M.

### uat-scenario

1. **Sources**
   - `research/testing/specification-by-example-adzic.md`: one example carried through; business-language Given/When/Then (`:12,20`).
   - `research/requirements-and-user-stories/lean-agile-atdd-pugh.md`: the agreed test is not renegotiated; declarative style (`:11,14,34`).
   - `research/testing/agile-testing-crispin-gregory.md`: checking vs testing (`:11`).
   - `research/testing/explore-it-hendrickson.md`: scripted proves the known; stray findings are logged, not folded in (`:88`).
2. **Gaps and errors**
   - Product-specific trigger surface (W1-45).
   - ID-root rule vs 1:N mapping (W1-16).
   - Duplicated exploratory and severity material (W1-17, feedback-template).
   - Good and tight otherwise (body about 112 lines).
3. **Folder moves**
   - `references/scenario-format-and-examples.md` is mixed → `templates/uat-scenario.md` + `examples/` + the authoring rules as a reference.
   - `references/exploratory-charter-link.md` → delete, point to uat-plan.
4. **Examples**
   1. A simple CRUD scenario (lunch order placed before the cut-off).
   2. A B2B report-export scenario with seeded fixtures.
   3. A multi-tenant isolation scenario (tenant A cannot see tenant B's data) with per-tenant seeded fixtures and environment / flag state recorded.
5. **Eval ideas**
   - (a) Give a Gherkin AC with `Then sensitivity_level = 'restricted'`. The grader checks plain-language steps, an outcome visible on screen, the same ID root, and no new rule invented.
   - (b) The tester found an unrelated bug mid-scenario. The grader checks it is logged as feedback, not folded into the result.
6. **Overlaps**
   - `bdd-feature-file` (test-strategist; the boundary is stated at `:61-73`), `uat-plan`, `feedback-template`.
7. **Size:** S.

---

## Research coverage verdict

**Sufficient as-is (research library covers the skill's core):**

- **gtm-strategy**: Moore, Dunford, Lauchengco, Blank, Mom Test, Luhn, Dietz. Pricing is the one thin spot.
- **story-mapping**: Patton.
- **user-story-writing**: Cohn, Pugh, Hathaway.
- **epic-definition**: Cohn, Patton, Cagan. Cite SPIDR as Cohn's later material.
- **uat-plan** and **uat-scenario**: Hendrickson, Crispin and Gregory, Adzic *SbE*, Pugh, Winteringham.
- **acceptance-sign-off**: Mollick, Blank, Crispin and Gregory.
- **beta-program-design**: Blank, Mom Test, Stickdorn, Moore.

**Thin or missing grounding. Books the wave needs that are NOT in `research/`:**

| Title | Author | Skills | Why |
|---|---|---|---|
| *Business Model Generation* (and *Value Proposition Design*) | Alexander Osterwalder and Yves Pigneur | business-model-canvas | The skill's primary framework is cited (`references/canvas-blocks.md:4-5`) with no research file; Value Proposition Canvas missing |
| *Running Lean* | Ash Maurya | business-model-canvas | Lean Canvas is taught and attributed (`canvas-blocks.md:135`) with no source |
| *Measure What Matters* (or Christina Wodtke, *Radical Focus*) | John Doerr | okr-authoring | Grading, cadence and the committed vs aspirational split (W1-24) rest on "Google/Doerr" conventions (`okr-rules-and-grading.md:3`) with no file; only Cagan and Lemay support it today |
| *Good Strategy / Bad Strategy* | Richard Rumelt | mission-statement, roadmap-authoring, okr-authoring | Nothing in research defines a mission, or how strategy (diagnosis → guiding policy → coherent actions) connects vision to objectives and roadmap; would settle W1-2 and W1-4 on principle |
| *Product Roadmaps Relaunched* | C. Todd Lombardo, Bruce McCarthy, Evan Ryan, Michael Connors | roadmap-authoring | The outcome-theme roadmap, confidence and "not on roadmap" practice are unsourced; Cagan supports only the anti-feature-list stance |
| *Impact Mapping* | Gojko Adzic | impact-mapping | The skill's sole framework (`impact-mapping/SKILL.md:4,25`) has no research file; only Adzic's *Specification by Example* is in `research/testing/` |
| *Competing Against Luck* (Clayton Christensen et al.) plus *Jobs to Be Done: Theory to Practice* (Anthony Ulwick) or *When Coffee and Kale Compete* (Alan Klement) | as listed | jtbd-analysis, user-persona | Job statement vs job story, forces of progress and the JTBD originators are taught without any source (W1-21) |
| *The Inmates Are Running the Asylum* / *About Face* (Alan Cooper) or *The Persona Lifecycle* (John Pruitt and Tamara Adlin) | as listed | user-persona | Persona practice (goal-directed personas, proto vs research lifecycle) has no source; the only adjacent file (Baker) is low-confidence |
| *Continuous Discovery Habits* | Teresa Torres | jtbd-analysis, impact-mapping, feedback-template | Modern interview cadence, opportunity-solution trees and synthesis, i.e. how a solo PM keeps discovery running; complements Fitzpatrick |
| *Software Requirements* (3rd ed., Karl Wiegers and Joy Beatty) or *Mastering the Requirements Process* (Suzanne and James Robertson) | as listed | requirements-analysis, nfr-specification | The standard BA texts: requirement types, elicitation selection, fit criteria. Hathaway's file is concept-level and itself says it is not page-referenced (`it-requirements-lean-agile-hathaway.md:49`) |
| *Software Architecture in Practice* | Len Bass, Paul Clements, Rick Kazman | nfr-specification | Quality-attribute scenarios, the industry-standard testable NFR format; ISO/IEC 25010 (a standard, not a book) for the category model |
| *DSDM Agile Project Framework* handbook | Agile Business Consortium | moscow-prioritization | The origin of MoSCoW and the 60% Must rule; the skill cites DSDM (`moscow-rubric.md:9`) with no file |
| *The Challenger Customer* | Brent Adamson, Matthew Dixon et al. | stakeholder-mapping, gtm-strategy | B2B buying-committee roles (mobilizers, blockers): the customer-side half of W1-27. The Power/Interest grid (Mendelow; Eden and Ackermann, *Making Strategy*) and RACI also have no source |
| *Monetizing Innovation* | Madhavan Ramanujam and Georg Tacke | gtm-strategy, business-model-canvas | The pricing component and value anchor are unsourced (`gtm-strategy/SKILL.md:144-156`) |
| *User Acceptance Testing: A Step-by-Step Guide* (BCS) | Brian Hambling and Pauline van Goethem | uat-plan, acceptance-sign-off | Acceptance types (UAT, OAT, contractual, regulatory) and acceptance criteria for regulated products (W1-50) |

**Honest notes per skill where grounding is weak even after the table above:**

- **feedback-template**: grounded for elicitation (Mom Test) only. The severity rubric and triage routing are house rules, and no book in the table fully covers feedback operations. Torres helps; a defect-classification standard (IEEE 1044) would ground severity. Say so in the skill rather than imply a source.
- **mission-statement**: even with Rumelt, "mission" as a separate product artifact is a convention, not a researched method. The lean profile already skips it. Consider asking Shafi whether it should merge into the vision as its present-tense line.
- **competitive-analysis**: positioning is well covered (Dunford, Moore, Lauchengco). The capability-matrix and SWOT mechanics are generic and need no book. The real gap is evidence (no web research, W1-30), which a book would not fix.
- **nfr-specification**: the DORA numbers must be checked against *Accelerate* itself before any table is kept. The research file may carry later-report figures (W1-11).
- **Do not use** `agile-ux-storytelling-baker.md`, `art-of-crafting-user-stories-lee.md` or `learn-product-management-with-stories.md` as `sources:` (W1-48).

---

## What I could not finish or verify

- I did not run `claude plugin eval` or any model calls. The eval ideas are untested hypotheses about where plain Claude falls short.
- I did not check the DORA cluster values against the *Accelerate* text itself (no copy here). W1-11 reports a contradiction between three files; which numbers are right needs the book.
- I read reference files in full where a finding depended on them, and skimmed the rest via headings and targeted searches: `impact-map-levels.md`, `jtbd-interviewing.md`, `persona-fields-and-grounding.md`, `story-mapping/references/*`, `customer-development-and-graduation-discipline.md`, `scenario-format-and-examples.md`. Line citations into those files come from search results.
