# Go External Task Workers

A Conductor **SIMPLE** task is executed by an **external task worker**: a Go
loop that polls Conductor for work of one task type, runs domain logic, and
posts the result back. The worker is a thin adapter over the same domain
functions the chi HTTP handlers call — business logic stays in the service,
flow state stays in Conductor. This reference gives the full worker skeleton,
the `taskId` idempotency pattern, and how workers run alongside the chi
`http.Server` under shared graceful shutdown.

Uses Go + `pgx` + chi, per this repo's stack. The Conductor HTTP API calls are
shown against the raw endpoints so the mechanics are explicit; in production the
official `conductor-go` client wraps the same calls.

---

## 1. The Poll → Execute → Update Loop

Each worker owns one task type. It polls, and on a returned task it executes and
posts the outcome via `updateTask`.

```go
package worker

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"log/slog"
	"net/http"
	"time"
)

// Task is the subset of Conductor's polled-task shape a worker needs.
type Task struct {
	TaskID            string                 `json:"taskId"`
	WorkflowInstanceID string                `json:"workflowInstanceId"`
	TaskType          string                 `json:"taskType"`
	InputData         map[string]any         `json:"inputData"`
}

// TaskResult is posted back to Conductor after execution.
type TaskResult struct {
	TaskID     string         `json:"taskId"`
	WorkflowInstanceID string `json:"workflowInstanceId"`
	Status     string         `json:"status"` // COMPLETED | FAILED | FAILED_WITH_TERMINAL_ERROR | IN_PROGRESS
	OutputData map[string]any `json:"outputData,omitempty"`
	ReasonForIncompletion string `json:"reasonForIncompletion,omitempty"`
}

// Handler runs the domain logic for one task and returns its output.
type Handler func(ctx context.Context, in map[string]any) (map[string]any, error)

// Worker polls one task type and dispatches to a Handler.
type Worker struct {
	conductorURL string
	taskType     string
	workerID     string       // stable identity, e.g. pod name
	handle       Handler
	client       *http.Client
	pollInterval time.Duration
	log          *slog.Logger
}

func (w *Worker) Run(ctx context.Context) {
	ticker := time.NewTicker(w.pollInterval)
	defer ticker.Stop()
	for {
		select {
		case <-ctx.Done():
			w.log.Info("worker stopping", "taskType", w.taskType)
			return
		case <-ticker.C:
			task, ok := w.poll(ctx)
			if !ok {
				continue // no work available
			}
			w.process(ctx, task)
		}
	}
}
```

### poll — take one task of this type

```go
func (w *Worker) poll(ctx context.Context) (Task, bool) {
	// GET /api/tasks/poll/{taskType}?workerid={id}
	url := fmt.Sprintf("%s/api/tasks/poll/%s?workerid=%s",
		w.conductorURL, w.taskType, w.workerID)
	req, _ := http.NewRequestWithContext(ctx, http.MethodGet, url, nil)
	resp, err := w.client.Do(req)
	if err != nil {
		w.log.Error("poll failed", "err", err)
		return Task{}, false
	}
	defer resp.Body.Close()
	if resp.StatusCode == http.StatusNoContent {
		return Task{}, false // empty queue — normal
	}
	var t Task
	if err := json.NewDecoder(resp.Body).Decode(&t); err != nil || t.TaskID == "" {
		return Task{}, false
	}
	return t, true
}
```

### process — idempotent execute + update

```go
func (w *Worker) process(ctx context.Context, t Task) {
	// Bound each task to a timeout shorter than the taskdef's
	// responseTimeoutSeconds so we always report before Conductor re-queues.
	ctx, cancel := context.WithTimeout(ctx, 40*time.Second)
	defer cancel()

	out, err := w.handle(ctx, t.InputData) // domain function
	res := TaskResult{
		TaskID:             t.TaskID,
		WorkflowInstanceID: t.WorkflowInstanceID,
	}
	switch {
	case err == nil:
		res.Status = "COMPLETED"
		res.OutputData = out
	case errors.Is(err, ErrTerminal):
		// Non-retriable (bad input): stop retrying immediately.
		res.Status = "FAILED_WITH_TERMINAL_ERROR"
		res.ReasonForIncompletion = err.Error()
	default:
		// Retriable: Conductor re-attempts per the taskdef retryLogic.
		res.Status = "FAILED"
		res.ReasonForIncompletion = err.Error()
	}
	w.update(ctx, res)
}

func (w *Worker) update(ctx context.Context, res TaskResult) {
	// POST /api/tasks  with the TaskResult body
	body, _ := json.Marshal(res)
	req, _ := http.NewRequestWithContext(ctx, http.MethodPost,
		w.conductorURL+"/api/tasks", bytesReader(body))
	req.Header.Set("Content-Type", "application/json")
	if resp, err := w.client.Do(req); err != nil {
		w.log.Error("updateTask failed", "taskId", res.TaskID, "err", err)
	} else {
		resp.Body.Close()
	}
}
```

`FAILED` lets Conductor re-attempt per the task definition's `retryCount` /
`retryLogic`; `FAILED_WITH_TERMINAL_ERROR` stops retrying immediately for
un-fixable input. Distinguishing the two in the worker is what makes the JSON
retry policy meaningful — return `ErrTerminal` for a poisoned message, a plain
error for a transient one.

