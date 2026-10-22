# Transactional Outbox 与外部副作用投递

状态：Draft

## 1. 目标

确保业务事务提交后，SpiceDB 关系同步、auditx 审计和检索索引事件不会因进程崩溃或外部服务故障而永久丢失。

## 2. 原子写入

在一个 PostgreSQL 事务中：
1. 验证 Principal、资源归属和当前 revision。
2. 修改业务数据。
3. 插入 integration_outbox 事件，包含 dedupe_key、event_type、aggregate、schema_version 和脱敏 payload。
4. 提交事务。

不得在此事务内调用 SpiceDB、auditx、new-api 或对象存储网络接口。

## 3. Outbox 状态

- pending：等待发布。
- publishing：被 worker 领取，具有 lease。
- published：外部服务确认成功。
- retryable_failed：暂时失败，等待 available_at。
- dead_letter：超过重试策略或不可恢复，需人工处理。

发布成功必须记录 published_at。worker 崩溃后，lease 过期的 publishing 事件可以重新领取。

## 4. 领取与并发

建议使用短事务：
- 选择 status=pending/retryable_failed 且 available_at <= now() 的事件，或 lease 已过期的 publishing 事件。
- 使用 FOR UPDATE SKIP LOCKED 防止多个 worker 领取同一行。
- 更新 status、lease_owner、lease_expires_at、attempt_count。
- 提交事务后调用外部服务。
- 成功后用短事务标记 published；失败后更新错误码、available_at 和状态。

不要在网络调用期间持有数据库行锁。需要租约续期时更新 lease_expires_at；过期 worker 即使返回，也必须检查 lease owner/version 后再提交结果。

## 5. 投递语义

Outbox 提供 at-least-once，不承诺 exactly-once。外部调用可能成功但 ACK 丢失，因此每个 consumer 必须按 dedupe_key 幂等。

- SpiceDB：重复关系写入/删除应产生同样的最终关系状态。
- auditx：使用稳定 event_id/dedupe key 去重，避免重复审计记录。
- retrieval：索引操作按 work/source/split/artifact revision 版本化，旧事件不得覆盖更新版本。
- consumer 处理顺序不能只依赖 created_at；同一 aggregate 的关键事件可增加 aggregate_sequence 或 version guard。

## 6. 重试策略

- 网络超时、HTTP 429、5xx：可重试，指数退避并加随机抖动。
- 无效 payload、schema 版本不支持、权限/配置错误：按策略进入 dead_letter，避免无限重试。
- attempt_count 达上限后转 dead_letter，产生告警。
- 重试时保留原始 dedupe_key；人工重放应记录 operator、reason 和重放次数。
- 不允许通过删除 outbox 行“解决”积压。

## 7. 监控

- pending/retryable_failed 数量。
- 最老待处理事件年龄。
- publishing lease 过期数。
- dead_letter 数量。
- 按 event_type 的成功率、重试次数和延迟。
- auditx、SpiceDB、retrieval 各消费者的错误率。

## 8. 数据保留

published 事件按审计/排障策略保留有限期限或归档；dead_letter 和失败详情保留更长时间。payload 只包含投递所需的最小脱敏数据。不得将完整正文或密钥塞入 outbox。

## 9. 验收用例

- 业务事务回滚时，不存在对应 outbox 事件。
- 业务事务提交后，进程立即崩溃，事件仍能被发布。
- 外部服务已处理但 ACK 丢失，重试不产生重复副作用。
- worker 在 publishing 状态崩溃，lease 到期后事件可重新领取。
- 超过重试上限进入 dead_letter 并告警。
- 新旧索引事件乱序到达时，旧 revision 不覆盖新 revision。
