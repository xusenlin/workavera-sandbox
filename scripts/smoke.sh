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

# Workavera passes this label to the assistant, so it has to name what the
# checks below find installed.
tools_label="$(docker image inspect --format '{{index .Config.Labels "org.workavera.sandbox.tools"}}' "${image}")"
missing_from_label=""
for item in "Node.js 24" pnpm /opt/venv uv numpy pandas duckdb matplotlib openpyxl python-docx python-pptx pypdf pandoc typst poppler-utils qpdf tesseract chi_sim ocrmypdf graphviz git ripgrep "Noto Sans CJK"; do
  [[ "${tools_label}" == *"${item}"* ]] || missing_from_label+=" ${item}"
done
if [[ -z "${tools_label}" ]]; then
  echo "FAIL  org.workavera.sandbox.tools label is missing"
  failures=$((failures + 1))
elif [[ -n "${missing_from_label}" ]]; then
  echo "FAIL  org.workavera.sandbox.tools label omits:${missing_from_label}"
  failures=$((failures + 1))
else
  echo "ok    org.workavera.sandbox.tools label names the installed tools"
fi

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
check "document, OCR, and data tools" 'for t in pandoc typst pdftotext pdftoppm pdfimages qpdf tesseract ocrmypdf duckdb dot; do command -v "$t" >/dev/null || { echo "missing $t" >&2; exit 1; }; done'
check "Noto Sans CJK SC installed" 'fc-list :lang=zh family | grep -q "Noto Sans CJK SC"'
check "data stack imports" 'python -c "import matplotlib, numpy, openpyxl, pandas; print(pandas.__version__)"'
check "Python document and data libraries import" 'python -c "import docx, duckdb, pptx, pypdf; print(duckdb.__version__)"'
check "tesseract reads Chinese" 'tesseract --list-langs 2>/dev/null | grep -qx chi_sim && tesseract --list-langs 2>/dev/null | grep -qx chi_tra && echo chi_sim chi_tra'
check "typst typesets Chinese into a PDF" 'cd /tmp && printf "%s\n" "#set page(width: 12cm, height: auto, margin: 1cm)" "#set text(font: \"Noto Sans CJK SC\", size: 28pt)" "季度销售报告" >smoke.typ && typst compile smoke.typ smoke.pdf && pdftotext smoke.pdf - | grep -q 季度销售报告 && qpdf --check smoke.pdf >/dev/null && echo smoke.pdf'
# OCR reads a short paragraph at body size, rendered by Typst and rasterized
# by Poppler the way a scanner would produce it: opaque, at 300 dpi.
check "OCR recognizes rendered Chinese text" 'cd /tmp && printf "%s\n" "#set page(width: 16cm, height: auto, margin: 1.5cm, fill: white)" "#set text(font: \"Noto Sans CJK SC\", size: 12pt)" "第三季度销售报告" "" "本季度华东地区销售额同比增长百分之十二，主要来自新客户的采购订单。" >ocr.typ && typst compile ocr.typ ocr.pdf && pdftoppm -r 300 -png -singlefile ocr.pdf ocr && tesseract ocr.png - -l chi_sim 2>/dev/null | tr -d " \n" | grep -q 销售额同比增长 && echo 销售额同比增长'
check "ocrmypdf adds a text layer to a scan" 'cd /tmp && ocrmypdf -q -l chi_sim --image-dpi 300 ocr.png scan.pdf 2>ocr.log || { cat ocr.log >&2; exit 1; }; pdftotext scan.pdf - | tr -d " \n" | grep -q 销售额同比增长 && echo scan.pdf'
check "duckdb queries a CSV" 'cd /tmp && printf "a,b\n1,2\n3,4\n" >smoke.csv && q=$'"'"'\x27'"'"' && [ "$(duckdb -noheader -csv -c "select sum(b) from ${q}smoke.csv${q}")" = 6 ] && echo 6'
check "pandoc writes docx" 'printf "# 标题\n\n正文\n" | pandoc -f markdown -o /tmp/smoke.docx && file -b /tmp/smoke.docx | cut -d" " -f1-3'
check "graphviz renders" 'echo "digraph { a -> b }" | dot -Tpng -o /tmp/smoke-graph.png && file -b /tmp/smoke-graph.png | cut -d, -f1'
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
