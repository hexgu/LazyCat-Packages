# LazyCat Application Repository
# 重要提示：
# 写任何代码前必须完整阅读 @lzc-developer-doc/docs/spec（包含完整规范列表）
# 写任何代码前必须完整阅读 @lzc-developer-doc/docs 下的 advanced 文档（包含高级技巧）
## Project Overview
This repository serves as a workspace for **LazyCat (lzc)** application definitions and developer documentation. It contains:
1.  **Application Packages**: Directories defining apps ported to the LazyCat platform (e.g., `Certimate`, `DDNS-GO`, `lobehub`).
2.  **Documentation**: The `lzc-developer-doc` directory contains the official developer guide and API references.
3.  **Porting Guides**: Resources for converting standard Docker/Compose applications into LazyCat `.lpk` packages.

## Key Concepts
*   **LazyCat (Lzc)**: A microservices platform allowing developers to build, package, and deploy applications easily.
*   **`.lpk`**: The executable package format for LazyCat applications.
*   **Manifest (`lzc-manifest.yml`)**: The central configuration file defining an application's metadata, services, networking, and storage.
*   **Build Config (`lzc-build.yml`)**: Configuration for the `lzc-cli` to package the application.

## Directory Structure
```
/
├── AGENTS.md               # Guide for AI Agents on porting Docker apps to Lzc
├── lzc-developer-doc/      # Source code for LazyCat Developer Documentation
├── Certimate/              # Example Application Directory
│   ├── lzc-manifest.yml    # App definition
│   ├── lzc-build.yml       # Build configuration
│   └── icon.png            # App icon
├── DDNS-GO/                # ... other applications
└── ...
```

## Development Workflow

### 1. Porting an App (Docker -> LazyCat)
Refer to **`AGENTS.md`** for detailed rules. Key mapping principles:

*   **Volumes**: Host paths must be mapped to specific LazyCat persistent directories.
    *   Docker: `$HOME/data:/data`
    *   LazyCat: `/lzcapp/var/data:/data` (Persistent) or `/lzcapp/cache/...` (Cache)
*   **Networking**:
    *   **HTTP/HTTPS (80/443)**: Map via `application.routes`.
        *   Format: `/<Path>=<Protocol>://<ServiceName>:<InternalPort>`
    *   **TCP/UDP (e.g., SSH 22)**: Map via `application.ingress`.
*   **Service Naming**: Services **cannot** be named `app`.
*   **Environment**: Use `${LAZYCAT_BOX_DOMAIN}` for internal domain references.

### 2. Building an App
Run the following command inside an application directory (containing `lzc-build.yml`):
```bash
lzc-cli project build
```
*Output*: A `.lpk` file (e.g., `cloud.lazycat.app.example-v1.0.0.lpk`).

### 3. Installing & Testing
Deploy the built package to a connected LazyCat device:
```bash
lzc-cli app install ./path/to/app.lpk
```

## Essential CLI Commands (`lzc-cli`)

| Category | Command | Description |
| :--- | :--- | :--- |
| **Project** | `lzc-cli project build` | Build the current project into an `.lpk` file. |
| | `lzc-cli project create <name>` | Create a new LazyCat application template. |
| **App** | `lzc-cli app install <path>` | Install a local or remote package. |
| | `lzc-cli app status <pkgId>` | Check the status of an installed app. |
| | `lzc-cli app log <pkgId>` | View application logs (crucial for debugging). |
| **Config** | `lzc-cli config set <key> <val>` | Modify CLI configuration. |

## Documentation
*   **Introduction**: `lzc-developer-doc/docs/introduction.md`
*   **Manifest Specification**: `lzc-developer-doc/docs/spec/manifest.md`
*   **Build Specification**: `lzc-developer-doc/docs/spec/build.md`
