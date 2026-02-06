# Agents.md - Docker to Lazy Cat Porting Guide

本指南用于指导 AI Agent 将现有的 Docker 镜像 (`docker run`) 或 Docker Compose 应用 (`docker-compose.yml`) 移植到懒猫微服平台 (`.lpk`)。

# 重要提示：
# 写任何代码前必须完整阅读 @lzc-developer-doc/docs/spec（包含完整规范列表）
# 写任何代码前必须完整阅读 @lzc-developer-doc/docs 下的 advanced 文档（包含高级技巧）

## 1. 核心规范参考 (Core Specifications)

* **Manifest 配置**: @lzc-developer-doc/docs/spec/manifest.md
* **构建配置**: @lzc-developer-doc/docs/spec/build.md
* **移植示例教程**: @lzc-developer-doc/docs/app-example-porting.md
* **CLI 参考**: 见本文档第 5 节 (基于 lzc-cli help 输出)

---

## 2. 映射逻辑详解 (Mapping Logic)

将 Docker 参数转换为 `lzc-manifest.yml` 的核心规则如下：

### 2.1 基础字段映射

| Docker / Compose | lzc-manifest.yml | 转换规则与约束 |
| :--- | :--- | :--- |
| `image` | `services.<name>.image` | 直接复制镜像名。 |
| `--env` / `environment` | `services.<name>.environment` | 直接复制。**技巧**: 内部 URL 可使用变量 `${LAZYCAT_BOX_DOMAIN}` 替代硬编码域名。 |
| `--volume` / `volumes` | `services.<name>.binds` | **强制修改**: 宿主机路径（冒号左侧）必须改为 `/lzcapp/var/...` (持久化) 或 `/lzcapp/cache/...`。<br>例: `$HOME/data:/data` &rarr; `/lzcapp/var/data:/data` |
| `depends_on` | `services.<name>.depends_on` | 复制依赖关系，但**严禁**依赖名为 `app` 的服务。 |
| `container_name` | (Key in `services`) | 用作服务名，但**不能**命名为 `app`。 |

### 2.2 网络端口映射 (关键)

懒猫微服不直接使用 `ports` (`-p`)，而是根据协议类型分流：

#### A. HTTP/HTTPS 服务 (网站/API)
* **配置位置**: `application.routes`
* **转换逻辑**: 将 Docker 的 `80/443` 端口映射为内部路由。
* **格式**: `<Path>=<Protocol>://<ServiceName>.<PackageID>.lzcapp:<InternalPort>`
* **示例**:
    ```yaml
    routes:
      # 将 Web 流量转发到 gitlab 容器的 80 端口
      - /=[http://gitlab.cloud.lazycat.app.gitlab.lzcapp:80](http://gitlab.cloud.lazycat.app.gitlab.lzcapp:80)
    ```

#### B. TCP/UDP 服务 (SSH, 数据库等)
* **配置位置**: `application.ingress`
* **转换逻辑**: 非 HTTP 的端口（如 SSH 的 22 端口）需通过 Ingress 暴露。
* **示例**:
    ```yaml
    ingress:
      - protocol: tcp
        port: 22        # 外部访问端口
        service: gitlab # 目标服务名
    ```

---

## 3. 实战案例：GitLab 移植 (Case Study)

以下展示如何将 GitLab 的 `docker run` 命令转换为 `lzc-manifest.yml`。

### 3.1 输入：原始 Docker 命令
```bash
sudo docker run --detach \
  --hostname gitlab.example.com \
  --env GITLAB_OMNIBUS_CONFIG="external_url '[http://gitlab.example.com](http://gitlab.example.com)'" \
  --publish 443:443 --publish 80:80 --publish 22:22 \
  --name gitlab \
  --volume $GITLAB_HOME/config:/etc/gitlab \
  --volume $GITLAB_HOME/logs:/var/log/gitlab \
  --volume $GITLAB_HOME/data:/var/opt/gitlab \
  gitlab/gitlab-ee:17.2.8-ee.0

```

