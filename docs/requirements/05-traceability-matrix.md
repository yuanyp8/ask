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
| CAP-04 / FR-REV-* | 证据审核 | artifacts, claims, anchors, integration_outbox, auditx | 09 API：审核 | P-04、P-05 | TEST-REVIEW-* |
| CAP-05 / FR-READ-* | 阅读导师 | Planned: reading_progress, reading_notes, quiz_attempts | 后续 API 详设 | P-08 | Planned |
| CAP-06 / FR-WRITE-* | 小说创作 | Planned: canon_items, manuscript_versions, manuscript_chapters | 后续 API 详设 | P-09 | Planned |
| CAP-08 | 检索与知识库 | source chapters, entities, events, evidence | Internal retrieval contract | 阅读/拆书/创作工作台 | TEST-RETRIEVAL-* |
| CAP-09 / NFR-SEC-* | 安全与运维 | project_members, integration_outbox, IAM/SpiceDB, auditx, run/step metadata | 全部 API | 全局权限/任务状态 | TEST-SEC-*, TEST-OPS-* |
| FR-ANL-009 / FR-ANL-012 | 叙事时序与信息流 | event_mentions, event_relations, claims, evidence_anchors | 09 API：事件/证据 | 事件时间线、叙述顺序视图 | TEST-NARR-* |
| FR-ANL-010 | 事件因果图 | story_events, event_mentions, event_relations | 09 API：事件关系 | 因果图与证据侧栏 | TEST-CAUSAL-* |
| FR-ANL-011 | 主线/支线与线索账本 | plotlines, plotline_nodes, event_relations, artifacts | 09 API：故事线 | 故事线板、伏笔账本 | TEST-THREAD-* |
| FR-WRITE-001/002 | 原创小说设计 | works, story_entities, story_events, plotlines, outline_sets, outline_nodes | 09 API：创作设计（需补齐 DTO） | 创作简报、人物关系、事件图、大纲工作台 | TEST-DESIGN-* |

| FR-SERIAL-001/005 | 分卷与阶段目标 | Planned: volumes / narrative_arcs；现有 outline_sets/plotlines 可承载部分候选 | 概念 API 见 24 领域提案 | W02 卷地图、W09 连载节奏 | TEST-SERIAL-ARC-* |
| FR-SERIAL-002 | 长期线索账本 | Planned: narrative_threads / thread_occurrences；现有 claims/evidence/plotline 候选 | 概念 API 见 24 领域提案 | W05 线索账本 | TEST-SERIAL-THREAD-* |
| FR-SERIAL-003 | 人物/资源状态 | Planned: entity_state_deltas / world_rules | 概念 API 见 24 领域提案 | W06、W07 状态板 | TEST-SERIAL-STATE-* |
| FR-SERIAL-004 | 截止章与防剧透 | Planned: serial_analysis_snapshots；现有 run/source/split 作为基线 | 新增 cutoff 语义待详设 | W01–W10 全局截止章 | TEST-SERIAL-CUTOFF-* |
| FR-SERIAL-006 | 长篇原创设计 | planned outlines + planned events + arcs/threads | 概念 API 见 24 领域提案 | 原创网文设计工作台 | TEST-SERIAL-DESIGN-* |

## 2. 测试 ID 约定

- TEST-PROJ：项目、成员和权限。
- TEST-SRC：文件上传、hash、规范化版本。
- TEST-SPLIT：章节边界、Unicode offsets、切分版本。
- TEST-RUN：幂等、重试、取消、lease 恢复。
- TEST-ANALYSIS：模型 schema、章节分析、证据验证。
- TEST-ENTITY：mention resolution、merge/split、跨 work 防护。
- TEST-EVENT：事件聚合、叙事顺序和故事时间。
- TEST-PLOT：主线支线、节点顺序和伏笔状态。
- TEST-NARR：叙事顺序、故事时间、视角和信息揭示。
- TEST-CAUSAL：因果边、前置条件、促成/阻止关系和反例。
- TEST-THREAD：伏笔建立、强化、误导、回收与未解状态。
- TEST-DESIGN：创作简报、计划事件、人物动机、结构树和一致性诊断。
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
