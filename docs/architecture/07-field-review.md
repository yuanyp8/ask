# 数据模型字段评审与优化清单

状态：Draft

## 1. 评审结论

当前 000001 SQL 是概念验证草案，不应直接作为定稿。需要优先处理跨作品/跨版本引用、运行级模型元数据、弱类型 scope、源文本偏移定义、任务恢复和审核历史等问题。

## 2. P0 必须修正

### DATA-001：统一 work / source / split 归属

现有部分外键只验证 ID 存在，不能证明它们属于同一 work。例如 story relation、event relation、plotline node、outline node、evidence anchor 可能意外连接不同作品的数据。

设计决策：
- 为需要跨表验证的对象增加可用于复合外键的唯一键，例如 (id, work_id)。
- source version、split version、chapter 均带可验证的 work 归属；通过复合外键保证 source→split→chapter 链路一致。
- story relation 两端必须属于同一 work；event relation 同理。
- plotline node 的 plotline、event、chapter 必须属于同一 work。
- outline node 的 parent、event、chapter 必须属于同一 work 和同一个 outline set。
- claim、evidence anchor 和 artifact 必须属于同一 work；证据还必须属于 artifact 对应的 split version。
- 对于无法仅靠简单外键表达的语义，应用层必须在同一事务内校验。

### DATA-002：项目 owner 单一事实来源

projects.owner_id 与 project_members.role='owner' 存在重复事实风险。

推荐方案：以 project_members 为唯一成员/角色来源；创建项目和插入 owner 成员在同一事务完成；通过 partial unique index 保证每个项目至多一个 owner。若后续支持多个管理员，另设 admin 权限，不重复定义 owner。

### DATA-003：原文偏移字段命名

将 source_chapters.start_offset/end_offset 改为 source_start_char/source_end_char，明确它们是相对于规范化全文的字符区间；证据锚点 start_char/end_char 是相对于 chapter.content_text 的局部区间。

统一采用 Unicode code point、零基、左闭右开区间。不要混用 UTF-8 字节偏移、JavaScript UTF-16 code unit 和 Unicode code point。

章节内容定义为规范化全文对应区间的精确文本切片；若解析器需要去掉标题或装饰内容，必须同时保存明确的映射，不能假定章节字符区间等于 UI 渲染文本偏移。

### DATA-004：source version 必须可重现

- source_documents.sha256：原始文件字节的 SHA-256。
- source_versions.content_sha256：规范化全文字节的 SHA-256。
- normalized_text_storage_key：规范化全文在对象存储中的不可变 key，应为必填字段。
- parser_name/parser_version/normalization_profile：用于解释文本如何产生。
- 文件相同但解析器版本变化，应产生新 source version，而不是覆盖旧版本。
- MVP 对同一 work 的原始文件 SHA-256 实施唯一约束；重复上传默认复用已有 document。显式副本语义暂缓，未来如需支持需引入独立 duplicate policy，而不是绕过唯一约束。

### DATA-005：多模型流水线元数据

analysis_runs.model_id 和 prompt_version 不能代表一次可能使用多个模型/提示词的完整工作流。

调整建议：
- run 保存 pipeline_version、execution_profile、input_hash、requested_options、input_manifest。
- step 保存 provider、model_id、prompt_template_id、prompt_version、schema_version、input/output token、latency_ms、attempt_count、lease_owner、lease_expires_at、heartbeat_at。
- run 保留汇总用量和状态，但汇总值由 step 聚合，避免人工写入不一致。

### DATA-006：scope_id 多态外键

artifacts.scope_type + scope_id 无法由数据库验证目标存在且属于同一 work。

推荐用显式可空外键列替代：
- scope_chapter_id
- scope_entity_id
- scope_plotline_id
- scope_outline_set_id

根据 scope_type 使用 CHECK 约束，要求恰好一个正确的 scope 字段非空；work scope 时全部为空。若后续 scope 类型增长较多，再评估独立 artifact_scopes 表。

### DATA-007：证据锚点验证

evidence_anchors 增加 work_id、split_version_id、verification_status、verified_at、verification_error；通过复合外键保证 claim 与 chapter 属于同一作品/切分版本。

