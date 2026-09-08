#!/usr/bin/env bash
# Run before executing any candidate code on the host runner.
set -euo pipefail
if [[ $# -ne 4 ]]; then
  echo 'Usage: run_trusted_control_plane.sh TRUSTED_ROOT CANDIDATE_ROOT TRUSTED_SHA NEW_REPORT_DIRECTORY' >&2
  exit 2
fi
trusted_root=$(cd -- "$1" && pwd -P)
candidate_root=$(cd -- "$2" && pwd -P)
trusted_sha=$3
evaluator_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
if [[ ! "$trusted_sha" =~ ^[0-9a-f]{40}$ ]]; then
  echo 'Expected an exact trusted commit SHA' >&2
  exit 2
fi
mkdir -- "$4"
report_root=$(cd -- "$4" && pwd -P)
image_name="control-plane-evaluator:${GITHUB_RUN_ID:-local}"
docker build --quiet --tag "$image_name" \
  --file "$evaluator_root/.github/control-plane/Dockerfile" "$evaluator_root/.github/control-plane"
runner=/trusted/scripts/trusted_control_plane.py
bootstrap_args=()
if [[ ! -f "$trusted_root/scripts/trusted_control_plane.py" ]]; then
  runner=/candidate/scripts/trusted_control_plane.py
fi
if [[ ! -f "$trusted_root/evidence/control-plane/ledger.json" ]]; then
  bootstrap_args=(--bootstrap-ledger)
fi
# No host credentials or Docker socket are mounted. Only /tmp and report output
# are writable; even candidate Python cannot rewrite the mounted trusted oracle.
docker run --rm --network none --read-only --cap-drop ALL \
  --security-opt no-new-privileges --pids-limit 128 --memory 512m --cpus 2 \
  --user "$(id -u):$(id -g)" \
  --tmpfs /tmp:rw,noexec,nosuid,nodev,size=256m,mode=1777 \
  --mount "type=bind,source=$trusted_root,target=/trusted,readonly" \
  --mount "type=bind,source=$candidate_root,target=/candidate,readonly" \
  --mount "type=bind,source=$report_root,target=/reports" \
  "$image_name" python3 -I "$runner" \
  --trusted-root /trusted --trusted-sha "$trusted_sha" --candidate-root /candidate \
  --report /reports/trusted-control-plane.json "${bootstrap_args[@]}"
