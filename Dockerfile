# syntax=docker/dockerfile:1.7

# The Workavera sandbox image. Workavera starts one container per user from it
# and runs every command through `docker exec`; README.md lists what Workavera
# relies on here. A published tag is never rebuilt, so any change to this file
# ships under a new tag.
#
# The base image, Node.js, and uv are pinned so a change is reviewable; apt and
# Python packages resolve when a tag is first built.
FROM ubuntu:26.04@sha256:0e73b71479e7bc5f006bca872e25c3cd680dc052a0116f90d63ae363537db0dd

ARG DEBIAN_FRONTEND=noninteractive
ARG NODE_VERSION=24.22.1
ARG NODE_SHA256_X64=6c172a9ab6718f7b801fb5a7bd486af2ee5e32758086a04b84fcce2aa77095e6
ARG NODE_SHA256_ARM64=dbabf7a1cbf947e6059ffad2c27b80041db97dea1e553b62afdee7f13fca336e
ARG UV_VERSION=0.13.6
ARG UV_SHA256_X64=f29c3e94ffabd7e6f3ba521dba169a9b7ec12100bf3257087f0f24f6123f3645
ARG UV_SHA256_ARM64=229e194255c7958d86d56e8790d969a6f74736592133f0dfd0076f754c642c1d
ARG PNPM_VERSION=12.15.0
ARG TYPST_VERSION=0.15.1
ARG TYPST_SHA256_X64=a6d077d0a95eed5a2eba715b2dae06be954f624ccbf85758a03f389ded33118c
ARG TYPST_SHA256_ARM64=5aa8d74a3d906e60ea12a66ac2f37f8eef1b14cbad7182a745e393a10c23dcee
ARG DUCKDB_VERSION=2.0.0
ARG DUCKDB_SHA256_X64=c6507206baf7793c6013dbd82368469a45f20dc0e17a6f92f204602f652ed2bc
ARG DUCKDB_SHA256_ARM64=859e1875d2a9515fbb4bf8871061437a14af82320da68c753f094c4b776348fe

LABEL org.opencontainers.image.title="workavera-sandbox" \
      org.opencontainers.image.description="Per-user sandbox image for Workavera." \
      org.opencontainers.image.source="https://github.com/xusenlin/workavera-sandbox" \
      org.opencontainers.image.licenses="Apache-2.0"

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

ENV LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    TZ=Etc/UTC

