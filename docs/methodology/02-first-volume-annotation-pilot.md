# 《父可敌国》第一卷：实证标注规范与十个锚点样例

状态：Pilot，非完整全卷审核｜文本：用户上传 EPUB｜规范化协议：pilot-v1-remove-heading-join-p-with-LF

## 1. 输入可复验事实

EPUB OPF spine index 4–76 对应第一卷《大本堂中》的第1–73章。第74章起属于第二卷《中都风云》。段落化规范正文共 169,732 个 Unicode 码点；单章中位数 2,282 码点。

本轮暂行规范化：移除 HTML 的 script/style/章节 heading，取正文 p 文本，清除每个 p 两端空白，段落间以 LF 连接；引用位置为章节正文零基 Unicode 码点、左闭右开。字符/哈希仅在该规范化版本下成立；正式 parser 对文字、换行、空格有任何变动都必须换 normalizer_version，不得套用旧锚点。

**完成状态要严格分开**：
- 已完成：73章阅读顺序、标题、长度、段落数量、各章正文 SHA-256；10 处短引用的本地子串 offset/sha 校验。
- 部分完成：选定章节的事件与人物认知人工初标。
- 尚未完成：全73章事件/人物/因果/线索的完整黄金标注，以及这些引用对生产规范化文本的最终校验。

## 2. 样本引用锚点（技术可定位，不代表解释都获人工认可）

以下引用都是短片段，不包含正文长段。SHA 为该短片段 UTF-8 SHA-256 的前16位，用于方便对照；完整值可从本地试验 manifest 复验。

| 样本 | 章 | 章节局部范围 [start,end) | 引用短片段 | quote SHA 前16位 | source kind |
|---|---:|---|---|---|---|
| T01 | 2 | [61,69) | 好像被人推了一把 | c667789c10fcd4df | 人物回忆：不确定 |
| T02 | 2 | [2861,2869) | 自己想办法救人了 | 32493d9d1d99064f | 叙述者呈现的目标 |
| T03 | 13 | [203,218) | 老七已经承认，是他推我下水的了 | e279a63ac86e3cb5 | 朱桢说法（角色报告） |
| T04 | 14 | [2577,2597) | 老夫确实亲眼目睹了，齐王推殿下落水那一幕 | 71a43ee6f0654027 | 刘基说法（角色证词） |
| T05 | 18 | [1938,1946) | 母妃，我来接你了 | 5e2a934b3463a271 | 角色当场发言 |
| T06 | 56 | [7,15) | 这不是刚才那张了 | 374b79bd437ab766 | 药方不同的发现 |
| T07 | 57 | [27,38) | 为臣的方子是滋补润肺的 | 64dd2be752a84eaa | 周院判陈述 |
| T08 | 71 | [1849,1860) | 父皇命户部制作的户贴册 | 299794476bfb0640 | 角色介绍制度文书 |
| T09 | 72 | [1779,1784) | 统统记下来 | 21642acc71b1b895 | 角色提出任务要求 |
| T10 | 73 | [2326,2338) | 着五人于后湖闭门读书一载 | 540ac0e9e8ab86db | 叙述中的官方上谕 |

**注意**：某句话被准确定位，只证明文本确实包含这句话。人物说“亲眼目睹了”不等于系统有权把所说事件标记为无条件客观真相。文本证据验证状态与命题真假/可信度是两个字段。

## 3. 带截止章的线索示例：落水疑云

本例对第2、13、14章的若干片段做初始关系追踪，**不声称覆盖第3–12章全部相关情节**。

### 截止第2章
- 朱桢回忆落水前仿佛有人推他。
- 位置：T01；source_kind=character_memory；epistemic=reported_uncertain。
- 命题：“似乎有人推了朱桢下水”，属于人物记忆/怀疑；推人者未确认。
- 不能由这一处证据推出“齐王就是凶手”。

### 截止第13章
- 朱桢对刘基表示“老七已经承认”；位置：T03。
- 必须区分“朱桢确实如此说”与“齐王在具体何章如何承认”。
- 需要回查被报告的原始承认章节及语境，完成 report → firsthand evidence 的链路；否则保留 reported。

### 截止第14章
- 刘基声称自己曾亲眼看见齐王推朱桢；位置：T04。
- 可以形成第二个不同主体的证词，增加对“谁推”的支持；但幕后动机、他人指使及落水造成的宫廷政治后果属于另外的命题。
- 应把“推人者身份问题”“是否存在背后指使”“母妃受到处罚的因果责任”拆为不同 thread，避免一条线索被简单标记 resolved 就隐藏了剩余疑问。

这说明**长期线索不是单独一个问答对，而是一张不断得到证据、改变解释、分裂出子问题的关系图**。

