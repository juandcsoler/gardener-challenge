#!/usr/bin/env bash
# EC2 user-data: prepares an Ubuntu 22.04 box to run Gardener's local (KinD-based) dev setup.
# Output is captured by cloud-init at /var/log/cloud-init-output.log.
set -euxo pipefail

GO_VERSION="1.23.4"
GARDENER_REPO="https://github.com/gardener/gardener.git"

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y --no-install-recommends \
  git jq parallel iproute2 ca-certificates curl gnupg build-essential

# --- Docker CE + compose plugin ---
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
  > /etc/apt/sources.list.d/docker.list
apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
usermod -aG docker ubuntu

# Local dev registry used by `make kind-up` is plain HTTP — tell Docker to trust it.
mkdir -p /etc/docker
cat > /etc/docker/daemon.json <<'EOF'
{
  "insecure-registries": ["registry.local.gardener.cloud:5001"]
}
EOF
systemctl restart docker

# --- Go (bootstrap toolchain; go.mod's `go 1.26.0` directive triggers an
#     automatic toolchain download via GOTOOLCHAIN=auto on first build) ---
curl -fsSL "https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz" -o /tmp/go.tar.gz
tar -C /usr/local -xzf /tmp/go.tar.gz
rm /tmp/go.tar.gz
echo 'export PATH=$PATH:/usr/local/go/bin:/home/ubuntu/go/bin' > /etc/profile.d/go.sh
chmod +x /etc/profile.d/go.sh

# --- kubectl (>= 1.30 required) ---
KUBECTL_VERSION="$(curl -fsSL https://dl.k8s.io/release/stable.txt)"
curl -fsSL "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl" -o /usr/local/bin/kubectl
chmod +x /usr/local/bin/kubectl

# --- yq ---
curl -fsSL https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 -o /usr/local/bin/yq
chmod +x /usr/local/bin/yq

# --- Clone Gardener source as the ubuntu user ---
sudo -u ubuntu -H bash -c "git clone --depth 1 '${GARDENER_REPO}' /home/ubuntu/gardener"

touch /home/ubuntu/SETUP_DONE
chown ubuntu:ubuntu /home/ubuntu/SETUP_DONE
