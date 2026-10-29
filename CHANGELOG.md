# Changelog

All notable changes to the Workavera sandbox image are documented in this file.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
Versions are whole numbers, each published once as an image tag and never
rebuilt.

Server-side changes are recorded separately, in the
[Workavera changelog](https://github.com/xusenlin/workavera/blob/main/CHANGELOG.md).

## [Unreleased]

## [3] - 2026-10-29

### Added

- Document, OCR, and data tools: pandoc, Typst, Poppler, and qpdf for
  converting and typesetting documents and handling PDFs; Tesseract with
  Simplified Chinese, Traditional Chinese, and English, and OCRmyPDF to add
  a text layer to scanned PDFs; the DuckDB CLI and Graphviz; and DuckDB,
  python-docx, python-pptx, and pypdf in `/opt/venv`. The
  `org.workavera.sandbox.tools` label names them, and the smoke test checks
  a Chinese round trip from Typst through OCR.

## [2] - 2026-10-28

### Added

- The `org.workavera.sandbox.tools` label describes the installed tools and
  fonts, so Workavera can tell the assistant what the sandbox offers, and an
  image built elsewhere can describe its own.

## [1] - 2026-10-28

### Added

- The first sandbox image: Ubuntu 26.04 with Node.js 24, npm, and pnpm;
  Python 3 in a user-owned virtual environment with uv, NumPy, pandas,
  matplotlib, and openpyxl; git, curl, jq, ripgrep, and archive tools; and
  Noto Sans CJK fonts, which matplotlib uses by default so Chinese text in
  charts renders. Commands run as the `workavera` user (UID 1000) in
  `/workspace`, with passwordless `sudo`. Published for `linux/amd64` and
  `linux/arm64`.

[Unreleased]: https://github.com/xusenlin/workavera-sandbox/compare/v3...HEAD
[3]: https://github.com/xusenlin/workavera-sandbox/compare/v2...v3
[2]: https://github.com/xusenlin/workavera-sandbox/compare/v1...v2
[1]: https://github.com/xusenlin/workavera-sandbox/releases/tag/v1
