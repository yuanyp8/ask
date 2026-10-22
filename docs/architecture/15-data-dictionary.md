# 核心数据字典

状态：Draft

本字典定义字段的业务语义。SQL 类型和约束以最终通过评审的 migration 为准；字段改名必须同步更新 API DTO、测试和本文件。

## 1. 通用字段约定

- id：UUID 主键，由服务端/数据库生成。
- created_at / updated_at：服务端 UTC 时间；updated_at 需要应用层或触发器维护。
- created_by / requested_by：可空用户 ID，表示系统任务时允许为空。
- status：有限状态集合，必须由状态机控制，不能接受任意字符串。
- metadata / attributes / options / manifest：JSONB，必须有明确 schema_version 或版本化定义。
- hash：SHA-256 小写十六进制字符串；区分原始字节 hash、规范化文本 hash 和引用 hash。
- revision/version_no：正整数，语义不同，不可混用。
- 所有字符范围使用零基、左闭右开 Unicode code point；数据库字符函数与应用语言实现必须经过 Unicode 测试。

## 2. 工作空间

### projects
- id：项目标识。
- name：必填展示名称。
- description：可选说明。
- project_type：research / writing / mixed。
- status：active / archived。
- created_at / updated_at。

成员角色以 project_members 为准，项目创建和 owner 成员创建必须原子完成。

### project_members
- project_id、user_id：联合主键。
- role：owner / editor / viewer。
- joined_at：加入时间。
- owner 唯一性由数据库 partial unique index 或等效约束保证。

### works
- id：作品标识。
- title：作品标题。
- work_type：published / original。
- language_code：BCP 47 语言标签，默认 zh-CN。
- genre：可空题材标签；复杂多标签后续可拆表。
- metadata：出版信息、作者、版权/许可状态等扩展信息，需 schema 约束。

### project_works
- project_id、work_id：联合主键。
- role：primary / reference / inspiration。
- added_at：关联时间。

## 3. 原文与版本

### source_documents
- id、work_id：文档与作品归属。
- original_filename：仅展示，不作为路径。
- media_type：服务端检测后的媒体类型。
- storage_key：私有对象存储键。
- sha256：原始上传字节的哈希。
- byte_size：原始字节数。
- status：uploaded / parsing / ready / failed / archived。
- created_by、created_at。
- 同一 work 的 sha256 唯一；重复上传默认复用已有 document，MVP 不支持同 work 显式副本。

### source_versions
- id、source_document_id、work_id。
- version_no：同一 source document 内递增。
- normalized_text_storage_key：规范化全文的不可变对象键。
- content_sha256：规范化全文 hash。
- parser_name / parser_version：解析器实现和版本。
- normalization_profile：换行、Unicode、空白、编码等规范化配置。
- created_at。
- 解析器/规范化规则变化必须产生新版本。

### split_versions
- id、source_version_id、work_id。
- version_no：同一 source version 内递增。
- split_config：识别规则、手工修正来源等。
- status：draft / confirmed / superseded。
- created_by、created_at、confirmed_at。
- confirmed 后不允许直接修改章节边界。

### source_chapters
- id、split_version_id、work_id。
- chapter_no：当前切分版本内从 1 开始的展示顺序。
- title：章节标题；无标题时使用稳定生成标签，不伪造原文标题。
- chapter_type：normal / prologue / epilogue / interlude / appendix / unknown。
- content_text：规范化全文对应的精确章节文本切片。
- source_start_char / source_end_char：在规范化全文中的区间。
- content_sha256：chapter content_text 的哈希。
- content_char_count：Unicode code point 数。
- 同一 split version 的 chapter_no 唯一；source range 合法且不应意外重叠。

## 4. AI 执行

