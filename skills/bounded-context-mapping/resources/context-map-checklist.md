# Context Map Checklist

Check `artifacts/<product>/design/context-map.md` against this list before the domain-modeler's review gate. Any "no" is fixed first.

## Inputs

- [ ] The subdomain classification exists (or was produced first) and `traces-to` names it, the Event Storming output and the language documents it was drawn from.
- [ ] The mode is stated: agent-run, or a workshop (date, roles).

## Each context

- [ ] Named with a domain noun from the language, not a technical name.
- [ ] Its boundary evidence is cited: a word whose meaning changes, an Event Storming hint, a story group, a record-ownership split. Thin evidence is *assumed* and has an open question.
- [ ] It is not one Aggregate, one table, one team or one technical layer.
- [ ] Its subdomain(s) and their type are named.
- [ ] It points to its language document.
- [ ] Each record it owns is written by it alone; nothing is written by two contexts.
- [ ] No "deployable service" decided here (that's `container-diagram`).
- [ ] A possible later split is recorded with its trigger, rather than split now (start wide).

## The map

- [ ] If anything does this work today (a system, a spreadsheet, a bought tool, paper), there is a current map as it is, at every profile, with the target beside it.
- [ ] Every line marks its upstream side.
- [ ] Every line has one pattern and a reason, filled by `context-map-patterns`.
- [ ] External systems are boxes, with a line to the context that uses them.
- [ ] A legacy region with no coherent model is one box around it.

## At the gate

- [ ] The reply lists the contexts, the evidence for each line and the open questions.
