# Changelog

All notable changes to the Workavera sandbox image are documented in this file.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
Versions are whole numbers, each published once as an image tag and never
rebuilt.

Server-side changes are recorded separately, in the
[Workavera changelog](https://github.com/xusenlin/workavera/blob/main/CHANGELOG.md).

## [Unreleased]

## [1] - 2026-10-28

### Added

- The first sandbox image: Ubuntu 26.04 with Node.js 24, npm, and pnpm;
  Python 3 in a user-owned virtual environment with uv, NumPy, pandas,
  matplotlib, and openpyxl; git, curl, jq, ripgrep, and archive tools; and
  Noto Sans CJK fonts, which matplotlib uses by default so Chinese text in
  charts renders. Commands run as the `workavera` user (UID 1000) in
  `/workspace`, with passwordless `sudo`. Published for `linux/amd64` and
  `linux/arm64`.

[Unreleased]: https://github.com/xusenlin/workavera-sandbox/compare/v1...HEAD
[1]: https://github.com/xusenlin/workavera-sandbox/releases/tag/v1
