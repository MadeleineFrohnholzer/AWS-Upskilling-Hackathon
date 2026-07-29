# Chat UI — Implementation Tasks

Stack: Next.js (App Router) · ShadCN/ui · TypeScript · Docker / Docker Compose
Design: Accenture brand (black `#000000`, purple `#A100FF`, Graphik/Inter) · Open WebUI shell (dark sidebar, centered welcome input, bottom-anchored input in active chat)

---

## Phase 0 — Project Scaffolding

- [x] `npx create-next-app@latest . --typescript --tailwind --app --src-dir`
- [x] ShadCN init: `npx shadcn@latest init` — choose **New York** style, **Neutral** base color, CSS variables on
- [x] Install ShadCN components needed up-front:
  ```
  npx shadcn@latest add button input textarea scroll-area accordion
    avatar badge separator sheet dialog command tooltip popover
    dropdown-menu progress sonner skeleton
  ```
- [x] Install runtime dependencies:
  ```
  @aws-sdk/client-bedrock-agent-runtime
  @aws-sdk/client-lambda
  @aws-sdk/client-dynamodb
  @aws-sdk/lib-dynamodb
  next-themes
  react-markdown
  rehype-highlight
  highlight.js
  ```
- [x] Configure `next.config.ts`:
  - `output: 'standalone'`
  - `images.remotePatterns` if serving any S3 images
- [ ] ~~Set `forcedTheme="dark"` in root `ThemeProvider` — dark only, no toggle~~ **Changed:** `defaultTheme="light"` with sun/moon toggle per user request
- [x] Create `.env.local` from the env vars table in SPEC (never commit)
- [x] Add `.env.local` and `.env*.local` to `.gitignore`

---

## Phase 0b — Accenture Brand Setup

- [x] **ShadCN CSS variable overrides** — `src/app/globals.css` split into `:root` (light) and `.dark` blocks with Accenture colors:
  ```css
  .dark {
    --background:        0 0% 0%;        /* #000000 */
    --foreground:        0 0% 100%;      /* #FFFFFF */
    --card:              0 0% 7%;        /* #111111 */
    --card-foreground:   0 0% 100%;
    --muted:             0 0% 10%;       /* #1A1A1A */
    --muted-foreground:  0 0% 53%;       /* #888888 */
    --border:            0 0% 20%;       /* #333333 */
    --input:             0 0% 7%;
    --primary:           276 100% 50%;   /* #A100FF */
    --primary-foreground:0 0% 100%;
    --ring:              276 100% 50%;   /* focus ring = purple */
    --accent:            276 100% 50%;
    --accent-foreground: 0 0% 100%;
  }
  ```

- [x] **Typography** — Inter font via Google Fonts in `globals.css`:
  ```css
  @import url('https://fonts.googleapis.com/css2?family=Inter:wght@400;600;700&family=JetBrains+Mono:wght@400&display=swap');

  :root {
    --font-sans: 'Graphik', 'Inter', system-ui, sans-serif;
    --font-mono: 'JetBrains Mono', monospace;
  }
  ```
  `tailwind.config.ts` updated with `fontFamily: { sans: ['var(--font-sans)'], mono: ['var(--font-mono)'] }`

- [ ] **Graphik font** — Graphik WOFF2 files not available; Inter is used as fallback:
  - Place in `public/fonts/` when available
  - Add `@font-face` blocks in `globals.css` before the Google Fonts import

- [x] **Logo component** — `src/components/brand/AccentureMark.tsx` — purple `>` chevron SVG

- [x] **Favicon** — `public/favicon.svg`: purple `>` on black background; referenced in `layout.tsx`

- [x] **Global body styles** in `globals.css`:
  ```css
  body { background-color: hsl(var(--background)); color: hsl(var(--foreground)); font-family: var(--font-sans); }
  ```

---

## Phase 1 — Core Infrastructure (non-UI)

### 1.1 Session ID
- [x] `src/lib/session.ts` — `getOrCreateSessionId()`:
  - Reads from `localStorage` key `NEXT_PUBLIC_SESSION_KEY`
  - On missing: writes `crypto.randomUUID()` and returns it
  - Returns `null` during SSR (guard with `typeof window !== 'undefined'`)

