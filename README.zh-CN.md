# Workavera Sandbox

[English](./README.md)

[Workavera](https://github.com/xusenlin/workavera)（一个自托管的 AI 团队工作区）沙箱所用的容器镜像。用户开启沙箱后，Workavera 用这个镜像启动一个名为 `workavera-<用户 ID>` 的容器，Chat 中的助手在其中执行命令、处理文件。产品设计见 [Sandbox PRD](https://github.com/xusenlin/workavera/blob/main/doc/sandbox-prd.zh-CN.md)。

```text
ghcr.io/xusenlin/workavera-sandbox:<版本>
```

每个版本是一个整数，同时发布 `linux/amd64` 和 `linux/arm64`，只发布一次，不会重新构建。

## 镜像内容

| 类别 | 内容 |
| --- | --- |
| 基础 | Ubuntu 26.04 LTS，`LANG=C.UTF-8`，`TZ=Etc/UTC` |
| Node.js | Node.js 24 LTS、npm 和 pnpm |
| Python | 位于 `/opt/venv` 虚拟环境中的 Python 3，带 uv、NumPy、pandas、DuckDB、matplotlib、openpyxl、python-docx、python-pptx 和 pypdf |
| 文档 | pandoc（Markdown、HTML、docx、epub 互相转换）、Typst（PDF 排版）、Poppler（`pdftotext`、`pdftoppm`、`pdfimages`）和 qpdf |
| OCR | Tesseract（`chi_sim`、`chi_tra`、`eng`），以及给扫描版 PDF 加文字层的 OCRmyPDF |
| 数据与图表 | DuckDB 命令行（用 SQL 查询 CSV、Parquet、JSON）和 Graphviz（`dot`） |
| 命令行工具 | git、curl、ca-certificates、jq、ripgrep、unzip、zip、xz、zstd、file、procps、sudo |
| 字体 | Noto Sans CJK（`fonts-noto-cjk`），也是 matplotlib 的默认字体 |

- `/opt/venv` 归沙箱用户所有，并排在 `PATH` 最前面，所以 `python`、`pip` 和 `uv pip` 安装包时不需要 `sudo`，也不会遇到 Ubuntu 对系统 Python 的 PEP 668 限制。
- npm 的全局包安装在 `~/.local` 下，同样不需要 `sudo`。
- 预装数据、文档和 OCR 工具，是因为沙箱可能处于离线状态，此时什么都装不了。
- Typst 和 DuckDB 命令行取自各自的发布包，和 Node.js、uv 一样，用 GitHub 公布的 SHA-256 校验。
- 为控制镜像体积，不包含 LibreOffice、浏览器和 ffmpeg；任务需要时用 `sudo apt-get` 安装。
- matplotlib 默认使用 Noto Sans CJK SC，图表中的中文能正常显示，不会变成方框。
- 不包含 Go；需要时用 `sudo apt-get` 安装。

## Workavera 依赖的约定

Workavera 的代码依赖以下几点。修改其中任何一项，都需要 Workavera 同步修改，并与新版本一起发布：

- 用户 `workavera`，UID 1000，免密 `sudo`，主目录中没有 `.bash_logout`。Workavera 通过不带 TTY 的 `bash -lc` 执行所有命令，此时 Ubuntu 的 `.bash_logout` 会打印 `TERM` 警告，并把成功的退出码改成 1。
- 归 `workavera` 所有的 `/workspace`。Workavera 把用户的命名数据卷挂载在这里，Docker 会把这个属主复制到新建的数据卷上。
- `bash`、`procps`（`ps`、`pkill`）和 `setsid`，Workavera 用它们让命令在独立的进程组中运行，并在需要时终止。
- 标签 `org.workavera.sandbox.tools`：用简短的英文描述上表中的工具和字体。Workavera 用 `docker image inspect` 读取它（不需要启动容器），并写进给助手的系统提示，所以安装的工具变化时，这个标签也必须同步修改。为 Workavera 自建的镜像也可以设置同样的标签；没有这个标签时，Workavera 会让助手在使用某个工具前先确认它存在。

入口点、用户、工作目录、网络和资源限制都由 Workavera 在创建容器时设置，所以镜像除了上面的默认值外不定义这些内容。

## 开发

需要：带 Buildx 的 Docker，以及 [Task](https://taskfile.dev/) 3 或更高版本。

```bash
task build   # 为本机平台构建 <镜像>:<版本>
task test    # 构建后用 scripts/smoke.sh 测试镜像
task push    # 构建 linux/amd64 和 linux/arm64 并推送该版本
```

`task test` 以和 Workavera 相同的参数、在断网状态下启动容器，检查用户、工作区、干净退出的登录 shell、标签中声明的每个工具、带中文标题的 matplotlib 图表、Typst 生成的中文 PDF、Tesseract 和 OCRmyPDF 对这段文字的识别、DuckDB 查询、pandoc 生成的 docx，以及 Graphviz 绘图。

本地构建的镜像和发布的镜像同名，同一台机器上的 Workavera 会直接使用它而不拉取。发布之前就是用这种方式试用改动。

## 版本与发布

`VERSION` 记录正在开发的版本，而不是上一个已发布的版本；发布之前，`CHANGELOG.md` 把改动记在 `[Unreleased]` 下。

- `task push` 拒绝推送已经发布过的版本。
- ghcr.io 上新建的 package 首次推送后是私有的。需要在 GitHub 的 package 设置中把可见性改为公开一次，否则其他 Workavera 服务器无法拉取。
- Workavera 只通过 `sandbox.image` 设置使用某个版本。服务端发布新版本时，用迁移把默认值改到新版本，管理员自己设置的值保持不变。镜像必须先于引用它的服务端版本推送。
- 已有的容器会继续使用原来的镜像，直到用户在 Workavera 的 Settings 中重建。

## 许可证

Apache License 2.0，见 [LICENSE](./LICENSE)。
