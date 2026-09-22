# exercises-dataset — AGENTS.md

## 项目定位
纯静态健身动作数据集浏览器的懒猫微服 LPK V2 应用打包。

## 目录结构
```
exercises-dataset/
├── package.yml                                          # 应用元数据与权限声明
├── lzc-manifest.yml                                     # 运行清单：file:// 静态路由
├── lzc-build.yml                                        # 构建配置
├── content/                                             # 静态资源（挂载到 /lzcapp/pkg/content）
│   ├── index.html                                       # 主浏览器页面（~16MB，内嵌全部数据）
│   ├── setup.html                                       # 开发者集成指南
│   ├── data/exercises.json                              # 1,324 条运动数据
│   ├── data/exercises.schema.json                       # JSON Schema
│   ├── images/                                          # 1,324 × 180×180 缩略图
│   ├── videos/                                          # 1,324 × 动画 GIF
│   ├── LICENSE                                          # MIT 许可证
│   └── NOTICE.md                                        # 媒体归属声明
├── cloud.lazycat.app.exercises-dataset-v1.0.0.lpk       # 构建产出
└── AGENTS.md                                            # 本文件
```

## 架构决策
- **无后端服务**：纯静态项目，使用 `file://` 协议直接提供内容
- **无权限需求**：离线可用，不需要网络或存储权限
- **数据内嵌**：`index.html` 内嵌全部 JSON 数据（~16MB），无需 API 调用
