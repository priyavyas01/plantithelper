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
| E3 | Save & My Plants Collection | 3 | 3 |
| E4 | Plant Detail, Health & Scan History | 4 | 3 |
| E5 | Chat with Your Plant | 3 | 0 |
| E6 | Care Schedule & Reminders | 2 | 0 |
| E7 | Plant Journal | 1 | 0 |

**Total: 19 stories — 12 done**

**Roadmap rationale (updated 2026-07-15):**
- E8 (Plant Health Tracking) was dissolved. Health assessment belongs at scan time
  (E4-S3) not as a late-stage epic — it makes every scan immediately actionable.
  Health updates from chat move to E5-S3.
- `confidence` is removed from all UI surfaces. It is an AI metric, not a user metric.
  Users care whether their plant looks healthy, not how certain the model is.
- E4-S2 is rewritten as Scan History (not replace). Re-scanning adds a record; it never
  destroys prior data. Scan history feeds richer context to Claude in chat (E5).
- Health observation replaces the confidence badge everywhere: result screen,
  detail screen, collection cards.

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
- [x] Tap plant card → navigates to PlantDetailScreen (E4-S1)
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

---

### E3-S3: Client-Side Plant Data Caching [done]
**Completed:** 2026-07-15
**Goal:** Show cached plant data when the network is unavailable so the app
remains usable on a poor connection.

**User Story:**
> As a user, when I open the app without a network connection I still want to
> see my plants list from last time, not a blank error screen.

**Acceptance Criteria:**
- [x] After a successful GET /plants, write the list to an in-memory cache
- [x] On next load, if the network call fails, display the cached list with a
      "Could not refresh. Showing last saved data." banner instead of error state
- [x] After a successful GET /plants/{id}, cache the full plant detail
- [x] If detail fetch fails and cache exists, show cached data silently
- [x] Cache cleared on logout so one user cannot see another's cached data
- [x] Cache invalidated after POST /plants (new plant added)
- [x] Cache invalidated after DELETE /plants/{id} (plant removed)
- [x] No expiry for MVP — valid until invalidated or logout

**Implementation:** In-memory `_PlantCache` class in `PlantService` with
`plantList` and `plantDetails` map. `PlantListResult` wrapper communicates
`fromCache` flag to the UI. Logging uses `[CACHE HIT]` / `[CACHE SET]` /
`[CACHE CLEAR]` tags for easy filtering. Persistence across restarts is a
future improvement using shared_preferences.

**Dependencies:** E3-S2 complete [done], E4-S1 complete (detail cache needs the detail endpoint)


## E4 — Plant Detail, Health & Scan History

### E4-S1: Plant Detail Screen [done]
**Completed:** 2026-07-15

**Goal:** Full scrollable screen for a saved plant showing all care info and a re-scan option.

**User Story:**
> As a user, I want to tap a plant in my collection and see all its care details so I know exactly how to look after it.