### 3.2 转换过程分析

1. **Volume**: `$GITLAB_HOME` 全部替换为 `/lzcapp/var` 前缀。
2. **Ports**:
* `80/443` -> 识别为 Web 服务 -> 放入 `application.routes`。
* `22` -> 识别为 SSH 服务 -> 放入 `application.ingress`。


3. **Env**: 将 `gitlab.example.com` 替换为动态域名变量 `${LAZYCAT_BOX_DOMAIN}`。

### 3.3 输出：lzc-manifest.yml

```yaml
lzc-sdk-version: '0.1'
name: GitLab
package: cloud.lazycat.app.gitlab
version: 17.2.8-patch1
application:
  subdomain: gitlab
  # 1. 处理 HTTP 端口 (80)
  routes:
    - /=[http://gitlab.cloud.lazycat.app.gitlab.lzcapp:80](http://gitlab.cloud.lazycat.app.gitlab.lzcapp:80)
  # 2. 处理 TCP 端口 (22)
  ingress:
    - protocol: tcp
      port: 22
      service: gitlab
services:
  # 3. 定义服务 (注意：名字不能是 app)
  gitlab:
    image: gitlab/gitlab-ee:17.2.8
    # 4. 转换挂载路径
    binds:
      - /lzcapp/var/config:/etc/gitlab
      - /lzcapp/var/logs:/var/log/gitlab
      - /lzcapp/var/data:/var/opt/gitlab
    # 5. 注入环境变量
    environment:
      - GITLAB_OMNIBUS_CONFIG=external_url 'http://gitlab.${LAZYCAT_BOX_DOMAIN}'; gitlab_rails['lfs_enabled'] = true;

```

---

## 4. 构建与安装流程 (Build Workflow)

### Step 1: 准备文件结构

在项目根目录下，必须包含以下三个文件：

```text
.
├── lzc-build.yml     # 构建配置 (见下文)
├── lzc-manifest.yml  # 应用定义 (上一步生成)
└── icon.png          # 应用图标 (必须是 png 格式)

```

**lzc-build.yml 模板**:

```yaml
pkgout: ./        # 输出位置
icon: ./icon.png  # 图标路径
manifest: ./lzc-manifest.yml

```

### Step 2: 执行构建

在包含上述文件的目录中运行：

```bash
lzc-cli project build

```

*成功后会生成文件：`cloud.lazycat.app.gitlab-v17.2.8-patch1.lpk*`

### Step 3: 安装测试

将生成的 `.lpk` 包安装到测试设备：

```bash
lzc-cli app install ./cloud.lazycat.app.gitlab-v17.2.8-patch1.lpk

```

---

好的，我理解您的需求。由于官方文档中缺乏对 `lzc-cli` 详细命令的说明，保留这份完整的 Help 输出对于 Agent 正确使用工具至关重要。

我已更新 `Agents.md`，将您提供的终端 Help 输出整理为详细的 **CLI 命令参考手册**，替代了原本简单的摘要。

