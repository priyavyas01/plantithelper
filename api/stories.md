# PlantIt Helper — Story Tracker

## Status Legend
| Symbol | Meaning |
|--------|---------|
| ✅ | Done |
| 🚧 | In Progress |
| ⬜ | Not Started |
| 🔴 | Blocked |

---

## Epic Progress

| Epic | Title | Stories | Done |
|------|-------|---------|------|
| E1 | Foundation & Auth | 3 | 1 |
| E2 | Plant Scan & Identification | 4 | 0 |
| E3 | Plant Detail & Care Info | 3 | 0 |
| E4 | Chat with Plant | 3 | 0 |
| E5 | Care Schedule & Reminders | 3 | 0 |
| E6 | Plant Journal & Collection | 4 | 0 |

**Total: 20 stories — 1 done**

---

## E1 — Foundation & Auth

### E1-S1: Project Scaffolding ✅
**Completed:** 2026-07-07
**What was done:**
- Flutter app created and running (default counter app as shell)
- FastAPI running with `GET /health` returning `{"status": "ok"}`
- Backend folder structure: `models/`, `router/`, `services/`, `db/`, `cpp/`
- All `__init__.py` files created
- C++ files stubbed: `preprocess.cpp`, `preprocess.hpp`, `CMakeLists.txt`

**Next:** Push to GitHub, then E1-S2

---

### E1-S2: User Signup & Login ⬜
**Goal:** Register and login users; return JWT; Flutter auth screens
**Endpoints:** `POST /auth/register`, `POST /auth/login`

**Acceptance Criteria:**
- [ ] `POST /auth/register` accepts `{email, password}`, returns `{access_token, token_type}`
- [ ] `POST /auth/login` accepts `{email, password}`, returns same shape
- [ ] Password stored as bcrypt hash — never plaintext
- [ ] Duplicate email returns `400` with clear message
- [ ] Wrong credentials return `401`
- [ ] JWT contains `user_id` and `exp` (24h expiry default)
- [ ] Flutter: Register screen with email + password + confirm password fields
- [ ] Flutter: Login screen with email + password fields
- [ ] Flutter: Form validation (email format, password min 8 chars)
- [ ] Flutter: Loading state while request is in flight
- [ ] Flutter: Error messages rendered inline (not just snackbar)

**Implementation Plan:**
1. `db/database.py` — SQLAlchemy engine + session + Base
2. `models/user.py` — SQLAlchemy User model
3. `services/auth_service.py` — hash_password, verify_password, create_jwt, decode_jwt
4. `router/auth.py` — register + login endpoints
5. Flutter: `lib/screens/auth/` — login_screen.dart, register_screen.dart
6. Flutter: `lib/services/auth_service.dart` — API calls + token storage

