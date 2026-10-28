#!/usr/bin/env bash
# Starts a container the way Workavera does and checks what Workavera relies
# on: the user, the workspace, a clean login shell, the tools it advertises to
# the assistant, and CJK text in a matplotlib chart. Needs no network.
#
# Usage: scripts/smoke.sh <image>
set -euo pipefail

image="${1:?usage: scripts/smoke.sh <image>}"
name="workavera-sandbox-smoke-$$"
failures=0

cleanup() { docker rm -f "${name}" >/dev/null 2>&1 || true; }
trap cleanup EXIT

docker run -d \
  --name "${name}" \
  --network none \
  --init \
  --user workavera \
  --workdir /workspace \
  --entrypoint /bin/sh \
  "${image}" -c "sleep 2147483647" >/dev/null

# check <description> <command run under `bash -lc`>
# Passes when the command exits 0 and writes nothing to stderr.
check() {
  local description="$1" command="$2" stdout stderr status
  stderr="$(mktemp)"
  set +e
  stdout="$(docker exec "${name}" bash -lc "${command}" 2>"${stderr}")"
  status=$?
  set -e
  if [[ ${status} -eq 0 && ! -s "${stderr}" ]]; then
    printf 'ok    %s%s\n' "${description}" "${stdout:+  (${stdout//$'\n'/ })}"
  else
    printf 'FAIL  %s (exit %s)\n' "${description}" "${status}"
    sed 's/^/      /' "${stderr}"
    failures=$((failures + 1))
  fi
  rm -f "${stderr}"
}

check "runs as workavera with UID 1000" '[ "$(id -un):$(id -u)" = workavera:1000 ] && id -un'
check "starts in a writable /workspace" '[ "$PWD" = /workspace ] && touch .smoke && rm .smoke && pwd'
check "login shell exits cleanly" 'exit 0'
check "passwordless sudo" 'sudo -n true'
check "node" 'node --version'
check "npm" 'npm --version'
check "pnpm" 'pnpm --version'
check "python is the sandbox venv" '[ "$(command -v python)" = /opt/venv/bin/python ] && python --version'
check "pip installs into the venv" 'pip --version | grep -q /opt/venv && pip --version | cut -d" " -f1-2'
check "uv" 'uv --version'
check "command-line tools" 'for t in git curl jq rg unzip zip xz zstd file ps pkill setsid; do command -v "$t" >/dev/null || { echo "missing $t" >&2; exit 1; }; done'
check "Noto Sans CJK SC installed" 'fc-list :lang=zh family | grep -q "Noto Sans CJK SC"'
check "data stack imports" 'python -c "import matplotlib, numpy, openpyxl, pandas; print(pandas.__version__)"'
check "CJK chart renders without missing glyphs" 'python -W error -c "
import matplotlib
matplotlib.use(\"Agg\")
import matplotlib.pyplot as plt
plt.plot([1, 2, 3], [-1, 0, 1])
plt.title(\"销售趋势 −1\")
plt.savefig(\"/tmp/smoke.png\")
" && file -b /tmp/smoke.png | cut -d, -f1'

if [[ ${failures} -gt 0 ]]; then
  echo "${failures} check(s) failed" >&2
  exit 1
fi
echo "all checks passed"