### 1.2 API helper
- [x] `src/lib/api.ts` — `callApi(url, options?)`:
  - Detects expired ALB session: `response.redirected` or content-type not `application/json`
  - On detection: `window.location.href = '/'` (forces full nav, completes Cognito redirect chain)
  - Otherwise: returns `response.json()`

### 1.3 AWS clients (server-only, `'use server'` / route handlers)
- [x] `src/lib/aws/bedrock.ts` — singleton `BedrockAgentRuntimeClient`
- [x] `src/lib/aws/dynamodb.ts` — singleton `DynamoDBDocumentClient`
- [x] `src/lib/aws/lambda.ts` — singleton `LambdaClient`

### 1.4 User identity
- [x] `src/lib/auth.ts` — `getUserFromRequest(headers: Headers): string | null`:
  - Reads `x-amzn-oidc-data`, base64-decodes payload segment, returns `email ?? sub`
  - No JWT library needed (ALB already verified the signature)

### 1.5 Shared types
- [x] `src/types/chat.ts`:
  ```typescript
  export type Role = 'user' | 'assistant';
  export interface Citation { source: string; page?: number; excerpt?: string; }
  export interface Message { id: string; role: Role; content: string; citations: Citation[]; }
  export interface Session { sessionId: string; title: string; lastMessageAt: string; }
  ```

---

## Phase 2 — API Routes

### 2.1 Health check
- [x] `src/app/api/health/route.ts` — `GET`: returns `{ status: "ok" }`

### 2.2 Chat
- [x] `src/app/api/chat/route.ts` — `POST { sessionId, message }`:
  - Call `InvokeAgentCommand` with `agentId`, `agentAliasId`, `sessionId`, `inputText`
  - Iterate streamed chunks; accumulate text; extract citations from trace events
  - Write user + assistant turns to DynamoDB (including `userEmail` and `sessionTitle` on first turn)
  - Return `{ message: string, citations: Citation[] }`

### 2.3 Upload presigned URL
- [x] `src/app/api/upload-url/route.ts` — `POST { fileName, fileType, industry, documentType, useCase?, client? }`:
  - Invoke upload Lambda via `InvokeCommand`
  - Return `{ url: string }`

### 2.4 History
- [x] `src/app/api/history/[sessionId]/route.ts` — `GET`:
  - Query DynamoDB by `sessionId` ascending by `timestamp`
  - Return `{ items: Message[] }`

### 2.5 Sessions list (sidebar)
- [x] `src/app/api/sessions/route.ts` — `GET`:
  - Query DynamoDB GSI on `userEmail` (from OIDC header)
  - Return `{ sessions: Session[] }` sorted by `lastMessageAt` descending

---

## Phase 3 — Layout Shell

### 3.1 Root layout
- [x] `src/app/layout.tsx`:
  - Wrap with `ThemeProvider` (`next-themes`, `defaultTheme="light"`, `enableSystem={false}`)
  - Add `<Toaster />` (`sonner`) for upload/error toasts
  - Full-height flex: `<AppSidebar />` + `<main>` side by side

### 3.2 Sidebar — `src/components/layout/AppSidebar.tsx`
- [x] Desktop: fixed width `w-64`, `bg-background border-r border-border`, full viewport height, `hidden md:flex flex-col`
- [x] Top section:
  - `<AccentureMark size={24} />` + "accenture" wordmark (`font-semibold text-sm tracking-tight`)
- [x] Nav buttons (`Button` variant ghost, full width, left-aligned, semantic muted colors):
  - **New Chat** — `PlusIcon`
  - **Search** — `SearchIcon`
  - **Upload Document** — `UploadIcon`
- [x] Section label style: `text-muted-foreground text-xs font-semibold uppercase tracking-widest`
- [x] Active session item: `bg-[rgba(161,0,255,0.08)] border-l-2 border-[#A100FF]`
- [x] Chat history list: `<ChatHistoryList />`
- [x] Bottom: `<UserIdentity />`
- [x] **Mobile:** hamburger button (`md:hidden fixed top-2.5 left-3 z-20`) opens `Sheet` drawer

