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

决策：项目、作品、版本、任务、人物、事件、关系、大纲、证据和审核状态以 PostgreSQL 为事实来源。对象存储保存原始文件与规范化全文。

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

决策：run 和 step 状态存储在 PostgreSQL；worker 使用 lease/heartbeat 和幂等键恢复任务。模型调用不持有长事务。

## ADR-008：首期先用关键词与结构检索

状态：Proposed

决策：先建立章节、实体、事件和证据的结构化查询及关键词检索；向量与重排通过 retrieval interface 接入，并由固定样本集评估效果。

## ADR-009：AI 产物采用版本化 schema

状态：Proposed

决策：每类 artifact 有 schema_version，模型输出经过 JSON Schema 和领域校验。提示词、模型或 schema 变更创建新 run，不覆盖历史产物。

## ADR-010：用户审核不覆盖原始模型输出

状态：Proposed

决策：接受、拒绝、编辑和实体合并/拆分均保留审计记录；用户修改后的结果形成新 revision 或独立审核状态。

## 待评审问题

- 任务队列首期使用 PostgreSQL job table 还是接入现有 MQ。
- 规范化全文和章节文本在对象存储/数据库之间的最终存储策略。
- 原始文件去重时默认复用还是允许显式副本。
- 用户/作品级模型路由与成本配额的具体策略。
