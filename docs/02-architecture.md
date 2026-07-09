# Part 2: Architectural Presentation

> Notes for the STACKIT technical interview — 2026

---

## 1. The three layers: Garden, Seed, Shoot

Gardener manages clusters in three layers (the names are botanical):

1. **Garden**: the central brain. You talk to it to ask for clusters, and it stores everything (the `Shoot`, `Seed`, `Project` objects).
2. **Seed**: a cluster that hosts the *control planes* of the customer clusters.
3. **Shoot**: the actual cluster a user gets and runs their workloads on.

The main components:

- **Gardener API server** (Garden): adds `Shoot`/`Seed`/`Project` to the Kubernetes API. It's the entry point for users and automation.
- **Scheduler** (Garden): decides which Seed will host a new Shoot.
- **Gardenlet** (Seed): runs on each Seed, watches the Garden for Shoots assigned to it, and builds them. It *pulls* work from the Garden rather than the Garden pushing to it (this matters in Part 3).
- **Machine controller manager** (Seed): turns "I need a node" into an actual VM on the provider.

One thing I noticed locally: with KinD there's only one physical cluster, but the Garden still runs as its own set of pods *inside* the Seed (the `virtual-garden-*` pods), with its own separate kubeconfig. So the Garden/Seed split is logical even when they share the same hardware.

---

## 2. Hosted control planes (Kubeception)

Normally each cluster runs its own control plane (API server, etcd, …) on dedicated VMs. Gardener instead runs a Shoot's control plane as **normal pods inside a Seed**. Only the Shoot's worker nodes are real VMs.

Why it's a good design: you don't pay for dedicated control-plane VMs per customer, because the control planes are just pods packed onto shared Seed nodes, so one Seed can host many. It also isolates things a bit better, since the control plane isn't sitting on the same machine as the customer's workloads, so a compromised workload can't easily reach it.

The downside is the flip side of that sharing. Control planes sit on the same Seed nodes, so a misbehaving one could in theory affect its neighbours. Gardener limits that with resource limits and network policies.

I saw this directly: after creating the Shoot, its `kube-apiserver`, `etcd`, etc. were all just pods in a `shoot--local--local` namespace on the Seed, no separate control-plane VM in sight.

---

## 3. Networking basics

**User → Shoot API server.** Many Shoots share one entry point on the Seed (an Istio gateway). It routes by hostname using the TLS SNI field (the server name the client sends in the handshake), without decrypting the traffic, so it stays encrypted end-to-end to the right Shoot's API server. This avoids needing a public IP per Shoot.

I saw the routing rule for my Shoot's API server (`api.local.local…`) sitting behind that shared gateway.

**Control plane → worker nodes.** The control plane (on the Seed) needs to reach the workers, but workers are usually behind a firewall with nothing open for inbound traffic. Gardener uses a "reversed VPN": it is the worker that connects out to the Seed and opens a tunnel, and the control plane sends traffic back through it. I saw both ends: a `vpn-seed-server` pod on the Seed and a `vpn-shoot` pod on the worker.