---

## 2. Idempotency Keyed on taskId

Conductor redelivers a task after a `responseTimeoutSeconds` lapse, a worker
crash, or a retry — and Redpanda redelivers downstream events. Every worker
must be idempotent, keyed on the Conductor **`taskId`** (unique per task
instance), not on the workflow input (two legitimate retries share the same
input). Persist a processed-key row in the same local transaction as the work,
so re-execution is a no-op that re-posts the prior result.

```go
// handleClassify is a Handler; it is safe to run twice for the same taskId.
func (s *Service) handleClassify(ctx context.Context, in map[string]any) (map[string]any, error) {
	taskID, _ := in["_taskId"].(string) // injected from Task.TaskID by the worker
	assetID, _ := in["assetId"].(string)

	tx, err := s.pool.Begin(ctx)
	if err != nil {
		return nil, fmt.Errorf("begin: %w", err)
	}
	defer tx.Rollback(ctx)

	// Dedup: if this taskId already produced a result, return it unchanged.
	var level string
	err = tx.QueryRow(ctx,
		`SELECT level FROM task_dedup WHERE task_id = $1`, taskID).Scan(&level)
	if err == nil {
		return map[string]any{"level": level}, nil // already done — no-op
	}
	if !errors.Is(err, pgx.ErrNoRows) {
		return nil, fmt.Errorf("dedup lookup: %w", err)
	}

	level = classify(ctx, assetID) // the real domain logic

	// Record the result under the taskId in the SAME transaction as the work.
	_, err = tx.Exec(ctx,
		`INSERT INTO task_dedup (task_id, level) VALUES ($1, $2)
		 ON CONFLICT (task_id) DO NOTHING`, taskID, level)
	if err != nil {
		return nil, fmt.Errorf("record dedup: %w", err)
	}
	if err := tx.Commit(ctx); err != nil {
		return nil, fmt.Errorf("commit: %w", err)
	}
	return map[string]any{"level": level}, nil
}
```

The worker injects `Task.TaskID` into the handler input (e.g. as `_taskId`) so
the domain function can key on it. The `task_dedup` row and the business write
commit atomically — a crash between them leaves neither, and the redelivered
task re-does the whole unit cleanly.

---

## 3. Running Workers Alongside the chi Service

Workers are not a separate microservice — they run in the same process as the
owning bounded context's chi HTTP service, sharing its `pgx` pool, config,
logger, OTel telemetry, and per-tenant deployment. Start them from the same
composition root (`go-service-skeleton`), all descending from the one root
context so a single `SIGTERM` stops the HTTP server and every worker together.

```go
func run() error {
	ctx, stop := signal.NotifyContext(context.Background(),
		os.Interrupt, syscall.SIGTERM)
	defer stop()

	pool := mustConnectPostgres(ctx)   // shared with chi handlers
	defer pool.Close()
	svc := NewService(pool)

	var wg sync.WaitGroup
	workers := []*Worker{
		NewWorker(conductorURL, "classify_data_asset", svc.handleClassify),
		NewWorker(conductorURL, "scan_pii", svc.handleScanPII),
		NewWorker(conductorURL, "register_data_asset", svc.handleRegister),
		NewWorker(conductorURL, "publish_to_catalog", svc.handlePublish),
		NewWorker(conductorURL, "deregister_data_asset", svc.handleDeregister),
	}
	for _, w := range workers {
		wg.Add(1)
		go func(w *Worker) { defer wg.Done(); w.Run(ctx) }(w)
	}

	srv := &http.Server{Addr: ":8080", Handler: chiRouter(svc)}
	go func() { _ = srv.ListenAndServe() }()

	<-ctx.Done()                       // SIGTERM: cancel workers + drain HTTP
	shutdownCtx, cancel := context.WithTimeout(context.Background(), 25*time.Second)
	defer cancel()
	_ = srv.Shutdown(shutdownCtx)
	wg.Wait()                          // let in-flight tasks report before exit
	return nil
}
```

`ctx.Done()` cancels every worker's poll loop; `wg.Wait()` after the HTTP drain
gives in-flight tasks the chance to post their result (COMPLETED or FAILED)
before the process exits, so Conductor is not left waiting the full
`responseTimeoutSeconds` to re-queue work the pod already finished.

---

## 4. Health and Metrics

Each worker process exposes the same readiness/liveness contract as any chi
service (`health-check-design`) plus worker-specific signals:

- **Liveness** (`/healthz`): the process is up and the poll loops are running.
- **Readiness** (`/readyz`): the `pgx` pool answers `SELECT 1` **and** the
  Conductor server is reachable (a `GET /api/health`) — a worker that cannot
  reach Conductor should report not-ready so it is not counted as draining work.
- **Metrics** (Prometheus, per this repo's OTel/Prometheus default): per task
  type, counters for polled / completed / failed / terminal-failed, and a
  histogram of handler duration. These make "is a worker keeping up with its
  queue?" a dashboard question, mirroring Conductor's own workflow-level view.

Never gate liveness on Conductor reachability — a Conductor outage should not
cause Kubernetes to restart otherwise-healthy worker pods; that belongs on
readiness only.
