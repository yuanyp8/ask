# 共享平台集成契约

状态：Draft

## 1. 集成原则

ASK 只实现小说领域能力。认证、授权、审计、模型路由和对象存储均通过内部 adapter contracts 访问现有平台。业务模块依赖接口，不直接依赖平台 SDK 或具体供应商协议。

## 2. 身份 Principal

API 从可信网关/认证中间件取得 Principal，至少包含：
- subject_id：稳定 IAM subject。
- tenant/org context（如果上游提供且当前操作需要）。
- authentication method / session assurance（高风险操作按策略使用）。
- request_id / trace_id。

请求体中的 user_id、role、org_id 不能覆盖可信 Principal。app_users.iam_subject_id 是本地映射键，不是认证凭据。

## 3. 资源命名与授权动作

资源 URN 采用稳定、可版本化的命名：
- ask:project:<project_id>
- ask:work:<work_id>
- ask:artifact:<artifact_id>
- ask:outline:<outline_set_id>

动作建议：
- project.read / project.manage
- member.read / member.manage / ownership.transfer
- work.read / work.edit / work.archive
- source.upload / source.download / source.confirm_split
- analysis.create / analysis.cancel / analysis.retry
- artifact.read / artifact.review / artifact.edit
- writing.read / writing.edit / writing.accept

统一 Authorizer 把动作映射到 SpiceDB permission/relation，不允许 handler 自行把 role 字符串解释成授权结果。资源归属仍由业务层校验；SpiceDB 检查不能替代 source/work/split 的数据一致性约束。

## 4. project_members 与 SpiceDB 同步

- project_members 保存 ASK 产品层成员与角色。
- 成员变更和 integration_outbox 写入同一个 PostgreSQL 事务。
- Outbox publisher 把关系写入/删除请求同步到 SpiceDB。
- 关系写操作使用 dedupe_key，消费者必须幂等。
- 关系投影成功后记录发布状态和外部响应摘要，不记录 token/secret。
- 授权检查始终 fail-closed。对刚变更成员的高风险写操作，应等待关系投影成功，或使用上游支持的 consistency token / read-after-write 机制。
- outbox backlog 超阈值时告警；不能因同步失败自动绕过授权。

角色语义：
- owner：项目管理、成员管理和所有权转移。
- editor：修改作品、分析审核和创作内容。
- viewer：只读访问。
- owner 不能直接被移除；先在一个事务中调整旧 owner 角色、授予新 owner，并写出关系同步事件。

## 5. auditx

auditx 是审计历史的权威来源。ASK 发送事件至少包含：
- event_id / dedupe_key。
- actor subject、action、resource type/id。
- project/work context。
- result、reason/error code、request_id、trace_id、occurred_at。
- 脱敏的 before/after summary。

不得发送整本正文、完整提示词、模型原始上下文、访问令牌或对象存储凭证。业务事务先写 integration_outbox，再由 publisher 投递。审计投递失败必须重试和告警。

## 6. new-api 模型网关

ModelGateway 输入：
- logical_model_route。
- task type、system/user messages 或结构化 input。
- output schema / response format。
- token budget、timeout、request ID、trace ID。

输出：
- normalized response payload。
- gateway request ID。
- resolved route/model ID（如果返回）。
- input/output token、latency、finish status。
- provider-neutral error category。

ASK 记录每个 run step 的 route/model/prompt/schema 版本和用量。new-api 管理供应商密钥、模型路由、供应商级重试与平台配额；ASK 管理业务任务、成本上限、结果验证和业务级重试。不要在 ASK 再实现一个通用模型供应商管理平台。

Embedding 与 rerank 同样经过网关；向量索引记录 embedding model/version，模型切换后不能把不同 embedding space 的向量混用。

## 7. metastoragex/objectstorex

业务存储接口支持：
- Put immutable object。
- Head/stat、读取流、下载授权 URL（如平台支持）。
- Delete/retention workflow。
- Checksum 和对象元数据。
- 按 logical storage profile 路由。

ASK 保存逻辑 storage key，不把 bucket、endpoint、secret 拼进业务对象。原始文件和规范化全文使用不可变 key；文件下载前检查权限。

## 8. Redis 使用边界

允许：
- worker queue/wakeup。
- 运行时锁和短期 lease 辅助。
- 缓存。
- SSE/流式 token 的短期恢复。
- 限流计数（如已确定策略）。

禁止：
- 只在 Redis 保存唯一 run/step 状态。
- 只在 Redis 保存待投递的审计或授权关系变更。
- Redis 清空后无法恢复已接受任务。

## 9. 故障策略

- Authorizer/SpiceDB 不可用：敏感读写 fail-closed；公开健康检查不泄漏资源数据。
- auditx 不可用：业务变更可在事务 outbox 中持久化；达到积压阈值时按风险策略暂停高风险写操作。
- new-api 不可用：run step 进入可重试失败，使用退避和配额。
- object storage 不可用：导入/下载返回可重试错误；不得生成 ready source version。
- Redis 不可用：API 可按策略拒绝新的高成本任务；已有任务从 PostgreSQL 恢复，不能丢失。
