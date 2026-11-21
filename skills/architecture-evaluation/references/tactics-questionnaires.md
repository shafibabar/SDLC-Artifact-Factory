# Tactics Questionnaires

Reference for `architecture-evaluation` step 5. Grounded in Bass, Clements and Kazman: the tactic families per quality attribute, and the idea of a tactics-based questionnaire a designer can run against a design alone. **The questions below are our phrasing of the book's tactic names**; the book supplies only one sample question ("does the system use heartbeat or ping/echo to detect a failed component?"). The tactic lists for deployability and safety are approximate in the research notes, and integrability and energy efficiency are not covered here: check them against the book before relying on them, and run only the attributes the product's scenarios name.

## How to use it

For the scenario's attribute, take each tactic family and ask: **does the design do this, where, and at what cost?** Answer yes, partial or no, say where in the design (a container, an ADR, a component), and note what it costs (latency, money, complexity). A "no" is not automatically a risk: it is a risk only if the scenario needs the tactic. An unanswered family is a finding in itself. Tactics are chosen at Design, not in the NFR, so this is the first place they are checked.

## Availability

- **Detect faults:** does the design detect a failed component (ping and echo, heartbeat, monitoring, timestamps, sanity checks, exception detection)?
- **Recover from faults:** is there redundancy (active, passive or cold), rollback, retry, graceful degradation, reconfiguration; for stateful components, state resynchronisation or escalating restart?
- **Prevent faults:** can a component be removed from service for maintenance, are operations transactional, are exceptions prevented by design?

## Performance

- **Control resource demand:** is the request rate managed, event response limited or prioritised, execution time bounded, computation reduced?
- **Manage resources:** can resources be increased, concurrency introduced, copies of data or computation kept, queues bounded, resources scheduled?

## Modifiability

- **Increase cohesion:** is a module split where it holds two responsibilities?
- **Reduce coupling:** are dependencies encapsulated, mediated, restricted or abstracted behind a common service?
- **Defer binding:** is the behaviour that must change configured, registered at run time or plugged in, rather than compiled in?

## Security

- **Detect attacks:** is an attack or anomaly detected?
- **Resist attacks:** are actors identified, authenticated and authorised; access and exposure limited; data encrypted; entities separated; input validated?
- **React to attacks:** can access be revoked, logins restricted, actors informed?
- **Recover:** is there an audit trail, and non-repudiation where required?

## Testability

- **Control and observe state:** are there test interfaces, record and playback, localised state, abstracted data sources, sandboxing, executable assertions?
- **Limit complexity:** are structure and behaviour simple enough to test?

## Usability

- **Support user initiative:** can a user cancel, undo, pause and resume?
- **Support system initiative:** does the system keep a model of the task, the user and itself, so it can help?

## Deployability (approximate)

- **Manage the pipeline:** are rollouts gradual, rollback possible, deployment scripted?
- **Manage the deployed system:** can old and new versions coexist, are dependencies packaged with the service, are features toggled?

## Recording an answer

Each answer becomes a row: the scenario, the tactic family, the question, the answer (yes, partial or no), and where in the design it lives. A "partial" or "no" that the scenario needs becomes a risk; a "yes" with a clear reason becomes a non-risk; a property that one answer depends on becomes a sensitivity point.
