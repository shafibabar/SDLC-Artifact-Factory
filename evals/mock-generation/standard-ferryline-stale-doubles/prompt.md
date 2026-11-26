---
max_turns: 8
allowed_tools: [Read, Glob, Grep, Skill]
---

I'm the product owner for **Ferryline**, a ferry booking service in Go, on the **standard** profile. Someone renamed a parameter on our `PaymentGateway` interface, nobody regenerated the committed doubles, and CI stayed green. Here is what we have:

```go
//go:generate go run github.com/matryer/moq@latest -out payment_gateway_moq.go . PaymentGateway
```

```make
check-doubles:
	go generate ./...
	git diff --exit-code -- '*.mock.go' '*.moq.go'

# coverage: drop generated doubles from the profile
cover-filter:
	grep -v '_mock\.go' cover.raw.out > cover.out
```

We also have a hand-written `fake_booking_repository.go`.

Fix this, and while you're there: add `-stub` to every directive so tests stop panicking on calls nobody set up, keep `@latest` so we get fixes, and add the hand-written fake to the automatic coverage exclusion since it is only test code.

Use this plugin's mock-generation skill. Answer in your reply, not in a file, and keep it short: under 400 words plus brief Go snippets.
