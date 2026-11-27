# Integration Harness (Redpanda)

Copy into `internal/test/kafka.go` beside the PostgreSQL harness, only when the product has a broker. Compiled and run on Go 1.27.4 with the Testcontainers Redpanda module v0.45.0, franz-go v1.22.3 and kadm v1.20.0.

```bash
go get github.com/testcontainers/testcontainers-go/modules/redpanda@v0.45.0 \
  github.com/twmb/franz-go@v1.22.3 github.com/twmb/franz-go/pkg/kadm@v1.20.0
go mod tidy
```

Topics have one partition, so "committed offset N on partition 0" means every earlier record is done. A test of partition behaviour needs its own helper.

### `internal/test/kafka.go`

```go
package test

import (
	"context"
	"errors"
	"fmt"
	"io/fs"
	"log"
	"sync/atomic"
	"testing"
	"time"

	"github.com/testcontainers/testcontainers-go"
	"github.com/testcontainers/testcontainers-go/modules/redpanda"
	"github.com/twmb/franz-go/pkg/kadm"
	"github.com/twmb/franz-go/pkg/kgo"
)

// Pin the tag to the version production runs.
const RedpandaImage = "redpandadata/redpanda:v26.2.7"

// Redpanda is one throwaway single-node broker.
type Redpanda struct {
	Brokers string
	Admin   *kadm.Client
	client  *kgo.Client
	ctr     *redpanda.Container
	names   atomic.Int64
}

// StartRedpanda starts the broker. The caller calls Close.
func StartRedpanda(ctx context.Context) (*Redpanda, error) {
	ctr, err := StartWithRetry(ctx, RedpandaImage, func(ctx context.Context) (*redpanda.Container, error) {
		return redpanda.Run(ctx, RedpandaImage, loopback("9092/tcp", "9644/tcp", "8081/tcp", "8082/tcp"))
	})
	if err != nil {
		return nil, err
	}
	brokers, err := ctr.KafkaSeedBroker(ctx) // the host port is random: never hard-code 9092
	if err != nil {
		return nil, errors.Join(fmt.Errorf("seed broker: %w", err), testcontainers.TerminateContainer(ctr))
	}
	client, err := kgo.NewClient(kgo.SeedBrokers(brokers))
	if err != nil {
		return nil, errors.Join(fmt.Errorf("kafka client: %w", err), testcontainers.TerminateContainer(ctr))
	}
	return &Redpanda{Brokers: brokers, Admin: kadm.NewClient(client), client: client, ctr: ctr}, nil
}

// Close closes the client and removes the container.
func (r *Redpanda) Close() error {
	r.client.Close()
	return testcontainers.TerminateContainer(r.ctr)
}

// RunPostgresAndRedpanda is the body of TestMain for a package that needs both.
func RunPostgresAndRedpanda(m *testing.M, migrations fs.FS, use func(*Postgres, *Redpanda)) (code int) {
	if Short() {
		return m.Run()
	}
	broker, err := StartRedpanda(context.Background())
	if err != nil {
		log.Printf("integration harness: %v", err)
		return 1
	}
	defer func() {
		if err := broker.Close(); err != nil {
			log.Printf("integration harness: stop redpanda: %v", err)
			code = 1
		}
	}()
	return RunPostgres(m, migrations, func(pg *Postgres) { use(pg, broker) })
}

// Name is unique within the package run: use it for consumer groups.
func (r *Redpanda) Name(prefix string) string {
	return fmt.Sprintf("%s-%d", prefix, r.names.Add(1))
}

// NewTopic creates a one-partition topic of the test's own and deletes it afterwards.
func (r *Redpanda) NewTopic(t testing.TB, prefix string) string {
	t.Helper()
	topic := r.Name(prefix)
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	if _, err := r.Admin.CreateTopic(ctx, 1, 1, nil, topic); err != nil {
		t.Fatalf("create topic %s: %v", topic, err)
	}
	t.Cleanup(func() {
		ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()
		if _, err := r.Admin.DeleteTopic(ctx, topic); err != nil {
			t.Errorf("delete topic %s: %v", topic, err)
		}
	})
	return topic
}

// Publish writes one record and waits for the broker's acknowledgement.
func (r *Redpanda) Publish(t testing.TB, topic string, value []byte) {
	t.Helper()
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	if err := r.client.ProduceSync(ctx, &kgo.Record{Topic: topic, Value: value}).FirstErr(); err != nil {
		t.Fatalf("publish to %s: %v", topic, err)
	}
}

// Read returns the first n records of a topic, or fails the test at the deadline.
func (r *Redpanda) Read(t testing.TB, topic string, n int, timeout time.Duration) []*kgo.Record {
	t.Helper()
	reader, err := kgo.NewClient(kgo.SeedBrokers(r.Brokers), kgo.ConsumeTopics(topic),
		kgo.ConsumeResetOffset(kgo.NewOffset().AtStart()))
	if err != nil {
		t.Fatalf("reader for %s: %v", topic, err)
	}
	defer reader.Close()
	ctx, cancel := context.WithTimeout(context.Background(), timeout)
	defer cancel()
	var records []*kgo.Record
	for len(records) < n {
		fetches := reader.PollFetches(ctx)
		if ctx.Err() != nil {
			t.Fatalf("topic %s: %d of %d records within %s", topic, len(records), n, timeout)
		}
		if err := fetches.Err(); err != nil {
			t.Fatalf("read %s: %v", topic, err)
		}
		records = append(records, fetches.Records()...)
	}
	return records
}

// AwaitCommitted waits until the group has committed offset `next` on partition 0,
// which proves the consumer has finished every record before it.
func (r *Redpanda) AwaitCommitted(t testing.TB, group, topic string, next int64) {
	t.Helper()
	Await(t, 30*time.Second, fmt.Sprintf("group %s committed offset %d of %s", group, next, topic),
		func(ctx context.Context) (bool, error) {
			offsets, err := r.Admin.FetchOffsets(ctx, group)
			if err != nil {
				return false, err
			}
			committed, ok := offsets.Lookup(topic, 0)
			return ok && committed.At >= next, nil
		})
}
```