## 4. 跨章目标：救母妃

- 第2章：T02 明确朱桢准备自行设法救人（目标建立）。
- 第18章：T05 出现接母妃的行动（阶段性反馈）。
- 第19–21章：需复核返宫安排、其他人物应对、目标是否已经达到以及有什么新的人物关系/代价。

重要：可以标记“营救母妃的局部目标逐步兑现”，但不能因此认为皇室内部的关系矛盾一并解决。

## 5. 跨章制度/因果：刘伯温与药方

- 第13–14章：主角对刘伯温可能遭遇的风险提出判断；涉及历史认知优势和现实情报不足。
- 第56章：T06 出现药方与原先不同的发现。
- 第57章：T07 周院判表述自己原先的用药性质，并进入对药方真实性的质询。
- 第64–65章：观察到皇帝与刘伯温相关的局势变化和朱桢付出的行动代价。

这里应同时建立：
- 事件图：谁换药方、为什么、如何被发现、谁承担责任。
- 知识图：皇帝、御医、刘家、朱桢、胡惟庸各自何时知道哪些事实/误以为哪些事情。
- 规则/资源图：宫廷诏令、药房记录、私人求见资格、官职和皇权怎样改变行动条件。
- 风险/代价图：保护人物的方案为什么带来新的风险。

第56/57章同一药方的不同说法是多个 EventMention/Claim，不能因为题材历史就自动与真实明史事实混同。

## 6. 卷界与“信息继承”：第71–74章

- 第71章引入户贴和人口/土地/赋税相关制度文书（T08）。
- 第72章布置实地接触民情并记录所见（T09）。
- 第73章出现对外公布的上谕说法（T10），其字面内容与实际安排之间需要结合第72章和第74章核查。
- 第74章正式进入第二卷《中都风云》，转向临淮地方治理情境。

因此卷界应记录：
- 上卷已建立的父子、兄弟、宫廷关系。
- 本卷末对新任务的知识、规则、身份和资源准备。
- 下卷新的地点/制度/行动限制。
- 哪些问题只是转入另一种场景继续推进。

卷界不是“前73章清空、74章重新建人物”。

## 7. 标注 schema 的最小字段

### observation
- observation_key、work_id、split_version_id、chapter_id、anchor_id。
- observation_type（narrator_fact / character_report / character_memory / character_inference / dialogue / world_rule / authorial_commentary）。
- asserted_by_entity_id（可空）、content_summary、epistemic_status、review_status。

### event_candidate
- local_event_key、participants、action_or_change、story_time_candidate、source_mentions。
- precondition_candidates、direct_outcomes、state_delta_keys、assertion_provenance。

### thread_occurrence
- thread_key、occurrence_type（introduced / reinforced / contested / partially_resolved / resolved / reinterpreted）。
- chapter_id、anchor_id、asserted_by、epistemic_status、cutoff_chapter_no。
- claim_ref、alternative_explanations、review_status。

### character_knowledge_delta
- entity_id、proposition_key、before_belief、after_belief。
- learned_in_chapter、source_event、knowledge_source、truth_status、effective_story_time。

### arc_candidate
- arc_key、goal_or_problem、start_trigger、opposition、milestone_event_keys、outcome。
- start_chapter、latest_relevant_chapter、open_questions、carry_over。
- human_review_notes、status。

注意上述新实体字段属于方法论/DTO 提案；并非宣称都已加入现有 PostgreSQL schema。

## 8. 人工审核指令（黄金标注）

1. 先检查是否能定位原文，再检查事件是否被准确转述。
2. 对人物转述必须追溯原始叙述位置，追不到也应保留 reported 而不是改成 explicit fact。
3. 同一事件的多个讲述留多个 mention，不要重复 canonical event。
4. 评价“因果”时检查前提、行动机制、结果和其他可能原因；不因连续章节就建立 causes。
5. 伏笔必须有可追踪的建立点与回收候选，确认关联不是仅靠相似词汇。
6. 审核“读者截止第N章”时，不得使用 N 之后任何原文、正文衍生摘要或模型缓存。
7. 对作者意图/主题/爽点/人物塑造等审美解释，允许多种有依据的答案；不要制造伪精度。

## 9. 质量门禁

- 10个 pilot anchor 的规范化文本范围及 SHA 匹配：本地技术校验全部通过。
- 73章的标题、spine 序、长度及正文 hash：已生成本地 manifest。
- 73章逐章事件黄金标注：未完成。
- 全卷 arc、因果和伏笔最终评审：未完成。
- 生产级 parser/数据库校验：未完成。

完成下一轮应提交审核后的章节卡、Arc 地图、线程账本和跨卷过渡图，再对照简单逐章摘要基线评估价值。