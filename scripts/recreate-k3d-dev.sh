#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cluster=dev
expected_context="k3d-${cluster}"

current_context="$(kubectl config current-context)"
if [[ "$current_context" != "$expected_context" ]]; then
  printf 'Refusing to recreate %s: current context is %s, expected %s.\n' \
    "$cluster" "$current_context" "$expected_context" >&2
  exit 1
fi

if ! k3d cluster list --no-headers | awk -v cluster="$cluster" '$1 == cluster { found = 1 } END { exit !found }'; then
  printf 'Refusing to recreate %s: the named k3d cluster does not exist.\n' "$cluster" >&2
  exit 1
fi

printf 'This will delete and recreate only k3d cluster %s.\n' "$cluster"
printf 'Data stored only inside the cluster nodes will be lost; the Mantooth Tasks host data directories will be retained.\n'
read -r -p "Type 'dev' to continue: " confirmation
if [[ "$confirmation" != "$cluster" ]]; then
  printf 'Confirmation did not match; no changes made.\n' >&2
  exit 1
fi

data_root="${HOME}/.local/share/mantooth-tasks"
for path in "$data_root" "${data_root}/dev" "${data_root}/prod"; do
  if [[ -L "$path" ]]; then
    printf 'Refusing to use symlinked storage path: %s\n' "$path" >&2
    exit 1
  fi
done

umask 077
mkdir -p "${data_root}/dev" "${data_root}/prod"
for path in "$data_root" "${data_root}/dev" "${data_root}/prod"; do
  if [[ ! -d "$path" || ! -O "$path" ]]; then
    printf 'Refusing storage path not owned by the current user: %s\n' "$path" >&2
    exit 1
  fi
done
chmod 700 "$data_root" "${data_root}/dev" "${data_root}/prod"

make -C "$repo_root" cluster-delete K3D_CLUSTER=dev
make -C "$repo_root" cluster-up K3D_CLUSTER=dev
