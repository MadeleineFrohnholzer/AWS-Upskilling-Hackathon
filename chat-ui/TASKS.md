# Chat UI — Implementation Tasks

Stack: Next.js (App Router) · ShadCN/ui · TypeScript · Docker / Docker Compose
Design: Accenture brand (black `#000000`, purple `#A100FF`, Graphik/Inter) · Open WebUI shell (dark sidebar, centered welcome input, bottom-anchored input in active chat)

---

## Phase 0 — Project Scaffolding

- [ ] `npx create-next-app@latest . --typescript --tailwind --app --src-dir`
- [ ] ShadCN init: `npx shadcn@latest init` — choose **New York** style, **Neutral** base color, CSS variables on
- [ ] Install ShadCN components needed up-front:
  ```
  npx shadcn@latest add button input textarea scroll-area accordion
    avatar badge separator sheet dialog command tooltip popover
    dropdown-menu progress sonner skeleton
  ```
- [ ] Install runtime dependencies:
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
- [ ] Configure `next.config.ts`:
  - `output: 'standalone'`
  - `images.remotePatterns` if serving any S3 images
- [ ] Set `forcedTheme="dark"` in root `ThemeProvider` — dark only, no toggle
- [ ] Create `.env.local` from the env vars table in SPEC (never commit)
- [ ] Add `.env.local` and `.env*.local` to `.gitignore`

---

## Phase 0b — Accenture Brand Setup

- [ ] **ShadCN CSS variable overrides** — replace generated defaults in `src/app/globals.css` `.dark` block:
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

- [ ] **Typography** — add to `globals.css` before Tailwind directives:
  ```css
  @import url('https://fonts.googleapis.com/css2?family=Inter:wght@400;600;700&family=JetBrains+Mono:wght@400&display=swap');

  :root {
    --font-sans: 'Graphik', 'Inter', system-ui, sans-serif;
    --font-mono: 'JetBrains Mono', monospace;
  }
  ```
  Update `tailwind.config.ts` to use `fontFamily: { sans: ['var(--font-sans)'], mono: ['var(--font-mono)'] }`

- [ ] **Graphik font** — if Graphik WOFF2 files are available from Accenture's brand portal:
  - Place in `public/fonts/`
  - Add `@font-face` blocks in `globals.css` before the Google Fonts import (takes precedence automatically)
  - Remove the Google Fonts `@import` once Graphik is confirmed working

- [ ] **Logo component** — `src/components/brand/AccentureMark.tsx`:
  ```tsx
  export function AccentureMark({ size = 24 }: { size?: number }) {
    return (
      <svg width={size} height={size} viewBox="0 0 24 24" fill="none">
        <path d="M6 4l12 8-12 8" stroke="#A100FF" strokeWidth="3"
              strokeLinecap="round" strokeLinejoin="round" />
      </svg>
    );
  }
  ```
  > Note: replace with the official Accenture SVG asset if available from brand portal — the chevron above is a programmatic approximation.

- [ ] **Favicon** — `public/favicon.svg`: purple `>` on black background; reference in `layout.tsx` `<head>`

- [ ] **Global body styles** in `globals.css`:
  ```css
  body { background-color: #000000; color: #FFFFFF; font-family: var(--font-sans); }
  ```

---

## Phase 1 — Core Infrastructure (non-UI)

### 1.1 Session ID
- [ ] `src/lib/session.ts` — `getOrCreateSessionId()`:
  - Reads from `localStorage` key `NEXT_PUBLIC_SESSION_KEY`
  - On missing: writes `crypto.randomUUID()` and returns it
  - Returns `null` during SSR (guard with `typeof window !== 'undefined'`)

### 1.2 API helper
- [ ] `src/lib/api.ts` — `callApi(url, options?)`:
  - Detects expired ALB session: `response.redirected` or content-type not `application/json`
  - On detection: `window.location.href = '/'` (forces full nav, completes Cognito redirect chain)
  - Otherwise: returns `response.json()`

