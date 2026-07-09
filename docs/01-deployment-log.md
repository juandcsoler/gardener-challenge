# Part 1: Hands-On Deployment — Gardener on KinD

> Environment: EC2 `m5.2xlarge` (8 vCPU / 32Gi RAM), Ubuntu 22.04 | Gardener v1.146.0-dev (master)

---

## What Didn't Work (and how I fixed it)

### 0. Local machine didn't have enough memory

The docs of Gardener ask for at least 8 CPUs / 8Gi memory for one Seed + one Shoot, and ~120Gi of disk. I'm on WSL2 with 16Gi total. When WSL and Docker take their share there isn't much left, and I hit memory pressure early rather than getting a clean run. I tried deploying it twice, but it didn't work and my computer was lagging really hard.

So I moved to a bigger cloud VM instead of fighting the laptop: an EC2 `m5.2xlarge` (8 vCPU / 32Gi RAM, 200Gi gp3), provisioned with Terraform.

**Why plain EC2 + KinD and not EKS?** Gardener's local quickstart (`make kind-up` / `make gardener-up`) is built specifically around KinD. Using a managed cluster like EKS would mean throwing that quickstart away and doing a full production-style install instead. The EC2 box just gives me the RAM I was missing.

### 1. Existing KinD cluster blocked network setup

Gardener's `make kind-up` needs to reconfigure the Docker `kind` network with specific subnets. A pre-existing KinD cluster from another project was using that network. This happened when I was trying to install Gardener on my local computer.

**Error**: `error while removing network: network kind has active endpoints`

**Fix**: `kind delete cluster --name k8s-app-factory-dev` → re-run `make kind-up`

### 2. Docker HTTPS vs HTTP local registry

Skaffold failed pushing images to the local registry because Docker defaults to HTTPS, but the dev registry uses HTTP.

**Error**: `http: server gave HTTP response to HTTPS client`

**Fix**:
```bash
sudo bash -c 'echo "{ \"insecure-registries\": [\"registry.local.gardener.cloud:5001\"] }" > /etc/docker/daemon.json'
sudo systemctl restart docker
```

**Note**: This is mentioned in the official docs but easy to miss. In a real deployment, the registry would have proper TLS. This is only a local dev shortcut.

### 3. First Shoot apply failed: wrong file + wrong kubeconfig

I tried `kubectl apply -f example/90-shoot.yaml` first.

**Error**: `error: resource mapping not found for name: "crazy-botany" namespace: "garden-dev" from "example/90-shoot.yaml": no matches for kind "Shoot" in version "core.gardener.cloud/v1beta1"`

Two separate mistakes happened here:

1. `example/90-shoot.yaml` seems to be the generic multi-cloud template (placeholders like `<some-provider-name>`, `<some-image-name>`). The good one for the local setup is `example/provider-local/shoot.yaml`.
2. `no matches for kind "Shoot"` means whatever API server I was pointed at doesn't serve that resource at all. I still had `KUBECONFIG` pointed at the **runtime** cluster (the physical KinD node). `Shoot` is only served by `gardener-apiserver`, which lives in the **virtual garden**, a separate logical API reachable only via `dev-setup/kubeconfigs/virtual-garden/kubeconfig`. The docs actually call this out explicitly right before this step, which I'd skipped over.

**Fix**:
```bash
export KUBECONFIG=$PWD/dev-setup/kubeconfigs/virtual-garden/kubeconfig
kubectl apply -f example/provider-local/shoot.yaml
```
→ `shoot.core.gardener.cloud/local created`

---

## What Works

### KinD cluster (Garden + Seed)

```
$ kubectl get nodes
NAME                           STATUS   ROLES           AGE   VERSION
gardener-local-control-plane   Ready    control-plane   12m   v1.35.1
```

### Gardener Components

All Garden + Seed components came up healthy after `make gardener-up` (operator-up → garden-up → seed-up):

