# Playground 作为主入口 + Flow 像 Agent 一样切换（交互与逻辑方案）

## 1. 总结

目标是让用户进入项目后默认进入一个“可运行 Flow 的 Playground 工作台”，并且能在同一个 Playground 内像 CodeX 切换 Agent 一样简单地切换当前使用的 Flow（左侧固定列表点击切换），同时“按 Flow 保留会话并记住上次 session”。

核心思路：
- 把“运行/对话/IO 交互”作为主入口体验：`/` → `/playground`。
- 新增一个“Authenticated Playground 工作台”（不等同于目前的 shareable `/playground/:id/`），用于列出当前用户可用的 flows 并支持快速切换。
- 在现有全屏 `IOModal` 左侧栏顶部增加一个 Flow 列表区（固定常驻），下方仍保持现有 sessions/inputs/outputs 的侧栏逻辑。
- 切换 Flow 时对 `IOModal` 的内部状态做显式 reset（否则会话/消息可能串到旧 flow），并把“lastFlowId”和“lastSessionIdByFlowId”持久化到本地。

## 2. 当前状态分析（基于仓库现状）

### 2.1 路由与入口
- 当前首页重定向到 `flows`（资源管理页）：[routes.tsx:L86-L92](file:///d:/LangFlow/src/frontend/src/routes.tsx#L86-L92)
- 目前存在一个顶层 shareable Playground 路由：`/playground/:id/`，由 `PlaygroundAuthGate` 包裹，渲染 [PlaygroundPage](file:///d:/LangFlow/src/frontend/src/pages/Playground/index.tsx)。

### 2.2 PlaygroundPage 的定位
- 目前的 [PlaygroundPage](file:///d:/LangFlow/src/frontend/src/pages/Playground/index.tsx) 用 `getFlow({ public: true })` 拉取公开 flow，并强校验 `access_type === "PUBLIC"`，更像“公开分享的运行页”，不适合作为“登录态主入口的工作台”。
- Playground UI 的主体不是页面本身，而是常驻打开的 `CustomIOModal(open=true)`，其实际实现是全屏 [IOModal](file:///d:/LangFlow/src/frontend/src/modals/IOModal/playground-modal.tsx)。

### 2.3 Flow 切换能力（缺口）
- Flow 切换的 store 能力是存在的：`useFlowsManagerStore.setCurrentFlow` 会更新 `currentFlowId/currentFlow` 并 `resetFlow`：[flowsManagerStore.ts:L37-L46](file:///d:/LangFlow/src/frontend/src/stores/flowsManagerStore.ts#L37-L46)
- 但 `IOModal` 内部对 “currentFlowId 变化” 没有完整的 reset 逻辑（例如 `visibleSession/sessionId/messages` 可能沿用旧值），这会阻碍“在同一 Playground 内快速切换 Flow”的体验。

### 2.4 会话（sessions）机制
- `IOModal` 通过 `useGetSessionsFromFlowQuery({id: currentFlowId})` 拉取 sessions，并把 `currentFlowId` 作为默认 session 插入头部：[playground-modal.tsx:L91-L111](file:///d:/LangFlow/src/frontend/src/modals/IOModal/playground-modal.tsx#L91-L111)
- 当前 `visibleSession`/`sessionId` 主要由 `visibleSession` 驱动更新，但没有“按 Flow 记住上次 session”的持久化策略。

## 3. 目标体验（交互方案）

### 3.1 主入口
- 用户访问 `/` 后直接进入 Playground 工作台（而不是 flows 管理页）。
- 默认 Flow 策略（已确认偏好）：优先进入“上次使用的 Flow”；若无记录，则进入“第一个可用 Flow”（或提示用户选择）。

### 3.2 左侧栏信息架构（按你给的结构）
目标结构（从上到下）：
- **新对话**
  - 一个明显的按钮/列表项，点击后创建并进入新 session（复用现有逻辑：`setvisibleSession(undefined)` + `setNewChatOnPlayground(true)`）。
- **项目**
  - 展示“项目（Folder/Project）→ 工作流（Flow）”的树形结构。
  - 默认行为：
    - 若只有一个项目：显示一个项目分组，展开列出该项目下 flows。
    - 若有多个项目：显示多个可折叠的项目分组。
  - 每个工作流项展示：icon（如果有）+ name；当前工作流高亮；点击即切换。
  - 该区块只在登录态 Workbench Playground 显示（shareable `/playground/:id/` 不显示）。
- **对话**
  - 显示当前 Flow 的 sessions 列表（复用 [SidebarOpenView](file:///d:/LangFlow/src/frontend/src/modals/IOModal/components/sidebar-open-view.tsx) + [SessionSelector](file:///d:/LangFlow/src/frontend/src/modals/IOModal/components/IOFieldView/components/session-selector.tsx)）。
  - 空态规则（你描述的“暂无聊天”）：
    - 当后端 sessions 为空，或只有默认 session 且该 session 下无消息时，显示“暂无聊天”占位。
- **设置**
  - 最底部固定一行或一个小面板：
    - 主题切换（复用 `ThemeButtons`）
    - 进入设置页（跳转 `/settings/general`，或打开一个简化的设置弹层，二选一见实现章节）

### 3.3 切换 Flow 的行为规则
切换 Flow 时（点击左侧 Flow 列表项）：
- 立即切换 `currentFlow`（加载对应 flow 数据，刷新 IO schema）。
- 恢复该 Flow 上次使用的 session（如果本地有记录并且后端仍存在），否则回退到默认 session（flowId）。
- 清空当前消息视图避免串流（UI 先空，再由 messages query 填充）。
- 记录 `lastFlowId` 到本地，保证下次进入仍回到这里。

### 3.4 异常/边界处理
- Flow 拉取失败（403/404/网络错误）：提示错误并保持在当前 flow，不切换成功态。
- 目标 Flow 不具备可运行 IO（没有 inputs/outputs 或缺少 ChatInput/ChatOutput 时）：
  - Playground 仍可打开，但在聊天区提示“该 Flow 无可运行输入/输出”，并提供“打开编辑器”按钮跳转 `/flow/:id/`。

## 4. 逻辑与实现方案（决策完备）

### 4.1 路由调整（让 Playground 成为主入口）
修改：[routes.tsx](file:///d:/LangFlow/src/frontend/src/routes.tsx)
- 将 `index` 重定向从 `flows` 改为 `playground`。
- 在 authenticated 主应用分支内新增一个路由：
  - `path="playground"` → 新页面 `PlaygroundWorkbenchPage`
- 保留原有 shareable 路由 `"/playground/:id/"` 不变，用于公开分享场景（避免把“列出所有 flows”暴露在 share 场景里）。

### 4.2 新增页面：Authenticated Playground 工作台
新增文件（建议路径）：
- `src/frontend/src/pages/MainPage/pages/playgroundWorkbenchPage/index.tsx`

页面职责（仅负责“选 Flow + 打开 IOModal 全屏工作台”）：
- 进入时拉取 flows 列表（轻量 header 列表即可）：
  - 方案 A（复用现有）：调用 `useGetRefreshFlowsQuery({ get_all: true, header_flows: true })`，并依赖其内部 `setFlows` 写入 store。
  - 方案 B（更轻量，推荐）：新增一个专用 query hook（例如 `useGetFlowHeadersQuery`），只请求 `/flows?get_all=true&header_flows=true`，不再额外拉取 components 列表（当前 useGetRefreshFlowsQuery 会额外请求 components）。
- 初始 Flow 选择：
  - 优先取 `localStorage["lf_playground_last_flow_id"]`
  - 否则取 flows 列表第一个（排除 components/mcp 等不适合运行的项，如果需要）
- 当决定了 targetFlowId：
  - 调用 `useGetFlow().mutateAsync({ id: targetFlowId })` 拉 full flow（私有接口），成功后 `useFlowsManagerStore.setCurrentFlow(flow)`
  - 同步写 `localStorage["lf_playground_last_flow_id"] = targetFlowId`
- 渲染方式：
  - 常驻打开 `CustomIOModal open={true} isPlayground playgroundPage`
  - `setOpen` 在工作台场景可为 no-op（保持常驻），也可以允许关闭后返回 `/flows/`

### 4.3 IOModal：增加 Flow 列表区（左侧固定）
修改文件：
- [playground-modal.tsx](file:///d:/LangFlow/src/frontend/src/modals/IOModal/playground-modal.tsx)
- 以及其左侧栏组件：
  - [SidebarOpenView](file:///d:/LangFlow/src/frontend/src/modals/IOModal/components/sidebar-open-view.tsx)（当前已存在，被 IOModal 调用）

实现方式（建议）：
- 重构 `SidebarOpenView` 为 4 个区块（新对话 / 项目 / 对话 / 设置），其中“项目”区块就是你要的“项目 → 工作流”树。
- **项目区块（ProjectWorkflowsSection）数据组织**
  - folders 数据源：`useFolderStore((s) => s.folders)`（已由 [AppInitPage](file:///d:/LangFlow/src/frontend/src/pages/AppInitPage/index.tsx#L46-L53) 在认证后拉取）。
  - flows 数据源：`useFlowsManagerStore((s) => s.flows)`（由 workbench 页面拉取 headers 后写入）。
  - 分组规则：按 `flow.folder_id` 映射到 `folders` 的 `name`；若找不到则归到“未分类”。
  - 切换动作：`useGetFlow().mutateAsync({ id })` → `setCurrentFlow(flow)`。
- **新对话区块**
  - 直接做成一个列表项按钮（而不是只保留当前顶部 “Chat + Plus” 的 icon），点击触发现有新对话逻辑。
- **对话区块**
  - 标题从现在的 “Chat” 改成“对话”，并支持空态“暂无聊天”。
- **设置区块**
  - 主题切换：复用 `ThemeButtons`。
  - 跳转设置页：使用 `useCustomNavigate()` 或 `useNavigate()`（取决于该模态是否在自定义路由体系内，执行阶段以现有全局导航封装为准）。
- 显示条件（避免 shareable 泄露“我的项目/工作流”）：
  - 推荐做法：给 `CustomIOModal/IOModal` 增加显式 props：
    - `showProjectWorkflows?: boolean`
    - `showSettingsSection?: boolean`
  - shareable Playground（`/playground/:id/`）传 `false`；Authenticated Workbench Playground 传 `true`。

### 4.4 IOModal：Flow 切换时的状态 reset（关键）
修改：[playground-modal.tsx](file:///d:/LangFlow/src/frontend/src/modals/IOModal/playground-modal.tsx)

新增一个 `useEffect` 监听 `currentFlowId`（来自 [useGetFlowId](file:///d:/LangFlow/src/frontend/src/modals/IOModal/hooks/useGetFlowId.ts) 或 store）变化，执行：
- `useMessagesStore.getState().clearMessages()`（避免 UI 先显示旧消息）
- `setSessions([])`（短暂清空，等 sessions query 回填）
- 从本地恢复该 flow 的 last session：
  - `const lastSession = localStorage["lf_playground_last_session_by_flow"]?.[currentFlowId]`
  - `setvisibleSession(lastSession ?? currentFlowId)`
- `setSelectedViewField(startView())`（避免旧 viewField 指向旧 flow 的节点/会话）

同时在 `visibleSession` 变化时做持久化：
- `localStorage["lf_playground_last_session_by_flow"][currentFlowId] = visibleSession`

### 4.5 数据与类型（可选增强）
如果希望 Flow 列表展示 icon/gradient/updated_at（更接近 CodeX 的“Agent 卡片感”）：
- 后端扩展 `FlowHeader` 模型字段（把 `icon/icon_bg_color/gradient/updated_at` 加到 header 响应里），并保证 `/flows?header_flows=true` 返回这些字段。
- 前端对应更新 FlowHeader 类型与渲染。

这属于可选优化，不影响“先做出可用切换”的主目标。

## 5. 已确认的偏好与关键决策
- 默认进入：上次使用的 Flow（无记录再 fallback）。
- 切换入口：左侧固定列表点击切换（不以顶部下拉为主）。
- 会话策略：按 Flow 保留并记住上次 session。
- 安全边界：shareable `/playground/:id/` 保持隔离，不展示“我的 flows 列表”。

## 6. 验证与验收（执行后怎么确认）

### 6.1 手动验收清单
- 访问 `/`：进入 `/playground` 工作台而非 `/flows`。
- 第一次进入（无 lastFlowId）：自动进入第一个可用 Flow 或弹出选择提示（按实现方案）。
- 在左侧 Flow 列表点击切换：
  - 标题/IO schema/聊天行为切换到新 flow
  - 不出现旧 flow 的消息串流
  - sessions 列表变为新 flow 的 sessions
- 切换回之前的 flow：恢复上次打开的 session（可观察 session 高亮/消息列表）。
- shareable `/playground/:id/`：仍能正常打开（公开 flow），且不出现“我的 flows 列表”。

### 6.2 建议的本地验证命令
- `make frontend`（启动前端）
- `make backend`（如需 API）
