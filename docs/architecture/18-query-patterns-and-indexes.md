# 数据库查询模式与索引设计

状态：Draft

## 1. 原则

索引根据真实查询模式设计，而不是为每个字段盲目建索引。关系表负责强一致查询，JSONB 不承担高频关联字段。上线后使用 EXPLAIN (ANALYZE, BUFFERS) 和慢查询统计迭代。

## 2. 高频查询

### 项目列表
条件：当前用户是 project_members 成员；按 updated_at/created_at 倒序。
索引候选：project_members(user_id, project_id)、projects(updated_at DESC)。
如果 owner 访问也通过 membership 记录，查询路径统一。

### 作品列表
条件：project_id，按 added_at 倒序。
索引：project_works(project_id, added_at DESC)；主键已覆盖 project_id + work_id。

### 章节列表
条件：split_version_id，按 chapter_no。
索引：source_chapters(split_version_id, chapter_no)。
章节正文按需读取，不在列表接口返回整本章节全文。

### 分析任务队列
条件：status IN queued/running，按 created_at 或 retry_after。
索引：analysis_runs(project_id,status,created_at DESC)；analysis_run_steps(run_id,status,sequence_no)。
任务领取需要使用短事务和适当锁定策略；避免 worker 长时间持有锁。

### 章节证据
条件：claim_id，或 chapter_id + start_char。
索引：evidence_anchors(claim_id)、evidence_anchors(chapter_id,start_char,end_char)。
读取时同时校验 artifact/claim/chapter 的 work 和 split version。

### 人物提及
条件：split_version_id + chapter_id + mention_start_char；或 work_id + entity_id + split_version_id。
索引：entity_mentions(split_version_id,chapter_id,mention_start_char) 和 entity_mentions(work_id,entity_id,split_version_id)。

### 事件与时间线
条件：split_version_id + narrative_order，或 work_id + event_id + narrative_order。
索引：event_mentions(split_version_id,narrative_order)、event_mentions(work_id,event_id,narrative_order)。
story_events 保存 canonical event；不要用其 UUID 顺序代替叙事顺序。

### 故事线节点
条件：plotline_id，按 position。
索引：唯一约束 plotline_nodes(plotline_id,position) 已覆盖。
### 大纲树
条件：outline_set_id + parent_id，按 position。
索引：outline_nodes(outline_set_id,parent_id,position)；根节点使用独立 partial unique index。

### 审计记录
条件：project_id 或 work_id，按 created_at 倒序。
索引：audit_events(project_id,created_at DESC)、audit_events(work_id,created_at DESC)。

## 3. 分页

- 对高频列表采用 cursor pagination，cursor 由排序键和唯一 ID 组成。
- 同一排序键下使用 id 作为稳定的 tie-breaker。
- 章节列表可以用 split_version_id + chapter_no 游标。
- 不允许通过客户端直接提交任意 SQL 排序字段。

## 4. 全文与向量检索

首期：
- 结构查询和关系表查询优先。
- 对章节内容建立 PostgreSQL 全文检索前，先验证中文分词效果。
- 若采用独立搜索引擎，需定义索引版本、删除同步、权限过滤和重建策略。
- 向量索引记录 embedding model/version、文本 chunk 版本和源锚点；模型变更必须重建或并行维护新索引。
- 检索结果必须能回到 source version、split version、chapter 和文本范围。

## 5. 观测和优化门槛

- 对超过阈值的查询记录 query fingerprint、耗时、rows、buffers，不记录正文参数。
- 先看查询计划和数据量，再决定增加索引或物化视图。
- 高写入表避免过多冗余索引。
- 每次 schema migration 后运行关键查询计划测试。
