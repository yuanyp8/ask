# 系统架构详细设计

状态：Draft

## 1. 目标与原则

ASK 负责小说领域产品能力，不重复建设通用身份、授权、审计、模型网关和对象存储平台。业务模块围绕版本化故事模型、原文证据和可恢复 AI 工作流组织。

核心原则：
- PostgreSQL 是业务事实源；Redis 仅承载运行时状态、队列唤醒、锁、缓存和可恢复流式进度。
- 文件经统一存储接口访问；业务包不直接依赖 MinIO/S3 SDK。
- 认证、授权、审计和模型路由复用已有平台服务。
- 外部副作用通过 transactional outbox 发布，不在数据库事务里直接调用 SpiceDB、auditx、搜索索引或模型服务。
- 模块化单体优先；业务模块边界不等于部署边界。

## 2. 逻辑分层

### 表现层
- Next.js Web：项目、作品、导入向导、章节阅读器、分析结果、人物/故事线浏览器、创作编辑器。
- 前端只消费版本化 API DTO，不直接映射数据库表。
- 长任务展示服务端状态；页面关闭不影响任务。

### API / 应用层
- Project：项目成员、作品关联、角色操作。
- Source：上传、版本、章节切分和确认。
- Analysis：创建 run、取消、重试、查询进度。
- Story：人物、提及、事件、关系、故事线和大纲。
- Review：审核、合并/拆分实体、版本比较。
- 后续 Reading / Writing。

### 领域层
Project、Work、SourceVersion、SplitVersion、AnalysisRun、Artifact、StoryEntity、EntityMention、StoryEvent、EventMention、Plotline、OutlineSet 等领域对象。
领域规则不依赖 HTTP、SQL 驱动、Casdoor/SpiceDB SDK、模型供应商 SDK 或前端。

### 基础设施适配层
- PostgreSQL：事务数据、版本、领域关系、run/step 和 outbox。
- Redis：任务队列唤醒、运行时锁、缓存、SSE/流式进度恢复；不作为唯一事实源。
- 对象存储：原始文件和规范化全文，通过现有 metastoragex / objectstorex 抽象访问。
- Worker：异步任务和阶段恢复。
- Preprocessor：格式解析、规范化和章节切分适配器。
- AuthN：Casdoor OIDC / 现有 IAM Principal。
- AuthZ：通过统一 Authorizer/IAM 调用 SpiceDB；业务代码不直接依赖 SpiceDB SDK。
- Audit：通过 auditx 记录审计；ASK 不建立与 auditx 竞争的审计事实库。
- Model Gateway：通过 new-api 的 OpenAI-compatible 接口调用 chat、embedding、rerank；由网关负责模型路由、配额、重试和用量汇总。
- Retrieval：结构查询、PostgreSQL 全文检索和 pgvector；向量检索与 rerank 通过接口适配。

## 3. 推荐部署形态

首期：
- 一个 Next.js Web 应用。
- 一个 Go API 进程。
- 一个同仓库 Go Worker 进程，可独立扩缩容。
- 一个预处理服务/进程，通过接口隔离。
- PostgreSQL。
- Redis。
- S3-compatible 对象存储，通过存储抽象访问。

Casdoor、Kernel IAM/Authorizer、SpiceDB、auditx、new-api 和模型端点视为已有平台依赖，不因 ASK 单独复制部署。开发/测试可使用独立配置和数据库。

## 4. 核心依赖方向

- HTTP handler → application service → domain contract / repository interface。
- Repository implementation → PostgreSQL。
- Worker → application service 和任务接口。
- Analysis orchestration → source repository、artifact repository、model gateway、retrieval。
- Authorization adapter → Authorizer contract；业务代码不直接调用 Casdoor/SpiceDB SDK。
- Storage adapter → metastoragex/objectstorex contract；业务代码不直接调用 MinIO/S3 SDK。
- Model Gateway adapter → new-api OpenAI-compatible API。
- Audit adapter → auditx contract；领域事务通过 outbox 保证副作用可重试。
- Preprocessor 不负责业务权限、人物消歧或大纲生成。
- Web 只依赖版本化 API DTO。

禁止：
- handler 内直接写复杂 SQL 和模型提示词。
- 数据库模型包反向依赖 HTTP 或供应商 SDK。
- 模型响应未经校验直接写入关系表。
- 把整个分析状态只存 Redis 或进程内内存。
- 绕过 Authorizer 直接依赖前端角色判断。
- 直接把对象存储管理员凭证交给浏览器。

## 5. 关键数据流

### 导入
Upload → object storage abstraction → source document → source_parse run → preprocessing → source version → chapter_split run → draft split version → preview/edit → confirmed split version。

### 分析
Create run → validate exact input versions and authorization → persist run/steps → enqueue wake-up in Redis or worker queue → worker claims durable step → build bounded context → call new-api → schema validate → evidence verify → persist chapter artifact and mentions → consolidate entities/events → synthesize plotlines/outlines → final validation → review-ready artifacts.

### 用户编辑与外部副作用
API checks Principal + Authorizer + expected revision → domain validation → database transaction updates domain data and inserts integration_outbox rows → outbox publisher sends relationship changes to SpiceDB, audit records to auditx, and indexing events to retrieval → idempotent acknowledgment.

## 6. 事务边界

同一数据库事务内：
- 创建项目及 owner membership。
- 创建 run 和初始 steps。
- 写入一个章节的 artifact/claims/evidence/mentions。
- 人物合并及其关系去重/引用更新。
- 大纲树同一版本内的节点排序变更。
- 用户审核状态和对应 outbox event。

不应把模型、SpiceDB、auditx 或对象存储调用放在数据库事务中。先记录任务/副作用，再异步执行；外部调用按 dedupe key 幂等。

## 7. 身份与授权流程

1. Web 使用 Casdoor OIDC 完成登录。
2. API 从可信网关/认证中间件取得 Principal，不接受请求体中的 user_id 作为身份。
3. API 通过统一 Authorizer 检查 action/resource；默认 fail-closed。
4. project_members 保存产品级成员关系和角色；变更通过 outbox 投影到 SpiceDB。
5. 对高风险写操作使用合适的授权一致性要求；关系投影未完成或授权服务不可用时拒绝写入。
6. 关键操作通过 auditx 记录真实用户 Principal、资源、动作和 request_id。

## 8. 任务与状态一致性

- PostgreSQL 的 analysis_runs/steps 是任务生命周期事实源。
- Redis 负责队列唤醒、锁、缓存和流式状态；Redis 数据丢失后可以从 PostgreSQL 找回 queued 或过期 lease 的步骤。
- Worker 通过 lease/heartbeat 接管过期步骤。
- outbox 的 pending/failed 事件可重放；发布成功后标记 published。
- 模型 token/chunk 不逐 token 写入 PostgreSQL；需要刷新恢复时由 Redis 短期保留，数据库只保存阶段结果、生命周期、摘要和审计事实。

## 9. 可扩展边界

仅在预处理资源/依赖独立、Worker 负载影响 API 延迟、检索索引需要独立扩缩容或网络隔离要求强制时才拆独立部署。

## 10. 非功能属性

正确性优先；任务可恢复；run/step/outbox 全链路可观测；模型和存储可替换；payload 有 schema_version；章节并发和 token 预算受限；检索前先做权限过滤。
