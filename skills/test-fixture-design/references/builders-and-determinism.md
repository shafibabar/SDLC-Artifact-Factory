# Builders, Object Mothers and Deterministic Data

Self-contained. Use when constructing test objects or controlling time, IDs and randomness.

## Choosing the shape

| Shape | Use when | Avoid when |
|---|---|---|
| Inline literal | A unit case with few fields, the whole input visible in the table row | The same long construction repeats across tests |
| Test data builder (Go) / factory fixture (Python) | Many tests build the same type and each cares about different fields | One small literal says it all |
| Object Mother | A named configuration recurs and its details are not what any test is about | A test needs one field changed: use the builder |
| Seed helper | Rows must exist in a database | Constructing an object in memory |

A builder's gain is maintainability, one of Khorikov's four pillars of a good test: a new required field changes the builder's default, not every test. A pytest factory fixture returns a function the test calls with the values it cares about, and fixtures compose by naming each other (Okken).

## Rules for builders and mothers

- Defaults make a **valid** object. A test states only what it cares about.
- Build through the domain's own constructors and behaviour. Reach a state such as archived or refunded by calling the behaviour that produces it, or the repository's reconstitution function with the real state value; then the precondition is true, not implied by a name.
- Every call returns a new object. Share construction, never instances; a module-level or package-level mutable fixture couples outcomes (Khorikov).
- Fixture scope in pytest: anything holding data a test changes is function-scoped. Session scope is for expensive resources such as a container or engine (Okken).
- A call that sets every field is a literal in disguise; split the test or add a mother.
- Use the product's own glossary terms for builders and mothers.

## Time

- Code under test receives the time (a parameter or a clock port). Tests pass a fixed instant with an explicit time zone.
- Database column defaults that read the wall clock are also uncontrolled: pass the value from the application, or do not assert on it.
- Code built on Go timers: `testing/synctest` (Go 1.25 and later) gives a fake clock inside a bubble; I/O and mutex waits do not count as blocked there, so it does not suit database tests.
- A polling deadline in a test may read the real clock; it bounds the wait and is not test data.

## IDs

- Builder defaults are fixed constants.
- When committed rows from different tests must not collide, derive the ID from the test's name and a label (a name-based UUID). Same test, same ID, every run.
- Assert the exact ID, not "some UUID".

## Randomness

- Inject the generator and give it a fixed seed.
- Go: `math/rand/v2`'s global functions are always randomly seeded, so build an explicit source with a fixed seed. Python: a local `random.Random(seed)`.
- Property-based and fuzz runs manage their own inputs; keep each failing input as a fixed case.

## Data content

Write values that are obviously made up. Using copies of production data, masked or not, is not covered by any rule in this skill: put it to the product owner and the data-classification and compliance owners before anyone does it.
