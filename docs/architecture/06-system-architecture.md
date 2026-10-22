# 系统架构详细设计

状态：Draft

## 1. 目标

在保持首期实现复杂度可控的前提下，支持长篇文本导入、可追溯分析、结构化故事数据、阅读和原创创作。架构首先保证业务边界、可恢复任务和版本正确性，不以微服务数量作为目标。

## 2. 逻辑分层

### 表现层
- Web App：项目、作品、导入向导、章节阅读器、分析结果、人物/故事线浏览器、创作编辑器。
- 前端只消费 API DTO，不直接映射数据库表。
- 长任务展示服务端状态；页面关闭不影响任务。

### API / 应用层
- Project Application：项目成员与作品关联。
- Source Application：上传记录、版本、章节切分和确认。
- Analysis Application：创建 run、取消、重试、查询进度。
- Story Application：人物、事件、关系、故事线和大纲编辑。
- Review Application：审核、合并/拆分实体、版本比较。
- 后续 Reading / Writing Application。

### 领域层
- Project、Work、SourceVersion、SplitVersion、AnalysisRun、Artifact、StoryEntity、StoryEvent、Plotline、OutlineSet 等领域对象。
- 领域规则不依赖 HTTP、SQL 驱动、模型供应商或前端。
- 关键不变量在领域服务/应用事务中校验；数据库约束负责防止并发下的数据不一致。

### 基础设施层
- PostgreSQL：事务性数据、关系、版本、任务状态。
- S3-compatible object storage：原始文件和规范化全文。
- Worker：异步任务和阶段恢复。
- Preprocessor：格式解析、规范化和章节切分适配器。
- Model Gateway：多模型统一调用、结构化输出、用量和重试。
- Retrieval：全文检索、结构查询、可选向量与 reranker。

## 3. 推荐部署形态

首期建议：
- 一个 Next.js Web 应用。
- 一个 Go API 进程。
- 一个同仓库 Go Worker 进程，可独立扩缩容。
- 一个预处理服务/进程，通过接口隔离。
- PostgreSQL。
- S3-compatible 对象存储。
- 初期可使用 PostgreSQL 持久任务表；若吞吐和并发需求证明需要，再接入现有 MQ/Redis 设施。

不要在首期为 project、storymodel、evidence、outline 等每个模块各建一个微服务。模块化单体先保证依赖方向和事务边界。

## 4. 核心依赖方向

- HTTP handler → application service → domain contract / repository interface。
- Repository implementation → PostgreSQL。
- Worker → application service 和任务接口。
- Analysis orchestration → source repository、artifact repository、model gateway、retrieval。
- Model Gateway 不直接写业务表，只返回经过规范化的响应。
- Preprocessor 不负责业务权限、人物消歧或大纲生成。
- Web 只依赖版本化 API DTO。

禁止：
- handler 内直接写复杂 SQL 和模型提示词。
- 数据库模型包反向依赖 HTTP 或供应商 SDK。
- 模型响应未经校验直接写入关系表。
- 把整个分析状态只存 Redis 或进程内内存。

## 5. 关键数据流

### 导入
Upload → file validation → object storage → source document → preprocessing → source version → draft split version → preview/edit → confirmed split version。

### 分析
Create run → validate exact input versions → persist run and steps → worker claims step → build bounded context → call model → schema validate → evidence verify → persist chapter artifact → consolidate entities/events → synthesize plotlines/outlines → final validation → review-ready artifacts。

### 用户编辑
API checks membership + expected revision → domain validation → transaction updates current draft/revision and audit → invalidates affected derived artifacts → returns new revision.

## 6. 事务边界

必须在一个数据库事务内执行：
- 创建项目及 owner membership。
- 创建分析 run 和初始 steps。
- 写入一个章节的提取结果及其 artifact/claims/evidence。
- 人物合并及其关系去重/引用更新。
- 大纲树同一版本内的节点排序变更。
- 用户审核状态和审计记录。

不应把模型调用放在数据库事务中。先记录 step/lease，再调用模型，随后用短事务持久化结果。

## 7. 可扩展边界

以下场景出现时才考虑独立部署：
- 预处理依赖和资源与 Go API 不同，或需要独立扩缩容。
- Worker 模型调用负载影响 API 延迟。
- 检索服务有独立的索引构建和扩缩容需求。
- 用户隔离、网络或模型部署要求强制服务边界。

## 8. 关键非功能属性

- 正确性优先：版本、证据、实体关系不能因重试而重复或串书。
- 可恢复：worker 崩溃后能够重新领取过期 lease。
- 可观测：run/step 贯穿日志、指标和错误。
- 可替换：模型和预处理实现通过接口替换。
- 可演进：结构化 payload 具备 schema_version。
- 成本可控：章节级并发和 token 预算受限。
