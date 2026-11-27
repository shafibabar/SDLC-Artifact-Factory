# Integration Harness (Redpanda)

Copy only when the product has a broker, beside `harness.py` as `tests/integration/broker.py`. Run on Python 3.14.4 with testcontainers 4.15.0, aiokafka 0.15.0 and `redpandadata/redpanda:v26.2.7`.

Its async fixtures need `asyncio_mode = "auto"` in `[tool.pytest.ini_options]` (or `@pytest_asyncio.fixture`).

## Dependencies

`aiokafka==0.15.0` in `[project] dependencies`.

## Make the fixtures visible

Add to `tests/integration/conftest.py`, with the other imports:

```python
from tests.integration.broker import new_topic, redpanda  # noqa: F401 - fixtures
```

## Change only

The image tag (`REDPANDA_IMAGE`) and the start limit passed to `start`. `RedpandaContainer` fixes the broker's start flags (`--memory 1G --smp 1` in testcontainers 4.15.0). One partition per test topic: a test that needs more also reads their offsets.

### `tests/integration/broker.py`

```python
"""Redpanda part of the integration harness. Copy only when the product has a broker."""

import uuid
from collections.abc import AsyncIterator, Awaitable, Callable, Iterator

import pytest
from aiokafka import AIOKafkaConsumer, ConsumerRecord, TopicPartition
from aiokafka.admin import AIOKafkaAdminClient, NewTopic
from testcontainers.community.kafka import RedpandaContainer

from tests.integration.harness import loopback, start_with_retry

# Pin the tag to the version production runs.
REDPANDA_IMAGE = "redpandadata/redpanda:v26.2.7"


@pytest.fixture(scope="session")
def redpanda() -> Iterator[str]:
    """Bootstrap address of one throwaway broker per test process."""

    def make() -> RedpandaContainer:
        container = RedpandaContainer(REDPANDA_IMAGE)
        container.ports.clear()
        return loopback(container, 9092)

    # RedpandaContainer.start() waits with LogMessageWaitStrategy ("Started Kafka API
    # server"); its default limit is 10 seconds.
    container = start_with_retry(REDPANDA_IMAGE, make, lambda c: c.start(timeout=60))
    try:
        yield container.get_bootstrap_server()
    finally:
        container.stop()


@pytest.fixture
async def new_topic(redpanda: str) -> AsyncIterator[Callable[..., Awaitable[str]]]:
    """A one-partition topic of this test's own, deleted afterwards."""
    admin = AIOKafkaAdminClient(bootstrap_servers=redpanda)
    await admin.start()
    created: list[str] = []

    async def make(name: str = "") -> str:
        name = name or f"t-{uuid.uuid4().hex}"  # unique on the broker; not used as test data
        response = await admin.create_topics([NewTopic(name, num_partitions=1, replication_factor=1)])
        assert all(t[1] == 0 for t in response.topic_errors), response.topic_errors
        created.append(name)
        return name

    try:
        yield make
    finally:
        try:
            if created:
                response = await admin.delete_topics(created)
                failed = [t for t in response.topic_error_codes if t[1] != 0]
                assert not failed, f"topics not deleted: {failed}"
        finally:
            await admin.close()


async def committed_offset(bootstrap: str, group: str, topic: str) -> int:
    """The group's committed offset on partition 0; 0 when nothing is committed."""
    admin = AIOKafkaAdminClient(bootstrap_servers=bootstrap)
    await admin.start()
    try:
        offsets = await admin.list_consumer_group_offsets(group)
        found = offsets.get(TopicPartition(topic, 0))
        return max(found.offset, 0) if found else 0
    finally:
        await admin.close()


async def read_all(bootstrap: str, topic: str) -> list[ConsumerRecord]:
    """Every record now on partition 0, read without a consumer group."""
    consumer = AIOKafkaConsumer(bootstrap_servers=bootstrap, enable_auto_commit=False)
    await consumer.start()
    try:
        partition = TopicPartition(topic, 0)
        consumer.assign([partition])
        await consumer.seek_to_beginning(partition)
        end = (await consumer.end_offsets([partition]))[partition]
        records: list[ConsumerRecord] = []
        while len(records) < end:
            batch = await consumer.getmany(partition, timeout_ms=1000)
            assert batch, f"{topic}: broker returned nothing below end offset {end}"
            records.extend(batch[partition])
        return records
    finally:
        await consumer.stop()
```
