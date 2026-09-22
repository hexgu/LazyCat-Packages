#!/bin/sh
set -e

# 这里应当编写构建或者拉取 geoflow-app:latest 镜像的逻辑。
# 如果已经构建好了镜像（或者通过 git clone 源码在本地通过 docker build 编译过），则直接返回 0。
# 也可以配置将远程镜像 pull 并 tag 为目标镜像名。

echo "Geoflow 镜像就绪检查..."
# 检查本地是否有 geoflow-app:latest 镜像
if ! docker image inspect geoflow-app:latest >/dev/null 2>&1; then
  echo "警告: 本地未找到 geoflow-app:latest 镜像。"
  echo "请先在有源码的目录下执行 'docker build -t geoflow-app:latest -f docker/Dockerfile .' 以编译镜像。"
fi

echo "Build finished."
exit 0