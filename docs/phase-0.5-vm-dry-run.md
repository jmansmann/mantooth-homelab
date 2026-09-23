# Phase 0.5 — VM Dry Run on the Mac

Rehearse Phase 1 **before buying hardware**. Stand up a 3-node Ubuntu + kubeadm cluster in VMs on the Mac, with real virtual disks, so you can develop the Ansible baseline and debug kubeadm, kube-vip, Cilium, and Longhorn where mistakes cost minutes instead of a drive wipe.

> **Architecture caveat:** these VMs are **arm64** (the real cluster is amd64). Everything used here — containerd, kubelet, kubeadm, Cilium, Longhorn — is multi-arch, and your images are built multi-arch (ADR-004). The mechanics are identical; only the CPU arch differs.

## 1. Tooling

```bash
brew install lima
limactl --version
```

Lima runs Ubuntu VMs with the host (arm64) architecture and supports extra disks.

## 2. VM definition

Create `node.yaml` (one template, three instances):

```yaml
vmType: vz
arch: aarch64
cpus: 2
memory: "4GiB"
disk: "40GiB"
images:
  - location: "https://cloud-images.ubuntu.com/releases/24.04/release/ubuntu-24.04-server-cloudimg-arm64.img"
    arch: aarch64
mounts: []
additionalDisks:
  - name: "data"
    size: "20GiB"
```

> If `additionalDisks` is rejected by your Lima version, either bump Lima or set `vmType: qemu`. Verify the schema against `limactl` docs for your version.

Create the three nodes:

```bash
for n in 1 2 3; do limactl start --name="node$n" ./node.yaml; done
limactl list
```

Inside each node the disk appears as a second block device (`lsblk` — e.g. `/dev/vdb`).

**Resource note:** 3 × 4 GiB = 12 GiB on a 32 GB Mac — comfortable. Bump to 6 GiB each if you have headroom.

## 3. What to rehearse

Work through these in order. The first two are the actual Phase 1 work; do them on the VMs first.

1. **OS baseline via Ansible** — develop the `mantooth-ansible` playbooks here: users/SSH, time sync, swap off, kernel modules (`overlay`, `br_netfilter`), sysctl (`ip_forward`, bridge-nf-call-iptables), containerd, `kubeadm`/`kubelet`/`kubectl`.
2. **Prep the data disk** — partition the second disk, create LVM (`vg0` → `lv_longhorn`), format, mount at `/var/lib/longhorn`, and install `open-iscsi` (required by Longhorn). This is the exact procedure to reuse on the NVMe in Phase 1.
3. **Control plane** — install **kube-vip** for the API VIP, then `kubeadm init --control-plane-endpoint=<VIP>` with `--upload-certs`; join the other two as control planes. Verify etcd quorum (`kubectl -n kube-system exec etcd-node1 -- etcdctl member list`).
4. **CNI** — install **Cilium**. Nodes should go `Ready`.
5. **Storage** — install **Longhorn**, register the `/var/lib/longhorn` path as a node disk, create a 3-replica volume, and confirm replicas land on all three nodes (`kubectl -n longhorn-system get replicas.longhorn.io`).
6. **Failure drill** — stop one VM (`limactl stop node3`). Watch Longhorn rebuild replicas and etcd stay healthy (quorum 2/3). Restart it and confirm recovery. This is the payoff of the disk mock.

## 4. Exit criteria

Before moving to Phase 1, you should have:

- Ansible playbooks that turn a fresh Ubuntu VM into a ready k8s node, committed to `mantooth-ansible`.
- A reproducible disk/LVM/`open-iscsi` procedure for Longhorn.
- A working 3-node HA cluster (`kubeadm`, kube-vip, Cilium, Longhorn).
- Evidence of surviving a one-node failure.

Then Phase 1 is mostly "do the same thing on real metal," with the known-good artifacts already in hand.