### 1.3 AWS clients (server-only, `'use server'` / route handlers)
- [ ] `src/lib/aws/bedrock.ts` — singleton `BedrockAgentRuntimeClient`
- [ ] `src/lib/aws/dynamodb.ts` — singleton `DynamoDBDocumentClient`
- [ ] `src/lib/aws/lambda.ts` — singleton `LambdaClient`

### 1.4 User identity
- [ ] `src/lib/auth.ts` — `getUserFromRequest(headers: Headers): string | null`:
  - Reads `x-amzn-oidc-data`, base64-decodes payload segment, returns `email ?? sub`
  - No JWT library needed (ALB already verified the signature)

### 1.5 Shared types
- [ ] `src/types/chat.ts`:
  ```typescript
  export type Role = 'user' | 'assistant';
  export interface Citation { source: string; page?: number; excerpt?: string; }
  export interface Message { id: string; role: Role; content: string; citations: Citation[]; }
  export interface Session { sessionId: string; title: string; lastMessageAt: string; }
  ```

---

## Phase 2 — API Routes

### 2.1 Health check
- [ ] `src/app/api/health/route.ts` — `GET`: returns `{ status: "ok" }`

### 2.2 Chat
- [ ] `src/app/api/chat/route.ts` — `POST { sessionId, message }`:
  - Call `InvokeAgentCommand` with `agentId`, `agentAliasId`, `sessionId`, `inputText`
  - Iterate streamed chunks; accumulate text; extract citations from trace events
  - Write user + assistant turns to DynamoDB (including `userEmail` and `sessionTitle` on first turn)
  - Return `{ message: string, citations: Citation[] }`

### 2.3 Upload presigned URL
- [ ] `src/app/api/upload-url/route.ts` — `POST { fileName, fileType, industry, documentType, useCase?, client? }`:
  - Invoke upload Lambda via `InvokeCommand`
  - Return `{ url: string }`

### 2.4 History
- [ ] `src/app/api/history/[sessionId]/route.ts` — `GET`:
  - Query DynamoDB by `sessionId` ascending by `timestamp`
  - Return `{ items: Message[] }`

### 2.5 Sessions list (sidebar)
- [ ] `src/app/api/sessions/route.ts` — `GET`:
  - Query DynamoDB GSI on `userEmail` (from OIDC header)
  - Return `{ sessions: Session[] }` sorted by `lastMessageAt` descending

---

## Phase 3 — Layout Shell

### 3.1 Root layout
- [ ] `src/app/layout.tsx`:
  - Wrap with `ThemeProvider` (`next-themes`, `forcedTheme="dark"`)
  - Add `<Toaster />` (`sonner`) for upload/error toasts
  - Full-height flex: `<AppSidebar />` + `<main>` side by side

### 3.2 Sidebar — `src/components/layout/AppSidebar.tsx`
- [ ] Fixed width `w-64`, `bg-black border-r border-[#333333]`, full viewport height, `flex flex-col`
- [ ] Top section:
  - `<AccentureMark size={24} />` + "accenture" wordmark (`text-white font-semibold text-sm tracking-tight`) + collapse toggle
- [ ] Nav buttons (`Button` variant ghost, full width, left-aligned, `text-[#888888] hover:text-white hover:bg-[#1A1A1A]`):
  - **New Chat** — `PlusIcon`
  - **Search** — `SearchIcon`
  - **Upload Document** — `UploadIcon`
- [ ] Section label style: `text-[#888888] text-xs font-semibold uppercase tracking-widest px-3 mt-4 mb-1`
- [ ] Active session item: `bg-[rgba(161,0,255,0.08)] border-l-2 border-[#A100FF] text-white`
- [ ] Chat history list: `<ChatHistoryList />` (see §3.3)
- [ ] Bottom: `<UserIdentity />` (see §3.4)