```markdown
# Agents.md - Docker to Lazy Cat Porting Guide

本指南用于指导 AI Agent 将现有的 Docker 镜像 (`docker run`) 或 Docker Compose 应用 (`docker-compose.yml`) 移植到懒猫微服平台 (`.lpk`)。

## 1. 核心规范参考 (Core Specifications)

* **Manifest 配置**: @lzc-developer-doc/docs/spec/manifest.md
* **构建配置**: @lzc-developer-doc/docs/spec/build.md
* **原始教程**: "移植一个应用" (Porting an App)
* **CLI 参考**: 见本文档第 5 节 (基于 lzc-cli help 输出)

---

## 2. 映射逻辑详解 (Mapping Logic)

将 Docker 参数转换为 `lzc-manifest.yml` 的核心规则如下：

### 2.1 基础字段映射

| Docker / Compose | lzc-manifest.yml | 转换规则与约束 |
| :--- | :--- | :--- |
| `image` | `services.<name>.image` | 直接复制镜像名。 |
| `--env` / `environment` | `services.<name>.environment` | 直接复制。**技巧**: 内部 URL 可使用变量 `${LAZYCAT_BOX_DOMAIN}` 替代硬编码域名。 |
| `--volume` / `volumes` | `services.<name>.binds` | **强制修改**: 宿主机路径（冒号左侧）必须改为 `/lzcapp/var/...` (持久化) 或 `/lzcapp/cache/...`。<br>例: `$HOME/data:/data` &rarr; `/lzcapp/var/data:/data` |
| `depends_on` | `services.<name>.depends_on` | 复制依赖关系，但**严禁**依赖名为 `app` 的服务。 |
| `container_name` | (Key in `services`) | 用作服务名，但**不能**命名为 `app`。 |

### 2.2 网络端口映射 (关键)

懒猫微服不直接使用 `ports` (`-p`)，而是根据协议类型分流：

#### A. HTTP/HTTPS 服务 (网站/API)
* **配置位置**: `application.routes`
* **转换逻辑**: 将 Docker 的 `80/443` 端口映射为内部路由。
* **格式**: `<Path>=<Protocol>://<ServiceName>.<PackageID>.lzcapp:<InternalPort>`
* **示例**:
    ```yaml
    routes:
      # 将 Web 流量转发到 gitlab 容器的 80 端口
      - /=[http://gitlab.cloud.lazycat.app.gitlab.lzcapp:80](http://gitlab.cloud.lazycat.app.gitlab.lzcapp:80)
    ```

#### B. TCP/UDP 服务 (SSH, 数据库等)
* **配置位置**: `application.ingress`
* **转换逻辑**: 非 HTTP 的端口（如 SSH 的 22 端口）需通过 Ingress 暴露。
* **示例**:
    ```yaml
    ingress:
      - protocol: tcp
        port: 22        # 外部访问端口
        service: gitlab # 目标服务名
    ```

---

## 3. 实战案例：GitLab 移植 (Case Study)

以下展示如何将 GitLab 的 `docker run` 命令转换为 `lzc-manifest.yml`。

### 3.1 输入：原始 Docker 命令
```bash
sudo docker run --detach \
  --hostname gitlab.example.com \
  --env GITLAB_OMNIBUS_CONFIG="external_url '[http://gitlab.example.com](http://gitlab.example.com)'" \
  --publish 443:443 --publish 80:80 --publish 22:22 \
  --name gitlab \
  --volume $GITLAB_HOME/config:/etc/gitlab \
  --volume $GITLAB_HOME/logs:/var/log/gitlab \
  --volume $GITLAB_HOME/data:/var/opt/gitlab \
  gitlab/gitlab-ee:17.2.8-ee.0

```

### 3.2 转换过程分析

1. **Volume**: `$GITLAB_HOME` 全部替换为 `/lzcapp/var` 前缀。
2. **Ports**:
* `80/443` -> 识别为 Web 服务 -> 放入 `application.routes`。
* `22` -> 识别为 SSH 服务 -> 放入 `application.ingress`。


3. **Env**: 将 `gitlab.example.com` 替换为动态域名变量 `${LAZYCAT_BOX_DOMAIN}`。

### 3.3 输出：lzc-manifest.yml

```yaml
lzc-sdk-version: '0.1'
name: GitLab
package: cloud.lazycat.app.gitlab
version: 17.2.8-patch1
application:
  subdomain: gitlab
  # 1. 处理 HTTP 端口 (80)
  routes:
    - /=[http://gitlab.cloud.lazycat.app.gitlab.lzcapp:80](http://gitlab.cloud.lazycat.app.gitlab.lzcapp:80)
  # 2. 处理 TCP 端口 (22)
  ingress:
    - protocol: tcp
      port: 22
      service: gitlab
services:
  # 3. 定义服务 (注意：名字不能是 app)
  gitlab:
    image: gitlab/gitlab-ee:17.2.8
    # 4. 转换挂载路径
    binds:
      - /lzcapp/var/config:/etc/gitlab
      - /lzcapp/var/logs:/var/log/gitlab
      - /lzcapp/var/data:/var/opt/gitlab
    # 5. 注入环境变量
    environment:
      - GITLAB_OMNIBUS_CONFIG=external_url 'http://gitlab.${LAZYCAT_BOX_DOMAIN}'; gitlab_rails['lfs_enabled'] = true;

```

