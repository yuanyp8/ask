# 平台模块详细设计

状态：Draft

本文将产品能力进一步拆为可开发模块。每个模块明确边界、主要页面、输入输出、关键规则、权限和验收，不代表这些模块都要独立部署。

## M01 项目与作品

**职责**：项目空间、作品注册、成员权限和作品关联。

**页面**：项目列表、项目首页、成员管理、作品创建/设置。

**核心数据**：projects、project_members、works、project_works。

**主要操作**：创建项目、邀请/移除成员、创建作品、关联参考作品、归档项目。

**规则**：
- 项目创建和 owner 成员记录在同一事务中。
- owner/editor/viewer 的权限在服务端执行。
- 当前 owner 不可直接移除；所有权转移必须在同一事务内先调整旧 owner 角色再授予新 owner。
- work 可被多个项目引用，但资源访问仍必须通过当前项目授权。
- 已被历史分析引用的作品不能通过级联删除消失。

**验收**：viewer 修改被拒绝；移除成员后不能访问项目；同一项目不重复关联作品；项目归档不删除作品和历史分析。

## M02 原文导入与版本

**职责**：管理原始文件、规范化文本和版本。

**页面**：上传向导、导入历史、解析诊断、版本列表。

**核心数据**：source_documents、source_versions、integration_outbox；审计投递到 auditx。

**输入**：文件、作品 ID、格式选项、规范化配置。

**输出**：源文件记录、SHA-256、对象存储 key、解析状态、source version。

**规则**：
- 上传字节与规范化文本使用不同哈希。
- source version 不可原地修改。
- 同一 work + 原始 SHA-256 在 MVP 中唯一；重复上传复用现有 document。
- 解析失败保留原文件，可用新 parser version 重试。
- 不将原始文件名拼接成对象存储路径。

**异常**：文件过大、格式不支持、编码错误、空文本、对象存储失败、重复上传、解析器超时。

**验收**：原始文件 hash 可复验；解析版本可追溯；重复请求幂等；失败不产生伪造的 ready 版本。

## M03 章节切分与校对

**职责**：识别章节，允许人工修正，并锁定分析输入。

**页面**：章节列表、章节预览、边界编辑器、切分版本对比。

**核心数据**：split_versions、source_chapters。

**规则**：
- draft 可编辑；confirmed 不可原地修改。
- 新边界必须产生新 split version 和新 chapter IDs。
- source_start_char/source_end_char 是规范化全文的零基左闭右开区间。
- content_text 必须与规范化全文中的章节范围保持定义一致。
- 确认前检查空章节、范围越界、顺序错误和意外重叠。
- 同一 source version 最多一个当前 confirmed split；确认新版本时旧版本标记 superseded。

**验收**：非法边界不能确认；修改不会改变旧分析引用的章节；同一章节能精确定位原文。

## M04 分析任务中心

**职责**：创建、调度、监控、重试和取消 AI 任务。

**页面**：任务队列、任务详情、阶段进度、失败诊断。

**核心数据**：analysis_runs、analysis_run_steps。

**规则**：
- 创建 run 必须指定源版本/切分版本和分析范围。
- 服务端计算 input_hash；相同 idempotency key 配合不同输入必须冲突。
- 模型调用不持有数据库长事务。
- worker 使用 lease/heartbeat；lease 过期后可接管。
- 重试只重跑失败或过期步骤，成功步骤按策略复用。
- 取消保留已完成产物并阻止启动后续昂贵步骤。

**验收**：重复提交不产生重复 run；worker 被杀后可恢复；错误可追踪到具体 step；任务进度在刷新页面后保持一致。

## M05 章节细纲与全书概览

**职责**：从章节级抽取建立可追溯的全书摘要与细纲。

**页面**：全书概览、章节工作台、分析结果审核。

**核心数据**：artifacts、analysis_claims、evidence_anchors、source_chapters。

**输入**：confirmed split version、分析选项、模型执行配置。

**输出**：chapter_analysis、book_overview、technique_analysis 等 artifact。

**规则**：
- 不要求每章都出现反转/高潮。
- 模型候选必须经过 JSON Schema、业务引用和证据验证。
- 每条关键结论保留 epistemic_status。
- 用户修改形成新 revision 或审核记录。
- 新版本产物不覆盖旧版本。

**验收**：结果结构可解析；关键结论可跳转原文；无证据推断被清晰标注；输出 schema 版本可追溯。

## M06 人物、实体与提及消歧

**职责**：建立 canonical entity，保留每个章节中的具体提及。

**页面**：人物列表、人物详情、别名编辑器、待消歧队列、合并/拆分向导。

**核心数据**：story_entities、entity_aliases、entity_mentions、story_relations。