### 3.3 Chat history — `src/components/layout/ChatHistoryList.tsx`
- [x] Fetches `GET /api/sessions` on mount
- [x] Groups sessions by date bucket: **Today** / **Yesterday** / **This Week** / **Older**
- [x] Each group has a small muted label (`text-muted-foreground text-xs`)
- [x] Each session: `Button` ghost full-width, truncated title
- [x] Active session highlighted with `bg-[rgba(161,0,255,0.08)] border-l-2 border-[#A100FF]`
- [x] `Skeleton` placeholder rows while loading

### 3.4 User identity — `src/components/layout/UserIdentity.tsx`
- [x] Client component fetches `/api/me`, extracts email
- [x] `Avatar` with initials on `bg-[#A100FF] text-white` + truncated email in `text-muted-foreground text-sm`
- [x] Pinned to bottom of sidebar with `mt-auto`, separator above

### 3.5 Top bar — `src/components/layout/TopBar.tsx`
- [x] Agent name displayed as `Badge`
- [x] **Theme toggle** — sun/moon `Button` icon switches light/dark via `useTheme`
- [x] Settings `Button` icon (gear) — placeholder
- [x] User `Avatar` (top-right corner)

---

## Phase 4 — Chat Components

### 4.1 Welcome screen — `src/components/chat/WelcomeScreen.tsx`
- [x] `flex flex-col items-center justify-center h-full bg-background gap-6 pt-12 md:pt-0`
- [x] `<AccentureMark size={48} />` + `<h2 className="text-foreground text-2xl font-semibold">{appName}</h2>`
- [x] Muted tagline: `text-muted-foreground text-sm` — "Powered by Accenture & Amazon Bedrock"
- [x] `<ChatInput>` at `max-w-2xl w-full` — controlled (`value`/`onChange` lifted to WelcomeScreen)
- [x] `<SuggestedPrompts>` below input

### 4.2 Suggested prompts — `src/components/chat/SuggestedPrompts.tsx`
- [x] 3 hardcoded domain-specific prompt cards
- [x] Card style: `bg-card border border-border rounded-lg p-3 hover:border-[#A100FF] transition-colors cursor-pointer`
- [x] Bold title `text-foreground text-sm font-medium` + muted subtitle `text-muted-foreground text-xs`
- [x] Clicking **populates** ChatInput and auto-focuses (textarea focuses via `useEffect` on value change)
- [x] **Responsive:** `grid-cols-1 sm:grid-cols-3`

### 4.3 Message list — `src/components/chat/MessageList.tsx`
- [x] `ScrollArea` fills remaining height between `TopBar` and `ChatInput`
- [x] `useEffect` to scroll to bottom on new message (`scrollIntoView` on bottom sentinel `div`)
- [x] Maps `messages[]` to `<MessageBubble />`
- [x] Appends `<ThinkingBubble />` while awaiting response

### 4.4 Message bubble — `src/components/chat/MessageBubble.tsx`
- [x] **User**: right-aligned row; bubble `bg-muted border-l-2 border-[#A100FF] rounded-2xl px-4 py-2 text-foreground`; `Avatar` with `bg-[#A100FF]` initials to the right
- [x] **Assistant**: left-aligned row, `<AccentureMark size={20} />` to the left, `prose dark:prose-invert max-w-none`
- [x] Assistant body via `react-markdown` + `rehype-highlight`; code block via `<CodeBlock />`
- [x] `<CitationList citations={citations} />` below body if citations present

### 4.5 Citations — `src/components/chat/CitationList.tsx`
- [x] ShadCN `Accordion`; trigger in `text-[#A100FF] text-sm`: "N sources"
- [x] Each citation: filename `Badge` + page number; excerpt in `Tooltip` on hover

### 4.6 Thinking indicator — `src/components/chat/ThinkingBubble.tsx`
- [x] Left-aligned, `<AccentureMark size={20} />`, three dots `bg-[#A100FF]` with `animate-pulse` stagger delay

