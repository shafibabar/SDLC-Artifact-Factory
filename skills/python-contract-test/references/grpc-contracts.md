# gRPC Contracts

Self-contained. Read when an internal service-to-service API is gRPC (`grpc-contract-design`; REST is the default, gRPC only inside the product). Results marked "run" were observed with buf 1.75.0. Buf reads `.proto` files, so nothing here depends on the service being written in Python.

## The gate

Every pull request compares the Protobuf files with the ones **deployed**:

```bash
buf breaking --against ".git#ref=$DEPLOYED_REF"
```

with the strictest category in `buf.yaml`:

```yaml
version: v2
breaking:
  use:
    - FILE
```

Exit status 100 means a breaking change (run). Buf is the tool `grpc-contract-design` names as its example; another tool that fails the build on the same changes satisfies it.

## Why `FILE` (run)

| Change | `FILE` | `WIRE_JSON` | `WIRE` |
|---|---|---|---|
| Rename a field | fails | fails | **passes** |
| Renumber, retype or remove a field | fails | fails | fails |
| Remove an RPC | fails | **passes** | **passes** |
| Add a field | passes | passes | passes |
| Change only a comment (the meaning) | passes | passes | passes |

The looser categories protect encoded bytes only. Python code generated from the file breaks on a rename (the attribute and keyword argument change name) or a removed RPC (the stub method is gone), so they are not enough for services that import the generated module. A breaking redesign is a new package (`hotel.v2`) beside the old one.

A missing or empty baseline made buf exit 1 with a `Failure:` line, not 0 (run). The `.git#ref=` form of `--against` was not run for this skill; a folder was used.

## What the gate does not cover

- Meaning: a field whose unit changes passes every category (run).
- Behaviour: the status code for each documented failure is tested against the real server (`python-integration-test`).
- Pact: the rule that every direct request/response call gets a Pact applies to gRPC calls too. pact-python supports gRPC only through a plugin (`Pact.using_plugin`), which was not run for this skill; until it has been, say that the gRPC call's consumer expectations are unverified and list it in the test strategy.
- Generating the Python stubs and compiling against them was not run for this skill; the statement about generated code above is read from how `grpcio-tools` names attributes and methods, not observed.
