# PlantIt Helper — Story Tracker

## Status Legend
| Symbol | Meaning |
|--------|---------|
| [done] | Done |
| [in progress] | In Progress |
| [not started] | Not Started |
| [blocked] | Blocked |

---

## Technical Decisions (Resolved)

| Decision | Choice | Reason |
|----------|--------|--------|
| Database | PostgreSQL (SQLite for tests) | Postgres from day 1 — avoids migration pain later |
| Auth | Access token (15min) + refresh token (30d) with rotation | More secure than long-lived single token |
| State management | Plain StatefulWidget + service classes | Simple for now; add Riverpod when app grows |
| Image AI | Claude Opus via Anthropic SDK | Tried and working end-to-end |
| Image preprocessing | flutter_image_compress (client-side) | C++ pybind plan scrapped — unnecessary complexity |
| File storage | Local filesystem for MVP | Add S3 when going to production |
| Push notifications | flutter_local_notifications for MVP | FCM for production v2 |

---

## Epic Progress

| Epic | Title | Stories | Done |
|------|-------|---------|------|
| E1 | Foundation & Auth | 3 | 3 |
| E2 | Plant Scan & Identification | 3 | 3 |
| E3 | Save & My Plants Collection | 2 | 2 |
| E4 | Plant Detail & Care Info | 2 | 0 |
| E5 | Chat with Your Plant | 2 | 0 |
| E6 | Care Schedule & Reminders | 2 | 0 |
| E7 | Plant Journal | 1 | 0 |
| E8 | Plant Health Tracking | 2 | 0 |

**Total: 17 stories — 8 done**

---

## E1 — Foundation & Auth

### E1-S1: Project Scaffolding [done]
**Completed:** 2026-07-07
- Flutter app scaffolded; FastAPI running with `GET /health`
- Backend folder structure: `models/`, `router/`, `services/`, `db/`
- PostgreSQL + SQLAlchemy async setup
- Alembic migrations configured

---

### E1-S2: User Signup & Login [done]
**Completed:** 2026-07-08
- `POST /auth/register` — bcrypt password, returns access + refresh tokens
- `POST /auth/login` — same response shape
- `POST /auth/logout` — revokes refresh token
- `POST /auth/forgot-password` — 6-digit code via email
- `POST /auth/reset-password` — verifies code, updates password
- Flutter: login, register, forgot password, reset password screens
- Form validation: email format, password min 8 chars, confirm match
- Inline error messages, loading states, all buttons disabled during request

---

### E1-S3: Auth Persistence [done]
**Completed:** 2026-07-09
- `GET /auth/me` — validates token, returns current user
- `POST /auth/refresh` — token rotation (old token revoked, new pair issued)
- Flutter: `TokenService` using `flutter_secure_storage`
- Flutter: `SplashScreen` — checks token on launch, auto-routes to home or login
- Flutter: logout clears both tokens from secure storage

---

## E2 — Plant Scan & Identification

### E2-S1: Camera & Gallery Capture [done]
**Completed:** 2026-07-10
- `CaptureScreen` — two options: Take a Photo / Choose from Gallery
- `image_picker` for camera and gallery access
- `flutter_image_compress` — JPEG, 512px min, quality 85
- Permission denial handled with banner + "Go to Settings" guidance
- Loading state during compression; graceful cancel handling

---

### E2-S2: Preview & Scan [done]
**Completed:** 2026-07-10
- `PreviewScreen` — shows compressed image before submitting
- Retake button navigates back to capture
- "Scan This Plant" triggers `POST /scan`
- Spinner + both buttons disabled while scan is in-flight
- Label changes to "Try Again" after error
- Error banner shown inline (not just snackbar) for all failure types

---

### E2-S3: Plant Identification & Result Screen [done]
**Completed:** 2026-07-15
**Branch merged:** `feature/E2-S3-scan-flutter`

