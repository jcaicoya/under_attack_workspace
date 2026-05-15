# NEXT_STEPS — Bajo Ataque

## Done
- [x] Create `~/.claude/CLAUDE.md` — global AI rules
- [x] Create `.claude/CLAUDE.md` — project context (app map, orchestrator, look & feel)
- [x] Create `CODEX.md` — Codex entry point
- [x] Create `NEXT_STEPS.md` — this file
- [x] Rename `phising` → `phishing_qt`
- [x] Create `phishing_android` app
- [x] Rename directories, apps, and GitHub repos (`ataque-inicial` → `permission_qt`, `android-companion` → `permission_android`)
- [x] Fix Android app names: `permission_android` → "Permission", others correct
- [x] Fix Android launcher icons: each app uses its own cuarzito color (green/amber/red), dark background
- [x] Fix `password_qt` WebSocket server: single client, heartbeat/pong, UDP beacon — matches phishing/permission pattern
- [x] Fix `password_android` connection: WebSocketManager + PasswordService + UDP discovery — matches phishing/permission pattern
- [x] Standardize cuarzito connection state colors across all three Android pairs (green=connected, amber=connecting, blue=disconnected)

## Pending

1. Evolve `phishing_qt` screens 1–4 (message builder) and screen 5 (climax)
2. Evolve `phishing_android` to show incoming SMS and handle link tap
3. Add `phishing_qt` + `phishing_android` to Orchestrator
4. Add `password_qt` + `password_android` to Orchestrator (config exists; verify ADB tunnel port 8767)
5. Implement Orchestrator → Qt app command channel via stdin (see architecture note below)
6. Analyze whether to include Cuarzito Race into Orchestrator

---

## Architecture: Orchestrator command channel (stdin IPC)

**Decision:** Orchestrator sends commands to running Qt apps via their **stdin** (QProcess write).
Apps listen with `QSocketNotifier` on fd 0 and handle `CYBERSHOW_CMD` tokens.
Standalone mode is unaffected — if stdin is idle or closed, apps behave exactly as today.

**Protocol (Orchestrator → app):**
```
CYBERSHOW_CMD NEXT_SCREEN
CYBERSHOW_CMD PREV_SCREEN
CYBERSHOW_CMD ACTION <id>
CYBERSHOW_CMD TRIGGER <name>
```

**Orchestrator UI:** contextual action buttons that update automatically based on
`CYBERSHOW_SCREEN` messages received from the active app.

**Performance:** zero overhead — event-driven, no polling, kernel pipe, microsecond latency.

**Risks (all low):**
- Blocking write if app hangs → use non-blocking QProcess write
- Broken pipe on app crash → QProcess `finished()` already signals this
- Garbage input in standalone mode → parser ignores lines without `CYBERSHOW_CMD` prefix
