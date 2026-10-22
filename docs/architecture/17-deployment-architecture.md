# 部署架构与环境设计

状态：Draft

## 1. 环境

- local：开发者本地，独立数据库、Redis 和测试 bucket。
- test：自动化测试，临时数据库和对象存储。
- staging：尽可能复刻生产拓扑，验证迁移、outbox、任务恢复和模型路由。
- production：正式用户数据和持久化存储。

禁止开发/测试环境复用生产密钥或将生产正文复制到未授权测试环境。

## 2. ASK 自有部署单元

- web：Next.js 应用。
- api：Go HTTP API。
- worker：Go 异步执行进程。
- preprocessor：文本解析与规范化适配器。
- PostgreSQL：业务事实源、版本、run/step、outbox。
- Redis：任务队列唤醒、缓存、锁和可恢复流式进度。
- object storage：原始文件和规范化全文，通过现有存储抽象访问。

API 与 Worker 可共用一个镜像但使用不同 command。Worker 数量受模型并发和成本配额限制，不能无限扩容。

## 3. 复用的现有平台服务

- 身份认证：Casdoor OIDC。
- Principal/IAM/授权：Kernel IAM 与统一 Authorizer，关系授权由 SpiceDB 提供。
- 审计：auditx。
- 模型网关：new-api（OpenAI-compatible chat/embedding/rerank）。
- 文件存储：metastoragex/objectstorex 抽象，底层可为 MinIO/S3。
- 观测：现有 Prometheus / Loki / OpenTelemetry 接入方式。

这些是外部依赖，不应在 ASK 内复制同类服务。若本地开发需要替身，使用明确的 dev profile，不得改变生产接口契约。

## 4. 配置类别

非敏感配置：
- 环境名、监听地址、日志级别、请求超时、最大上传大小。
- PostgreSQL 连接池、Redis 队列/lease 参数、worker 并发。
- 模型路由名、token 预算、任务配额。
- 对象存储逻辑 bucket/profile 名称。

敏感配置：
- PostgreSQL 密码、Redis 凭证。
- 对象存储访问密钥。
- new-api 服务 token。
- 内部服务 token、OIDC 客户端密钥。

敏感配置通过环境注入或密钥管理系统提供，不写入配置仓库、前端 bundle 或日志。

## 5. 健康检查

- API liveness：进程是否存活，不依赖模型服务瞬时可用性。
- API readiness：数据库和必要配置就绪。
- Worker health：heartbeat、lease、最近成功任务和队列积压。
- Preprocessor health：版本、解析器和依赖状态。
- 外部依赖健康由独立指标暴露；不可用时 API 按策略 fail-closed 或返回可重试错误。

健康接口不得暴露凭证、完整配置或用户数据。

## 6. 发布顺序

1. 备份数据库和对象存储关键元数据。
2. 在 staging 执行 migration。
3. 验证数据库约束、outbox 投递、SpiceDB 关系投影和 auditx 记录。
4. 运行关键集成测试和故障恢复测试。
5. 发布兼容的 API/worker。
6. 观察错误率、队列、模型成本、outbox backlog 和证据验证率。
7. 回滚应用前确认 schema 向后兼容；数据库回滚单独评估，不默认自动执行。

## 7. 资源规划原则

首期资源按真实并发和模型部署情况测量。主要瓶颈：
- PostgreSQL：章节/关系查询和任务状态写入。
- Redis：队列、锁、缓存和流式恢复。
- 对象存储：原始文件、规范化全文和导出。
- Worker：文本处理、模型并发和重试。
- new-api/模型端点：上下文窗口、吞吐、并发限制和成本。

压测场景：多本长篇同时导入、章节批量分析、Redis 暂时不可用、outbox 堆积、worker 重启、多个用户同时浏览大纲和人物关系。