```
$ export KUBECONFIG=$PWD/dev-setup/kubeconfigs/runtime/kubeconfig
$ kubectl get pods -A | grep -E "garden|seed|istio"
extension-provider-local-dfbff     gardener-extension-provider-local-77d5746987-d7qgg           1/1     Running   0               3m1s
extension-provider-local-dfbff     gardener-extension-provider-local-77d5746987-rdgl2           1/1     Running   0               3m
garden                             alertmanager-garden-0                                        2/2     Running   0               8m10s
garden                             alertmanager-garden-1                                        2/2     Running   0               8m10s
garden                             blackbox-exporter-77c57bcfb-vqzwb                            1/1     Running   0               5m48s
garden                             blackbox-exporter-77c57bcfb-wnl76                            1/1     Running   0               5m48s
garden                             dependency-watchdog-prober-568dbb4fbb-77bf5                  1/1     Running   0               3m8s
garden                             dependency-watchdog-prober-568dbb4fbb-x4wsh                  1/1     Running   0               3m8s
garden                             dependency-watchdog-weeder-6fc9f48fb5-8t54l                  1/1     Running   0               3m8s
garden                             dependency-watchdog-weeder-6fc9f48fb5-fjbcd                  1/1     Running   0               3m8s
garden                             etcd-druid-7c8f975f84-bdfpq                                  1/1     Running   0               8m16s
garden                             etcd-druid-7c8f975f84-kqb7v                                  1/1     Running   0               8m16s
garden                             fluent-bit-c6dcd-hfztw                                       1/1     Running   0               8m10s
garden                             fluent-operator-8677589677-gt9tp                             1/1     Running   0               8m17s
garden                             fluent-operator-8677589677-vl7lp                             1/1     Running   0               8m17s
garden                             gardener-admission-controller-5d9d9695f5-9hk2t               1/1     Running   0               6m4s
garden                             gardener-admission-controller-5d9d9695f5-gtb77               1/1     Running   0               6m4s
garden                             gardener-apiserver-6fbfbcf954-mz92j                          1/1     Running   2 (6m26s ago)   6m30s
garden                             gardener-apiserver-6fbfbcf954-rx5r5                          1/1     Running   2 (6m26s ago)   6m30s
garden                             gardener-controller-manager-798ff574b9-499pj                 1/1     Running   0               6m5s
garden                             gardener-controller-manager-798ff574b9-sf6dj                 1/1     Running   0               6m5s
garden                             gardener-dashboard-d6c5d494b-765gr                           1/1     Running   0               5m47s
garden                             gardener-dashboard-d6c5d494b-nxsfb                           1/1     Running   0               5m47s
garden                             gardener-discovery-server-7cc9b49c84-79s8l                   1/1     Running   0               6m4s
garden                             gardener-discovery-server-7cc9b49c84-cpmdp                   1/1     Running   0               6m4s
garden                             gardener-extension-admission-calico-6b454b6cb5-5cvv4         1/1     Running   0               3m59s
garden                             gardener-extension-admission-calico-6b454b6cb5-qq4p4         1/1     Running   0               5m1s
garden                             gardener-extension-admission-cilium-858b56485c-xwhbr         1/1     Running   0               5m
garden                             gardener-extension-admission-cilium-858b56485c-zz8zr         1/1     Running   0               3m59s
garden                             gardener-extension-admission-local-6fd4f4fbbb-299pl          1/1     Running   0               4m1s
garden                             gardener-extension-admission-local-6fd4f4fbbb-pgc88          1/1     Running   0               4m59s
garden                             gardener-metrics-exporter-75854446d-xmbsf                    1/1     Running   0               6m5s
garden                             gardener-operator-8c8999b44-sqlfr                            1/1     Running   0               9m16s
garden                             gardener-resource-manager-77d685bdc5-52j28                   1/1     Running   0               8m52s
garden                             gardener-resource-manager-77d685bdc5-88z79                   1/1     Running   0               8m52s
garden                             gardener-scheduler-777577596b-6t8rq                          1/1     Running   0               6m5s
garden                             gardener-scheduler-777577596b-jkvbb                          1/1     Running   0               6m5s
garden                             gardenlet-857ccb8686-k5xwc                                   1/1     Running   0               3m33s
garden                             istio-basic-auth-server-554c776bd-c2htj                      1/1     Running   0               2m4s
garden                             kube-state-metrics-runtime-8d4d876bd-hkspg                   1/1     Running   0               7m33s
garden                             kube-state-metrics-runtime-8d4d876bd-zvlmn                   1/1     Running   0               7m33s
garden                             kube-state-metrics-seed-6cf499bcbc-f6m6f                     1/1     Running   0               3m8s
garden                             kube-state-metrics-seed-6cf499bcbc-v5mhz                     1/1     Running   0               3m8s
garden                             opentelemetry-collector-collector-7c4ff749fd-p2kr6           1/1     Running   0               8m10s
garden                             opentelemetry-operator-6cbcfb6765-czfzv                      1/1     Running   0               8m17s
garden                             opentelemetry-operator-6cbcfb6765-x84br                      1/1     Running   0               8m17s
garden                             perses-operator-cbdbdf7b6-9679q                              1/1     Running   0               8m17s
garden                             plutono-7d48c9cddc-xqv55                                     3/3     Running   0               8m16s
garden                             prometheus-aggregate-0                                       2/2     Running   0               3m3s
garden                             prometheus-cache-0                                           2/2     Running   0               3m7s
garden                             prometheus-garden-0                                          2/2     Running   0               5m47s
garden                             prometheus-garden-1                                          2/2     Running   0               5m47s
garden                             prometheus-longterm-0                                        3/3     Running   0               5m46s
garden                             prometheus-longterm-1                                        3/3     Running   0               5m46s
garden                             prometheus-operator-6b794d8676-vw9qw                         1/1     Running   0               8m17s
garden                             prometheus-seed-0                                            2/2     Running   0               3m5s
garden                             vali-0                                                       2/2     Running   0               8m17s
garden                             victoria-operator-796f494f7-p7w4f                            1/1     Running   0               8m17s
garden                             victoria-operator-796f494f7-x7g26                            1/1     Running   0               8m17s
garden                             virtual-garden-etcd-events-0                                 2/2     Running   0               7m55s
garden                             virtual-garden-etcd-main-0                                   2/2     Running   0               7m55s
garden                             virtual-garden-gardener-resource-manager-85d7d9ff88-qfbqm    1/1     Running   0               7m1s
garden                             virtual-garden-gardener-resource-manager-85d7d9ff88-tpch5    1/1     Running   0               6m48s
garden                             virtual-garden-istio-basic-auth-server-789d546c78-g59w6      1/1     Running   0               5m21s
garden                             virtual-garden-kube-apiserver-5c9f49fc44-6pkf4               1/1     Running   0               7m22s
garden                             virtual-garden-kube-apiserver-5c9f49fc44-fsdsr               1/1     Running   0               7m22s
garden                             virtual-garden-kube-controller-manager-545ff98959-rbcsk      1/1     Running   0               7m6s
garden                             virtual-garden-kube-controller-manager-545ff98959-wg9dg      1/1     Running   0               7m6s
garden                             vlsingle-victoria-logs-6fccf4fdf5-c24cl                      1/1     Running   0               8m11s
garden                             vpa-admission-controller-659684ff5f-45f8w                    1/1     Running   0               8m15s
garden                             vpa-admission-controller-659684ff5f-fkdb6                    1/1     Running   0               8m15s
garden                             vpa-recommender-64cd45597f-4q56g                             1/1     Running   0               8m15s
garden                             vpa-recommender-64cd45597f-xsv5j                             1/1     Running   0               8m15s
garden                             vpa-updater-6dd99b6788-4b82m                                 1/1     Running   0               8m14s
garden                             vpa-updater-6dd99b6788-p7wh4                                 1/1     Running   0               8m14s
istio-ingress-handler-local        istio-ingressgateway-bb449b866-p4wjx                         1/1     Running   0               3m7s
istio-ingress-handler-local        istio-ingressgateway-bb449b866-v62mc                         1/1     Running   0               3m7s
istio-ingress                      istio-ingressgateway-66598bcf74-2f4pb                        1/1     Running   0               3m7s
istio-ingress                      istio-ingressgateway-66598bcf74-2lx9f                        1/1     Running   0               3m7s
istio-system                       istiod-5c46f9d784-gpm97                                      1/1     Running   0               8m16s
istio-system                       istiod-5c46f9d784-z6tpx                                      1/1     Running   0               8m16s
kube-system                        etcd-gardener-local-control-plane                            1/1     Running   0               14m
kube-system                        kube-apiserver-gardener-local-control-plane                  1/1     Running   0               14m
kube-system                        kube-controller-manager-gardener-local-control-plane         1/1     Running   0               14m
kube-system                        kube-scheduler-gardener-local-control-plane                  1/1     Running   0               14m
runtime-extension-provider-local   gardener-extension-provider-local-runtime-7c844f466b-bwjkd   1/1     Running   0               7m1s
runtime-extension-provider-local   gardener-extension-provider-local-runtime-7c844f466b-g57l8   1/1     Running   0               7m1s
virtual-garden-istio-ingress       istio-ingressgateway-d98677557-nb9jr                         1/1     Running   0               8m16s
virtual-garden-istio-ingress       istio-ingressgateway-d98677557-rdvkc                         1/1     Running   0               8m16s
```