---

## 4. 构建与安装流程 (Build Workflow)

### Step 1: 准备文件结构

在项目根目录下，必须包含以下三个文件：

```text
.
├── lzc-build.yml     # 构建配置
├── lzc-manifest.yml  # 应用定义
└── icon.png          # 应用图标 (必须是 png 格式)

```

**lzc-build.yml 模板**:

```yaml
pkgout: ./        # 输出位置
icon: ./icon.png  # 图标路径
manifest: ./lzc-manifest.yml

```

### Step 2: 执行构建

```bash
lzc-cli project build

```

### Step 3: 安装测试

```bash
# 安装生成的 lpk 包
lzc-cli app install ./cloud.lazycat.app.gitlab-v17.2.8-patch1.lpk

```


## 5. CLI 命令参考手册 (CLI Reference)

以下内容源自 `lzc-cli help` 输出，请在操作时以此为准。

### 5.1 全局命令概览

* `lzc-cli config`: 配置管理
* `lzc-cli box`: 盒子管理
* `lzc-cli app`: 应用管理
* `lzc-cli project`: 项目管理
* `lzc-cli appstore`: 应用商店
* `lzc-cli docker`: 微服应用 docker 管理
* `lzc-cli docker-compose`: 微服应用 docker-compose 管理

### 5.2 项目管理 (Project)

用于应用的创建、构建和开发环境调试。

```bash
lzc-cli project init                # 初始化懒猫云应用(提供最基础的模板)
lzc-cli project create <name>       # 创建懒猫云应用
lzc-cli project build [context]     # 构建应用 (生成 .lpk)
lzc-cli project devshell [context]  # 进入盒子的开发环境

```

### 5.3 应用管理 (App)

用于应用的安装、卸载和状态检查。

```bash
lzc-cli app install [pkgPath]   # 部署应用至设备, pkgPath 可以为路径，或者https://,http://请求地址
                                # 如果不填写，将默认为当前目录下的lpk
lzc-cli app uninstall <pkgId>   # 从设备中卸载某一个应用 (pkgId 为 manifest 中的 package 字段)
lzc-cli app status <pkgId>      # 获取某一个应用的状态
lzc-cli app log <pkgId>         # 查看某一个app的日志 (调试关键命令)

```

### 5.4 应用商店 (AppStore)

用于应用的发布和镜像管理。

```bash
lzc-cli appstore login                   # 登录
lzc-cli appstore pre-publish <pkgPath>   # 发布到内测
lzc-cli appstore publish <pkgPath>       # 发布到商店
lzc-cli appstore copy-image <img>        # 复制镜像至懒猫微服官方源 (解决拉取困难)
lzc-cli appstore my-images               # 查看已上传镜像列表

```

### 5.5 盒子管理 (Box)

用于管理连接的设备。

```bash
lzc-cli box switch <boxname>    # 设置默认的盒子
lzc-cli box default             # 输出当前默认的盒子名
lzc-cli box list                # 查看盒子列表
lzc-cli box add-public-key      # 添加public-key到开发者工具中

```

### 5.6 配置管理 (Config)

```bash
lzc-cli config set [key] [value]  # 设置配置
lzc-cli config del [key]          # 删除配置
lzc-cli config get [key]          # 获取配置
# 示例:
# lzc-cli config set noCheckVersion false  # 禁用 lzc-cli 的版本更新检测