**Edge Cases:**
- Email with + alias (valid — don't strip it)
- Password with Unicode characters
- Very long email/password (enforce max lengths: 254 chars email, 72 chars password for bcrypt)
- Race condition: two simultaneous register requests with same email → unique constraint on DB catches it
- JWT secret must be in `.env`, never hardcoded
- Expired token on a protected route → redirect to login, don't crash

**Dependencies:** PostgreSQL running locally; `.env` with `SECRET_KEY`, `DATABASE_URL`

---

### E1-S3: Auth Persistence ⬜
**Goal:** App remembers login across closes; auto-login on launch; logout clears state

**Acceptance Criteria:**
- [ ] JWT stored in `flutter_secure_storage` after login/register
- [ ] On app launch, if token exists and is not expired → go directly to home screen
- [ ] On app launch, if token expired or missing → go to login screen
- [ ] Logout clears token from secure storage and pops to login
- [ ] Backend: `GET /auth/me` returns current user from JWT (token validation endpoint)

**Implementation Plan:**
1. Backend: `GET /auth/me` — decode JWT, return user
2. Flutter: `lib/services/token_service.dart` — read/write/clear token
3. Flutter: app startup logic in `main.dart` — check token → route accordingly
4. Flutter: logout button calls `token_service.clear()` + navigates to login

**Edge Cases:**
- Token valid locally but user deleted from DB → `GET /auth/me` returns 404 → force logout
- Device time skewed → JWT exp check may fail → log warning, don't crash
- Secure storage unavailable (jailbroken device) → fallback to in-memory only (don't persist)
- App killed mid-write to secure storage → next launch treats it as no token (safe default)

**Dependencies:** E1-S2 complete

---

## E2 — Plant Scan & Identification

### E2-S1: Camera & Gallery Image Capture ⬜
**Goal:** User takes a photo or picks from gallery, previews it, then submits for scan

**Acceptance Criteria:**
- [ ] Camera capture works on iOS and Android
- [ ] Gallery pick works on iOS and Android
- [ ] Preview screen shows image before submitting
- [ ] User can retake/reselect before submitting
- [ ] Image compressed before upload (max 2MB sent to API)
- [ ] Permission denied state handled gracefully with "open settings" prompt

**Implementation Plan:**
1. Flutter: add `image_picker` + `flutter_image_compress` packages
2. Flutter: `lib/screens/scan/capture_screen.dart` — two buttons: Camera / Gallery
3. Flutter: `lib/screens/scan/preview_screen.dart` — show image, Retake, Confirm
4. Compress image client-side before multipart upload

**Edge Cases:**
- User denies camera permission → show banner + "open Settings" deep link
- EXIF orientation issues (portrait photo sent sideways) → strip/normalize EXIF
- Very dark or blurry image — warn user but allow submission (LLM decides quality)
- Gallery pick cancelled (user backs out) → return to capture screen gracefully
- Device has no camera (tablet, emulator) → show gallery option only

**Dependencies:** E1-S3 complete (need auth token to call scan endpoint)

---

### E2-S2: C++ Image Preprocessing ⬜
**Goal:** pybind11 module that preprocesses images in <50ms

**Acceptance Criteria:**
- [ ] C++ module builds with `cmake` and imports in Python as `import plantit_preprocess`
- [ ] `preprocess(image_bytes: bytes) -> dict` returns `{processed_bytes, width, height, feature_vector}`
- [ ] Resize to 512×512 (letterbox pad if non-square, preserve aspect ratio)
- [ ] Normalize pixel values to 0.0–1.0 float32
- [ ] Feature vector: per-channel mean + std (fast baseline)
- [ ] End-to-end time <50ms measured via pytest-benchmark on test hardware
- [ ] Raises `ValueError` on invalid input (caught cleanly by Python caller)

**Implementation Plan:**
1. `cpp/preprocess.hpp` — declare `preprocess()` signature
2. `cpp/preprocess.cpp` — OpenCV-based: decode → resize → normalize → feature vector
3. `cpp/CMakeLists.txt` — find OpenCV + pybind11, build shared lib
4. `tests/test_preprocess.py` — benchmark + correctness + error path tests

**Edge Cases:**
- Corrupted or truncated image bytes → `std::runtime_error` bubbles to Python `ValueError`
- Zero-byte input → early return error before decode attempt
- Non-RGB image (RGBA, grayscale, CMYK) → convert to RGB before processing
- Extremely large raw image (20MB+) → reject at API layer with 413 before reaching C++
- Apple Silicon: OpenCV cmake path differs — document `brew install opencv` fix in README

**Dependencies:** cmake, OpenCV, pybind11 installed on host

---

### E2-S3: Plant Identification LLM Call ⬜
**Goal:** `POST /scan` preprocesses image, calls GPT-4 Vision, returns structured result

**Acceptance Criteria:**
- [ ] `POST /scan` accepts multipart image upload (auth required)
- [ ] Calls GPT-4 Vision with structured JSON prompt
- [ ] Response parsed into: `{species, common_name, confidence, health_status, health_issues[], care_requirements{}}`
- [ ] Unparseable LLM response returns `502` with error logged
- [ ] Non-plant image → `{species: null, confidence: 0, health_status: "unknown", message: "No plant detected"}`
- [ ] Response time logged for monitoring
- [ ] Scan record persisted to DB on success

**Prompt (stored in `services/llm_service.py`):**
```
You are a botanist AI. Analyze the plant in this image and return ONLY valid JSON
with no markdown, no code fences:
{
  "species": "scientific name or null",
  "common_name": "common name or null",
  "confidence": 0.0 to 1.0,
  "health_status": "healthy|stressed|diseased|unknown",
  "health_issues": [{"issue": "...", "severity": "low|medium|high", "fix": "..."}],
  "care_requirements": {
    "watering": {"frequency": "...", "level": "low|medium|high", "notes": "..."},
    "sunlight": {"level": "low|medium|high", "notes": "..."},
    "soil": {"type": "...", "notes": "..."},
    "fertilization": {"frequency": "...", "level": "low|medium|high", "notes": "..."},
    "temperature_range": "..."
  }
}
```

**Edge Cases:**
- OpenAI API down → return `503`, do NOT store failed scan
- Rate limit (429) → exponential backoff, max 2 retries, then return `503`
- LLM returns markdown-wrapped JSON (common) → strip ` ```json ` fences before parsing
- LLM returns partial JSON → catch `JSONDecodeError`, return `502`
- Same plant scanned twice quickly → store both scans (no idempotency needed)
- Image exceeds OpenAI size limit → reject at API layer with `413`

**Dependencies:** E2-S2 (preprocessing), OpenAI API key in `.env`

---

### E2-S4: Scan Results Screen ⬜
**Goal:** Flutter screen showing species ID, health diagnosis, and care cards after scan

**Acceptance Criteria:**
- [ ] Shows: species (scientific + common name), confidence as percentage
- [ ] Health status badge: green=healthy, amber=stressed, red=diseased, grey=unknown
- [ ] Health issues listed with severity chips (color-coded)
- [ ] Care requirement cards: watering, sunlight, soil, fertilization
- [ ] "Save Plant" button → E6-S2 save flow
- [ ] "Scan Again" button → back to capture screen
- [ ] Confidence <60% shows warning banner: "Identification uncertain — try better lighting"

**Edge Cases:**
- `species: null` → show "Unknown Plant" with retake suggestion
- No health issues → show "Looking healthy! 🌿" positive state
- Network error during scan → show retry button, not blank/crash screen
- Very long species name → ellipsis in header, full name below
- User navigates away during scan in-flight → cancel request or handle stale result on return

**Dependencies:** E2-S3 complete

---

## E3 — Plant Detail & Care Info

### E3-S1: Plant Detail Screen ⬜
**Goal:** Full scrollable screen for a saved plant with all data

**Acceptance Criteria:**
- [ ] Hero image at top with plant name overlaid
- [ ] Species name, last scanned date shown
- [ ] Sections: Overview / Care / Health / History (tabs or sections)
- [ ] Navigable from My Plants collection (E6-S1)
- [ ] `GET /plants/{id}` endpoint returning plant + latest scan data

**Edge Cases:**
- Image fails to load from S3 → show placeholder leaf illustration
- Plant has no scans yet → show "Not yet scanned" state with scan CTA
- Plant name very long → truncate in header, show full in body

**Dependencies:** E6-S1, E6-S2

---

### E3-S2: Care Requirements Cards ⬜
**Goal:** Visual cards for watering, light, soil, fertilization with level indicators

**Acceptance Criteria:**
- [ ] Each care type has its own card with icon (💧 🌞 🌱 🌿)
- [ ] Level shown as filled dots: low=●○○, medium=●●○, high=●●●
- [ ] Frequency shown as human-readable text ("Water every 7 days")
- [ ] Notes shown in expandable section per card

**Edge Cases:**
- `care_requirements` null or partial → show "Data unavailable" per affected card
- All fields "unknown" → prompt to rescan with better image

**Dependencies:** E3-S1

---

### E3-S3: Health Issue Display ⬜
**Goal:** Health issues list with severity labels and fix recommendations

**Acceptance Criteria:**
- [ ] Each issue shows: name, severity chip (color-coded), recommended fix text
- [ ] No issues → show healthy state with green checkmark
- [ ] Issues sorted: high → medium → low severity
- [ ] Severity colors: high=red, medium=amber, low=blue/grey

**Edge Cases:**
- Issue has no `fix` field → show "Monitor closely" as fallback
- More than 5 issues → show top 3 by severity + "Show all" toggle

**Dependencies:** E3-S1

---

## E4 — Chat with Plant

### E4-S1: Chat Screen UI ⬜
**Goal:** Message bubble UI with input field and auto-scroll

**Acceptance Criteria:**
- [ ] User messages: right-aligned, green bubbles
- [ ] AI messages: left-aligned, grey bubbles with small plant icon
- [ ] Input field pinned to bottom with send button
- [ ] Auto-scroll to latest message on new message
- [ ] "Typing..." indicator while awaiting AI response
- [ ] Timestamp shown per message group
- [ ] Keyboard does not overlap input field (iOS + Android)

**Edge Cases:**
- Very long AI response → scrollable bubble, not truncated
- Empty message → disable send button when input is empty
- Rapid-fire sends → disable send button while request in flight (prevent double-send)

**Dependencies:** E4-S2 (need endpoint to wire up)

---

### E4-S2: LLM Chat Endpoint ⬜
**Goal:** `POST /chat/{plant_id}/message` using plant context as system prompt

**Acceptance Criteria:**
- [ ] System prompt includes: species, common name, health status, health issues, care requirements
- [ ] Conversation history (last 20 messages) included in each request
- [ ] Returns `{role: "assistant", content, timestamp}`
- [ ] JWT auth required; ownership check: user can only chat about their own plants
- [ ] `GET /chat/{plant_id}/history` returns all messages for that plant

**System Prompt Template:**
```
You are a knowledgeable plant care assistant. The user is asking about their plant:
- Species: {species} ({common_name})
- Health status: {health_status}
- Known issues: {health_issues_summary}
- Care needs: {care_summary}
Be helpful, concise, and practical. Focus only on this plant.
```

**Edge Cases:**
- History > 20 messages → trim oldest (keep system prompt + last 20 user/assistant pairs)
- Plant with no scan data → system prompt notes "No scan data yet" and still works
- User asks about another plant → gentle redirect: "I'm configured for {name} — scan your other plant to chat about it"
- Harmful/off-topic queries → OpenAI moderation handles; log flagged requests

**Dependencies:** E4-S1, E3-S1 (need plant data for system prompt)

---

### E4-S3: Chat History Persistence ⬜
**Goal:** Store messages per plant; load on screen open; optional local cache

**Acceptance Criteria:**
- [ ] Messages stored: role, content, timestamp, plant_id
- [ ] `GET /chat/{plant_id}/history` returns messages in chronological order
- [ ] Flutter loads history on chat screen open (show loading indicator)
- [ ] Pagination: return last 50, "load more" on scroll to top
- [ ] Plant deleted → cascade delete all chat messages (DB foreign key constraint)

**Edge Cases:**
- Very long chat (100+ messages) → paginate, don't load all at once
- Multiple devices → both write to DB, merged history visible on next open
- No network on open → show cached messages (if local cache implemented) or empty with error banner

**Dependencies:** E4-S2

---

## E5 — Care Schedule & Reminders

### E5-S1: Auto-Generate Care Schedule ⬜
**Goal:** After scan, create scheduled care tasks for the next 4 weeks

**Acceptance Criteria:**
- [ ] Called automatically after successful scan + plant save
- [ ] Creates watering tasks from `watering.frequency`
- [ ] Creates fertilization tasks from `fertilization.frequency`
- [ ] Generates 4 weeks of upcoming tasks
- [ ] Re-scanning a plant does NOT delete existing incomplete tasks (append only)
- [ ] All `due_date` values stored in UTC

**Frequency mapping:**
| LLM output | Interval |
|-----------|----------|
| "daily" | 1 day |
| "every 2-3 days" | 2 days |
| "weekly" | 7 days |
| "biweekly" / "every 2 weeks" | 14 days |
| "monthly" | 30 days |
| "every 2 months" | 60 days |
| unrecognized | skip + log warning |

**Edge Cases:**
- `care_requirements` has no frequency → skip that task type, log warning
- Re-scan updates care frequency → new tasks generated with new interval, old incomplete tasks kept
- Timezone: always store UTC, convert to local time in Flutter

**Dependencies:** E2-S3 (scan data), E6-S2 (need plant_id to attach tasks)

---

### E5-S2: Care Schedule Screen ⬜
**Goal:** View tasks, mark complete, edit, see overdue items

**Acceptance Criteria:**
- [ ] Tasks listed sorted by due date ascending
- [ ] Overdue tasks at top, highlighted red
- [ ] Tap to mark task done → strike-through, move to completed section
- [ ] Undo available via snackbar for 3 seconds
- [ ] Edit due date by tapping task → date picker
- [ ] Tasks grouped: Today / This Week / Later
- [ ] Plant name + task type icon per row
- [ ] "All caught up!" empty state when nothing pending

**Edge Cases:**
- Task marked done by mistake → snackbar undo within 3 seconds
- Plant deleted → remove tasks from schedule view
- Task due date edited to the past → mark as overdue immediately

**Dependencies:** E5-S1

---

### E5-S3: Push Notifications ⬜
**Goal:** Notify user when care task is due; tap opens the correct plant

**Acceptance Criteria:**
- [ ] Notification fires when a task's `due_date` is reached
- [ ] Title: "Time to water {plant_name}!" / "Fertilize {plant_name} today!"
- [ ] Tapping notification deep-links to that plant's detail screen
- [ ] User can disable notifications per-plant or globally in settings
- [ ] Permission requested on first schedule creation, not on app launch

**Implementation Decision:** Start with `flutter_local_notifications` for MVP; migrate to FCM for production v2 (background delivery reliability on iOS)

**Edge Cases:**
- User denies permission → schedule works, no push sent (not a crash)
- Multiple tasks due same day → batch: "3 plants need care today"
- App killed when notification tapped → app launches and deep-links to plant
- Task manually completed before notification fires → cancel the scheduled notification

**Dependencies:** E5-S2, deep link routing in place

---

## E6 — Plant Journal & Collection

### E6-S1: My Plants Collection Screen ⬜
**Goal:** Grid/list of saved plants; home screen of the app

**Acceptance Criteria:**
- [ ] Grid of plant cards: photo thumbnail, plant name, species, health badge
- [ ] Empty state: illustration + "Scan your first plant" CTA button
- [ ] Tap card → Plant Detail screen (E3-S1)
- [ ] FAB → scan flow (E2-S1)
- [ ] Pull-to-refresh
- [ ] `GET /plants` returns the current user's plants (auth required)
- [ ] Uses `ListView.builder` / `GridView.builder` — not a static Column

**Edge Cases:**
- No network → show cached data with offline banner
- Image load failure → placeholder leaf icon
- 0 plants → empty state illustration (not blank)
- 50+ plants → lazy loading for performance

**Dependencies:** E6-S2 (need saved plants), E1-S3 (auth)

---

### E6-S2: Save Plant from Scan ⬜
**Goal:** After scan, user names plant and saves it to their collection

**Acceptance Criteria:**
- [ ] "Save Plant" on scan result shows bottom sheet with name input
- [ ] Name pre-filled with species common name (editable)
- [ ] `POST /plants` creates plant record: name, species, image_url, user_id, scan_id
- [ ] Image uploaded to S3; URL stored in DB
- [ ] Navigates to My Plants on save success
- [ ] Scan record linked to new plant

**Edge Cases:**
- S3 upload fails → retry once; if still fails: save plant without image (don't block save)
- User cancels save → scan result still displayed, nothing written to DB
- Duplicate plant name → allowed (same species, different pots)
- Empty name → require non-empty; default to common name if field cleared

**Dependencies:** E2-S4, S3 configured, `POST /plants` endpoint

---

### E6-S3: Scan History Per Plant ⬜
**Goal:** Chronological list of scans showing health trend over time

**Acceptance Criteria:**
- [ ] `GET /plants/{id}/scans` returns scans reverse-chronologically
- [ ] Each scan shows: date, thumbnail, health status badge, confidence
- [ ] Health trend sparkline for last 10 scans (healthy=green, stressed=amber, diseased=red)
- [ ] Tap scan → expand to full scan detail

**Edge Cases:**
- Only 1 scan → no trend line, show single entry
- Health changed between scans → highlight the delta
- Scan with no image_url → show date + text details only

**Dependencies:** E6-S2

---

### E6-S4: Plant Journal (Notes) ⬜
**Goal:** Free-text timestamped journal entries per plant

**Acceptance Criteria:**
- [ ] `POST /plants/{id}/journal` creates a journal entry
- [ ] `GET /plants/{id}/journal` returns entries reverse-chronologically
- [ ] Journal tab on Plant Detail screen
- [ ] Each entry: timestamp + content text
- [ ] Edit and delete own entries (with confirm dialog on delete)
- [ ] Max entry length: 5000 characters (enforced frontend + backend)

**Edge Cases:**
- Empty note → prevent submission
- Delete by mistake → confirm dialog required
- Very long entry → enforce 5000-char limit at both layers

**Dependencies:** E3-S1 (journal tab lives on plant detail screen)

---

## Open Questions

| # | Question | Needed Before |
|---|----------|--------------|
| 1 | Database: SQLite for dev or Postgres from day 1? | E1-S2 |
| 2 | Flutter state management: Riverpod vs BLoC? | E1-S2 Flutter work |
| 3 | Push notifications: flutter_local_notifications or FCM? | E5-S3 |
| 4 | S3 or local file storage for dev? | E6-S2 |
| 5 | JWT: 24h access token only, or access + refresh token pair? | E1-S2 |

---

## Decisions Log

| Date | Decision | Rationale |
|------|----------|-----------|
| 2026-07-07 | C++ + pybind11 for image preprocessing | `<50ms` requirement; Python OpenCV adds GIL overhead and can't reliably hit this under load |
| 2026-07-07 | OpenAI GPT-4 Vision for plant ID + chat | Best structured-output vision model; covers both E2 and E4 with one integration |
| 2026-07-07 | Folder structure: models / router / services / db / cpp | Clean separation of concerns; mirrors FastAPI community conventions |