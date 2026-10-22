# 需求—设计—实现追踪矩阵

状态：Draft

## 1. 追踪原则

每个功能需求至少映射到：业务模块、核心数据、API、前端入口和验收测试。尚未实现的 API 或表应标记为 Planned，不得误标为已完成。

| 能力/需求 | 模块 | 数据对象 | API 设计 | UI 设计 | 验收依据 |
|---|---|---|---|---|---|
| CAP-01 / FR-PROJ-001 | 项目与作品 | projects, project_members, works, project_works | 09 API：项目与作品 | P-01 | TEST-PROJ-* |
| CAP-02 / FR-SRC-001 | 原文导入 | source_documents, source_versions | 09 API：文件导入 | P-02 | TEST-SRC-* |
| FR-SRC-003–006 | 章节切分 | split_versions, source_chapters | 09 API：切分版本 | P-02、P-04 | TEST-SPLIT-* |
| CAP-07 / FR-ANL-001 | 任务中心 | analysis_runs, analysis_run_steps | 09 API：分析任务 | P-01、任务详情 | TEST-RUN-* |
| CAP-03 / FR-ANL-002 | 章节细纲 | artifacts, analysis_claims, evidence_anchors | 09 API：产物与证据 | P-03、P-04 | TEST-ANALYSIS-* |
| FR-ANL-003 | 实体消歧 | story_entities, entity_aliases, entity_mentions | 09 API：人物与提及 | P-05 | TEST-ENTITY-* |
| FR-ANL-004 | 事件提取 | story_events, event_mentions, event_relations | 09 API：事件 | P-05、P-06 | TEST-EVENT-* |
| FR-ANL-005 / FR-ANL-007 | 主线支线/伏笔 | plotlines, plotline_nodes, event_relations | 09 API：故事线 | P-06 | TEST-PLOT-* |
| FR-ANL-006 | 大纲树 | outline_sets, outline_nodes | 09 API：大纲 | P-07 | TEST-OUTLINE-* |
| CAP-04 / FR-REV-* | 证据审核 | artifacts, claims, anchors, audit_events | 09 API：审核 | P-04、P-05 | TEST-REVIEW-* |
| CAP-05 / FR-READ-* | 阅读导师 | Planned: reading_progress, reading_notes, quiz_attempts | 后续 API 详设 | P-08 | Planned |
| CAP-06 / FR-WRITE-* | 小说创作 | Planned: canon_items, manuscript_versions, manuscript_chapters | 后续 API 详设 | P-09 | Planned |
| CAP-08 | 检索与知识库 | source chapters, entities, events, evidence | Internal retrieval contract | 阅读/拆书/创作工作台 | TEST-RETRIEVAL-* |
| CAP-09 / NFR-SEC-* | 安全与运维 | project_members, audit_events, run/step metadata | 全部 API | 全局权限/任务状态 | TEST-SEC-*, TEST-OPS-* |

## 2. 测试 ID 约定

- TEST-PROJ：项目、成员和权限。
- TEST-SRC：文件上传、hash、规范化版本。
- TEST-SPLIT：章节边界、Unicode offsets、切分版本。
- TEST-RUN：幂等、重试、取消、lease 恢复。
- TEST-ANALYSIS：模型 schema、章节分析、证据验证。
- TEST-ENTITY：mention resolution、merge/split、跨 work 防护。
- TEST-EVENT：事件聚合、叙事顺序和故事时间。
- TEST-PLOT：主线支线、节点顺序和伏笔状态。
- TEST-OUTLINE：树结构、版本、移动与排序冲突。
- TEST-REVIEW：审核状态、审计和版本比较。
- TEST-SEC：鉴权、越权访问、上传安全。
- TEST-OPS：备份、恢复、监控和成本保护。

## 3. 设计变更审查清单

每个 PR 必须回答：
1. 修改/新增了哪些 CAP/FR/BR/NFR？
2. 哪些数据对象或字段变化？
3. 哪些 API DTO 和页面受影响？
4. 哪些状态机/权限规则受影响？
5. 哪些自动化测试和人工验收样本更新？
6. 是否影响历史数据、版本兼容或迁移？
7. 是否影响模型 token 成本、延迟或证据质量？
