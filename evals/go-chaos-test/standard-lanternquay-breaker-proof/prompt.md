---
max_turns: 8
timeout_seconds: 300
allowed_tools: [Read, Glob, Grep, Skill]
---

I'm the product owner for **Lanternquay**, a freight-quote platform on the **standard** profile. Our Go `quotes` service calls an internal `rates` service through a circuit breaker configured as the integration design says: it opens after 5 consecutive failures and resets after 5 seconds. A developer wrote these chaos tests in `quotes/chaos_test.go`, which has no build tag and so runs in `go test ./...` on every pull request:

```go
// Breaker test
_ = proxy.AddToxic("slow", "latency", "downstream", 1.0, toxiproxy.Attributes{"latency": 3000})
start := time.Now()
_, err := client.GetQuote(ctx, req)
require.Error(t, err)
require.Less(t, time.Since(start), 500*time.Millisecond) // failed fast, so the breaker works

// Deadlock test
go func() { muB.Lock(); time.Sleep(10 * time.Millisecond); muA.Lock() }()
go func() { muA.Lock(); time.Sleep(10 * time.Millisecond); muB.Lock() }()
// assert both goroutines are still blocked after 1s: deadlock detected
```

He says these prove the breaker and our lock handling. Please review them and tell me what to change. Use this plugin's go-chaos-test skill, and answer in your reply, not in a file. Keep it short: under 350 words, with brief code only where it helps.
