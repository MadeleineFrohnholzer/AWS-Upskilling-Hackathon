# Chat UI — Architecture Specification

## Stack

| Layer | Technology |
|---|---|
| Frontend | Next.js (App Router), ShadCN/ui, TypeScript |
| Backend | Next.js Route Handlers (API routes, same container) |
| AWS SDK | `@aws-sdk/client-bedrock-agent-runtime`, `@aws-sdk/client-lambda`, `@aws-sdk/client-dynamodb` / `@aws-sdk/lib-dynamodb` |
| Container | Multi-stage Dockerfile, Docker Compose for local dev |
| Auth | ALB-native Cognito (Entra ID via OIDC federation) |

---

## 1. UI Design — Accenture-branded, Open WebUI-inspired Layout

The visual language follows Accenture's brand guidelines (pure black, signature purple `#A100FF`, Graphik typeface) mapped onto the Open WebUI shell: collapsible left sidebar with chat history, centered floating input on the welcome screen, bottom-anchored input once a conversation starts. All interactive elements use ShadCN components with Accenture CSS variable overrides.

### 1.1 Overall Chrome

```
┌──────────────────────────────────────────────────────────────────────┐
│ ┌────────────────────┐  ┌──────────────────────────────────────────┐ │
│ │ >  accenture    ⊡  │  │  Knowledge Assistant ▾            ⚙  👤 │ │
│ ├────────────────────┤  ├──────────────────────────────────────────┤ │
│ │ ✚  New Chat        │  │                                          │ │
│ │ 🔍  Search         │  │                                          │ │
│ │ ↑   Upload Doc     │  │         >  Knowledge Assistant           │ │
│ ├────────────────────┤  │                                          │ │
│ │ RECENT CHATS       │  │   ┌──────────────────────────────────┐   │ │
│ │  Today             │  │   │  Ask anything about your docs…   │   │ │
│ │   · Contract Q3    │  │   │ ─────────────────────────────── │   │ │
│ │   · Risk Analysis  │  │   │  ✚  ✦                    ↑ Send │   │ │
│ │  Yesterday         │  │   └──────────────────────────────────┘   │ │
│ │   · Finance Q2     │  │                                          │ │
│ ├────────────────────┤  │   ✦ Suggested                            │ │
│ │ 👤  user@accenture │  │    · Summarise the risks in the Q3 doc   │ │
│ └────────────────────┘  │    · What changed since last quarter?     │ │
│                         └──────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────────────────┘
```

### 1.2 Active Conversation

```
┌────────────────────┐  ┌──────────────────────────────────────────┐
│  (sidebar same)    │  │                                          │
│                    │  │  👤  What are the risks in the Q3 doc?   │
│                    │  │                                          │
│                    │  │  >   Based on the document, the key      │
│                    │  │     risks are:                           │
│                    │  │     1. Market volatility…                │
│                    │  │     2. Regulatory changes…               │
│                    │  │     ▼ 2 citations                        │
│                    │  │       · Q3_Report.pdf · p. 4             │
│                    │  │       · Q3_Report.pdf · p. 12            │
│                    │  │                                          │
│                    │  ├──────────────────────────────────────────┤
│                    │  │ ┌──────────────────────────────────────┐ │
│                    │  │ │ Reply…                               │ │
│                    │  │ │ ─────────────────────────────────── │ │
│                    │  │ │ ✚  ✦                   [  Send  >]  │ │
│                    │  │ └──────────────────────────────────────┘ │
└────────────────────┘  └──────────────────────────────────────────┘
```

### 1.3 Brand Tokens

These override ShadCN's default CSS variables in `globals.css`.

| Token | Hex | CSS variable | Usage |
|---|---|---|---|
| Accenture Purple | `#A100FF` | `--accent` / `--primary` | Send button, active sidebar item, focus rings, links |
| Purple hover | `#8C00E6` | `--primary-hover` | Button hover state |
| Purple subtle | `rgba(161,0,255,0.08)` | `--accent-subtle` | Active sidebar row background |
| Black | `#000000` | `--background` | App shell, sidebar |
| Surface dark | `#111111` | `--card` | Input box, message area |
| Surface mid | `#1A1A1A` | `--muted` | Hover states, user bubble |
| Border | `#333333` | `--border` | Dividers, input border |
| Text primary | `#FFFFFF` | `--foreground` | Body text |
| Text muted | `#888888` | `--muted-foreground` | Section labels, timestamps |
| User bubble | `#1A1A1A` + left border `#A100FF` | — | User message background |
| Assistant | transparent | — | No bubble — prose on black |

