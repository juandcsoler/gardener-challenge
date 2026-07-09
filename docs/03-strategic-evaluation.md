# Part 3: The Strategic Evaluation (Your Opinion)

> My take for the STACKIT technical interview — 2026

---

## 1. Is Gardener the right tool?

Short answer: yes for STACKIT, but the extra work of running it offline (air-gapped) is the real challenge.

Why it fits:

- It already runs thousands of clusters in production (SAP, T-Systems), so it's proven, not experimental.
- The hosted-control-plane model (Part 2) is much cheaper than running a full control plane per cluster.
- You can extend it for STACKIT's own infrastructure without forking the project. I saw it uses swappable extensions (e.g. for networking).

---

## 2. Risks of running it offline (air-gapped)

A few things get harder offline.

The images are the main one. Gardener needs a lot of container images, and offline you have to mirror them all into an internal registry and keep it in sync on every upgrade. That's the biggest ongoing chore.

Updates are the other big one. Gardener and Kubernetes both release often, and without internet, updating is manual and easy to fall behind on, so it needs a proper process rather than being done ad hoc.

And it assumes some internet services exist by default, like public DNS and certificates for the Shoot endpoints. Offline you have to provide internal equivalents.

---

## 3. Two points I can back up from the deployment

- **It manages itself with an operator.** `make gardener-up` runs an operator that sets everything up in the right order. Using an operator to run Gardener (the same way Gardener runs clusters) is a good model for upgrades in an air-gapped environment.
- **The Gardenlet pulls, it doesn't get pushed to.** Each Seed reaches *out* to the Garden for its work. That's much easier to firewall than the Garden having to reach into every Seed, and a real plus for a private/offline setup.