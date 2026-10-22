# 架构决策记录（ADR）

状态：Draft

本文件记录当前建议决策。被评审接受后，状态改为 Accepted；改变决策时新增 ADR，不静默覆盖历史理由。

## ADR-001：首期采用模块化单体

状态：Proposed

背景：项目仍处于分析阶段，领域边界尚在验证。过早微服务化会增加部署、事务和调试成本。

决策：Go API 和 Worker 在同一代码仓库，按业务能力划分 internal packages；API 与 Worker 可作为不同进程运行。预处理服务通过稳定接口隔离。

后果：开发简单、跨模块事务容易；必须通过包依赖规则防止模块耦合。满足独立扩缩容条件后再拆部署单元。

## ADR-002：PostgreSQL 作为事务数据源

状态：Proposed

决策：项目、作品、版本、任务、人物、事件、关系、大纲、证据和审核状态以 PostgreSQL 为事实来源。Redis 仅用于运行时队列、缓存、锁和流式进度；对象存储保存原始文件与规范化全文，章节文本存于 PostgreSQL 以支持定位。

后果：可以用外键和事务保护核心不变量；需要控制全文存储、索引和大纲树查询成本。

## ADR-003：使用关系边表，不先引入图数据库

状态：Proposed

决策：story_relations、event_relations、plotline_nodes 等使用关系表表达。图数据库只在实际查询复杂度、性能和产品需求证明必要时评估。

## ADR-004：源版本和确认后的切分版本不可变

状态：Proposed

决策：解析器或规范化规则改变产生新 source version；章节边界变化产生新 split version。分析产物绑定精确版本。

## ADR-005：反向分析与计划创作分开

状态：Proposed

决策：outline_mode 至少区分 reverse_analysis 和 planned_outline。前者依赖源版本，后者表示作者意图；共享树操作，但不可混淆事实语义。

## ADR-006：证据为一等数据对象

状态：Proposed

决策：关键结论通过 claim 和 evidence anchor 保存原文位置、引用、哈希、验证状态。AI 不能直接标记引用已验证。

## ADR-007：分析任务持久化并可恢复

状态：Proposed

决策：run 和 step 状态存储在 PostgreSQL；Redis 负责队列唤醒和运行时状态，worker 使用 PostgreSQL lease/heartbeat 和幂等键恢复任务。Redis 丢失后可以从 PostgreSQL 恢复 queued/expired steps。模型调用不持有长事务。

## ADR-008：首期先用关键词与结构检索

状态：Proposed

决策：先建立章节、实体、事件和证据的结构化查询；使用 PostgreSQL 全文检索与 pgvector，embedding/rerank 通过 new-api 路由和 retrieval interface 接入。首期不引入独立向量数据库；效果由固定样本集评估。

## ADR-009：AI 产物采用版本化 schema

状态：Proposed

决策：每类 artifact 有 schema_version，模型输出经过 JSON Schema 和领域校验。提示词、模型或 schema 变更创建新 run，不覆盖历史产物。

## ADR-010：用户审核不覆盖原始模型输出

状态：Proposed

决策：接受、拒绝、编辑和实体合并/拆分均保留审计记录；用户修改后的结果形成新 revision 或独立审核状态。auditx 是审计事实源，ASK 通过 integration_outbox 可靠投递审计事件。

## ADR-011：Canonical entity/event 与 source mention 分离

状态：Proposed

背景：一个人物或事件可能在多个章节、切分版本和不同版本文本中出现；把 chapter_id 或 narrative_order 放在 canonical entity/event 上会错误地绑定到单一版本。

决策：story_entities/story_events 保存 work 级概念；entity_mentions/event_mentions 保存来源版本、切分版本、章节、原文形式、局部位置和叙事顺序。故事线节点引用具体 event mention，跨版本汇总通过 canonical event 完成。

后果：增加两张关系表和消歧步骤，但能保留原文证据、支持不同版本并减少跨版本数据污染。



## ADR-012：复用统一身份、授权、审计和模型平台

状态：Proposed

决策：Casdoor OIDC 作为认证入口；Kernel IAM/Authorizer 提供 Principal 和统一授权接口，SpiceDB 作为关系授权后端；auditx 保存审计事实；new-api 作为模型路由入口；metastoragex/objectstorex 封装对象存储。ASK 不在业务模块中直接依赖这些供应商 SDK，也不复制同类基础平台。

后果：统一身份、授权、审计和模型路由；需要清晰的 adapter contracts、配置边界和集成测试。

## ADR-013：使用 transactional outbox 可靠投递外部副作用

状态：Proposed

背景：数据库事务不能与 SpiceDB、auditx、检索索引等外部系统共享原子提交。

决策：成员关系变更、审计事件和索引变更在领域事务中写入 integration_outbox；独立 publisher 按 dedupe_key 幂等投递，并记录 retryable_failed/dead_letter 状态。

后果：允许短暂最终一致，但避免数据库提交成功而外部副作用永久丢失；敏感写操作在授权关系投影未完成或授权检查不可用时 fail-closed。

## ADR-014：身份/授权/审计数据的权威来源分离

状态：Proposed

决策：app_users 仅是可信 IAM subject 的内部映射；project_members 是 ASK 产品成员元数据；SpiceDB 是运行时关系授权图；auditx 是审计事实源。任何本地投影都不得宣称取代其权威来源。

## ADR-015：模型调用统一经 new-api

状态：Proposed

决策：Analysis/Reading/Writing 通过 provider-neutral ModelGateway 接口调用 new-api 的 OpenAI-compatible chat/embedding/rerank API。ASK 保存逻辑 route、模型/提示词/schema 版本和任务用量，不存第三方供应商密钥，也不绕过网关直接调用模型供应商。

## 待评审问题

- 是否在后续版本支持同一 work 内显式重复导入相同字节的 source document。
- 用户/作品级模型路由与成本配额的具体策略。