### analysis_runs
- id、project_id、work_id：任务和授权范围。
- source_version_id、split_version_id：输入版本；非源文本任务允许为空。
- task_type：chapter_analysis / book_reverse_analysis / entity_resolution / plotline_synthesis / outline_generation / consistency_check / custom。
- status：queued / running / completed_with_warnings / succeeded / failed / cancelled。
- idempotency_key：防止重复创建 run。
- input_hash：服务端根据实际输入清单计算。
- input_manifest：章节 ID、版本、选项和输入依赖。
- requested_options：用户选择的分析项和语言。
- pipeline_version / execution_profile：流水线版本和模型路由配置。
- progress：展示用聚合进度，不能作为任务唯一事实来源。
- error_code / error_message / error_details：脱敏错误。
- requested_by、cancel_requested_at、heartbeat_at、created_at、started_at、finished_at。

### analysis_run_steps
- run_id、step_key：步骤归属和幂等键。
- sequence_no：执行顺序，不代表跨分支 DAG 的唯一拓扑关系。
- status：pending / running / succeeded / retryable_failed / terminal_failed / skipped。
- attempt_count：实际尝试次数。
- provider / model_id / prompt_template_id / prompt_version / schema_version：步骤级模型和模板信息。
- input_json / output_json：仅存必要摘要/引用，避免存储敏感全文。
- input_tokens / output_tokens / latency_ms：可用时记录。
- lease_owner / lease_expires_at / heartbeat_at：工作租约。
- error_code / error_message / started_at / finished_at。
- output_artifact_id：步骤产物，可空。

## 5. 分析产物与审核

### artifacts
- id、work_id。
- artifact_key：稳定逻辑键，例如 book-overview 或 chapter-outline:UUID。
- artifact_type：book_overview / chapter_analysis / entity_profile / plotline_analysis / outline_tree / technique_analysis 等。
- revision：同一 work + artifact_key 内递增。
- scope_type：work / chapter / entity / plotline / outline_set。
- scope 目标外键：应使用显式列和约束，不推荐无约束的 scope_id 多态引用。
- source_version_id / split_version_id：输入版本。
- payload_schema_version：payload 的 schema 版本。
- payload：结构化内容。
- rendered_markdown：可选的展示缓存，不作为唯一数据源。
- status：draft / in_review / accepted / rejected / superseded / stale。
- run_id：生成来源。
- supersedes_artifact_id：被此 revision 替代的产物。
- created_by、created_at。
- 原始生成和用户编辑应保留不同 revision。

### analysis_claims
- id、artifact_id、work_id。
- claim_key：同一 artifact 内的稳定幂等键。
- claim_type、claim_text。
- entity_id 或 event_id：可选的主要关联对象；不能通过未校验的自由文本代替关联。
- epistemic_status：explicit / inferred / speculative。
- review_status：unreviewed / accepted / rejected / edited。
- confidence：可选模型估计，范围 0–1，不等于真实性。
- attributes：类型特有的附加字段。
- reviewed_by、reviewed_at、created_at。

### evidence_anchors
- id、claim_id、work_id、split_version_id、chapter_id。
- anchor_kind：quote / span / chapter_context。
- start_char / end_char：章节局部字符范围。
- quote_text / quote_sha256。
- evidence_role：supports / challenges / context。
- verification_status：verified / invalid / unverified。
- verified_at、verification_error、created_at。
- 证据必须与 claim、chapter 和 split version 属于同一作品/版本。

## 6. 故事结构

### story_entities
- id、work_id。
- entity_type：character / location / organization / object / concept / other。
- canonical_name：展示主名称。
- normalized_name：用于检索和匹配的规范化名称。
- description：人工或模型生成的简介，需记录来源/审核状态。
- attributes：人物目标、弱点、秘密等类型扩展字段。
- status：active / merged / archived。
- merged_into_entity_id：仅 status=merged 时非空，必须同 work。
- created_at / updated_at。

### entity_aliases
- entity_id、work_id。
- alias、normalized_alias。
- alias_type：alternate_name / title / nickname / transliteration / unknown。
- 同一实体的 normalized_alias 唯一；同一作品内不同实体可拥有同名 alias，作为消歧候选。