Dark mode is the **only** mode — `next-themes` with `forcedTheme="dark"` in `layout.tsx`.

### 1.4 Typography

| Role | Family | Weight | Notes |
|---|---|---|---|
| Primary | `Graphik` | 400 / 600 / 700 | Accenture licensed typeface — load from internal CDN or bundled WOFF2 if available |
| Fallback | `Inter` | 400 / 600 / 700 | Free Google Fonts substitute; nearly identical metrics |
| Code | `JetBrains Mono` | 400 | Code blocks in assistant messages |

```css
/* globals.css */
@import url('https://fonts.googleapis.com/css2?family=Inter:wght@400;600;700&family=JetBrains+Mono:wght@400&display=swap');

:root {
  --font-sans: 'Graphik', 'Inter', system-ui, sans-serif;
  --font-mono: 'JetBrains Mono', monospace;
}
```

If Graphik WOFF2 files are available (from Accenture's brand portal), add a `@font-face` block above the Google Fonts import and it takes precedence automatically.

### 1.5 Logo

The Accenture logo is the `>` accent mark — a bold right-pointing chevron — in `#A100FF` on black, followed by the "accenture" wordmark in lowercase white Graphik.

- In the sidebar: `>` as an inline SVG (or custom `AccentureLogo` component) at `24×24px`, wordmark in `text-white font-semibold text-sm tracking-tight`
- In the welcome screen hero: larger `>` at `48×48px`, `text-2xl` wordmark below
- Favicon: purple `>` on black, provided as `public/favicon.svg`

```tsx
// src/components/brand/AccentureLogo.tsx
export function AccentureMark({ size = 24 }: { size?: number }) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="none">
      <path d="M6 4l12 8-12 8" stroke="#A100FF" strokeWidth="3"
            strokeLinecap="round" strokeLinejoin="round" />
    </svg>
  );
}

---

## 2. Component Breakdown

### 2.1 Sidebar

`<AppSidebar>` — fixed-width (`w-64`), `bg-black`, collapsible via ShadCN `Sheet` on mobile or icon-toggle on desktop.

| Element | ShadCN primitive | Notes |
|---|---|---|
| App logo + name | `<AccentureMark>` + wordmark | Purple `>` SVG + "accenture" lowercase white |
| Collapse toggle | `Button` variant ghost | Hides sidebar, icon-only mode |
| New Chat | `Button` variant ghost | Clears state, navigates to `/` |
| Search | `Button` variant ghost | Opens `CommandDialog` over full history |
| Upload Document | `Button` variant ghost | Opens upload `Sheet` (see §2.4) |
| Chat history list | `ScrollArea` | Grouped by date: Today / Yesterday / This Week / Older |
| History item | `Button` variant ghost | Truncated title; hover `bg-[#1A1A1A]`; active item gets `bg-[rgba(161,0,255,0.08)]` left border `border-l-2 border-[#A100FF]` |
| User identity | `Avatar` + email text | Bottom-pinned; initials on `bg-[#A100FF]`; email from OIDC header |

### 2.2 Top Bar

Stretches full width of the main panel.

| Element | ShadCN primitive | Notes |
|---|---|---|
| Agent selector | `DropdownMenu` (or static `Badge`) | Shows Bedrock Agent alias name; dropdown if multiple aliases |
| Settings | `Button` icon | Navigates to `/settings` or opens sheet |
| User avatar | `Avatar` | Initials from email; tooltip shows full email |

### 2.3 Chat Area

**Welcome / empty state** (no messages yet):
- Vertically centered in the main panel, `bg-black`
- Large `<AccentureMark size={48} />` above the heading
- `h2` heading: "Knowledge Assistant" in `font-semibold text-white` (Graphik/Inter)
- Floating `<ChatInput>` centered at `max-w-2xl`, `bg-[#111111] border-[#333333]`
- Suggested prompts below input: 3 domain-specific clickable cards

**Active conversation**:
- `<MessageList>` fills available height, scrollable (`ScrollArea`)
- `<ChatInput>` anchored to the bottom, full width of main panel
- No top-to-bottom layout shift — input moves from center → bottom on first message send

### 2.4 Message Bubbles

**User message:**
- Right-aligned, `bg-[#1A1A1A]` pill + `border-l-2 border-[#A100FF]` left accent, white text
- `Avatar` with user initials on `bg-[#A100FF]` to the right

**Assistant message:**
- Left-aligned, no background, prose typography (`font-sans text-white`)
- `<AccentureMark size={20} />` icon to the left instead of a generic avatar
- Markdown rendered via `react-markdown` + `rehype-highlight` (code blocks styled with dark theme)
- Citations below message body as collapsible `Accordion`, trigger text in `text-[#A100FF] text-sm`:
  ```
  ▼ 2 sources
    · Q3_Report.pdf · page 4   [excerpt on hover via Tooltip]
    · Q3_Report.pdf · page 12
  ```

**Loading state:**
- Three dots with `animate-pulse`, `bg-[#A100FF]` dot color, replacing the assistant message while streaming

### 2.5 Chat Input

Single component used in both welcome (centered) and active (bottom-anchored) states.

```
┌──────────────────────────────────────────────────────────┐
│  Ask anything about your documents…                      │
│  ────────────────────────────────────────────────────    │
│  ✚  ✦                                          ↑ Send   │
└──────────────────────────────────────────────────────────┘
```

| Control | ShadCN | Behaviour |
|---|---|---|
| `Textarea` | auto-resize, max 6 rows | Enter submits; Shift+Enter newline; `bg-transparent text-white placeholder:text-[#888888]` |
| `+` button | `Button` icon ghost | Opens upload `Sheet`; icon `text-[#888888]` hover `text-white` |
| `✦` button | `Button` icon ghost | Reserved; same muted style |
| Send | `Button` | `bg-[#A100FF] hover:bg-[#8C00E6] text-white`; disabled state `opacity-40`; shows `Loader2` while loading |

### 2.6 Upload Sheet

Opens as a ShadCN `Sheet` (slides in from the right) — keeping the user in context. Styled in `bg-black border-l border-[#333333]`.

```
┌──────────────────────────────────────────────┐  bg-black
│  Upload Document                          ✕  │  border-b border-[#333333]
├──────────────────────────────────────────────┤
│  ┌─────────────────────────────────────────┐ │  border-2 border-dashed
│  │  Drag & drop or click to select a file  │ │  border-[#333333] hover:border-[#A100FF]
│  └─────────────────────────────────────────┘ │
│                                              │
│  Industry *        [ Select…           ▾ ]  │  label text-[#888888]; Select bg-[#111111]
│  Document Type *   [ Select…           ▾ ]  │
│  Use Case          [ Optional…           ]  │
│  Client            [ Optional…           ]  │
│                                              │
│  ████████████░░░░░░  62%  uploading…         │  Progress bar: bg-[#A100FF]
│                                              │
│  [      Cancel      ]  [   Upload  >  ]      │  Upload btn: bg-[#A100FF] hover:bg-[#8C00E6]
└──────────────────────────────────────────────┘
```

Flow:
1. User selects file + fills metadata
2. `POST /api/upload-url` → backend returns presigned S3 URL
3. Browser `PUT` directly to S3 (presigned URL); `Progress` bar tracks `XMLHttpRequest` upload progress
4. On success: `Sonner` toast "Document uploaded", sheet closes
5. On error: inline error state inside sheet, sheet stays open

### 2.7 Search (Command Palette)

`CommandDialog` (ShadCN `Command` + `Dialog`) triggered by sidebar Search or `Ctrl+K`. Styled `bg-black border-[#333333]`; matching items highlight with `bg-[rgba(161,0,255,0.08)] text-white`; the search input uses `text-white placeholder:text-[#888888]`.
- Searches session titles from DynamoDB history
- Selecting a result navigates to that session's chat

---

## 3. Routing & Pages

| Route | Component | Description |
|---|---|---|
| `/` | `app/page.tsx` | Welcome state — no messages, centered input |
| `/chat/[sessionId]` | `app/chat/[sessionId]/page.tsx` | Active conversation, hydrates from DynamoDB |
| `/api/health` | route handler | ALB health check |
| `/api/chat` | route handler | Bedrock Agent invocation |
| `/api/upload-url` | route handler | Presigned URL via Lambda |
| `/api/history/[sessionId]` | route handler | DynamoDB read |
| `/api/sessions` | route handler | List all sessions for sidebar (DynamoDB scan by user) |

---

## 4. Backend (Next.js Route Handlers)

Single Next.js app — serves the React build and API from one container on one port.

### `POST /api/chat`
- Reads `{ sessionId, message }` from request body
- Calls Bedrock Agent via `InvokeAgentCommand` (`agentId`, `agentAliasId`, `sessionId`, `inputText`)
- Parses streamed chunks; extracts citations from trace events
- Writes both user and assistant turns to DynamoDB
- Returns `{ message: string, citations: Citation[] }`

### `POST /api/upload-url`
- Receives `{ fileName, fileType, industry, documentType, useCase?, client? }`
- Invokes the presigned-URL Lambda directly via `@aws-sdk/client-lambda` (`InvokeCommand`)
- Returns `{ url: string }` — browser `PUT`s directly to S3

### `GET /api/history/[sessionId]`
- Queries DynamoDB by `sessionId`, ordered by `timestamp` ascending
- Returns `{ items: HistoryItem[] }` for conversation hydration

### `GET /api/sessions`
- Queries DynamoDB sessions for the current user (from OIDC header)
- Returns `{ sessions: { sessionId, title, lastMessageAt }[] }` for sidebar list

### `GET /api/health`
- Returns `{ status: "ok" }` — ALB target group health check

---

## 5. Auth — ALB-native Cognito

### Normal case
- ALB refreshes tokens transparently; route handlers see a valid `x-amzn-oidc-data` header on every request
- No expiry-handling code needed server-side

### Expired ALB session — `callApi()` wrapper

```typescript
async function callApi(url: string, options?: RequestInit) {
  const response = await fetch(url, options);

  const contentType = response.headers.get('content-type') ?? '';
  if (response.redirected || !contentType.includes('application/json')) {
    // ALB returned Cognito login HTML instead of JSON — force full navigation
    // so the ALB→Cognito→Entra redirect chain completes properly
    window.location.href = '/';
    return;
  }

  return response.json();
}
```

### User identity (server-side)

```typescript
function getUserFromRequest(headers: Headers): string | null {
  const oidcData = headers.get('x-amzn-oidc-data');
  if (!oidcData) return null;
  const payload = JSON.parse(
    Buffer.from(oidcData.split('.')[1], 'base64').toString('utf-8')
  );
  return payload.email ?? payload.sub;
}
```

ALB has already verified the signature — no third-party JWT library needed.

---

## 6. DynamoDB

### Chat History Table

| Attribute | Type | Role |
|---|---|---|
| `sessionId` | String | Partition key |
| `timestamp` | String (ISO-8601) | Sort key |
| `role` | String | `"user"` or `"assistant"` |
| `message` | String | Message text |
| `citations` | List | `{ source, page, excerpt }[]` |
| `userEmail` | String | For `GET /api/sessions` filtering (GSI on `userEmail`) |
| `sessionTitle` | String | First user message (truncated, written on first turn) |

### Agent Config Item(s)
- System prompt overrides, temperature, model ID — read at request time; no redeploy needed

---

## 7. Statelessness & Scaling

- Every `/api/chat` call is a stateless HTTP request — no pinned connections
- Server holds no per-session state; all context lives in DynamoDB
- Any ECS task can serve any request — no sticky sessions, ever

---

## 8. Container

### Dockerfile (multi-stage)

```dockerfile
# Stage 1 — build
FROM node:20-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build

# Stage 2 — run
FROM node:20-alpine AS runner
WORKDIR /app
ENV NODE_ENV=production
COPY --from=builder /app/.next/standalone ./
COPY --from=builder /app/.next/static ./.next/static
COPY --from=builder /app/public ./public
EXPOSE 3000
CMD ["node", "server.js"]
```

### Docker Compose (local dev)

```yaml
services:
  chat-ui:
    build: .
    ports:
      - "3000:3000"
    environment:
      - AWS_REGION
      - BEDROCK_AGENT_ID
      - BEDROCK_AGENT_ALIAS_ID
      - DYNAMODB_TABLE_NAME
      - UPLOAD_LAMBDA_NAME
    volumes:
      - ~/.aws:/root/.aws:ro   # local dev credentials only
```

### ECS Task Role — required permissions

```
bedrock:InvokeAgent
dynamodb:GetItem
dynamodb:PutItem
dynamodb:Query
lambda:InvokeFunction
```

---

## 9. Environment Variables

| Variable | Description |
|---|---|
| `AWS_REGION` | e.g. `eu-west-1` |
| `BEDROCK_AGENT_ID` | Bedrock Agent resource ID |
| `BEDROCK_AGENT_ALIAS_ID` | Agent alias (e.g. `TSTALIASID` for draft) |
| `DYNAMODB_TABLE_NAME` | Chat history table name |
| `UPLOAD_LAMBDA_NAME` | Lambda function name/ARN for presigned URL generation |
| `NEXT_PUBLIC_APP_NAME` | Display name shown in sidebar + welcome screen (default: `Knowledge Assistant`) |