`gardener-apiserver` shows 2 restarts. I think it's expected during startup (it comes up before its dependencies are fully ready), stable afterwards with no further restarts.

### Shoot Cluster

Progress snapshot while the `local` Shoot's control plane was still being reconciled (~2m44s after `kubectl apply`, after fixing the wrong-file/wrong-kubeconfig issue in point 3 above):

```
$ export KUBECONFIG=$PWD/dev-setup/kubeconfigs/virtual-garden/kubeconfig
$ kubectl get shoot -A -o wide
NAMESPACE      NAME    CLOUDPROFILE   PROVIDER   REGION   SEED    K8S VERSION   HIBERNATION   LAST OPERATION            STATUS    PURPOSE      GARDENER VERSION   APISERVER   CONTROL       OBSERVABILITY   NODES         SYSTEM        AGE
garden-local   local   local          local      local    local   1.36.0        Awake         Create Processing (75%)   healthy   evaluation   v1.147.0-dev       True        Progressing   Progressing     Progressing   Progressing   2m44s
```

The `Shoot` status has a nice per-component breakdown (`APISERVER`, `CONTROL`, `OBSERVABILITY`, `NODES`, `SYSTEM`). Here the `kube-apiserver` was already `True` while the workers were still `Progressing`.

**Final state** (~7m43s after apply, fully healthy):