**What was built:**
- `POST /scan` — multipart image upload, Claude Opus identification, returns structured JSON
- Claude system prompt: botanist persona, strict JSON-only output, handles bulbs/tubers/corms
- `ResultScreen` — plant name, scientific name, confidence badge, 2x2 care grid, action buttons
- `ScanResult` + `CareInfo` Dart models with full `fromJson` parsing
- `AppConfig` — single source of truth for API base URL (overridable via `--dart-define`)

**All error states handled:**
- 422 → "No plant detected. Try a clearer photo."
- 401 mid-scan → clears tokens, redirects to login screen (no dead end)
- 413 → "Image is too large. Try a smaller photo."
- Timeout (30s) → "Request timed out. Please try again."
- Network failure → "Could not connect to server. Check your network."
- 500 → "Something went wrong. Please try again."

**Technical decisions made:**
- `debugPrint` instead of `dart:developer` — visible in `flutter run` terminal
- `fun_fact` is `Optional[str]` — Claude sometimes omits it
- Content-type: Flutter sends `MediaType('image', 'jpeg')` explicitly — avoids `application/octet-stream` rejection
- `application/octet-stream` added to allowed types as fallback
- Double-pop navigation: `Scan Another Plant` pops ResultScreen + PreviewScreen → lands on CaptureScreen

---

## E3 — Save & My Plants Collection

### E3-S1: Save Plant [done]
**Goal:** After a successful scan, user saves the plant to their collection with a custom name.

**User Story:**
> As a user, after I scan a plant and see the result, I want to save it to my collection so I can refer back to its care info and track it over time.

**Acceptance Criteria:**
- [x] "Save This Plant" button on ResultScreen opens a bottom sheet
- [x] Name field pre-filled with the plant's common name (editable)
- [x] Name cannot be empty — show inline error if user clears it and tries to save
- [x] `POST /plants` creates a plant record tied to the current user
- [x] On save success: close bottom sheet, show snackbar "Plant saved!", button changes to "Saved" (disabled)
- [x] On save error: show error in bottom sheet, keep it open so user can retry
- [x] `POST /plants` requires auth — 401 redirects to login
- [x] Saving the same plant twice is allowed (same species, different pots)

**API: POST /plants**
Request:
```json
{
  "name": "My Monstera",
  "common_name": "Monstera",
  "scientific_name": "Monstera deliciosa",
  "confidence": "high",
  "care": {
    "light": "...", "water": "...",
    "humidity": "...", "temperature": "...",
    "tips": ["..."]
  },
  "fun_fact": "..."
}
```
Response (201):
```json
{ "id": "uuid", "name": "My Monstera", "created_at": "..." }
```

**DB: plants table**
```
id          UUID PK
user_id     UUID FK → users
name        VARCHAR(100)   — user's custom name
common_name VARCHAR(100)
scientific_name VARCHAR(150)
confidence  VARCHAR(10)    — low/medium/high
care_json   JSONB          — full care object
fun_fact    TEXT nullable
created_at  TIMESTAMPTZ
```

**Edge Cases:**
- Name field left blank → inline error "Please give your plant a name"
- Name > 100 chars → frontend truncates at 100, backend enforces VARCHAR(100)
- `POST /plants` fails (network/500) → show "Could not save. Try again." in sheet, keep sheet open
- User taps save twice quickly → disable button immediately on first tap (prevent duplicate DB rows)
- User navigates away before saving → nothing saved, no data loss (scan result still shows)
- `fun_fact` is null → save succeeds, null stored cleanly
- Very long care text from Claude → JSONB stores any length, no truncation

**Tests to write:**
- Unit: `POST /plants` returns 201 with correct fields
- Unit: `POST /plants` without auth returns 401
- Unit: `POST /plants` with empty name returns 422
- Unit: name > 100 chars returns 422
- Widget: save button disabled while request in flight
- Widget: success state shows "Saved" button
- Widget: error state shows message in bottom sheet

**Dependencies:** E2-S3 complete [done]

---

### E3-S2: My Plants Collection Screen [done]
**Completed:** 2026-07-15
**Goal:** Home screen showing all saved plants as a scrollable list. Tap to see detail. FAB to scan.

