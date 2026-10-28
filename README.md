# Workavera Sandbox

The container image behind the sandbox of
[Workavera](https://github.com/xusenlin/workavera), a self-hosted AI team
workspace. When a user turns the sandbox on, Workavera starts a container named
`workavera-<user ID>` from this image, and the Chat assistant runs commands and
works with files inside it. The product design is in the
[Sandbox PRD](https://github.com/xusenlin/workavera/blob/main/doc/sandbox-prd.md).

```text
ghcr.io/xusenlin/workavera-sandbox:<version>
```

Each version is a whole number, published once for `linux/amd64` and
`linux/arm64` and never rebuilt.

## What is inside

| Kind | Contents |
| --- | --- |
| Base | Ubuntu 26.04 LTS, `LANG=C.UTF-8`, `TZ=Etc/UTC` |
| Node.js | Node.js 24 LTS, npm, and pnpm |
| Python | Python 3 in a virtual environment at `/opt/venv`, with uv, NumPy, pandas, matplotlib, and openpyxl |
| Command-line tools | git, curl, ca-certificates, jq, ripgrep, unzip, zip, xz, zstd, file, procps, sudo |
| Fonts | Noto Sans CJK (`fonts-noto-cjk`), the default font of matplotlib |

- `/opt/venv` belongs to the sandbox user and comes first on `PATH`, so
  `python`, `pip`, and `uv pip` install packages without `sudo` and without
  running into Ubuntu's PEP 668 block on the system Python.
- npm installs global packages under `~/.local`, also without `sudo`.
- The NumPy, pandas, matplotlib, and openpyxl data stack is preinstalled
  because a sandbox can be offline, where nothing can be installed.
- matplotlib defaults to Noto Sans CJK SC, so Chinese text in charts renders
  instead of showing boxes.
- Go is not included; install it with `sudo apt-get` when needed.

## What Workavera relies on

Workavera's code depends on the following. Changing any of them needs a
matching change in Workavera, released together with the new tag:

- The user `workavera` with UID 1000, passwordless `sudo`, and a home directory
  without `.bash_logout`. Workavera runs every command through `bash -lc`
  without a TTY, where Ubuntu's `.bash_logout` prints a `TERM` warning and turns
  a successful exit into exit 1.
- `/workspace`, owned by `workavera`. Workavera mounts the user's named volume
  there, and Docker copies this ownership into a new volume.
- `bash`, `procps` (`ps`, `pkill`), and `setsid`, which Workavera uses to run
  commands in their own process group and to stop them.
- The tools and fonts in the table above, which Workavera lists to the
  assistant in its system prompt.

Workavera sets the entrypoint, user, working directory, network, and limits
itself when it creates a container, so the image defines none of them beyond
the defaults above.

## Development

Requirements: Docker with Buildx and [Task](https://taskfile.dev/) 3+.

```bash
task build   # build <image>:<version> for this machine's platform
task test    # build, then run scripts/smoke.sh against the image
task push    # build for linux/amd64 and linux/arm64 and push the tag
```

`task test` starts a container with the same arguments Workavera uses, without
network access, and checks the user, the workspace, a clean login shell, every
advertised tool, and a matplotlib chart with a Chinese title.

A locally built image carries the same name as the published one, so a
Workavera on the same machine uses it without pulling anything. That is the way
to try a change before publishing it.

## Versions and releases

`VERSION` holds the tag being developed, never the last one published, and
`CHANGELOG.md` records changes under `[Unreleased]` until a release.

- `task push` refuses to push a tag that is already published.
- A new package on ghcr.io is private after its first push. Set its visibility
  to public once, in the package settings on GitHub, or Workavera servers
  cannot pull it.
- Workavera picks a tag up only through its `sandbox.image` setting. A server
  release moves the default to a new tag in a migration, which leaves an
  administrator's own value alone. Push the image before releasing the server
  version that points at it.
- Existing containers keep their image until their user rebuilds them from
  Workavera's Settings.

## License

Apache License 2.0. See [LICENSE](./LICENSE).
