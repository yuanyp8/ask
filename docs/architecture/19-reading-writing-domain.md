# 阅读导师与原创创作域详细设计

状态：Draft（后续阶段设计，不纳入首期 core migration）

## 1. 为什么单独建域

阅读行为属于用户与某个源版本之间的个人状态；原创写作属于创作者对计划、Canon 和正文版本的持续修改。两者不能直接复用 published-source 的 immutable chapter 语义。

## 2. 阅读域建议模型

### reading_progress
- id、user_id、work_id。
- source_version_id、split_version_id。
- chapter_id、char_offset、updated_at。
- unique(user_id, work_id, split_version_id)；版本变化后由用户确认是否映射进度。

### reading_sessions
- id、user_id、work_id、source_version_id、split_version_id。
- started_at、ended_at、last_chapter_id、session_summary。
- 记录阅读会话和回顾，不把模型回答当作用户阅读事实。

### reading_notes
- id、user_id、work_id、split_version_id、chapter_id。
- start_char/end_char 可空；note_type、content、tags、created_at、updated_at。
- 笔记属于用户；模型重新分析不应覆盖笔记。
- 版本切换后，原笔记保留原版本定位，并提供人工迁移/重新定位功能。

### tutor_interactions
- id、user_id、work_id、split_version_id、chapter_id。
- question、answer_summary、context_manifest、model/run reference、created_at。
- 首期可以只保留用户主动保存的问答，避免无节制保存全部聊天上下文。

### quiz_attempts
- id、user_id、work_id、artifact_id 或 quiz_id。
- answers、score、feedback、completed_at。
- 测验题目和评分标准要版本化，模型变更不应改变已完成测验记录。

## 3. 阅读导师流程

1. 读取用户当前 work/source/split/chapter。
2. 根据问题类型选择章节证据、前文摘要、人物/事件关系和用户笔记。
3. 对上下文做权限过滤和 token 预算。
4. 生成回答及引用候选。
5. 服务端验证引用。
6. 展示“原文事实/推断/不确定”，允许保存笔记或继续追问。
7. 若证据不足，明确说明无法从当前文本确认，而不是补写事实。

## 4. 创作域建议模型

### canon_items
- id、work_id、canon_type、canon_key、title、content。
- status：proposed / accepted / deprecated。
- priority、effective_from_chapter_id（可空）、attributes。
- revision、created_by、reviewed_by、created_at、updated_at。
- Canon 的 accepted 事实优先于模型生成的未确认候选。

### manuscript_versions
- id、work_id、version_no、base_version_id、status。
- change_summary、created_by、created_at。
- 状态：draft / in_review / accepted / archived。
- 每个 accepted 版本不可原地修改。

### manuscript_chapters
- id、work_id、manuscript_version_id、chapter_no、title、content_text、content_sha256、word_count。
- unique(manuscript_version_id, chapter_no)。
- 章节正文与 source_chapters 分开；创作正文有自己的版本生命周期。

### consistency_findings
- id、work_id、manuscript_version_id、chapter_id。
- finding_type、severity、description、evidence_span、related_canon_item_id、status。
- status：open / accepted / dismissed / fixed。
- 检查结果是建议，不自动改写正文。

## 5. 创作工作流

1. 创建 original work 和创作项目。
2. 设定题材、主题、核心冲突和约束。
3. 创建 Canon 和人物/地点/组织。
4. 创建 planned outline 和计划故事事件。
5. 人工确认全书/分卷/章节细纲。
6. 生成章节草稿，输入仅包含当前细纲、相关 Canon、前文摘要和必要事件/人物。
7. 对正文做结构、人物、时间、地点、因果和文风检查。
8. 用户修改/接受，产生新 manuscript version。
9. 只将已写入并确认的内容更新为发生事实；计划内容仍保留 planned 状态。

## 6. Canon 与大纲冲突策略

- 用户已接受的 Canon 不被模型静默覆盖。
- 若新大纲/正文与 Canon 冲突，产生 consistency finding。
- 用户可修改 Canon、修改大纲或接受有意的设定变更。
- 每次变更记录原因和版本，检查受影响章节。
- 计划事件、生成草稿事件和已接受正文中的事件必须能区分来源和状态。

## 7. 与核心域的边界

阅读进度/笔记不进入 story_entities；原创 Canon 不作为已出版原著事实；manuscript chapter 不直接伪装成 source_chapter。可共享证据锚点抽象和结构化事件/实体能力，但需保留内容来源与版本类型。