**User Story:**
> As a user, I want to see all my saved plants in one place so I can quickly find one and check its care info.

**Acceptance Criteria:**
- [ ] `GET /plants` returns current user's plants, newest first
- [ ] Plants shown as cards: plant name, scientific name, confidence badge, saved date
- [ ] Empty state: illustration + "You have no plants yet. Scan your first one!" + scan button
- [ ] FAB (green, camera icon) → navigates to CaptureScreen
- [ ] Tap plant card → navigates to PlantDetailScreen (E4-S1)
- [ ] Pull-to-refresh reloads list
- [ ] Loading skeleton shown while fetching
- [ ] HomeScreen updated to show MyPlantsScreen instead of placeholder

**API: GET /plants**
Response (200):
```json
[
  {
    "id": "uuid",
    "name": "My Monstera",
    "common_name": "Monstera",
    "scientific_name": "Monstera deliciosa",
    "confidence": "high",
    "created_at": "2026-07-15T10:00:00Z"
  }
]
```

**Edge Cases:**
- 0 plants → empty state, not a blank screen
- Network error on load → "Could not load plants. Pull to refresh." banner, show last cached list if available
- Plant name very long → truncate at 2 lines with ellipsis
- 50+ plants → `ListView.builder` (lazy load), not a Column
- User saves a plant while on this screen, then navigates back → list refreshes automatically

**Tests to write:**
- Unit: `GET /plants` returns only current user's plants (not other users')
- Unit: `GET /plants` returns 401 without auth
- Widget: empty state shows CTA
- Widget: plant cards render name and scientific name
- Widget: pull-to-refresh calls API again

**Dependencies:** E3-S1 complete

---

## E4 — Plant Detail & Care Info

### E4-S1: Plant Detail Screen [not started]
**Goal:** Full scrollable screen for a saved plant showing all care info and a re-scan option.

**User Story:**
> As a user, I want to tap a plant in my collection and see all its care details so I know exactly how to look after it.