### 3.3 Chat history — `src/components/layout/ChatHistoryList.tsx`
- [ ] Fetches `GET /api/sessions` on mount
- [ ] Groups sessions by date bucket: **Today** / **Yesterday** / **This Week** / **Older**
- [ ] Each group has a small muted label (`text-zinc-400 text-xs`)
- [ ] Each session: `Button` ghost full-width, truncated title, hover reveals `Trash2Icon` delete button
- [ ] Active session highlighted with `bg-zinc-800`
- [ ] `Skeleton` placeholder rows while loading

### 3.4 User identity — `src/components/layout/UserIdentity.tsx`
- [ ] Server component reads `x-amzn-oidc-data` via `headers()` (Next.js), extracts email
- [ ] `Avatar` with initials on `bg-[#A100FF] text-white` + truncated email in `text-[#888888] text-sm`
- [ ] Pinned to bottom of sidebar with `mt-auto`, separator above in `border-[#333333]`

### 3.5 Top bar — `src/components/layout/TopBar.tsx`
- [ ] Agent name/alias display (static `Badge` or `DropdownMenu` if multiple aliases configured)
- [ ] Settings `Button` icon (gear) — placeholder for now
- [ ] User `Avatar` (top-right corner) — same email as sidebar

---

## Phase 4 — Chat Components

### 4.1 Welcome screen — `src/components/chat/WelcomeScreen.tsx`
- [ ] `flex flex-col items-center justify-center h-full bg-black gap-6`
- [ ] `<AccentureMark size={48} />` + `<h2 className="text-white text-2xl font-semibold">{appName}</h2>`
- [ ] Muted tagline: `text-[#888888] text-sm` e.g. "Powered by Accenture & Amazon Bedrock"
- [ ] `<ChatInput>` at `max-w-2xl w-full`
- [ ] `<SuggestedPrompts>` below input

### 4.2 Suggested prompts — `src/components/chat/SuggestedPrompts.tsx`
- [ ] 3 hardcoded domain-specific prompt cards:
  - "Summarise the key risks in the latest uploaded document"
  - "What changed between the last two quarterly reports?"
  - "List the main clauses in the most recent contract"
- [ ] Card style: `bg-[#111111] border border-[#333333] rounded-lg p-3 hover:border-[#A100FF] transition-colors cursor-pointer`
- [ ] Bold title `text-white text-sm font-medium` + muted subtitle `text-[#888888] text-xs`
- [ ] Clicking populates `ChatInput`

### 4.3 Message list — `src/components/chat/MessageList.tsx`
- [ ] `ScrollArea` fills remaining height between `TopBar` and `ChatInput`
- [ ] `useEffect` to scroll to bottom on new message (`scrollIntoView` on a bottom sentinel `div`)
- [ ] Maps `messages[]` to `<MessageBubble />`
- [ ] Appends `<ThinkingBubble />` while awaiting response

### 4.4 Message bubble — `src/components/chat/MessageBubble.tsx`
- [ ] **User**: right-aligned row; bubble `bg-[#1A1A1A] border-l-2 border-[#A100FF] rounded-2xl px-4 py-2 text-white`; `Avatar` with `bg-[#A100FF]` initials to the right
- [ ] **Assistant**: left-aligned row, no background, `<AccentureMark size={20} />` to the left, prose `max-w-3xl text-white`
- [ ] Assistant body via `react-markdown` + `rehype-highlight`; code block: `bg-[#111111] border border-[#333333] font-mono text-sm`
- [ ] `<CitationList citations={citations} />` below body if citations present

### 4.5 Citations — `src/components/chat/CitationList.tsx`
- [ ] ShadCN `Accordion` single item; trigger `text-[#A100FF] text-sm hover:text-[#8C00E6]`: "▼ N sources"
- [ ] Each citation: filename `Badge` (`bg-[#1A1A1A] border-[#333333] text-[#888888]`) + page number; excerpt in a `Tooltip` on hover
- [ ] Divider between citations: `border-[#333333]`