**Acceptance Criteria:**
- [x] Header: plant name (user's custom name) + scientific name
- [x] Confidence badge from original scan
- [x] Full 2x2 care grid (light, water, humidity, temperature) — same style as ResultScreen
- [x] Tips section: bulleted list from Claude
- [x] Fun fact shown if present (hidden if null)
- [x] Saved date shown: "Saved 3 days ago"
- [ ] "Scan Again" button → CaptureScreen (replaces scan data on save — E4-S2)
- [x] "Delete Plant" option in app bar menu → confirm dialog → DELETE /plants/{id} → back to collection
- [x] `GET /plants/{id}` endpoint returns full plant data

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

---

### E4-BUG-001: No way back to My Plants from ResultScreen [done]
**Completed:** 2026-07-15
**Fix alongside E4-S1** — adding the detail screen makes this worth fixing.
Without a working detail screen, sending the user to My Plants is only half useful.

**Problem:** ResultScreen has no path back to My Plants. The only button
("Scan Another Plant") double-pops to CaptureScreen. The AppBar back arrow
is hidden (automaticallyImplyLeading: false).

**Navigation stack at the bug:**
```
MyPlantsScreen -> CaptureScreen -> PreviewScreen -> ResultScreen
                                                    ^ no way back
```

**Fix:** Add a "Done" button to ResultScreen that calls
Navigator.popUntil(ModalRoute.withName('/home')), clearing the entire scan
stack in one tap. Keep "Scan Another Plant" as-is for users who want to scan again.

**Acceptance Criteria:**
- [x] "Done" button visible on ResultScreen after scan completes
- [x] Tapping "Done" lands on MyPlantsScreen, scan stack fully cleared
- [x] "Scan Another Plant" still works as before
- [x] If plant was saved before tapping "Done", it appears in the list immediately


### E4-BUG-002: No persistent navigation — no way to get home easily [not started]
**Reported:** 2026-07-15

**Problem:** The app has no persistent navigation shell. Once a user drills into a plant
detail or enters the scan flow, the only way back to My Plants is the AppBar back arrow
(subtle, easy to miss on iOS) or the gray "Done" text button on ResultScreen (small,
low-contrast, easy to overlook). There is no bottom navigation bar even though one was
planned and decided in E3-S2 but never implemented.

**Navigation stack that exposes the problem:**
```
HomeScreen (MyPlantsScreen)
  → PlantDetailScreen         ← only AppBar back arrow to go home
      → CaptureScreen
          → PreviewScreen
              → ResultScreen  ← "Done" is gray text, easy to miss
```

**Root causes:**
1. `HomeScreen` is a thin wrapper over `MyPlantsScreen` with no navigation shell
2. "Done" on ResultScreen is styled as a `TextButton` with gray color — visually the
   weakest element on the screen, below two more prominent buttons
3. No bottom nav bar means there is no persistent anchor point to return to

**Fix:**
1. Rebuild `HomeScreen` as a navigation shell with a `NavigationBar` (Material 3)
   — Tab 0: My Plants, Tab 1: Scan (navigates to CaptureScreen)
2. Make "Back to My Plants" on ResultScreen an `OutlinedButton` (visible, not just text)

**Acceptance Criteria:**
- [ ] Bottom navigation bar visible on My Plants screen with two tabs: "My Plants" and "Scan"
- [ ] Tapping "Scan" tab navigates to CaptureScreen
- [ ] After completing a scan (save or skip), bottom nav is still visible on return to My Plants
- [ ] "Back to My Plants" on ResultScreen is an OutlinedButton, not gray text
- [ ] Tapping "Back to My Plants" clears scan stack and lands on My Plants tab
- [ ] Tapping the system back button from PlantDetailScreen returns to My Plants (unchanged)
- [ ] No existing tests broken



**Goal:** Every scan returns a plain-English, actionable health observation alongside
plant identification. Health replaces confidence everywhere in the UI — confidence is
an AI-internal metric the user gains nothing from seeing. Health is something they can
act on immediately.

**User Story:**
> As a user, when I scan my plant I want to know immediately whether it looks healthy
> or if something is wrong — and I want to know exactly what to do about it, not just
> a colour-coded badge I have to interpret myself.

---

**What changes about the Claude prompt:**

Add to the existing system prompt:

> "Also assess the plant's visible health from the photo. Look for: leaf colour changes
> (yellowing, browning, blackening), spots or lesions, drooping or wilting, visible
> pests (mealybugs, spider mites, aphids, scale), root rot signs, sunburn, overwatering
> or underwatering signs. Return a `health` value and a plain-English `health_observation`
> that is specific and actionable — tell the user what you see and what to do.
> Keep `health_observation` under 200 characters. If the photo quality prevents health
> assessment, return health: 'unknown' and health_observation: null."

**Health values (strictly validated on backend):**
| Value | Badge | When to use |
|-------|-------|-------------|
| `healthy` | Green dot | No visible issues, plant looks well |
| `needs_attention` | Amber dot | Minor concerns — slight yellowing, dry-looking soil, minor droop |
| `concerning` | Red dot | Clear problems — visible pests, significant browning, severe wilt |
| `unknown` | No badge shown | Photo too dark/blurry, or health cannot be determined |

**`health_observation` examples:**
- `healthy`: *"Leaves are dark green and firm with no visible stress signs. Keep up the current care routine."*
- `needs_attention`: *"Lower leaves are yellowing and curling — likely too much direct sunlight. Move to bright indirect light."*
- `concerning`: *"Small white clusters on leaf undersides — looks like mealybugs. Isolate and treat with neem oil."*
- `unknown`: always null — no text rendered in the UI

**Why remove confidence from the UI:**
Confidence was shown as `high / medium / low`. Users read "medium confidence" and thought
the app was unsure about everything, including care advice. In reality confidence refers only
to species identification — a medium-confidence ID can still give perfectly valid care advice.
We keep `confidence` in the database for debugging and analytics. We just stop showing it.

---

**Backend changes:**

DB migration:
```sql
ALTER TABLE plants ADD COLUMN health VARCHAR(20) NOT NULL DEFAULT 'unknown';
ALTER TABLE plants ADD COLUMN health_observation TEXT;
```

`HealthStatus = Literal["healthy", "needs_attention", "concerning", "unknown"]`
Pydantic validates this — invalid values from Claude cause a 500 before anything is stored.

`health_observation` is truncated to 300 chars on the backend if Claude ignores the prompt
length guidance. Logged as a warning so we can tune the prompt if it happens often.

Updated `POST /scan` response:
```json
{
  "identified": true,
  "common_name": "Monstera",
  "scientific_name": "Monstera deliciosa",
  "confidence": "high",
  "care": { "light": "...", "water": "...", "humidity": "...", "temperature": "..." },
  "tips": ["..."],
  "fun_fact": "...",
  "health": "needs_attention",
  "health_observation": "Lower leaves yellowing — likely overwatering. Let soil dry out fully between waterings."
}
```

`GET /plants` (list) and `GET /plants/{id}` (detail) both return `health` and
`health_observation` so the UI never needs a second round trip.

---

**Flutter UI changes:**

*ResultScreen:*
- Remove `ConfidenceBadge` entirely
- Below plant name: `HealthBadge` (coloured dot + label) + `health_observation` text in a subtle card
- `unknown` health: show neither badge nor card — scan result still shows plant name and care guide

*PlantDetailScreen:*
- Remove confidence section
- Add `HealthSection`: badge + full observation text
- `unknown` with no prior scans: show "Scan again to assess your plant's health" with a camera icon link

*Collection card (PlantCard):*
- Remove confidence badge from `_BottomRow`
- Add small coloured dot (8px) + short label: "Looks healthy" / "Needs attention" / "Check your plant"
- `unknown`: show nothing — no dot, no label, no empty space

Delete `app/lib/widgets/confidence_badge.dart` and all imports once all usages are removed.

---

**Acceptance Criteria:**
- [ ] Claude prompt updated to request `health` + `health_observation` with 200 char guidance
- [ ] `HealthStatus` Literal validated on backend — invalid values rejected before storing
- [ ] `health_observation` truncated to 300 chars if Claude exceeds guidance; warning logged
- [ ] DB migration adds `health` (default `'unknown'`) and `health_observation` (nullable) to `plants`
- [ ] `POST /scan` response includes `health` and `health_observation`
- [ ] `POST /plants` stores both fields
- [ ] `GET /plants` list returns `health` and `health_observation` per plant
- [ ] `GET /plants/{id}` detail returns `health` and `health_observation`
- [ ] ResultScreen: confidence badge removed, health badge + observation shown (or nothing if unknown)
- [ ] PlantDetailScreen: confidence removed, health section shown
- [ ] PlantCard: confidence badge removed, health dot + short label shown (or nothing if unknown)
- [ ] `unknown` health: no badge, no text, no empty card visible anywhere in the app
- [ ] Old saved plants (health='unknown') show clean cards — no "unknown" label
- [ ] `ConfidenceBadge` widget deleted; no compile errors
- [ ] `confidence` field still present in DB, API responses, and Dart models — just not rendered

**Edge Cases:**
- Claude returns a health value outside the allowed set (e.g. `"good"`) → Pydantic rejects it, scan endpoint returns 500, error logged — never silently store bad data
- Claude returns `health_observation` when health is `unknown` → backend sets observation to null before storing
- Photo is very dark or blurry → Claude returns `unknown`, app shows no health badge — this is correct, not an error state
- Health is `concerning` (red) → do not block the save flow — the badge is informational only, not a gate
- User's plant was previously `healthy` in collection, re-scan (E4-S2) returns `concerning` → badge on collection card updates after refresh — no automatic alert pushed to user (that is a future push notification story)
- `health_observation` contains special characters or apostrophes → store and render without escaping issues (standard UTF-8 text field)

**Tests to write:**
- Unit (backend): `POST /scan` response contains `health` and `health_observation`
- Unit (backend): invalid health value `"good"` from Claude causes 500, not a 201
- Unit (backend): `health_observation` truncated to 300 chars when Claude returns too much
- Unit (backend): `health_observation` set to null when health is `unknown`, even if Claude returned text
- Unit (backend): `POST /plants` stores health fields correctly
- Widget: `HealthBadge` renders correct colour for each value
- Widget: no badge or text rendered when health is `unknown`
- Widget: `ConfidenceBadge` does not appear anywhere in widget tree after this story

**Dependencies:** E2-S3 complete [done], E3-S1 complete [done]

---

### E4-S2: Scan History [not started]
**Goal:** Re-scanning a saved plant adds a new scan record rather than overwriting the existing
data. Every scan is preserved. PlantDetailScreen shows the current scan plus a scrollable history.
Claude receives scan history as context in chat — enabling observations like "your plant's health
has declined since January, here is what may have changed."

**User Story:**
> As a user, I want to scan my plant again months later and see how its identification and
> health have changed — without losing what the app told me before.

**Why not replace:**
Replacing destroys information both the user and the AI benefit from. If a plant was `healthy`
in January and `concerning` in April, that trend is meaningful — it tells the user something
changed in their care routine and gives Claude context for better advice. Replacing silently
discards that signal.

---

**Architecture — data model migration:**

This is the most significant schema change in the project. The current `plants` table embeds
all scan data directly. After this story, scan data lives in a child table.

Current:
```
plants: id, user_id, name, common_name, scientific_name, confidence,
        care_json, fun_fact, health, health_observation, created_at
```

After:
```
plants:      id, user_id, name, created_at
plant_scans: id, plant_id, common_name, scientific_name, confidence,
             care_json, fun_fact, health, health_observation, scanned_at
```

"Current" data = the most recent `plant_scans` row for a given `plant_id`.
All DELETE operations on `plants` cascade to `plant_scans` (FK constraint).

**The Alembic migration must include a data migration step — not just DDL:**
```python
# 1. CREATE TABLE plant_scans (...)
# 2. INSERT INTO plant_scans
#    SELECT gen_random_uuid(), id, common_name, scientific_name,
#           confidence, care_json, fun_fact, health, health_observation, created_at
#    FROM plants
# 3. ALTER TABLE plants DROP COLUMN common_name, scientific_name,
#    confidence, care_json, fun_fact, health, health_observation
```
If step 2 fails (e.g. bad data), step 3 must not run. Alembic wraps the whole migration
in a transaction — test on a copy of prod data before deploying.

**Performance — GET /plants must not use N+1 queries:**
Each plant now requires fetching its latest scan. Do NOT loop and query per plant.
Use a lateral join or window function:
```sql
SELECT p.id, p.name, p.created_at, s.*
FROM plants p
JOIN LATERAL (
  SELECT * FROM plant_scans
  WHERE plant_id = p.id
  ORDER BY scanned_at DESC
  LIMIT 1
) s ON true
WHERE p.user_id = :user_id
ORDER BY p.created_at DESC
```

---

**New API endpoints:**

`POST /plants/{id}/scans`
- Adds a scan to an existing plant. Body: same as `POST /plants` minus `name`.
- Response 201: the new `plant_scans` row
- 404 if plant not found or belongs to another user

`GET /plants/{id}/scans`
- Returns full scan history, newest first, paginated at 20
- Each entry: id, common_name, scientific_name, health, health_observation, care, tips, fun_fact, scanned_at

---

**Flutter UX — the re-scan flow:**

*From PlantDetailScreen:*
"Scan Again" button (currently a placeholder) navigates to CaptureScreen passing `plantId`
as a route argument. CaptureScreen carries `plantId` forward through PreviewScreen to ResultScreen.

*ResultScreen when `plantId` context is present — shows two buttons:*
1. **"Update [plant name]"** (primary, filled green) — calls `POST /plants/{plantId}/scans`
2. **"Save as New Plant"** (secondary, outlined) — original flow

If the scanned genus differs significantly from the saved plant's name, show a warning
banner above the buttons:
> "This looks like a different plant from [saved name]. You can still add this scan to its history, or save it as a new plant."

*PlantDetailScreen — History section:*
Shown only when `scan_count > 1`. A collapsible "Scan History" section below the care guide.
Each row: health dot + date ("3 months ago") + common name if it changed from the previous scan.
Tap a row to expand: shows full observation text for that scan. Does not replace current view.
No delete-individual-scan in MVP — delete the whole plant if needed.

---

**Acceptance Criteria:**
- [ ] Alembic migration: creates `plant_scans`, migrates all existing plant data, drops columns — all in one transaction
- [ ] `POST /plants` creates `plants` + `plant_scans` rows atomically — if either insert fails, both roll back
- [ ] `POST /plants/{id}/scans` adds scan to existing plant; 404 if not found or wrong user (SECURITY)
- [ ] `GET /plants` uses lateral join — no N+1 queries regardless of list size
- [ ] `GET /plants/{id}` returns latest scan data + `scan_count` field
- [ ] `GET /plants/{id}/scans` returns history newest first, paginated at 20
- [ ] ResultScreen shows "Update [name]" + "Save as New" when opened via re-scan flow
- [ ] "Different plant" warning shown when genus mismatch detected
- [ ] PlantDetailScreen "Scan Again" button navigates correctly with plantId context
- [ ] History section visible only when scan_count > 1
- [ ] History section hidden on plants with only one scan (no empty section)
- [ ] Caching: `getPlant` cache invalidated after adding a new scan

**Edge Cases:**
- Scan in progress, plant deleted on another device → `POST /plants/{id}/scans` returns 404 → show "Plant no longer exists. Save as a new plant?" with a button
- Migration: plants created before E4-S3 may have `health='unknown'` and null `health_observation` → these are valid values, migration handles them correctly
- `GET /plants` for a user where migration partially failed (plant has no scan rows) → return plant with `latest_scan: null`; Flutter shows an "incomplete" card state rather than crashing
- Scan history has 20+ entries → paginate; "Load earlier scans" button at bottom of history list
- Identical result scanned twice → create two `plant_scans` rows — no deduplication. The user chose to scan again; that is intentional and should be recorded.
- "Scan Again" tapped while offline → scan fails at `POST /scan` step, not at save step — same error handling as the standard scan flow

**Tests to write:**
- Unit (backend): `POST /plants` creates both rows; if `plant_scans` insert fails, `plants` row is also rolled back
- Unit (backend): `POST /plants/{id}/scans` returns 404 for another user's plant (SECURITY)
- Unit (backend): `GET /plants` returns latest scan data for each plant (join correct)
- Unit (backend): `GET /plants/{id}` includes `scan_count`
- Unit (backend): `GET /plants/{id}/scans` returns results newest first
- Widget: ResultScreen shows "Update [name]" button when plantId context is present
- Widget: "different plant" warning shown when genus differs
- Widget: history section not rendered when scan_count is 1

**Dependencies:** E4-S1 complete [done], E4-S3 complete (health fields on plant_scans)

---

## E5 — Chat with Your Plant

### E5-S1: Chat Screen UI [not started]
**Goal:** A conversational screen where the user can ask Claude anything about a specific
plant, with Claude having full context about that plant's identity, care needs, current
health, and scan history.

**User Story:**
> As a user, I want to tap "Ask Claude" on my plant and have a real conversation — not
> just get static care tips. I want Claude to already know what my plant is, what it
> needs, and what it looked like when I last scanned it.

**What makes this different from a generic chat:**
Claude is not a blank slate when this screen opens. The system prompt is built from the
plant's full record: identity, care guide, current health observation, and a summary of
past scans. This means Claude can open with something relevant like:
> "Your Monstera had yellowing lower leaves when you last scanned it — want to talk about that?"

This is the payoff for doing E4-S3 (health) and E4-S2 (scan history) first.

---

**System prompt structure (backend constructs this per request):**
```
You are a plant care expert helping a user look after their plant.

Plant: {common_name} ({scientific_name})
Nickname: {user_name}
Care needs: Light: {light}. Water: {water}. Humidity: {humidity}. Temperature: {temperature}.
Tips: {tips joined as bullet points}
{fun_fact if present}

Current health: {health}
Health observation: {health_observation if not unknown else "Not yet assessed."}

Scan history ({scan_count} total scans):
{for each of last 3 scans: "{scanned_at_relative}: {health} — {health_observation or 'No observation'}"}

Keep your responses conversational and concise. Be direct about problems.
If the user describes new symptoms, address them specifically.
```

---

**API:**

`POST /plants/{id}/chat`
Request: `{ "message": "Why are my leaves turning yellow?" }`
Response: `{ "reply": "...", "message_id": "...", "timestamp": "..." }`
- Auth: plant must belong to current user (ownership check)
- System prompt built fresh from current plant state on every request (always up to date)
- Conversation history passed as `messages` array to Claude (last 20 messages for context window)
- Returns 404 if plant not found or belongs to another user

`GET /plants/{id}/chat`
Response: array of `{ role, content, timestamp }`, oldest first, last 50
- Used to restore history when the chat screen opens

---

**Flutter UX:**

*Entry point:* "Ask Claude" button on PlantDetailScreen (below the health section).

*Opening the screen:*
- If no prior messages: show an empty state with a suggested first question
  > "You could ask: 'How often should I water this?' or 'My leaves are turning yellow — why?'"
- If prior messages exist: load history, scroll to bottom

*Message layout:*
- User messages: right-aligned, filled green bubble, white text
- Claude messages: left-aligned, grey bubble, dark text, plant avatar icon
- Timestamps shown once per group of messages (not on every bubble)
- "Typing..." animated dots indicator while request in flight

*Input row (pinned to bottom):*
- TextField + Send button
- Send button: disabled when input is empty OR request in flight
- Keyboard behaviour: `resizeToAvoidBottomInset: true` — input field lifts above keyboard on both iOS and Android
- On send: message appended to list immediately (optimistic), "Typing..." shown, response fills in

*Scroll behaviour:*
- Auto-scroll to bottom on new message (user or Claude)
- If user has scrolled up to read history, do NOT auto-scroll until they scroll back to bottom

---

**Acceptance Criteria:**
- [ ] "Ask Claude" button on PlantDetailScreen navigates to ChatScreen with plantId
- [ ] ChatScreen loads message history on open (`GET /plants/{id}/chat`)
- [ ] Empty state with suggested questions shown when no prior messages
- [ ] User message bubble: right-aligned green
- [ ] Claude message bubble: left-aligned grey
- [ ] "Typing..." indicator shown while waiting for response
- [ ] Send button disabled when input empty or request in flight
- [ ] Input field lifts above keyboard on iOS and Android
- [ ] Auto-scroll to latest message on new message
- [ ] User's message appears immediately (before server responds)
- [ ] System prompt includes plant name, care, health, health_observation, last 3 scans
- [ ] `POST /plants/{id}/chat` returns 404 for another user's plant (SECURITY)
- [ ] 20 most recent messages passed to Claude as conversation history

**Edge Cases:**
- Empty message → send button disabled, no API call
- Claude response is very long → bubble wraps, scrollable — never truncated
- Network error mid-send → "Could not send. Try again." shown inline below the failed message; user's text stays in the input field
- Plant deleted while chat open → next send returns 404 → full-screen banner "This plant no longer exists" with "Go back" button
- User sends a message before history loads → queue message, send after history resolves
- User rapidly taps send → button disabled after first tap; second tap is a no-op
- Chat history has 50+ messages → load last 50 on open; "Load earlier messages" at top
- Claude takes > 10 seconds → "Typing..." stays; no timeout in MVP (Claude is occasionally slow)
- User pastes a very long message (>1000 chars) → allow it, Claude can handle it; no artificial cap

**Tests to write:**
- Unit (backend): `POST /plants/{id}/chat` returns 404 for another user's plant (SECURITY)
- Unit (backend): system prompt contains plant common_name, care, health_observation
- Unit (backend): system prompt contains last 3 scans when scan history exists
- Unit (backend): conversation history capped at last 20 messages sent to Claude
- Widget: send button disabled when input is empty
- Widget: send button disabled while request in flight
- Widget: "Typing..." indicator shown while request in flight
- Widget: user message appears immediately on send (before server responds)
- Widget: empty state with suggested questions shown when no history

**Dependencies:** E4-S1 complete [done], E4-S3 complete (health context in system prompt), E4-S2 complete (scan history in system prompt)

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

### E5-S3: Health Updates from Chat [not started]
**Goal:** When the user describes symptoms in chat, Claude updates the plant's health status
in the app — so the collection card reflects what the user just told Claude.

**User Story:**
> As a user, when I tell Claude "the leaves have gone yellow at the edges", I want my
> plant's status in the collection to update automatically — not just get a text reply.

**How it works:**
Claude's chat system prompt includes the current health status and observation. When the
user describes symptoms, Claude decides whether the health has changed and returns a
structured `health_update` field alongside the conversational reply. The app applies
the update silently — no extra step for the user.

Example:
> User: "The lower leaves have started going really yellow"
> Claude reply: "Yellowing lower leaves on a Monstera usually means overwatering..."
> `health_update`: `{ "health": "needs_attention", "health_observation": "User reports yellowing lower leaves — likely overwatering. Reduce watering frequency." }`

**Acceptance Criteria:**
- [ ] `POST /plants/{id}/chat` response includes optional `health_update` object
- [ ] If `health_update` present: app calls `PATCH /plants/{id}/health` immediately after receiving reply
- [ ] Collection card health badge updates without requiring pull-to-refresh
- [ ] PlantDetailScreen health section reflects the new status on next open
- [ ] Chat reply naturally incorporates the health change ("I've noted your plant needs attention")
- [ ] Health can go back to `healthy` if user says "it's looking much better now"
- [ ] If Claude is not confident enough to update → returns no `health_update`, status unchanged

**Edge Cases:**
- Chat message unrelated to health → no `health_update` in response, normal reply
- `PATCH /health` fails → show no error to user, health stays unchanged (silent fail — chat was still useful)
- User and Claude disagree on health → Claude's assessment from most recent scan takes precedence

**Dependencies:** E5-S1 complete, E4-S3 complete (health field exists)

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

## E8 — Plant Health Tracking [absorbed]

This epic was dissolved on 2026-07-15.

- **E8-S1** (Health Assessment at Scan Time) → moved to **E4-S3** and pulled forward.
  Health belongs at the point of scanning, not as a late addition.
- **E8-S2** (Health Updates from Chat) → moved to **E5-S3**.
  It depends on chat existing, so it lives in the chat epic.

The `confidence` badge is removed from all UI surfaces. It is an internal AI metric.
Users care whether their plant looks healthy and what to do about it — not a probability score.

## Open Questions

| # | Question | Needed Before | Status |
|---|----------|--------------|--------|
| 1 | Do we store the scanned image itself? (filesystem path or skip for MVP) | E3-S1 | Open |
| 2 | Should My Plants home screen replace the current HomeScreen entirely? | E3-S2 | **Resolved: yes** |
| 3 | Bottom nav bar or side drawer for main navigation? | E3-S2 | **Resolved: bottom nav bar in E3-S2** |
| 4 | Should confidence badge stay on the collection card? | E3-S2 | **Resolved: replaced by health badge (E8-S1); show ⚠ only for low confidence** |

---