### 4.7 Chat input — `src/components/chat/ChatInput.tsx`
- [x] Container: `bg-card border border-border rounded-xl focus-within:border-[#A100FF] transition-colors`
- [x] `Textarea` auto-resize (min 1 row, max ~6 rows): `bg-transparent text-foreground placeholder:text-muted-foreground resize-none` — Enter submits, Shift+Enter newline
- [x] Bottom toolbar row:
  - Left: `+` and `✦` as `Button` icon ghost, `text-muted-foreground hover:text-foreground`
  - Right: Send `Button` — `bg-[#A100FF] hover:bg-[#8A00E0] text-white disabled:opacity-40`; shows `Loader2` spin while loading
- [x] Accepts `onSubmit(message: string)` + `disabled` + optional `defaultValue`

---

## Phase 5 — Upload Sheet

### 5.1 Sheet component — `src/components/upload/UploadSheet.tsx`
- [x] ShadCN `Sheet` side="right", `w-full sm:w-[480px]`
- [x] Sheet styles: `bg-background border-l border-border text-foreground`
- [x] Header: "Upload Document" + step progress indicators

### 5.2 Drop zone — integrated in `UploadSheet.tsx`
- [x] `border-2 border-dashed border-border rounded-xl p-8 text-center text-muted-foreground`
- [x] Selected/drag-active state: `border-[#A100FF] bg-[rgba(161,0,255,0.04)]`
- [x] `onDragOver`/`onDragLeave`/`onDrop` handlers + click-to-open hidden `<input type="file" />`
- [x] Selected file: filename in `text-foreground`; drag-active shows "Drop to upload"

### 5.3 Metadata form — integrated in `UploadSheet.tsx`
- [x] Controlled with `react-hook-form` + `zod` schema:
  - `industry`: required `select`
  - `documentType`: required `select`
  - `useCase`: optional `Input`
  - `client`: optional `Input`
- [x] Inline validation errors via `FormMessage`

### 5.4 Upload progress — integrated in `UploadSheet.tsx`
- [x] ShadCN `Progress` bar: indicator `bg-[#A100FF]`, track `bg-muted`
- [x] Driven by `XMLHttpRequest` `progress` event
- [x] Status text `text-muted-foreground text-sm`: "Uploading… X%" / "Processing…"

### 5.5 Upload orchestration (in `UploadSheet.tsx`)
- [x] On submit:
  1. `POST /api/upload-url` with metadata → `{ url }`
  2. `XMLHttpRequest PUT` to S3 presigned URL, tracking progress
  3. On success: `toast.success('Document uploaded')`, close sheet
  4. On error: set error state, keep sheet open

---

## Phase 6 — Pages

### 6.1 Welcome page — `src/app/page.tsx`
- [x] Client component using `useChatSession` hook
- [x] Renders `<TopBar />` + `<WelcomeScreen />`
- [x] On first message submit: creates new `sessionId`, navigates to `/chat/[sessionId]`

### 6.2 Chat page — `src/app/chat/[sessionId]/page.tsx`
- [x] On mount: `GET /api/history/[sessionId]` to hydrate message list
- [x] Renders `<TopBar />` + `<MessageList />` + bottom-anchored `<ChatInput />`
- [x] On submit: optimistic user message append → `POST /api/chat` → append assistant response

---

## Phase 7 — Container

### 7.1 Dockerfile
- [x] Multi-stage build — `builder` (npm ci + build) → `runner` (standalone output only)
- [x] `CMD ["node", "server.js"]`, `EXPOSE 3000`
- [x] `ENV NODE_ENV=production` in runner stage

### 7.2 Docker Compose
- [x] `docker-compose.yml`
- [x] `docker-compose.override.yml` for local secrets (gitignored)
- [x] `.dockerignore`: `node_modules`, `.next`, `.env*`, `.git`, `*.md`

### 7.3 Verify locally
- [ ] `docker compose up --build` — app loads at `localhost:3000` *(Docker not installed on dev machine — verify on a machine with Docker)*
- [ ] AWS credential mount works for local Bedrock / DynamoDB calls *(see `DEPLOYMENT.md`)*

---

## Phase 8 — Terraform / ECS Integration