### 4.6 Thinking indicator — `src/components/chat/ThinkingBubble.tsx`
- [ ] Left-aligned, `<AccentureMark size={20} />`, three dots `bg-[#A100FF]` with `animate-pulse` stagger delay (`delay-0`, `delay-150`, `delay-300`)

### 4.7 Chat input — `src/components/chat/ChatInput.tsx`
- [ ] Container: `bg-[#111111] border border-[#333333] rounded-2xl px-4 py-3 focus-within:border-[#A100FF] transition-colors`
- [ ] `Textarea` auto-resize (min 1 row, max 6 rows): `bg-transparent text-white placeholder:text-[#888888] resize-none outline-none` — Enter submits, Shift+Enter newline
- [ ] Bottom toolbar row:
  - Left: `+` and `✦` as `Button` icon ghost, `text-[#888888] hover:text-white`
  - Right: Send `Button` — `bg-[#A100FF] hover:bg-[#8C00E6] text-white px-4 rounded-xl disabled:opacity-40`; shows `Loader2` spin while loading
- [ ] Accepts `onSubmit(message: string)` + `disabled` + optional `defaultValue` (for suggested prompts)

---

## Phase 5 — Upload Sheet

### 5.1 Sheet component — `src/components/upload/UploadSheet.tsx`
- [ ] ShadCN `Sheet` side="right", `max-w-md`
- [ ] Override sheet styles: `bg-black border-l border-[#333333]`
- [ ] Header: "Upload Document" in `text-white font-semibold` + close `Button` icon ghost `text-[#888888] hover:text-white`

### 5.2 Drop zone — `src/components/upload/FileDropZone.tsx`
- [ ] `border-2 border-dashed border-[#333333] rounded-xl p-8 text-center text-[#888888]`
- [ ] Drag-active state: `border-[#A100FF] bg-[rgba(161,0,255,0.04)]`
- [ ] `onDragOver`/`onDrop` handlers + click-to-open hidden `<input type="file" />`
- [ ] Selected file: filename in `text-white` + `XIcon` button to clear

### 5.3 Metadata form — `src/components/upload/MetadataForm.tsx`
- [ ] Controlled with `react-hook-form` + `zod` schema:
  - `industry`: required `Select` (dropdown list TBD from requirements)
  - `documentType`: required `Select`
  - `useCase`: optional `Input`
  - `client`: optional `Input`
- [ ] ShadCN `Label` + `FormMessage` for inline validation errors

### 5.4 Upload progress — `src/components/upload/UploadProgress.tsx`
- [ ] ShadCN `Progress` bar: override indicator to `bg-[#A100FF]`, track `bg-[#1A1A1A]`
- [ ] Driven by `XMLHttpRequest` `progress` event (not `fetch`, which lacks upload progress)
- [ ] Status text `text-[#888888] text-sm`: "uploading…" / "complete" — "complete" text briefly in `text-[#A100FF]`

### 5.5 Upload orchestration (in `UploadSheet.tsx`)
- [ ] On submit:
  1. `callApi('POST /api/upload-url', metadata)` → `{ url }`
  2. `XMLHttpRequest PUT` to S3 presigned URL, tracking progress
  3. On success: `toast.success('Document uploaded')`, close sheet
  4. On error: set error state in sheet, keep sheet open

---

## Phase 6 — Pages

### 6.1 Welcome page — `src/app/page.tsx`
- [ ] Server component: reads sessions list for sidebar (or defer to client)
- [ ] Renders `<AppSidebar />` + `<TopBar />` + `<WelcomeScreen />`
- [ ] On first message submit: creates new `sessionId`, navigates to `/chat/[sessionId]`, then sends message

### 6.2 Chat page — `src/app/chat/[sessionId]/page.tsx`
- [ ] On mount: `GET /api/history/[sessionId]` to hydrate message list
- [ ] Renders `<AppSidebar />` + `<TopBar />` + `<MessageList />` + bottom-anchored `<ChatInput />`
- [ ] On submit: optimistic user message append → `POST /api/chat` → append assistant response
- [ ] Input transitions: same `<ChatInput>` component, positioned `sticky bottom-0` inside main panel

