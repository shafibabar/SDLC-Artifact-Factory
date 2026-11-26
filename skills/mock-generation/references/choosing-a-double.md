# Choosing a Test Double

Self-contained. Use when classifying a dependency or naming a double. The managed and unmanaged distinction, mock against stub, and the classical school are Khorikov's (*Unit Testing: Principles, Practices, and Patterns*). Fakes over mocks for repositories is also the position of Percival and Gregory (*Architecture Patterns with Python*).

## Two questions, in order

1. **May it be doubled at all?** Only a port your code defines. A vendor or driver type is wrapped in a small port; the adapter behind the port is tested for real (`go-integration-test` for your database and broker).
2. **Can anyone outside the application observe the interaction?**

| Class | Definition | Examples | Verify |
|---|---|---|---|
| Managed | Your application fully controls it and it is reached only through your code | Your database and repositories, your file store, your in-process services | End state: fake, or real instance in an integration test. Never call assertions |
| Unmanaged | Its side effect is observable outside your application | Message broker publish, email, third-party payment API | A mock: the call happened, with these arguments |

If the answer is unclear, say so and ask. A database that other applications read directly does not meet the managed definition for what they read; how to treat it is the product owner's decision. An in-memory cache you own is managed.

## Five doubles

| Double | What it does | Asserted on |
|---|---|---|
| Dummy | Fills a parameter this path does not use | No |
| Stub | Returns fixed answers so the scenario can be set up | Never |
| Spy | Records calls for the test to inspect afterwards | Yes, so only for an unmanaged side effect |
| Mock | Verifies an interaction. Expectations may be declared beforehand or read from call records afterwards; moq does the second | Yes |
| Fake | A working lightweight implementation (an in-memory repository) | Its resulting state |

The name follows the role in the test, not the tool: a moq struct whose calls nobody reads is acting as a stub.

```go
// Dummy: the signature needs a context; this rule never uses it.
total, err := pricing.Quote(context.Background(), basket)

// Stub: fixed answer; no assertion about the call.
rates := &RateProviderMock{
	RateFunc: func(_ context.Context, currency string) (int64, error) { return 117, nil },
}
```

## Do not over-specify

Assert the part of the interaction the behaviour requires. Call order is asserted only when order is a real rule. Arguments that do not matter (a trace context) are left unchecked. "Nothing is sent when validation fails" is a legitimate assertion on an unmanaged port: zero calls.

## Classical, not London

The London (mockist) school isolates each class from all its collaborators with mocks. The classical (Detroit, Chicago) school isolates each test from other tests, treats a unit as a unit of behaviour that may span several types, and replaces only external dependencies. A handler test therefore runs the real aggregate. London-style mocking turns the suite red on a refactor that changed no behaviour, which loses Khorikov's resistance-to-refactoring pillar.

## Outbox

With a Transactional Outbox the command handler changes state and writes an outbox row in one transaction. Both live in your database, so both are managed: assert the new state and the row. Whether they commit together is an integration test with a real commit (`test-fixture-design`). The relay that reads rows and publishes is the unmanaged edge: mock its publisher port.

## Another service of the same product

It is not reached only through your code and its behaviour is observed outside your application, so by the definition above treat it as unmanaged: stub its queries, mock its commands. This is an application of the definition, not a case the book names. A hand-invented response can drift from the real service; Cruz and Prescott (*Contract Testing in Action*) run the consumer against a mock generated from the contract. Here the contract and its checks are `go-contract-test`'s: the data a stub returns must satisfy that contract, and if nothing checks it, record that as an open question. Do not add a contract tool in this skill.

## Other stacks

Python: `python-unit-test` (a hand-written fake behind a `typing.Protocol` port; patching only at the unmanaged edge). React: `react-component-testing` (fake the network, clock, telemetry and missing browser features only). The classification above is the same.
