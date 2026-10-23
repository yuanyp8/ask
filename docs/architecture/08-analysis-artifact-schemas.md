# AI 分析产物 Schema 设计

状态：Draft

## 1. 通用封装

每个持久化 artifact 的 payload 必须包含 schema_version。数据库列保存 work、scope、source/split version、run 和 revision 等通用元数据；payload 只保存该产物类型的业务内容。

所有模型响应先进入临时验证流程，再写入正式表。禁止把未经验证的模型 JSON 直接落库。

推荐的逻辑封装字段：
- schema_version：整数。
- artifact_type：稳定类型标识。
- title：供 UI 展示的标题。
- summary：短摘要。
- sections：按类型组织的结构化内容。
- warnings：缺失信息、歧义和验证问题。
- source_scope：由服务端填充的源版本/切分版本/章节范围。
- provenance：由服务端填充的模型、提示词和 run 信息。

provenance 不信任模型自行填写，服务端必须覆盖。

## 2. chapter_analysis.v1

必须包含：
- chapter_summary：章节摘要。
- chapter_function：本章在全书中的作用候选。
- beats：有序事件/情节节拍列表。
- character_mentions：人物提及和候选实体引用。
- conflicts：本章冲突。
- information_changes：读者/人物新增或失去的信息。
- emotional_curve：章节情绪变化节点，允许为空。
- ending_hook：结尾悬念或状态变化，允许为空。
- open_questions：未解决问题。
- evidence_candidates：供服务端验证的引用候选。

每个 beat：
- local_order：章节内顺序。
- summary：事件摘要。
- actors：人物提及 ID 或临时 mention key。
- action：行动。
- cause_or_motivation：动机/原因，必须标记 epistemic_status。
- consequence：直接结果。
- beat_type：setup/development/conflict/reversal/revelation/climax/aftermath/other。
- evidence_refs：候选证据索引。

不得要求每章都存在高潮、反转或悬念；字段允许为空，避免模型为了填满结构而臆造。

## 3. entity_candidate.v1

- mention_key：本次 run 内稳定键，写入 entity_mentions.mention_key。
- entity_type：character/location/organization/object/concept/other。
- surface_form：原文中的称呼。
- normalized_name：用于匹配的规范化名称。
- description_candidate：简短描述。
- aliases：其他称呼。
- first_mention_evidence：证据候选。
- identity_conflicts：与已知实体可能冲突的信息。
- match_candidates：候选 entity ID 和匹配原因，不由模型最终决定合并。
- epistemic_status：explicit/inferred/speculative。

同名不等于同一实体；化名、假身份、转世、同名人物和视角误认都必须保留歧义。模型首先产出 entity mention 候选，服务端再将其关联到 canonical entity；mention 的原文形式和位置不得因归并而丢失。

## 4. story_event.v1

- event_key：run 范围内的候选键；持久化时 canonical event_key 由服务端生成或复用，mention_key 保留 run 范围幂等性。
- summary：事件摘要。
- actors：事件参与者。
- action：发生的行动。
- preconditions：前置条件或原因候选。
- consequences：结果候选。
- chapter_id：由服务端绑定到 event mention，而不是 canonical event。
- local_order：章节内叙事顺序，写入 event_mentions。
- narrative_order：由服务端根据当前 split version 的章节顺序和章节内顺序计算或校验。
- story_time_label：原文所述故事时间，属于 event mention。
- story_time_sort_key：仅在有可靠依据时填写的可排序值。
- event_type：introduction/conflict/revelation/decision/action/reversal/payoff/closure/other。
- evidence_refs：候选证据。
- epistemic_status：explicit/inferred/speculative。

因果边和时间先后边应作为 event_relations 单独保存，不能把“先发生”自动解释成“导致”。

## 5. plotline_analysis.v1

- title、line_type、goal、stakes、central_conflict。
- start_condition、turning_points、convergence_points、resolution。
- nodes：按叙事顺序组织的 setup/development/turning_point/convergence/payoff/closure。
- related_entities、related_events。
- unresolved_threads：未收束或无法确定的线索。
- evidence_refs。
- confidence 与 epistemic_status。

支线是否“多余”属于分析判断。系统应给出它的功能、关联主线和证据，而不是仅凭篇幅短或出现次数少就判定冗余。

## 6. outline_tree.v1

节点类型：book、volume、act、story_arc、chapter、scene、beat。层级不固定，不能把三幕结构写死在 schema 中。

每个节点：
- node_key：当前 artifact 内稳定键；持久化后由服务端映射到 outline_nodes.node_key。
- parent_node_key：父节点，可为空。
- position：兄弟节点排序。
- node_type、title、summary。
- purpose：节点承担的叙事作用。
- goal、conflict、turning_point、outcome：可选字段。
- linked_chapter_id、linked_event_keys。
- plotline_keys、entity_keys。
- evidence_refs。
- epistemic_status。

reverse_analysis 必须绑定 source/split version。planned_outline 记录作者意图和创作状态，不要求存在源章节。

## 7. claim.v1 与证据

Claim 的 epistemic_status：
- explicit：原文明示或可直接定位的事实。
- inferred：基于文本证据的解释。
- speculative：存在多种合理解释、证据不足的假设。

Review status 独立使用 unreviewed/accepted/rejected/edited。

Evidence candidate 不直接等于 verified anchor。服务端需要：
1. 将引用映射到规范化章节文本。
2. 验证字符偏移范围。
3. 比较实际文本与 quote_text。
4. 计算 SHA-256。
5. 成功后标记 verified；失败则修复或标记 invalid/unverified。

一条结论可以有多个支持证据，也可以有反证和上下文证据。

## 8. 校验层次

- JSON Schema：字段、类型、必填项、枚举和长度。
- Domain validation：节点引用存在、同 work、顺序合法、状态转换合法。
- Evidence validation：原文区间、引用、哈希一致。
- Consistency validation：与已接受 Canon/实体/事件是否矛盾。
- Human review：对歧义和高影响结论做最终决定。

模型置信度不是事实正确性的保证。UI 应显示证据状态和审核状态，不应只显示一个百分比。


## 9. Persistence mapping: candidates versus canonical objects

- entity_candidate.v1 creates or updates an entity_mentions candidate first; canonical story_entities are resolved through a separate idempotent resolution step.
- story_event.v1 yields a canonical event candidate plus one or more event_mentions, each bound to a specific chapter/split version.
- plotline node references a source event mention when exact source location/order matters; it may reference a chapter-only node if no single event occurrence is appropriate.
- All IDs supplied by the model are run-local keys until the server maps them to persisted UUIDs. The model must never invent database UUIDs.