RUN set -eux; \
  apt-get update; \
  apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    file \
    fontconfig \
    fonts-noto-cjk \
    git \
    graphviz \
    jq \
    ocrmypdf \
    pandoc \
    poppler-utils \
    procps \
    python3 \
    python3-venv \
    python-is-python3 \
    qpdf \
    ripgrep \
    sudo \
    tesseract-ocr \
    tesseract-ocr-chi-sim \
    tesseract-ocr-chi-tra \
    tesseract-ocr-eng \
    unzip \
    xz-utils \
    zip \
    zstd; \
  rm -rf /var/lib/apt/lists/*

# Release tarballs are unpacked with Python's tarfile rather than GNU tar,
# whose extraction fails with "Function not implemented" when the amd64 image
# is built under emulation on an arm64 machine, as `task push` does on a Mac.
RUN printf '%s\n' \
    '#!/usr/bin/python3' \
    'import sys, tarfile' \
    'tarfile.open(sys.argv[1]).extractall(sys.argv[2], filter="data")' \
    >/usr/local/sbin/untar; \
  chmod 0755 /usr/local/sbin/untar

# Node.js from the official release tarball, checked against its published
# SHA-256, plus a pinned pnpm. pnpm is installed rather than left to corepack,
# which would download it on first use and fail in an offline sandbox.
RUN set -eux; \
  arch="$(dpkg --print-architecture)"; \
  case "${arch}" in \
    amd64) node_arch="x64"; node_sha256="${NODE_SHA256_X64}" ;; \
    arm64) node_arch="arm64"; node_sha256="${NODE_SHA256_ARM64}" ;; \
    *) echo "unsupported architecture: ${arch}" >&2; exit 1 ;; \
  esac; \
  node_file="node-v${NODE_VERSION}-linux-${node_arch}.tar.xz"; \
  curl -fsSLO "https://nodejs.org/dist/v${NODE_VERSION}/${node_file}"; \
  echo "${node_sha256}  ${node_file}" | sha256sum -c -; \
  untar "${node_file}" /tmp/node; \
  node_dir="/tmp/node/node-v${NODE_VERSION}-linux-${node_arch}"; \
  cp -a "${node_dir}/bin" "${node_dir}/lib" /usr/local/; \
  rm -rf "${node_file}" /tmp/node /usr/local/lib/node_modules/npm/docs /usr/local/lib/node_modules/npm/man; \
  # Node's release binary keeps about 20 MB of native symbols, used only to
  # name native frames in crash reports and profiles. binutils is needed for
  # strip alone and leaves with this layer.
  apt-get update; \
  apt-get install -y --no-install-recommends binutils; \
  strip --strip-unneeded /usr/local/bin/node; \
  apt-get purge -y --auto-remove binutils; \
  rm -rf /var/lib/apt/lists/*; \
  npm install -g "pnpm@${PNPM_VERSION}"; \
  npm cache clean --force; \
  node --version; npm --version; pnpm --version

# Typst and the DuckDB CLI from their release archives, checked against the
# SHA-256 digests GitHub publishes for them. Typst is a static musl binary.
RUN set -eux; \
  arch="$(dpkg --print-architecture)"; \
  case "${arch}" in \
    amd64) typst_arch="x86_64"; typst_sha256="${TYPST_SHA256_X64}"; duckdb_sha256="${DUCKDB_SHA256_X64}" ;; \
    arm64) typst_arch="aarch64"; typst_sha256="${TYPST_SHA256_ARM64}"; duckdb_sha256="${DUCKDB_SHA256_ARM64}" ;; \
    *) echo "unsupported architecture: ${arch}" >&2; exit 1 ;; \
  esac; \
  typst_file="typst-${typst_arch}-unknown-linux-musl.tar.xz"; \
  curl -fsSLO "https://github.com/typst/typst/releases/download/v${TYPST_VERSION}/${typst_file}"; \
  echo "${typst_sha256}  ${typst_file}" | sha256sum -c -; \
  untar "${typst_file}" /tmp/typst; \
  install -m 0755 "/tmp/typst/typst-${typst_arch}-unknown-linux-musl/typst" /usr/local/bin/; \
  duckdb_file="duckdb-cli-linux-${arch}.tar.gz"; \
  curl -fsSLO "https://github.com/duckdb/duckdb/releases/download/v${DUCKDB_VERSION}/${duckdb_file}"; \
  echo "${duckdb_sha256}  ${duckdb_file}" | sha256sum -c -; \
  untar "${duckdb_file}" /tmp/duckdb; \
  install -m 0755 /tmp/duckdb/duckdb /usr/local/bin/; \
  rm -rf "${typst_file}" "${duckdb_file}" /tmp/typst /tmp/duckdb; \
  typst --version; duckdb --version

# uv from its release tarball, checked the same way.
RUN set -eux; \
  arch="$(dpkg --print-architecture)"; \
  case "${arch}" in \
    amd64) uv_arch="x86_64"; uv_sha256="${UV_SHA256_X64}" ;; \
    arm64) uv_arch="aarch64"; uv_sha256="${UV_SHA256_ARM64}" ;; \
    *) echo "unsupported architecture: ${arch}" >&2; exit 1 ;; \
  esac; \
  uv_file="uv-${uv_arch}-unknown-linux-gnu.tar.gz"; \
  curl -fsSLO "https://github.com/astral-sh/uv/releases/download/${UV_VERSION}/${uv_file}"; \
  echo "${uv_sha256}  ${uv_file}" | sha256sum -c -; \
  untar "${uv_file}" /tmp/uv; \
  install -m 0755 "/tmp/uv/uv-${uv_arch}-unknown-linux-gnu/uv" "/tmp/uv/uv-${uv_arch}-unknown-linux-gnu/uvx" /usr/local/bin/; \
  rm -rf "${uv_file}" /tmp/uv /usr/local/sbin/untar; \
  uv --version

# The sandbox user. Ubuntu images ship an `ubuntu` user on UID 1000; it is
# replaced so Workavera's user owns that UID.
RUN set -eux; \
  if id -u ubuntu >/dev/null 2>&1; then userdel --remove ubuntu; fi; \
  useradd --create-home --uid 1000 --shell /bin/bash workavera; \
  # Ubuntu's skel .bash_logout runs clear_console when a login shell exits.
  # Workavera runs commands through `bash -lc` without a TTY, where it prints
  # "TERM environment variable not set." and turns `exit 0` into exit 1.
  rm -f /home/workavera/.bash_logout; \
  install -d --owner=workavera --group=workavera \
    /workspace \
    /opt/venv \
    /home/workavera/.local \
    /home/workavera/.local/bin \
    /home/workavera/.config/matplotlib; \
  # !fqdn: the sandbox hostname does not resolve, so sudo would warn on stderr.
  printf '%s\n' \
    'Defaults !fqdn' \
    'workavera ALL=(ALL) NOPASSWD:ALL' \
    >/etc/sudoers.d/workavera; \
  chmod 0440 /etc/sudoers.d/workavera; \
  visudo -cf /etc/sudoers.d/workavera

USER workavera

# Ubuntu's system Python refuses `pip install` (PEP 668). A venv owned by the
# sandbox user comes first on PATH, so `python`, `pip`, and `uv pip` install
# into it without sudo, and a small data stack works even while offline.
ENV VIRTUAL_ENV=/opt/venv \
    NPM_CONFIG_PREFIX=/home/workavera/.local \
    PATH=/opt/venv/bin:/home/workavera/.local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

RUN set -eux; \
  uv venv --seed /opt/venv; \
  uv pip install --no-cache numpy pandas duckdb matplotlib openpyxl python-docx python-pptx pypdf; \
  # Chinese text in charts renders as boxes unless matplotlib falls back to a
  # CJK font, and a CJK font's minus sign would otherwise be missing.
  printf '%s\n' \
    'font.family: sans-serif' \
    'font.sans-serif: Noto Sans CJK SC, DejaVu Sans' \
    'axes.unicode_minus: False' \
    >/home/workavera/.config/matplotlib/matplotlibrc; \
  python -c 'import docx, duckdb, matplotlib, numpy, openpyxl, pandas, pptx, pypdf'

WORKDIR /workspace

# Workavera reads this label with `docker image inspect` and passes it to the
# assistant in its system prompt, so it must match what this file installs.
# It comes last so that editing it does not rebuild the layers above.
LABEL org.workavera.sandbox.tools="Node.js 24 with npm and pnpm; Python 3 in a venv at /opt/venv (pip and uv install into it) with numpy, pandas, duckdb, matplotlib, openpyxl, python-docx, python-pptx, and pypdf; documents: pandoc (Markdown, HTML, docx, epub conversion), typst (PDF typesetting), poppler-utils (pdftotext, pdftoppm, pdfimages), and qpdf; OCR: tesseract with chi_sim, chi_tra, and eng, and ocrmypdf to add a text layer to scanned PDFs; duckdb CLI for SQL over CSV, Parquet, and JSON; graphviz (dot); git, curl, jq, ripgrep, zip, unzip, xz, zstd, and file; Noto Sans CJK fonts, which matplotlib uses by default (name Noto Sans CJK SC elsewhere for Chinese text)."
