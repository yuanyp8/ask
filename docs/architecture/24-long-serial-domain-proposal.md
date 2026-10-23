# 超长连载领域模型：概念字段与分析契约

状态：Draft · 特别说明：**领域提案，不是当前 000001 SQL 已完成字段清单**。先验证方法，确认后再起后续迁移。

## 1. 设计目标

现有核心表（works/source_versions/split_versions/source_chapters/story_entities/entity_mentions/story_events/event_mentions/plotlines/outline_sets/artifacts/claims/evidence）足以承载首期基础抽取，但要支持百万字网文的跨卷线索、阶段目标、资源/知识状态、连载截止章，还需补充显式的领域概念。不要一次把所有候选概念变成独立数据库表：先确定最小可靠数据、工作流和查询，再评审迁移。

## 2. 语义层级

- Work：整本小说。
- SourceVersion/SplitVersion：输入和章节的不可变版本。
- Volume：卷、部、篇等文本组织单元。
- Arc：跨多个章节的语义单元，可跨 Volume。
- Chapter：确定的文本组织单元。
- Scene/Beat：场景候选与节拍候选，可有原文范围。
- CanonicalEntity / Mention：人物与具体提及。
- CanonicalEvent / EventMention：事件及其一次叙述出现。
- Plotline：跨章节/卷的持续问题、目标或冲突。
- Thread：可被建立、重述、强化、误导、重解释或兑现的长期线索。
- StateDelta：某个人物、组织、资源、知识或关系随事件发生的变化。
- NarrativeObservation：视角、信息揭示、叙事/故事时间差异。
- AnalysisSnapshot：一个 cutoff、输入版本和分析选项组合。

特别约束：Volume、Arc、Plotline 不是同一对象。Volume 绑定章节的组织边界；Arc 绑定阶段问题和相对结算；Plotline 贯穿多个 Arc/Volume 并可能交叉。

## 3. 建议新增的逻辑对象（尚未迁移）

### serial_analysis_snapshots
- id、work_id、source_version_id、split_version_id、analysis_run_id。
- cutoff_chapter_no、analyzed_through_chapter_no、view_mode (reader_safe/full_spoiler)。
- publication_snapshot_key（可空，仅在有可信发行版本信息时）。
- analysis_profile / pipeline_version / schema_version / created_at。
- 约束：analyzed_through <= cutoff；引用的正文/mention/事件必须属于绑定版本且 chapter_no <= cutoff。
- **不能仅靠后端最终渲染隐藏结果**：模型上下文组装、检索、查询、缓存和导出全链路都要严格限定 cutoff。

### volumes
- id、work_id、split_version_id、title、volume_no、start_chapter_no、end_chapter_no、origin_type、review_status。
- 卷编号/章范围在 split version 内有效。
- 手工与模型候选分开；允许文本没有卷。

### narrative_arcs / arc_event_links
- id、work_id、arc_key、title、goal、opposition、start_condition、ending_condition、outcome、status、confidence、review_status。
- arc_event_links：event_id、event_mention_id（可空）、role、position、evidence reference。
- 单个 Arc 可以跨卷；单个事件可以服务多个 Arc。

### narrative_threads / thread_occurrences
- id、work_id、thread_key、kind、question_or_promise、status、created_scope、review_status。
- occurrence：thread_id、event_mention_id/anchor、chapter_no、role（introduced/reinforced/misdirected/partly_paid_off/paid_off/reinterpreted）、epistemic_status。
- 线索没有被确认回收时，status=open/unknown；作品 ongoing 不直接判失败。
- 同一线索可以有多个互斥解释，保留 alternative hypothesis。

### entity_state_deltas
- id、work_id、entity_id、event_id、property_namespace（goal/ability/resource/relationship/knowledge/location/status 等）。
- property_key、before_value、after_value、effective_story_time、revealed_at_chapter、evidence、epistemic_status、review_status。
- 状态变化有事件来源；允许 unknown/unreliable，不强行给每章写全量状态。
- “某角色在第100章知道 X”与“读者在第100章知道 X”不能当成同一记录。

### world_rules / rule_observations
- rule_id、scope、statement、known_by、constraints、cost、exceptions、status、evidence。
- 记录规则何时确立、谁知道、何时出现有证据的例外或冲突。
- 允许“疑似规则不一致”，但不能一看到例外就自动认定战力崩坏。

### reader_promises / promise_movements（可与 narrative_threads 共用基础模型）
- 一个长期读者期待何时建立、得到局部反馈、延迟兑现或被重新解释。
- 是文学分析候选，不要求客观“爽点评分”；与作者在作品中的明确承诺分开。

## 4. API 查询语义（概念契约）

- GET /works/{id}/serial-dashboard?cutoff_chapter=...
- GET /works/{id}/volumes?split_version_id=...
- GET /works/{id}/arcs?cutoff_chapter=...
- GET /works/{id}/threads?status=open&cutoff_chapter=...
- GET /threads/{id}/timeline?cutoff_chapter=...
- GET /entities/{id}/state?cutoff_chapter=...
- GET /works/{id}/resource-deltas?cutoff_chapter=...
- GET /works/{id}/serial-structure?view=volume|arc|plotline&cutoff_chapter=...
- POST /works/{id}/analysis-runs（提供 analysis_frontier 和 profile）
- POST /threads/{id}/review / POST /arcs/{id}/review（概念接口，具体状态转换需详设）

服务端强制同 work/source/split、一致授权和 cutoff；前端传递值只代表请求意图，不能绕过服务端权限与版本检查。

## 5. 分析上下文与知识隔离

### 每章分析输入
- 当前章节完整可处理片段；分块时保留上下文重叠和块级证据定位。
- 当前截止章以内的角色状态、相关 Arc/Thread、世界规则和短期前情。
- 当前分析 profile 和成本预算。
- 不允许从“整本书 RAG”取回 cutoff 之后的任何正文或其衍生摘要。

### 分层综合
Chapter/scene extraction → entity resolution / state deltas → arc consolidation → volume synthesis → thread/payoff linking → book-long engine synthesis.

### 增量更新
新章进入 → 产生新分析快照或扩展 frontier → 仅处理新增/受影响章 → 更新相关人物状态、Arc、Thread、卷综合与全书视图。历史 cutoff 快照保留不可变引用；全书结果不能覆盖之前“截至第 N 章”的认知快照。

## 6. 幂等与一致性

- Thread occurrence 唯一键建议由 split_version + anchor/mention + thread_key + role 组成，需评审实际冲突场景。
- 同一章节重新分析时保留以前的 artifact/revision，新的候选按稳定键复用或建立 revision。
- 章节切分变化产生新 split version，旧原文证据不静默重新绑定。
- 合并人物/事件时预览关联 Threads/Arcs/StateDeltas 的影响。
- 编辑 Arc/Thread 后，只重算下游依赖的卷/全书综合，不改变原文事实。

## 7. 按验证结果渐进实施

- **Phase 0**：用现有章节、人物、事件、关系、证据和 Artifact JSON 输出验证一卷和跨卷线索，保留候选结构与人工审核。
- **Phase 1**：当验证需要可检索跨卷生命周期时，正式添加 volumes/arcs/threads/occurrences 与 cutoff 快照。
- **Phase 2**：当资源/能力和信息差分析质量达标后，引入 state_deltas/world_rules/reader_promises 的结构化存储。
- **Phase 3**：原创设计复用这些对象的 planned 模式，再实现正文版本与自动改写。

这里所有表/接口仅是设计建议，不代表已写入 migrations、API 或前端。