```
$ kubectl get shoot -A -o wide
NAMESPACE      NAME    CLOUDPROFILE   PROVIDER   REGION   SEED    K8S VERSION   HIBERNATION   LAST OPERATION            STATUS    PURPOSE      GARDENER VERSION   APISERVER   CONTROL   OBSERVABILITY   NODES   SYSTEM   AGE
garden-local   local   local          local      local    local   1.36.0        Awake         Create Succeeded (100%)   healthy   evaluation   v1.147.0-dev       True        True      True            True    True     7m43s
```

The hosted control plane runs as Pods in namespace `shoot--local--local` on the Seed. This namespace only exists because Gardener put the Shoot's control plane here rather than on separate machines. Kubeception in practice:

```
$ export KUBECONFIG=$PWD/dev-setup/kubeconfigs/runtime/kubeconfig
$ kubectl get pods -n shoot--local--local
NAME                                                 READY   STATUS    RESTARTS   AGE
blackbox-exporter-78bfd94dcc-5lhzn                   1/1     Running   0          96s
blackbox-exporter-78bfd94dcc-wtvvh                   1/1     Running   0          96s
cloud-controller-manager-b88b955-sqzlc               1/1     Running   0          3m26s
cluster-autoscaler-56f4cc7bbb-8nn54                  1/1     Running   0          3m8s
etcd-events-0                                        2/2     Running   0          5m29s
etcd-main-0                                          2/2     Running   0          5m29s
event-logger-74dd895bd5-9pjsq                        1/1     Running   0          3m34s
gardener-resource-manager-5965fbb87-28lbj            1/1     Running   0          3m48s
gardener-resource-manager-5965fbb87-mjwrl            1/1     Running   0          4m
istio-basic-auth-server-ffd65d854-hvm46              1/1     Running   0          70s
kube-apiserver-74d477b5f7-f4mlh                      1/1     Running   0          4m51s
kube-apiserver-74d477b5f7-ttj77                      1/1     Running   0          4m51s
kube-controller-manager-74456fbb4b-xvzz7             1/1     Running   0          3m31s
kube-scheduler-69c84f6b88-b5jfj                      1/1     Running   0          3m32s
kube-state-metrics-775bb96b6c-rrvjl                  1/1     Running   0          94s
machine-controller-manager-5c86897f9-rzv2d           2/2     Running   0          3m13s
machine-shoot--local--local-local-z1-55b4d-42t7x     1/1     Running   0          3m9s
opentelemetry-collector-collector-57f6bb549c-wrx7c   3/3     Running   0          3m34s
plutono-b7c99bfd6-fsgq6                              3/3     Running   0          3m30s
prometheus-shoot-0                                   2/2     Running   0          94s
vali-0                                               2/2     Running   0          5m31s
vlsingle-victoria-logs-655b45c48b-mt8bk              1/1     Running   0          5m31s
vpa-admission-controller-bb84d8dc-g99k9              1/1     Running   0          3m34s
vpa-admission-controller-bb84d8dc-rpgfm              1/1     Running   0          3m33s
vpa-recommender-68ddccfdd4-2k247                     1/1     Running   0          3m33s
vpa-updater-7555bcdfb6-5r7jn                         1/1     Running   0          3m33s
vpn-seed-server-6fb4b85cf7-8vzkt                     2/2     Running   0          3m33s
```

Finally, the actual Shoot cluster, accessed with its own admin kubeconfig (`hack/usage/generate-kubeconfig.sh`, using the `shoots/adminkubeconfig` subresource):

```
$ export KUBECONFIG=$PWD/dev-setup/kubeconfigs/virtual-garden/kubeconfig
$ ./hack/usage/generate-kubeconfig.sh > /tmp/shoot-kubeconfig.yaml
$ KUBECONFIG=/tmp/shoot-kubeconfig.yaml kubectl get nodes -o wide
NAME                                               STATUS   ROLES    AGE     VERSION   INTERNAL-IP    EXTERNAL-IP   OS-IMAGE                                                                                           KERNEL-VERSION           CONTAINER-RUNTIME
machine-shoot--local--local-local-z1-55b4d-42t7x   Ready    worker   2m58s   v1.36.0   10.0.130.192   <none>        Machine Image Version 1.0.0 (version overwritten for tests, check VERSION_ID for actual version)   6.8.0-1057-aws (amd64)   containerd://2.3.1
```

That's the "living, breathing instance" the brief asks for: a Garden, a Seed, and one hosted Shoot control plane with a `Ready` worker node, each backed by the commands and output above.
