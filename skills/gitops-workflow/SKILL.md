---
name: gitops-workflow
description: >
  Teaches the GitOps workflow discipline — the four GitOps principles (declarative, versioned/immutable, pulled automatically, continuously reconciled), environment-repository directory conventions, the Sealed Secrets vs SOPS decision for secrets in Git, drift-as-incident policy, the App of Apps pattern, and the push-vs-pull model distinction. Tool-agnostic; applies equally to cd-pipeline workloads and opentofu-module infrastructure. Used by the platform-engineer during Deploy.
version: 1.0.0
phase: deploy
owner: platform-engineer
created: 2026-07-31
tags: ["deploy","gitops","flux","argocd","reconciliation","drift","declarative","environment-repo","sealed-secrets","sops"]
---

## Purpose

GitOps is an operating model for cloud-native systems in which Git is the single source of truth for desired state, and automated agents (not pipelines or humans) continuously reconcile the cluster toward that state. This skill defines the four principles, the directory conventions that make them operational, the secrets strategy for per-tenant environments, and the tool selection criteria.

---

## The Four GitOps Principles

These four properties define whether a workflow is GitOps. All four must hold — satisfying fewer is not GitOps.

| # | Principle | Definition | What violates it |
|---|---|---|---|
| 1 | **Declarative** | Entire desired state expressed as declarations (YAML/HCL), not procedural scripts | A pipeline that runs `helm install` via script instead of a `HelmRelease` CRD |
| 2 | **Versioned and Immutable** | Declared state stored in version control; historical versions immutable; complete audit trail | Editing live manifests directly in the cluster without a Git commit |
| 3 | **Pulled Automatically** | Approved changes to desired state are applied by in-cluster agents, not pushed by CI | A CI job that runs `kubectl apply` on merge — the pipeline is still pushing |
| 4 | **Continuously Reconciled** | Agents continuously observe actual state and reconcile toward desired state | A one-shot deploy script that only runs when triggered; no ongoing reconciliation |

**Critical distinction:** a CI pipeline that runs `kubectl apply` on merge satisfies Declarative and Versioned but **not** Pulled or Continuously Reconciled. It is not GitOps — it is scripted deployment with a Git log. Continuous Reconciliation is what makes drift detectable and self-healing possible.

---

## Drift-as-Incident Policy

Any detected diff between actual cluster state and Git-declared state that persists beyond one reconciliation interval is an **incident**, not a background condition.

- Manual `kubectl apply` or `kubectl edit` against a live environment is an incident, not a workflow — it produces drift that is invisible to Git history.
- The reconciliation interval is the window before a drift alert fires. For Flux this defaults to 10 minutes; for critical namespaces set to 5 minutes.
- Drift alerts route to the same on-call channel as availability alerts. See `alerting-rules-design` for the alert definition pattern.
- Self-healing (Flux `force: true` / Argo CD auto-sync with self-heal) automatically reverts manual edits. Enable it in all non-development environments.

---

## Environment-Repo Directory Convention

```
clusters/
  <cluster-name>/                       # one directory per cluster (tenant or shared)
    namespaces/
      <namespace>/                      # one directory per namespace
        <service>.helmrelease.yaml      # per-service delivery unit (or kustomization.yaml)
    flux-system/                        # bootstrapped by flux install / flux bootstrap
      gotk-components.yaml
      gotk-sync.yaml
```

The GitOps agent's source is a **path in this tree**, not a pipeline stage or script. Adding a service = adding a file. Tearing down an environment = deleting the cluster directory and applying the removal.

Full layout with example CRDs: `references/environment-repo-layout.md`

---

## App of Apps Pattern

A root Flux `Kustomization` (or Argo CD `Application`) points to a directory whose contents are child CRDs — one per service. The root CRD is the entire environment's stamp; committing it bootstraps the environment; deleting it tears it down.

When to use it: any environment with more than two services. Below two services, a flat list of `HelmRelease` CRDs is sufficient; above two, the App of Apps root provides a single Git commit as the environment lifecycle operator.

Step-by-step implementation: `references/app-of-apps-pattern.md`

---

## Tool Selection: Flux vs Argo CD

| Criterion | Flux | Argo CD |
|---|---|---|
| Architecture | Composable CRD controllers (`GitRepository` → `Kustomization` or `HelmRelease`) | `Application` CRD binding source to destination |
| UI | None (Kubernetes-native, CLI/gitops) | Rich web UI with per-application sync status |
| Multi-team visibility | SRE-mode; no dashboard for non-SREs | Non-SREs can inspect sync status without cluster access |
| SOPS support | Native in `kustomize-controller` | Plugin required |
| Multi-cluster | `Cluster` CRD via fleet extension | Hub cluster manages spoke clusters via API server |
| Default for this repo | **Yes** (SRE-mode, per-tenant stamps, SOPS-native) | Use when non-SRE teams need UI-visible deploy status |

**This repo's default is Flux.** Rationale: per-tenant ephemeral cluster stamps, SOPS-native secrets, no UI requirement, SRE-managed operations. Switch to Argo CD only when a product team explicitly needs UI-visible Application inventory.

---

## Secrets in GitOps

Secrets cannot go into Git as plaintext. Two patterns dominate:

| Pattern | How it works | Key risk | Use when |
|---|---|---|---|
| **Sealed Secrets** | `kubeseal` encrypts against cluster's public key; only in-cluster controller decrypts; `SealedSecret` CRD is safe to commit | Decryption coupled to cluster identity — cluster recreation requires key management | Long-lived, non-replaceable clusters |
| **SOPS** | Encrypts specific YAML keys via external KMS (AWS KMS, GCP KMS, age); Flux `kustomize-controller` decrypts natively | Requires external key management infrastructure | **Ephemeral / replaceable clusters (per-tenant stamps)** |

**Decision for this repo:** use SOPS + age key for per-tenant stamps (cluster is replaceable; decryption must survive cluster recreation). Use Sealed Secrets only for long-lived shared clusters where external KMS is not available.

Full comparison with concrete examples and Flux configuration: `references/secrets-in-gitops.md`

---

## GitOps Beyond Kubernetes Workloads

The four principles apply to infrastructure, not just workloads:

- `opentofu-module`'s plan-before-apply workflow (desired state in Git, automated `tofu apply` on merge, PR-required for changes) satisfies all four principles as applied to infrastructure.
- The same drift-as-incident policy applies: an out-of-band `terraform apply` against a live environment is an incident.
- Environment-repo conventions extend naturally: `infrastructure/<env>/main.tf` is the declarative desired state; the GitOps agent is a GitHub Actions workflow + OPA gate rather than a Flux controller — but the pull model (no human touches live infra without a Git commit) is identical.

---

## Related Skills

- `cd-pipeline` — the delivery pipeline that produces the image artifact the GitOps agent pulls into the cluster
- `environment-config` — per-environment values and cluster stamp conventions
- `secrets-management` — runtime secret injection (Vault Agent); SOPS/Sealed Secrets cover bootstrap secrets, Vault covers runtime credentials
- `alerting-rules-design` — drift alert definition that enforces the drift-as-incident policy
- `opentofu-module` — IaC side of the GitOps model
- `kubernetes-manifest` — the workload manifests that the GitOps agent reconciles
