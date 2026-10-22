# API 详细设计

状态：Draft

## 1. 全局约定

- 前缀：/api/v1。
- 资源 ID 使用 UUID。
- JSON 字段使用 snake_case；前端可以在客户端映射成 camelCase。
- 时间戳采用 RFC 3339，服务器存储 UTC。
- 列表使用 cursor pagination；cursor 应是不透明值。
- 修改有并发风险的资源时，要求 expected_revision 或 If-Match。
- 创建异步任务返回 202 Accepted。
- 所有资源访问验证 project membership 和 work 与 project 的关联。
- API DTO 与数据库实体分离，禁止把数据库行直接序列化给客户端。

## 2. 统一响应与错误

成功响应可以包含 data、meta。错误包含 code、message、details、request_id。

常见错误码：
- VALIDATION_ERROR
- NOT_FOUND
- FORBIDDEN
- CONFLICT
- STALE_REVISION
- SOURCE_VERSION_MISMATCH
- SPLIT_VERSION_NOT_CONFIRMED
- QUOTA_EXCEEDED
- TASK_NOT_RETRYABLE
- EVIDENCE_VERIFICATION_FAILED
- MODEL_OUTPUT_INVALID
- INTERNAL_ERROR

不向客户端返回 SQL、堆栈、密钥或未经脱敏的模型提供方异常。

## 3. 项目和作品

- POST /projects
- GET /projects?cursor=&limit=
- GET /projects/{project_id}
- PATCH /projects/{project_id}
- GET /projects/{project_id}/members
- PUT /projects/{project_id}/members/{user_id}
- DELETE /projects/{project_id}/members/{user_id}
- POST /projects/{project_id}/works
- GET /projects/{project_id}/works
- GET /works/{work_id}
- PATCH /works/{work_id}

项目创建必须在一个事务内建立项目和 owner 成员。不能通过客户端提交 role=owner 来转移所有权；所有权变更使用独立授权操作。

## 4. 文件导入和版本

- POST /works/{work_id}/sources：创建上传会话或上传记录。
- POST /sources/{source_id}/complete-upload：确认对象已上传并校验哈希。
- POST /sources/{source_id}/parse：启动解析任务。
- GET /sources/{source_id}
- GET /sources/{source_id}/versions
- GET /source-versions/{source_version_id}
- GET /source-versions/{source_version_id}/split-versions
- POST /source-versions/{source_version_id}/split-versions
- GET /split-versions/{split_version_id}/chapters?cursor=&limit=
- GET /chapters/{chapter_id}
- PATCH /split-versions/{split_version_id}/chapters/{chapter_id}
- POST /split-versions/{split_version_id}/confirm

章节边界修改只允许在 draft split 上执行。若版本已被 analysis run 引用，则必须创建新 split version。服务端验证字符范围、顺序、重叠和覆盖规则。

## 5. 分析任务

- POST /works/{work_id}/analysis-runs
- GET /analysis-runs/{run_id}
- GET /analysis-runs/{run_id}/steps
- POST /analysis-runs/{run_id}/cancel
- POST /analysis-runs/{run_id}/retry
- GET /analysis-runs/{run_id}/artifacts

创建请求至少包含 task_type、source_version_id、split_version_id、scope、outputs 和 options。服务端计算 input_hash；不能完全信任客户端提供的 hash。

重复 Idempotency-Key 且请求内容相同，应返回原 run；相同 key 但输入内容不同，应返回冲突错误。

取消是协作式取消；已经持久化的步骤保留。只有可重试失败的 step 能被 retry；成功步骤默认复用。

## 6. 产物、结论与证据

- GET /works/{work_id}/artifacts?type=&status=&cursor=
- GET /artifacts/{artifact_id}
- POST /artifacts/{artifact_id}/review
- GET /claims/{claim_id}
- POST /claims/{claim_id}/review
- GET /claims/{claim_id}/evidence
- POST /evidence-anchors/{anchor_id}/verify

审核请求包含 action、expected_revision 和可选 edited_text/reason。用户编辑产生新 revision 或显式审核记录，不覆盖模型原始输出。

## 7. 人物、事件和关系

- GET /works/{work_id}/entities?type=&query=&status=
- GET /entities/{entity_id}
- GET /entities/{entity_id}/mentions?split_version_id=&chapter_id=
- PATCH /entities/{entity_id}
- POST /entities/{entity_id}/merge
- POST /entities/{entity_id}/split
- GET /works/{work_id}/events?chapter_id=&cursor=
- GET /events/{event_id}
- GET /events/{event_id}/mentions?split_version_id=&chapter_id=
- PATCH /events/{event_id}
- GET /works/{work_id}/relations
- GET /works/{work_id}/plotlines
- GET /plotlines/{plotline_id}
- PATCH /plotlines/{plotline_id}
- POST /plotlines/{plotline_id}/nodes/reorder

merge 请求必须包含目标实体、预览冲突策略和 expected_revision。合并执行时要处理别名、关系去重、故事线引用、claim 关联及审计记录。

## 8. 大纲

- GET /works/{work_id}/outline-sets
- POST /works/{work_id}/outline-sets
- GET /outline-sets/{outline_set_id}/tree
- POST /outline-sets/{outline_set_id}/nodes
- PATCH /outline-nodes/{node_id}
- POST /outline-nodes/{node_id}/move
- POST /outline-nodes/{node_id}/duplicate
- POST /outline-sets/{outline_set_id}/review

move 操作需检查目标父节点属于同一 outline set，拒绝形成循环；排序更新必须在事务内完成。accepted 版本不直接原地改写，修改需创建 draft revision。

## 9. 任务进度事件

首期可以用轮询：
GET /analysis-runs/{run_id} 和 /steps。

响应至少包含 status、stage、completed_steps、total_steps、failed_steps、started_at、heartbeat_at、finished_at 和可供用户理解的 error_code。后续可增加 SSE，但不能改变任务状态语义。

## 10. API 安全规则

- 先鉴权再读取资源，避免通过错误信息泄漏其他项目资源存在性。
- 限制上传大小、请求体大小、分析并发和重试次数。
- 写操作采用审计和并发版本检查。
- 对可能产生高成本的分析任务实行配额和速率限制。
- 日志只记录资源 ID、状态、耗时和错误码；默认不记录正文和完整提示词。