---

## Phase 7 — Container

### 7.1 Dockerfile
- [ ] Multi-stage build per SPEC §8 — `builder` (npm ci + build) → `runner` (standalone output only)
- [ ] `CMD ["node", "server.js"]`, `EXPOSE 3000`
- [ ] `ENV NODE_ENV=production` in runner stage

### 7.2 Docker Compose
- [ ] `docker-compose.yml` per SPEC §8
- [ ] `docker-compose.override.yml` for local secrets (gitignored)
- [ ] `.dockerignore`: `node_modules`, `.next`, `.env*`, `.git`, `*.md`

### 7.3 Verify locally
- [ ] `docker compose up --build` — app loads at `localhost:3000`
- [ ] AWS credential mount works for local Bedrock / DynamoDB calls

---

## Phase 8 — Terraform / ECS Integration

- [ ] ECS task definition points to new ECR image
- [ ] Task role additions: `bedrock:InvokeAgent`, `dynamodb:GetItem/PutItem/Query`, `lambda:InvokeFunction`
- [ ] ALB target group health check → `/api/health`
- [ ] ALB Cognito auth rule unchanged
- [ ] DynamoDB table: add `userEmail` attribute + GSI for `GET /api/sessions`
- [ ] CI workflow (`.github/workflows/terraform.yml`): build + push Docker image to ECR before `terraform apply`

---

## Phase 9 — QA Checklist

**Branding**
- [ ] Background is pure black (`#000000`) everywhere — no gray tint on any surface
- [ ] Accenture purple (`#A100FF`) appears on: Send button, active sidebar item border, user bubble left border, citation links, progress bar, thinking dots, focus rings
- [ ] Font is Graphik (if available) or Inter — verify in DevTools > Computed > font-family
- [ ] `AccentureMark` `>` chevron renders in purple in sidebar and welcome screen
- [ ] No light mode — `forcedTheme="dark"` confirmed, no flash on load

**Layout**
- [ ] Sidebar renders correctly; collapse/expand works on desktop
- [ ] Mobile: sidebar is hidden behind `Sheet`, hamburger opens it

**Welcome screen**
- [ ] Centered input + suggested prompts visible on `/`
- [ ] Clicking a suggested prompt populates input and auto-focuses
- [ ] Sending first message creates session, navigates to `/chat/[sessionId]`

**Chat**
- [ ] Messages render with correct alignment (user right, assistant left)
- [ ] Markdown formatting renders in assistant messages (bold, lists, code blocks)
- [ ] Thinking indicator shows while waiting, disappears on response
- [ ] Citations accordion opens/closes; excerpt visible in tooltip
- [ ] Page reload at `/chat/[sessionId]` hydrates full history from DynamoDB
- [ ] Sidebar shows new session in "Today" group after first message

**Upload**
- [ ] Sheet opens from sidebar button and from `+` in chat input
- [ ] File drag-and-drop + click-to-browse both work
- [ ] Required fields (Industry, DocumentType) block submit if empty
- [ ] Progress bar tracks actual upload to S3
- [ ] Success toast fires; sheet closes
- [ ] Error state stays visible inside sheet if upload fails

**Auth**
- [ ] `x-amzn-oidc-data` decoded correctly; user email shown in sidebar + top bar
- [ ] Simulated expired session (clear ALB cookie) → `callApi()` redirects to `/` on next API call
- [ ] No infinite redirect loop

**Container**
- [ ] `docker compose up` runs cleanly with local AWS credentials
- [ ] Production image builds without dev deps
- [ ] `curl localhost:3000/api/health` → `{ "status": "ok" }`
- [ ] No `.env` files or AWS credentials baked into image (`docker inspect` check)
