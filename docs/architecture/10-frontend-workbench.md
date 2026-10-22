# 前端工作台与组件详细设计

状态：Draft

## 1. 信息架构

全局导航：
- 项目首页
- 作品列表
- 拆书研究
- 阅读工作台
- 创作工作台
- 个人技法库/知识库
- 设置

进入某部作品后，左侧二级导航根据 work_type 和项目权限显示可用功能。研究作品、原创作品的结构相似，但术语和状态必须清晰区分。

## 2. 主要页面

### P-01 项目首页
组件：ProjectHeader、WorkList、RecentActivity、TaskInbox、CreateWorkDialog。
展示最近作品、正在运行的分析、失败任务、待审核结果和最近访问位置。

### P-02 导入向导
阶段：上传 → 解析 → 章节预览 → 边界修正 → 确认。
组件：FileDropzone、UploadProgress、ParseDiagnostics、ChapterList、ChapterBoundaryEditor、ChapterPreview、SplitVersionBadge。
离开页面后保留服务器端状态。确认前明确显示章节数、空章节、疑似目录和异常边界。

### P-03 拆书总览
组件：BookOverview、StructureSummary、AnalysisCoverage、EvidenceCoverage、OpenQuestions。
区分已确认事实、AI 推断、待审核和缺证据结论。

### P-04 章节工作台
采用三栏布局：
- 左：ChapterNavigator，章节搜索、状态和分析进度。
- 中：SourceReader / ChapterOutline / EventBeatList 标签切换。
- 右：EvidencePanel / AI Assistant / ReviewPanel。

原文和分析结果共享 chapter ID、split version 和局部字符偏移。切换版本时必须显示版本标记。

### P-05 人物与关系
组件：EntityTable、EntityProfile、AliasEditor、RelationGraph、EntityMergeWizard、EvidenceDrawer。
关系图提供表格/列表备选，不能只靠图形交互；支持键盘访问、搜索和关系过滤。

### P-06 故事线与时间线
组件：PlotlineList、PlotlineTimeline、PlotlineNodeCard、CrossPlotlineMatrix、UnresolvedThreadList。
叙事顺序和故事内时间使用不同视图/标识。用户可以从节点跳转到事件、章节和证据。

### P-07 大纲树
组件：OutlineTree、OutlineNodeEditor、OutlineToolbar、NodeMoveDialog、VersionComparePanel。
支持拖拽排序、键盘操作、增加/删除/复制/移动节点。移动前验证循环和版本状态；对 accepted 版本先创建草稿副本。

### P-08 阅读工作台
组件：ReaderPane、ReadingProgress、MarginNotes、GuideQuestions、TutorPanel、QuizPanel。
AI 回答应显示证据范围、推断状态和“保存为笔记”操作。阅读进度与具体版本关联。

### P-09 创作工作台
组件：CanonSidebar、OutlineEditor、ManuscriptEditor、ContextInspector、ConsistencyPanel、RevisionHistory。
右侧上下文面板展示本章允许使用的 Canon、前文摘要、当前细纲和禁忌/约束。生成结果进入草稿，不能自动覆盖用户正文。

## 3. 通用组件

- ProjectSwitcher
- WorkBreadcrumbs
- VersionSelector
- TaskStatusBadge
- EvidenceCitation
- ClaimReviewControls
- StaleArtifactBanner
- EmptyState
- ErrorState
- RetryAction
- RevisionConflictDialog
- ConfirmImpactDialog
- PermissionGate

## 4. 前端状态原则

- 服务端资源状态由 API 查询管理；不要只保存在组件局部状态中。
- 编辑器草稿与已保存 revision 分离。
- 对 OutlineTree 等复杂编辑采用乐观更新时，必须具备回滚和 409 冲突处理。
- 长任务进度是服务端权威状态。
- URL 保存可分享的工作位置，如 work、chapter、artifact 和 outline_set。
- 版本切换必须清除不适用的选择状态，避免旧章节证据显示在新版本中。

## 5. 交互与可访问性

- 图形关系必须提供列表视图。
- 拖拽之外提供明确的“移动到”操作。
- AI 输出标记来源、版本和审核状态。
- 危险操作显示影响范围及撤销/恢复策略。
- 加载、空结果、部分失败和无权限状态均需设计。
- 超长章节按需渲染，避免一次加载整本全文到 DOM。