**Acceptance Criteria:**
- [ ] Header: plant name (user's custom name) + scientific name
- [ ] Confidence badge from original scan
- [ ] Full 2x2 care grid (light, water, humidity, temperature) — same style as ResultScreen
- [ ] Tips section: bulleted list from Claude
- [ ] Fun fact shown if present (hidden if null)
- [ ] Saved date shown: "Saved 3 days ago"
- [ ] "Scan Again" button → CaptureScreen (replaces scan data on save — E4-S2)
- [ ] "Delete Plant" option in app bar menu → confirm dialog → DELETE /plants/{id} → back to collection
- [ ] `GET /plants/{id}` endpoint returns full plant data

**API: GET /plants/{id}**
Response (200): full plant object including care_json

**API: DELETE /plants/{id}**
Response (204): no body

**Edge Cases:**
- Plant not found (deleted on another device) → 404 → show "This plant no longer exists" + back button
- `GET /plants/{id}` returns 401 → redirect to login
- `fun_fact` null → hide that section entirely (no empty card)
- Delete confirmed but network fails → show error snackbar, plant stays in list
- Delete cancelled → nothing happens

**Tests to write:**
- Unit: `GET /plants/{id}` returns 404 for another user's plant (ownership check)
- Unit: `DELETE /plants/{id}` returns 204; plant gone from `GET /plants`
- Unit: `DELETE /plants/{id}` returns 404 for another user's plant
- Widget: fun_fact section hidden when null
- Widget: delete confirm dialog appears, cancel does not delete

**Dependencies:** E3-S2 complete

---

### E4-S2: Re-scan a Plant [not started]
**Goal:** User can re-scan an existing saved plant to update its identification and care info.

**User Story:**
> As a user, my plant has grown and I want to scan it again to get updated care advice.

**Acceptance Criteria:**
- [ ] "Scan Again" on PlantDetailScreen → goes to CaptureScreen with plant context
- [ ] After successful scan, shows ResultScreen with option "Update [plant name]"
- [ ] `PATCH /plants/{id}` updates: common_name, scientific_name, confidence, care_json, fun_fact
- [ ] Updated care info immediately visible on PlantDetailScreen after returning
- [ ] Original saved date preserved; add `updated_at` field to plants table
- [ ] If user does NOT tap "Update" and just taps "Scan Another" — no update made

**Edge Cases:**
- Scan identifies a completely different plant → show warning "This looks like a different plant. Update anyway?" confirm dialog
- `PATCH` fails → show error, keep old data — never leave plant in partial state
- User re-scans and Claude returns lower confidence — still allow update, show confidence changed
- Network drops mid-PATCH → retry once, then show error

**Dependencies:** E4-S1 complete

---

## E5 — Chat with Your Plant

### E5-S1: Chat Screen UI [not started]
**Goal:** Message bubble UI for chatting with Claude about a specific plant.

**User Story:**
> As a user, I want to ask my plant questions like "why are my leaves turning yellow?" and get personalised advice based on that plant's care profile.

**Acceptance Criteria:**
- [ ] Accessible from PlantDetailScreen ("Ask a Question" button)
- [ ] User messages: right-aligned, green bubbles
- [ ] AI messages: left-aligned, grey bubbles
- [ ] Input field pinned at bottom; keyboard does not cover it (iOS + Android)
- [ ] Send button disabled when input empty or request in flight (prevents double-send)
- [ ] "Typing..." indicator while waiting for Claude response
- [ ] Auto-scrolls to latest message
- [ ] `POST /plants/{id}/chat` sends message, returns Claude response
- [ ] Chat history loaded on screen open (`GET /plants/{id}/chat`)

**API: POST /plants/{id}/chat**
Request: `{ "message": "Why are my leaves yellow?" }`
Response: `{ "reply": "...", "timestamp": "..." }`

**System prompt includes:** species, common name, confidence, care info, fun fact

**Edge Cases:**
- Empty message → send button disabled, no API call made
- Claude returns very long response → scrollable bubble, not truncated
- Network error → show "Could not send. Try again." inline, keep user's message in input
- Plant deleted while chat is open → next send returns 404 → "This plant no longer exists" banner
- User sends rapid messages → each request queued, not dropped

**Tests to write:**
- Unit: `POST /plants/{id}/chat` returns 401 for another user's plant
- Unit: system prompt contains plant name and care info
- Widget: send button disabled when input is empty
- Widget: "Typing..." indicator shown while request in flight

**Dependencies:** E4-S1 complete

---

### E5-S2: Chat History Persistence [not started]
**Goal:** Store all messages per plant in DB; load on chat screen open.

**User Story:**
> As a user, I want to come back to a conversation I had with my plant last week and read what advice was given.

**Acceptance Criteria:**
- [ ] Messages stored: role (user/assistant), content, timestamp, plant_id
- [ ] `GET /plants/{id}/chat` returns messages chronologically (oldest first)
- [ ] Flutter loads history on chat open (shows loading spinner)
- [ ] Pagination: return last 50 messages; "Load earlier" at top of list
- [ ] Plant deleted → cascade delete all chat messages (DB FK constraint)
- [ ] `chat_messages` table: id, plant_id, role, content, created_at

**Edge Cases:**
- 0 messages → "Ask your first question below" empty state
- 100+ messages → paginate, don't load all at once
- No network on open → show cached messages if available, or empty state with error banner
- Message content very long → store fully, wrap in bubble

**Dependencies:** E5-S1 complete

---

## E6 — Care Schedule & Reminders

### E6-S1: Auto-Generate Care Schedule [not started]
**Goal:** After saving a plant, generate a 4-week care task schedule based on Claude's care data.

**User Story:**
> As a user, after I save a plant I want the app to automatically tell me when to water and fertilize it.

**Acceptance Criteria:**
- [ ] Triggered automatically after `POST /plants` succeeds
- [ ] Creates watering tasks based on `care.water` frequency text
- [ ] Creates fertilization tasks if frequency mentioned in `care.tips`
- [ ] Generates tasks for the next 30 days
- [ ] `GET /plants/{id}/tasks` returns upcoming tasks sorted by due_date
- [ ] Re-saving (PATCH) does NOT delete existing incomplete tasks (append-only)
- [ ] All due_date values stored in UTC

**Frequency parsing (from Claude's free-text water/tips fields):**
| Text contains | Interval |
|---------------|----------|
| "daily" | 1 day |
| "every 2-3 days" / "every few days" | 3 days |
| "weekly" / "once a week" | 7 days |
| "every 2 weeks" / "biweekly" | 14 days |
| "monthly" / "once a month" | 30 days |
| unrecognized | skip, log warning |

**DB: tasks table**
```
id          UUID PK
plant_id    UUID FK → plants
task_type   VARCHAR(50)   — "water" / "fertilize"
due_date    TIMESTAMPTZ
completed   BOOLEAN default false
created_at  TIMESTAMPTZ
```

**Edge Cases:**
- Care text has no recognizable frequency → skip that task type, no crash
- User re-scans → new tasks appended, old incomplete tasks kept
- Plant deleted → cascade delete all tasks (FK constraint)
- Clock skew → all dates stored UTC, converted to local in Flutter

**Dependencies:** E3-S1 complete (need plant_id)

---

### E6-S2: Care Schedule Screen [not started]
**Goal:** View upcoming tasks, mark complete, see overdue items.

**User Story:**
> As a user, I want to see what care tasks I have coming up across all my plants so I don't forget to water them.

**Acceptance Criteria:**
- [ ] Tasks listed sorted by due_date ascending
- [ ] Overdue tasks shown at the top with red highlight
- [ ] Tasks grouped: Overdue / Today / This Week / Later
- [ ] Tap task → mark as complete; strikethrough and fade
- [ ] Snackbar "Task marked done" with Undo for 3 seconds
- [ ] `PATCH /tasks/{id}` updates completed=true
- [ ] "All caught up!" empty state when no pending tasks
- [ ] Plant name + task type icon shown per row
- [ ] Accessible from home screen (bottom nav or dedicated tab)

**Edge Cases:**
- Task marked done by mistake → snackbar undo within 3 seconds
- Plant deleted → those tasks disappear from schedule view
- No tasks generated yet → empty state with message "Save a plant to generate a schedule"
- Very long plant name → truncate at 1 line in task row

**Dependencies:** E6-S1 complete

---

## E7 — Plant Journal

### E7-S1: Journal Notes Per Plant [not started]
**Goal:** Free-text timestamped notes attached to a plant (repotting dates, observations, etc.)

**User Story:**
> As a user, I want to write notes about my plant like "repotted today" or "noticed new leaf" so I can track what I've done over time.

**Acceptance Criteria:**
- [ ] Journal tab on PlantDetailScreen
- [ ] `POST /plants/{id}/journal` creates entry: content, timestamp
- [ ] `GET /plants/{id}/journal` returns entries newest-first
- [ ] Each entry shows: timestamp ("2 days ago") + content
- [ ] Edit own entries (tap → inline edit mode → save)
- [ ] Delete own entries with confirm dialog
- [ ] Max entry length: 2000 characters (frontend counter + backend validation)
- [ ] Empty note → prevent submission (button disabled)

**API:**
- `POST /plants/{id}/journal` → 201 `{ id, content, created_at }`
- `GET /plants/{id}/journal` → 200 `[{ id, content, created_at, updated_at }]`
- `PATCH /journal/{id}` → 200 updated entry
- `DELETE /journal/{id}` → 204

**Edge Cases:**
- Empty note → save button disabled
- Entry > 2000 chars → counter turns red at 1900, blocked at 2000
- Edit cancelled → original text restored
- Delete confirmed but network fails → show error, entry stays
- Plant deleted → cascade delete all journal entries

**Dependencies:** E4-S1 complete (journal tab lives on PlantDetailScreen)

---

## E8 — Plant Health Tracking

Health status gives users an at-a-glance signal about how their plant is doing.
It replaces the "confidence" badge on collection cards — confidence is an AI
metric; health is something the user cares about every day.

Health has three sources: the initial scan photo (Claude sees visible symptoms),
chat (user describes what they're observing), and re-scanning over time.

### E8-S1: Health Assessment at Scan Time [not started]
**Goal:** When a plant is identified, Claude also assesses its visible health from the photo.

**User Story:**
> As a user, when I scan my plant I want to know not just what it is but whether it looks healthy, so I can act on any problems straight away.

**Acceptance Criteria:**
- [ ] `POST /scan` response includes `health` field: `healthy` / `needs_attention` / `concerning` / `unknown`
- [ ] `POST /scan` response includes optional `health_notes` (e.g. "Yellowing on lower leaves suggests overwatering")
- [ ] `POST /plants` stores `health` and `health_notes` on save
- [ ] ResultScreen shows a health badge below the confidence badge
- [ ] Health badge colours: green / amber / red / grey
- [ ] `plants` table gains `health` VARCHAR(20) and `health_notes` TEXT columns (migration)
- [ ] Collection card shows health badge instead of confidence badge
- [ ] `unknown` health shows no badge (clean default before any assessment)

**Claude prompt change:**
Add to system prompt: assess visible health signs (leaf colour, spots, drooping,
pests) and return `health` + `health_notes` alongside plant identification.

**Health values:**
| Value | Meaning | Badge colour |
|-------|---------|-------------|
| `healthy` | No visible issues | Green |
| `needs_attention` | Minor concerns (slight yellowing, dry soil) | Amber |
| `concerning` | Clear problems (spots, pests, severe wilting) | Red |
| `unknown` | Could not assess from photo | No badge |

**DB: plants table additions**
```
health        VARCHAR(20) default 'unknown'
health_notes  TEXT nullable
```

**Edge Cases:**
- Claude cannot assess health from the photo → return `unknown`, no notes
- User saves with `unknown` health → no badge shown, not an error
- `health_notes` is long → store fully, show truncated on card (full on detail)
- Old saved plants before this feature → default `unknown` via migration

**Tests to write:**
- Unit: `POST /scan` returns `health` field in response
- Unit: `POST /plants` stores health and health_notes
- Widget: health badge shows correct colour per value
- Widget: `unknown` health shows no badge

**Dependencies:** E2-S3 complete [done], E3-S1 complete [done]

---

### E8-S2: Health Updates from Chat [not started]
**Goal:** When a user describes symptoms in chat, Claude updates the plant's health status.

**User Story:**
> As a user, when I tell my plant assistant "the leaves are going yellow at the edges" I want the app to flag my plant as needing attention, not just give me text advice.

**Acceptance Criteria:**
- [ ] After each chat reply, Claude returns an optional `health_update` object
- [ ] If `health_update` present: `PATCH /plants/{id}` updates health + health_notes
- [ ] Collection card health badge updates immediately (no pull-to-refresh needed)
- [ ] Chat reply includes the health context ("I've updated your plant's status to Needs Attention")
- [ ] Health history not stored (only current status matters for MVP)

**How it works:**
Claude's chat system prompt includes the current health status. When the user
describes symptoms, Claude decides whether to update health and returns a
structured field alongside the conversational reply.

**Edge Cases:**
- User says "it's fine now" after previous warning → health can go back to `healthy`
- Claude not confident enough to update → returns no `health_update`, status unchanged
- Chat message unrelated to health → no update, normal reply

**Dependencies:** E5-S1 complete (chat exists), E8-S1 complete (health field exists)

---

## Open Questions

| # | Question | Needed Before | Status |
|---|----------|--------------|--------|
| 1 | Do we store the scanned image itself? (filesystem path or skip for MVP) | E3-S1 | Open |
| 2 | Should My Plants home screen replace the current HomeScreen entirely? | E3-S2 | **Resolved: yes** |
| 3 | Bottom nav bar or side drawer for main navigation? | E3-S2 | **Resolved: bottom nav bar in E3-S2** |
| 4 | Should confidence badge stay on the collection card? | E3-S2 | **Resolved: replaced by health badge (E8-S1); show ⚠ only for low confidence** |

---