### story_relations
- id、work_id、source_entity_id、target_entity_id。
- relation_key：服务端生成的稳定幂等键。
- relation_type：可扩展的关系类型，需统一字典。
- description、confidence、attributes。
- status：candidate / accepted / rejected / archived。
- 关系两端必须属于同一 work；关系证据单独关联。

### story_events
- id、work_id、event_key。
- event_type、summary。
- origin_type：source_analysis / planned / manual，表示对象最初的产生方式。
- attributes、status、created_at。
- 不保存单一 chapter_id 或 narrative_order；这些是具体文本版本中的出现位置，应存入 event_mentions。
- 事件去重键必须在同一 work 内稳定；不能用摘要字符串作为唯一身份。

### event_relations
- id、work_id、source_event_id、target_event_id。
- relation_type：causes / enables / precedes / foreshadows / reveals / contradicts / parallels / other。
- confidence、attributes、status。
- 时间先后不自动代表因果。

### plotlines / plotline_nodes
- plotlines：line_key、title、line_type、description、goal、resolution、confidence、status、attributes。
- line_type：main / subplot / character_arc / mystery / romance / theme / other。
- plotline_nodes：node_key、position、node_type、event_id、event_mention_id、split_version_id、chapter_id、summary、narrative_function。event_id 支持计划事件；event_mention_id 用于绑定特定源版本中的具体出现。
- node_type：setup / development / turning_point / convergence / payoff / closure / other。
- 节点至少关联事件或章节之一；关联对象必须同 work。

### outline_sets / outline_nodes
- outline_sets：work_id、title、outline_mode、version_no、source_version_id、split_version_id、status。
- outline_mode：reverse_analysis / planned_outline。
- outline_nodes：node_key、parent_id、node_type、title、summary、position、split_version_id、source_chapter_id、linked_event_id、attributes。源章节必须属于该 outline set 的 split version。
- node_type：book / volume / act / story_arc / chapter / scene / beat。
- parent 必须属于同一 outline_set；移动节点不能形成循环。
- accepted outline set 不原地修改，编辑时创建新草稿版本。

### entity_mentions
- id、work_id、entity_id、split_version_id、chapter_id。
- mention_key：本次 run 范围内的幂等键。
- surface_form / normalized_surface：原文称呼与规范化形式。
- mention_start_char / mention_end_char：章节局部字符范围。
- mention_role：name / alias / pronoun / title / reference / unknown。
- confidence、resolution_status、run_id、created_at。
- mention 是某个具体版本中的观察，不是 canonical entity 的替代物。

### event_mentions
- id、work_id、event_id、split_version_id、chapter_id。
- mention_key、local_order、narrative_order。
- story_time_label / story_time_sort_key：来源版本中的故事内时间描述及可选排序值。
- mention_start_char / mention_end_char：可选的章节局部范围。
- confidence、status、run_id、created_at。
- 同一 canonical event 可在不同 split version 中有多个 mention；排序值不得放在 canonical story_events 上。

### audit_events
- id、project_id、work_id、actor_id。
- action、resource_type、resource_id。
- change_summary：脱敏的变更摘要，不保存完整正文。
- request_id、created_at。

## 7. 后续域

阅读：reading_progress、reading_notes、reading_sessions、quiz_attempts。进度需关联 work 和具体 split/source version。

创作：canon_items、manuscript_versions、manuscript_chapters、consistency_findings。Canon 状态应区分 proposed/accepted/deprecated；正文版本与计划大纲分离。

## 8. 尚需评审的字段

- 如需支持同 work 内显式重复副本，需设计独立 duplicate policy；当前 MVP 采用 work_id + sha256 唯一约束。
- 章节内容是否始终在 PostgreSQL 保存，或未来改为按需读取对象存储。
- artifact scope 是否用显式外键列，或独立 scope 关联表。
- run progress 是持久化聚合值还是通过 step 状态实时计算。