- [x] ECS task definition points to new ECR image — `terraform/team2/main.tf` task definition updated to `chat-frontend` container on port 3000
- [x] Task role additions: `bedrock-agent-runtime:InvokeAgent/Retrieve/RetrieveAndGenerate`, `dynamodb:GetItem/PutItem/Query`, `lambda:InvokeFunction` — all added to `aws_iam_role_policy.ecs_task` in `terraform/team2/main.tf`
- [x] ALB target group health check → `/api/health` — updated in `aws_lb_target_group.chat_frontend`
- [x] ALB Cognito auth rule unchanged — `aws_lb_listener_rule.chat_frontend` in `terraform/team2/main.tf` untouched
- [x] DynamoDB table: `knowledge-base-chat-history` with PK `sessionId`, SK `timestamp`, `userEmail` GSI — added to `terraform/modules/storage/main.tf`; outputs added to storage module, team1 outputs, and referenced from team2 task role policy
- [x] CI workflow — `.github/workflows/docker.yml` builds and pushes chat-ui to ECR on `push` to `main`; `terraform.yml` triggers team2 plan/apply when `chat-ui/**` changes

---

## Phase 9 — QA Checklist

**Branding**
- [ ] Accenture purple (`#A100FF`) appears on: Send button, active sidebar item border, user bubble left border, citation links, progress bar, thinking dots, focus rings
- [x] Font is Inter (Graphik fallback) — verified via `tailwind.config.ts` and `globals.css`
- [x] `AccentureMark` `>` chevron renders in purple in sidebar and welcome screen
- [x] Light/dark theme toggle works — light is default, sun/moon button in TopBar

**Layout**
- [x] Sidebar renders correctly on desktop (`hidden md:flex`)
- [x] Mobile: sidebar hidden behind `Sheet`, hamburger opens it

**Welcome screen**
- [x] Clicking a suggested prompt populates input and auto-focuses — `WelcomeScreen` lifts state; `ChatInput` focuses via `useEffect` when `value` prop changes
- [x] Sending first message creates session, navigates to `/chat/[sessionId]` — `useChatSession` calls `router.push` after first response

**Chat**
- [x] Messages render with correct alignment (user right, assistant left) — `MessageBubble` user=`flex justify-end`, assistant=`flex gap-3`
- [x] Markdown formatting renders in assistant messages — `react-markdown` + `rehype-highlight`
- [x] Thinking indicator shows while waiting, disappears on response — `ThinkingBubble` rendered when `isLoading && messages.length > 0`
- [x] Citations accordion opens/closes; excerpt visible in tooltip — `CitationList` uses ShadCN `Accordion` + `Tooltip`
- [x] Page reload at `/chat/[sessionId]` hydrates full history from DynamoDB — `useEffect` on mount fetches `/api/history/[sessionId]`
- [ ] Sidebar shows new session in "Today" group after first message *(requires live DynamoDB)*

**Upload**
- [x] Sheet opens from sidebar Upload Document button
- [x] File drag-and-drop — `onDragOver`/`onDrop` on drop zone label; "Drop to upload" text while dragging
- [x] File click-to-browse works — hidden `<input type="file">` triggered by label click
- [x] Required fields (Industry, DocumentType) block submit if empty — `zod` schema + `react-hook-form` validation
- [x] Progress bar tracks actual upload to S3 — `XMLHttpRequest` `progress` event drives ShadCN `Progress`
- [x] Success toast fires; sheet closes — `sonner` `toast.success` + `handleClose()`
- [x] Error state stays visible inside sheet if upload fails — catches error, sets `step(2)`, keeps sheet open

**Auth**
- [ ] `x-amzn-oidc-data` decoded correctly; user email shown in sidebar + top bar
- [ ] Simulated expired session → `callApi()` redirects to `/` on next API call
- [ ] No infinite redirect loop

**Container**
- [ ] `docker compose up` runs cleanly with local AWS credentials
- [ ] Production image builds without dev deps
- [ ] `curl localhost:3000/api/health` → `{ "status": "ok" }`
- [ ] No `.env` files or AWS credentials baked into image (`docker inspect` check)
