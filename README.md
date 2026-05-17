# cc-hah

基于 Claude Code CLI 的 Web UI 桌面端，支持多会话管理、实时 WebSocket 通信、任务调度、MCP 扩展和团队协同。

A web-based desktop UI for Claude Code CLI, featuring multi-session management, real-time WebSocket communication, scheduled tasks, MCP extensions, and team collaboration.

---

## 功能特性

- **多会话管理**：支持同时运行多个 Claude Code 会话，通过侧边栏快速切换
- **实时 WebSocket 通信**：前后端通过 WebSocket 保持长连接，低延迟消息推送
- **会话持久化**：所有对话历史自动保存为 JSONL 格式，与 Claude Code CLI 数据互通
- **预加载（Prewarm）**：会话预加载机制，减少首次响应等待时间
- **任务调度（CronScheduler）**：内置定时任务系统，支持自定义任务和通知
- **MCP 扩展支持**：支持 Model Context Protocol 扩展，可接入外部工具和服务
- **Computer Use 权限控制**：桌面端 Computer Use 功能的安全审批流程
- **多 Provider 支持**：可切换不同 AI Provider（OpenAI、Anthropic 等）
- **团队协同（Teams）**：支持团队配置共享和成员管理

## 技术栈

| 层级 | 技术 |
|------|------|
| 后端运行时 | [Bun](https://bun.sh/) |
| 后端框架 | 原生 `Bun.serve()` + WebSocket |
| 前端框架 | React 19 + TypeScript |
| 构建工具 | Vite |
| 样式 | Tailwind CSS |
| 状态管理 | Zustand |
| UI 组件 | Radix UI |

## 快速开始

### 环境要求

- [Bun](https://bun.sh/) >= 1.1.0
- Node.js >= 20（用于 Vite 构建）

### 安装依赖

```bash
bun install
cd desktop && bun install
```

### 启动开发环境

```bash
# 同时启动后端和前端
bash bin/start-all.sh

# 或分别启动
bun run src/server/index.ts        # 后端 http://127.0.0.1:3456
cd desktop && bun run dev --host   # 前端 http://localhost:2024
```

### 生产部署

```bash
bash /root/start-cc-haha.sh
```

后端默认监听 `127.0.0.1:3456`，前端默认监听 `0.0.0.0:2024`。

## 项目结构

```
cc-hah/
├── src/
│   ├── server/              # 后端服务
│   │   ├── index.ts         # 服务入口（Bun.serve）
│   │   ├── ws/              # WebSocket 处理器
│   │   ├── api/             # REST API 路由
│   │   ├── services/        # 业务服务层
│   │   └── proxy/           # AI Provider 代理/转换层
│   └── utils/               # 工具函数
├── desktop/
│   ├── src/
│   │   ├── components/      # React 组件
│   │   ├── pages/           # 页面组件
│   │   ├── api/             # 前端 API 客户端
│   │   └── lib/             # 前端工具库
│   └── vite.config.ts       # Vite 配置
└── bin/
    └── start-all.sh         # 一键启动脚本
```

## 近期修复的关键 Bug

### 1. 后端启动失败 — Bun.serve `idleTimeout` 超限
Bun ≤1.3.13 要求 `idleTimeout ≤ 255`，原配置 `600` 导致服务器静默退出。已调整为 `255`。

### 2. 会话异常中断 — 断连清理计时器过短
WebSocket 断开后硬编码 60 秒即杀死 CLI 子进程。已改为可配置（默认 300 秒，通过 `CC_HAHA_DISCONNECT_GRACE_MS` 环境变量）。

### 3. 停止生成竞态条件 — 未跟踪的强制杀死计时器
用户点击停止后，3 秒强制杀死计时器未跟踪，可能误杀后续新对话。已增加 `stopGenerationTimers` 管理。

### 4. SIGKILL 计时器泄漏
`stopSession` 中 500ms 的 SIGKILL 计时器未跟踪，重复调用会产生多个悬空计时器。已为 `SessionProcess` 增加 `sigkillTimer` 字段。

### 5. WebSocket 发送崩溃
`ws.send()` 在连接关闭时抛出异常，会打断消息处理循环。已用 `try/catch` 包裹。

### 6. 模块导入错误
`sessionService.ts` 从 `node:fs/promises` 调用 `statSync`，该模块不提供同步方法。已改为从 `node:fs` 导入。

## 致谢

本项目基于 [NanmiCoder/cc-haha](https://github.com/NanmiCoder/cc-haha) 进行二次开发和维护。

## License

MIT
