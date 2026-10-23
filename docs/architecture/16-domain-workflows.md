# 领域状态机与生命周期

状态：Draft

## 1. Source document

uploaded → parsing → ready
parsing → failed
failed → parsing（重试）
ready → archived

原始文件一旦写入对象存储不可覆盖。重新上传产生新 document，或在显式去重策略下复用已有 document。

## 2. Source version

source version 是不可变产物，不提供编辑状态。解析失败应记录在 parse job 上，而不是创建一个看似有效的 source version。解析器/规范化配置变化产生新 version。

## 3. Split version

draft → confirmed → superseded
draft → discarded（如后续需要）

draft 可编辑章节标题、边界和顺序。confirmed 不允许原地修改；新修正创建新的 draft split version。被历史分析引用的 split version 不硬删除。确认操作必须记录 confirmed_by 和 confirmed_at。

## 4. Analysis run

queued → running → succeeded
running → completed_with_warnings
running → failed
queued/running → cancelled（取消请求由 worker 协作完成）
failed → queued/running（仅通过 retry policy 创建新的尝试或重启失败 step）

completed_with_warnings 表示主流程完成但存在可查看警告；不能当作全成功或全失败。每个状态变更需记录时间和错误信息。

## 5. Analysis step

pending → running → succeeded
running → retryable_failed → running
running → terminal_failed
pending → skipped

每个 running step 具有 lease。worker 心跳停止且 lease 到期后，其他 worker 可安全接管。接管前必须重新读取 step 状态并验证 attempt/lease，避免两个 worker 同时提交结果。

## 6. Artifact

draft → in_review → accepted
in_review → rejected
accepted → superseded
draft/in_review → stale（输入版本变化或依赖失效）

状态和版本不是同一概念。新版本创建新 artifact revision；旧 revision 保留供比较。已接受的产物如需修改，应创建新 revision，不直接改写。accepted/rejected 的审核决定必须记录 reviewer 和 review timestamp。

## 7. Claim

review_status：unreviewed / accepted / rejected / edited。
epistemic_status：explicit / inferred / speculative。

两者独立。例如一个 inferred claim 可以被用户 accepted；这表示用户认可该解释，不表示原文明确陈述该事实。

## 8. Entity merge

合并流程：
1. 校验源实体和目标实体同 work 且状态可合并。
2. 预览别名、关系、事件、claims 和 plotline 引用。
3. 检查自环、重复关系和潜在 merge cycle。
4. 在一个事务中迁移引用、去重关系、迁移别名并记录审计。
5. 源实体标记 merged 并指向目标实体。
6. 保留操作前后映射以支持审计/受控撤销。

不允许跨 work 合并。自动相似度只生成候选，不直接执行 merge。

## 9. Outline set

draft → in_review → accepted → superseded。
accepted 节点不可直接编辑。用户编辑时复制为新 draft revision；确认后切换当前有效版本。

节点移动规则：
- 父节点与目标节点属于同一 outline set。
- 不能把节点移动到自身或后代节点下。
- 排序冲突通过事务重排或临时排序策略解决。
- 删除父节点需显式选择级联删除、提升子节点或取消。

## 10. 失效与重算

- source version 变化：该源版本的分析产物不自动迁移；新版本需要重新分析。
- split version 变化：章节 ID 和 evidence anchors 属于旧版本，禁止静默重绑定。
- 单章内容变化：重算该章 extraction，并重跑受影响的跨章汇总。
- 人物合并：刷新人物档案、关系统计、相关故事线摘要。
- outline 修改：刷新受影响的父节点摘要和检查结果。
- prompt/schema 变化：生成新 run，旧结果留档。

每个 artifact 必须能回答“基于什么输入生成、何时失效、如何重新生成”。
