# 安全、隐私与运维设计

状态：Draft

## 1. 身份认证与授权

- 身份认证通过 Casdoor OIDC 和现有可信网关/IAM 获取 Principal。
- ASK 的 app_users 是内部主体映射/展示投影，不是密码或独立身份目录；iam_subject_id 对应可信 IAM subject。
- 项目角色首期为 owner/editor/viewer，产品成员关系保存在 project_members。
- 运行时资源授权通过统一 Authorizer/IAM 调用 SpiceDB；业务模块不直接依赖 Casdoor/SpiceDB SDK。
- 所有 API 执行对象级授权；前端隐藏按钮不构成安全控制。
- 对象查询必须在服务端限定项目范围，防止 IDOR。
- 默认 fail-closed；授权服务不可用、关系投影不一致或 Principal 缺失时拒绝敏感操作。
- project_members 变更在同一数据库事务写入 integration_outbox，再投影到 SpiceDB。授权关系同步失败时重试，不能静默丢失。

## 2. 审计

- auditx 是审计事实源；ASK 不维护另一套竞争性的 audit_events 主表。
- 关键变更与业务数据在同一事务中写入 integration_outbox，再由 publisher 调用 auditx。
- 审计事件包含真实 Principal、action、resource、request_id、结果和脱敏变更摘要。
- outbox payload 不保存完整小说正文、密钥或完整模型上下文。
- 发布失败进入 retryable_failed/dead_letter 并告警；审计类事件不可静默丢弃。

## 3. 文件导入安全

- 白名单校验媒体类型和扩展名；文件名仅作展示，不作为路径。
- 配置最大文件大小、单项目存储配额、单用户并发上传数和解析超时。
- 对 EPUB/压缩格式防范路径穿越、压缩炸弹和异常嵌套；首期 TXT 优先。
- 文件通过 metastoragex/objectstorex 抽象存取；业务代码不直接持有 MinIO/S3 管理凭证。
- 对象默认私有，下载原文件需再次授权。
- 原始文件哈希用于完整性和重复检测，不作为权限凭证。

## 4. 文本与模型数据保护

- 默认不在应用日志中记录完整正文、完整提示词或模型原始上下文。
- 日志记录 run ID、step key、资源 ID、模型路由、耗时、token 用量和错误码。
- 模型调用统一经 new-api；项目配置只保存逻辑 model route，不存第三方供应商密钥。
- 私有部署场景将敏感作品路由到内网模型；未授权时不得向外部 API 发送正文。
- embedding/rerank 请求同样遵守项目权限和数据发送策略。
- 数据导出、永久删除和备份清理需要明确流程；删除操作同时清理对象存储、索引和缓存。

## 5. 版权与使用边界

- 上传者必须拥有或获得处理文本的适当授权。
- 已出版作品与原创作品需要区分来源和权利状态。
- 不默认提供整本受版权保护作品的公开分享或全文再分发。
- 证据展示遵循最小必要引用原则；引用长度和导出策略可配置。
- 本文是技术控制建议，不替代具体司法辖区的法律审查。

## 6. 密钥和配置

- PostgreSQL、Redis、对象存储、new-api 和内部服务凭证使用环境注入或密钥管理系统。
- 不把生产密钥提交到 Git、前端 bundle 或日志。
- 配置区分 local/test/staging/production；敏感配置不允许通过普通 API 回显。
- 提示词模板可以版本化，但不得将密钥硬编码进模板。

## 7. 任务与成本保护

- 设置每用户/每项目并发 run 上限。
- 设置每个 run 的章节数、最大 token、最大重试、最大执行时间和成本预算。
- new-api 配额和 ASK 业务配额双层约束；避免绕过平台配额。
- 连续失败、模型限流和服务不可用采用退避；避免重试风暴。
- 用户取消任务后不再启动新阶段。
- 管理员可暂停队列和禁用特定 model route。

## 8. 备份与恢复

- PostgreSQL 定期备份并验证恢复。
- Redis 不作为业务事实源；丢失后应能从 PostgreSQL run/step 和 integration_outbox 重建待处理任务。
- 对象存储启用版本或不可变备份策略（按部署能力）。
- 恢复后验证对象 key、source hash、artifact/run 关系和 outbox backlog。
- 生产迁移前备份并在 staging 执行相同脚本。

## 9. 可观测性

指标：
- API 请求量、错误率、P95 延迟。
- 上传和解析成功率。
- analysis run/step 状态、队列年龄、lease 过期数。
- outbox pending/failed/dead-letter 数量与最老事件年龄。
- Authorizer/SpiceDB 检查延迟、拒绝率和关系投影失败率。
- new-api 请求成功率、延迟、token、费用和 schema 验证失败数。
- evidence verification 通过率和 unsupported claim 比例。
- PostgreSQL 连接池、慢查询、Redis 和对象存储错误。

告警：
- 任务队列持续积压。
- worker heartbeat 停滞。
- outbox 持续积压或 dead-letter 增长。
- 授权投影失败或审计投递失败。
- 模型连续失败或成本异常。
- 证据验证率显著下降。
