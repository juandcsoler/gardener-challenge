# Terraform — the Gardener dev box

Provisions a single EC2 instance sized for Gardener's local (KinD-based) setup, and bootstraps it
with everything the quickstart needs.

## Why this exists

Gardener's docs ask for at least 8 CPUs / 8Gi memory and ~120Gi disk to run one Seed + one Shoot.
My laptop (WSL2, 16Gi) didn't have the headroom once WSL and Docker took their share, so I moved to
a right-sized cloud VM rather than fight memory pressure. See `../docs/01-deployment-log.md`.

## What it creates

- One `m5.2xlarge` (8 vCPU / 32Gi RAM), Ubuntu 22.04, 200Gi gp3 root volume
- A security group allowing SSH **from your IP only** (no other inbound)
- A key pair from your local public key

`cloud-init/setup.sh` runs on first boot and installs Docker (with the local dev registry marked
insecure — see the deployment log for why), Go, kubectl, jq, yq, GNU parallel, and clones
`gardener/gardener`.

## Usage

```bash
cp terraform.tfvars.example terraform.tfvars.json
# edit allowed_ssh_cidr (use: curl -s ifconfig.me) and public_key_path

terraform init
terraform apply

ssh ubuntu@$(terraform output -raw instance_public_ip)
# wait for ~/SETUP_DONE, then:
cd ~/gardener && source /etc/profile.d/go.sh
make kind-up && make gardener-up
```

Then create a Shoot:
```bash
export KUBECONFIG=$HOME/gardener/dev-setup/kubeconfigs/virtual-garden/kubeconfig
kubectl apply -f example/provider-local/shoot.yaml
kubectl get shoot -A   # wait for healthy / Succeeded
```

## Tear down

Billed by the hour — destroy it when you're done.

```bash
terraform destroy
```
