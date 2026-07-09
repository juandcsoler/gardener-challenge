# Exploring Project Gardener

My take-home for STACKIT: deploy [Gardener](https://gardener.cloud/), document what worked and what
didn't, and give an honest opinion on whether it fits a private / potentially air-gapped cloud.

## What I built

A complete, minimal Gardener setup on a **single cloud VM**:

- **1 Garden**, **1 Seed**, and **1 Shoot cluster** with a real worker node — all healthy
- Deployed with the **`gardener-operator`** (the `make gardener-up` flow), on Gardener v1.146.0-dev
- Running on an EC2 box provisioned with Terraform (`infra/`), because my laptop was under
  Gardener's documented resource minimums

Everything in the docs below is backed by real command output captured from that deployment.

## The write-ups

| | |
|---|---|
| [**01 — Deployment log**](docs/01-deployment-log.md) | What worked, what didn't, and how I debugged it. Real `kubectl` output throughout. |
| [**02 — Architecture**](docs/02-architecture.md) | The three tiers, hosted control planes (Kubeception), and the two networking flows. |
| [**03 — Strategic evaluation**](docs/03-strategic-evaluation.md) | Is Gardener right for a private / air-gapped platform? Where the real work is. |

## Infrastructure

[`infra/`](infra/) holds the Terraform for the dev box, plus the cloud-init that bootstraps Docker,
Go, kubectl and the Gardener source. See [`infra/README.md`](infra/README.md).

## Notes on scope

The brief asked for a minimal, functional proof of concept — explicitly *not* HA, security hardening,
or backups — capped at 4–6 hours. I stuck to that: one clean end-to-end path, plus the time to
actually understand the architecture rather than just get it running.

Things I deliberately left out (and would want to explore next): HA control planes, etcd backups,
a second Seed / `ManagedSeed`, and genuinely simulating an air-gapped registry.

Every architectural claim in `docs/02` was checked against Gardener's own documentation, not just
asserted from memory.