start_char/end_char 必须在应用层与 chapter.content_text 长度比较；quote_text 必须等于指定区间，quote_sha256 必须匹配。数据库 CHECK 不能直接跨表校验内容长度。

## 3. P1 应修正

- analysis_run_steps 增加 lease、heartbeat、retry_after、attempt_count，支持崩溃恢复。
- artifacts 增加 created_by、reviewed_by、reviewed_at、content_hash 或 payload_hash；人工修改产生新 revision。
- analysis_claims 保留 epistemic_status 与 review_status 两个独立维度，不合并为单一状态。
- story_entities 合并操作必须同 work，保存 merge audit；避免自环和合并环。
- story_events 分离 narrative_order 与 story_time_label/story_time_sort_key。
- plotline_nodes 支持事件节点和章节节点，并明确其所属 work。
- outline_nodes 的父节点必须属于同一个 outline_set；重排时使用事务并避免唯一约束冲突。
- source_chapters 的 content_char_count 应等于 char_length(content_text)；全文偏移和局部文本偏移分别命名。
- 所有哈希字段统一 SHA-256 小写十六进制格式，并由应用校验长度和字符集。
- 关键状态变更写入 audit log，而不只依赖 updated_at。

## 4. P2 暂不加入

- 不为每个 JSON 字段创建独立关系表。
- 不在首期引入专用图数据库。
- 不引入全量 event sourcing。
- 不为模型每个 token 或每个中间思考步骤保存无业务价值的数据。
- 不提前实现复杂的实时协同编辑。
- 不将全部正文放入 JSONB；原文用对象存储和章节文本访问接口。

## 5. 字段分层原则

关系列：用于过滤、排序、JOIN、唯一性、权限和生命周期的稳定字段。

JSONB：仅用于模型输出中可变、特定 artifact 才使用的属性；必须带 schema_version 并经过服务端校验。

派生字段：例如 char_count、payload_hash、汇总 token 数可以存储以提高查询效率，但必须由服务端计算并有一致性测试。

审计字段：created_at、updated_at、created_by、reviewed_by、reviewed_at、revision。时间由服务端生成，不信任客户端时间。

## 6. 定稿前验证清单

- 空库执行 up。
- 测试跨 work 外键拒绝非法关联。
- 测试 source/split/version 错配被拒绝。
- 测试证据偏移越界、引用不匹配和 Unicode 字符处理。
- 测试任务重复提交、worker 崩溃和过期 lease。
- 测试 outline node 跨树 parent 被拒绝。
- 执行 down 后确认无遗留对象。
- 对每个字段确认其使用者：UI、API、Worker、查询、审计或约束；无使用者的字段应删除或明确为预留字段。


### DATA-008：拆分 canonical entity/event 与 source mention

人物/事件本体是 work 级对象；原文中的每次出现是 source/split/chapter 级 mention。删除 story_entities.first_seen_chapter_id，以及 story_events.chapter_id/narrative_order/story_time_label 这类依赖单一版本的字段。新增 entity_mentions、event_mentions，保存 surface form、chapter、split version、局部顺序、叙事顺序、故事内时间和可选文本范围。故事线节点支持 canonical event（适用于原创计划事件）和 event mention（适用于已存在文本中的具体出现）；同时绑定 event mention 时必须校验其 canonical event 与 split version 一致。需要跨版本统计时聚合 canonical event。

### DATA-009：Artifact scope 使用显式外键

scope_type + scope_id 是无法由数据库完整校验的多态引用。SQL 草案改用 scope_chapter_id、scope_entity_id、scope_plotline_id、scope_outline_set_id，并通过 CHECK 约束要求与 scope_type 一一对应。chapter scope 必须同时绑定相同 split version。新增 scope 类型时必须更新 CHECK、外键、API DTO 和测试。

### DATA-010：审计日志与 owner 事实来源

项目角色以 project_members 为唯一来源，owner 角色通过唯一部分索引限制每项目最多一位；创建项目和 owner membership 在同一事务完成。不在 ASK 数据库建立竞争性的 audit_events 主表。关键变更与业务数据同事务写入 integration_outbox，再投递到 auditx；outbox 保存脱敏事件 payload 和投递状态，不保存整本正文或密钥。
