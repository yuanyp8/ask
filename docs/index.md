# ASK 设计文档索引

状态：Draft。设计阶段所有文档都需要评审，详见本文件的文档规范。

## 产品与需求

- [文档工程规范](README.md)
- [平台能力地图](requirements/01-platform-capabilities.md)
- [核心用户旅程与异常流程](requirements/02-user-journeys.md)
- [平台功能拆解与验收矩阵](requirements/03-functional-decomposition.md)
- [平台模块详细设计](requirements/04-module-design.md)
- [需求—设计—实现追踪矩阵](requirements/05-traceability-matrix.md)

## 架构与详细设计

- [00 产品范围与 MVP](architecture/00-product-scope.md)（第一轮草案）
- [01 核心领域模型](architecture/01-domain-model.md)（第一轮草案）
- [02 PostgreSQL 数据模型](architecture/02-data-model.md)（第一轮草案）
- [03 异步分析流水线](architecture/03-analysis-pipeline.md)（第一轮草案）
- [04 REST API 契约](architecture/04-api-contract.md)（第一轮草案）
- [05 实施路线图](architecture/05-implementation-roadmap.md)（第一轮草案）
- [06 系统架构详细设计](architecture/06-system-architecture.md)
- [07 数据模型字段评审与优化](architecture/07-field-review.md)
- [08 AI 分析产物 Schema](architecture/08-analysis-artifact-schemas.md)
- [09 API 详细设计](architecture/09-api-detailed-design.md)
- [10 前端工作台设计](architecture/10-frontend-workbench.md)
- [11 AI 分析引擎](architecture/11-ai-analysis-engine.md)
- [12 安全、隐私与运维](architecture/12-security-privacy-operations.md)
- [13 测试策略与验收](architecture/13-test-and-acceptance.md)
- [14 架构决策记录](architecture/14-architecture-decisions.md)
- [15 核心数据字典](architecture/15-data-dictionary.md)
- [16 领域状态机与生命周期](architecture/16-domain-workflows.md)
- [17 部署架构](architecture/17-deployment-architecture.md)
- [18 数据库查询模式与索引设计](architecture/18-query-patterns-and-indexes.md)
- [19 阅读导师与原创创作域详细设计](architecture/19-reading-writing-domain.md)
- [20 共享平台集成契约](architecture/20-shared-platform-integration.md)
- [21 Transactional Outbox 详细设计](architecture/21-outbox-delivery.md)

## 数据库迁移

- [000001 初始化 schema](../migrations/000001_init_core.up.sql)
- [000001 回滚 schema](../migrations/000001_init_core.down.sql)

## 当前阶段说明

当前处于需求分析和详细设计阶段。文档与 SQL 均为可评审草案，不代表已通过实现验证。进入编码前应完成：
1. 需求范围和验收标准评审。
2. 字段字典、关系约束和版本规则评审。
3. SQL up/down 在 PostgreSQL 测试实例上的验证。
4. API DTO 与 artifact schema 定稿。
5. 文档间需求 ID 和变更影响追踪检查。

## 文档变更要求

字段/状态/关系变化必须同步数据字典、SQL、API、分析 schema 和测试；功能变化必须同步能力地图、用户旅程、功能拆解、API 和验收。任何未决问题必须显式列在文档中，不得用实现中的临时约定代替设计决策。