**规则**：
- canonical entity 是 work 级对象。
- entity mention 是 split/chapter 级出现记录，保存原文称呼、位置、来源 run 和解析状态。
- 同名不自动等于同一人；别名相似只生成候选。
- 合并前预览别名、关系、claims 和引用变化。
- 合并/拆分同 work、事务执行、有审计记录。

**验收**：原文提及不因合并而丢失；错误合并可通过受控操作修正；跨 work 合并被拒绝。

## M07 事件与因果

**职责**：提取事件，跨章节聚合，并区分叙事顺序和故事时间。

**页面**：事件列表、事件详情、事件关系图、时间线。

**核心数据**：story_events、event_mentions、event_relations。

**规则**：
- canonical event 不绑定唯一章节或唯一 narrative_order。
- event mention 保存 source/split/chapter、local_order、narrative_order、story-time label 和可选文本范围。
- precedes 不自动等于 causes。
- 倒叙、插叙、多视角不得被错误地按故事内时间重排。
- 事件候选先进入 candidate 状态，审核后才成为 accepted。

**验收**：同一事件可关联多个版本中的提及；因果边有独立类型；所有 mention 都能定位到原文。

## M08 主线、支线与伏笔

**职责**：维护故事线和其推进节点。

**页面**：故事线列表、时间轴、跨线交叉矩阵、未解线索列表。

**核心数据**：plotlines、plotline_nodes、event_mentions、event_relations、claims/evidence。

**规则**：
- line_type 包括 main/subplot/character_arc/mystery/romance/theme/other。
- 节点至少关联 canonical event 或 chapter；若关联 event mention，必须同时指向同一 canonical event，并绑定同一 split version。
- 节点顺序在故事线内唯一，node_key 用于幂等。
- “支线无用”“作者忘记伏笔”只能作为带证据的推断，不能作为确定事实。
- 交汇点和兑现点允许多条线关联同一事件。

**验收**：故事线可以按叙事顺序浏览；从节点可跳到事件和章节；重试不重复节点。

## M09 大纲树

**职责**：表示全书、卷、幕/阶段、故事弧、章节、场景和 beat 的任意层级。

**页面**：大纲树、节点编辑器、版本对比、移动节点对话框。

**核心数据**：outline_sets、outline_nodes。

**规则**：
- reverse_analysis 和 planned_outline 语义分离。
- 不强制固定三幕/三卷结构。
- node_key 在同一 outline set 内唯一。
- parent 必须属于同一 outline set，不能形成循环。
- accepted outline set 不原地编辑；先创建 draft revision。
- 排序操作在事务内执行，处理唯一 position 冲突。

**验收**：任意合法层级可编辑；跨树移动被拒绝；旧版本可对比；源分析大纲能回到证据。

## M10 原文证据与审核

**职责**：让分析结论可核验、可修正。

**页面**：证据侧栏、结论审核队列、引用验证错误视图。

**核心数据**：analysis_claims、evidence_anchors、integration_outbox；审计事实由 auditx 保存。

**规则**：
- explicit/inferred/speculative 与 review_status 分开。
- verified 必须有 verified_at；引用文本、字符范围和 hash 均通过校验。
- 不匹配引用显示 invalid，不自动隐藏错误。
- 用户编辑记录修改者、时间和原始 revision。
- 审核状态变更写审计日志。

**验收**：引用错位可被发现；用户能接受/拒绝/编辑；历史版本仍可查看。

## M11 阅读导师（后续）

**职责**：阅读进度、导读、上下文问答、笔记和测验。

**预计数据**：reading_progress、reading_sessions、reading_notes、quiz_attempts。

**规则**：阅读进度绑定具体 source/split version；AI 回答区分文本证据和解释；笔记属于用户，不随模型重新分析而覆盖。

## M12 创作工作台（后续）

**职责**：Canon、计划大纲、正文编辑、版本和一致性检查。

**预计数据**：canon_items、manuscript_versions、manuscript_chapters、consistency_findings。

**规则**：AI 生成进入草稿；Canon 已确认事实优先于未经确认的模型输出；计划事件与已写正文事实分离；修改设定后展示影响范围。

## M13 检索与知识库（后续）

**职责**：章节、实体、事件、证据、个人笔记和技法模板检索。

**规则**：先按 work/version/project 权限过滤，再检索；关键词、关系查询先于向量召回；所有结果保留来源位置。

## M14 管理与运维

**职责**：配额、模型路由、任务暂停、日志、监控、备份和数据删除。

**规则**：身份通过 Casdoor OIDC/IAM，授权经统一 Authorizer/SpiceDB，审计写入 auditx；成员关系、审计和索引副作用经 integration_outbox 可靠投递。模型路由走 new-api，文件通过 metastoragex/objectstorex 访问。权限和成本控制由服务端执行；模型失败不能无限重试；正文默认不进入日志；永久删除必须同时处理对象存储与数据库依赖。
