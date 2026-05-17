# Bajo Ataque — Project Context

Theatrical cybershow suite. All apps are scripted theatre — no real hacking.
Each subproject has its own `.claude/CLAUDE.md` with its specific details.

## Required Reading

Before working in this directory, read and apply:

- `README.md`
- `RUNBOOK.md`
- `NEXT_STEPS.md`

## Documentation Maintenance

- `README.md` must describe the project, architecture, design, and technology.
- `RUNBOOK.md` must contain deploy, launch, and operational instructions.
- `NEXT_STEPS.md` must contain the next pending work items.
- After each commit, keep these files updated so they reflect the real current state of the project.
- Do not duplicate the same information across these files unless there is a strong reason.

## App Map

### Orchestrator (director)
| Directory | Type | Role |
|---|---|---|
| `orchestrator` | Qt/C++ | Controls and coordinates all other apps during the show |

### Qt + Android pairs (each pair works independently)
| Qt app | Android app | Scene |
|---|---|---|
| `permission_qt` | `permission_android` | Permissions / radar attack |
| `password_qt` | `password_android` | Password cracking |
| `phishing_qt` | `phishing_android` | Phishing |

### Standalone Qt apps
| Directory | Scene |
|---|---|
| `public_wifi` | Public WiFi attack |
| `qr` | QR code display |
| `pulse_console` | Console / pulse display |
| `cuarzito_race` | Pre-show arcade game |

## Non-subproject directories
Everything else is tooling, assets, or legacy — not part of the show suite:
`_release-work`, `adb-bridge`, `blender`,
`gemini-web`, `html-qrs`, `images`, `inkskape`, `old-wifi`, `movil-app`,
`router-to-portatil-receiver`, `scrcpy-win64-v3.3.4`,
`simple-console-message-app`, `skeleton`, `web-page`

---

## How Orchestrator manages apps

### Qt apps
Launched and stopped via `QProcess` with a mode argument:

| Orchestrator mode | Launch arg | Behaviour |
|---|---|---|
| CONFIGURAR | `--configure` | App shows setup; Esc returns to setup at runtime |
| DISEÑO | `--design` | App starts at first runtime screen; setup unreachable |
| SHOW | `--show` | Same as `--design`, used for real performance |

Apps report status back to Orchestrator via stdout:
```
CYBERSHOW_STATUS READY | RUNNING | ERROR <code> | FINISHED
CYBERSHOW_SCREEN <number> <id>
CYBERSHOW_LOG INFO|WARNING|ERROR <component> <message>
```

### Android apps
Managed via ADB. Flow for each Qt+Android pair:
1. `setupReverseTunnel` — maps `localhost:<PORT>` on device to the Qt app's WebSocket server
2. `launchApp` — starts the Android app via ADB
3. Android connects via ADB tunnel (`localhost:<PORT>`); falls back to UDP discovery
4. `stopApp` — stops the Android app via ADB

Ports: `permission_android` → 8765, `password_android` → 8767.
ADB: `C:/Users/caico/AppData/Local/Android/Sdk/platform-tools/adb.exe`

### Shared Qt + Android pairing rules

These rules are common across the paired modules and should stay aligned unless a subproject has a documented exception.

- Qt is the server side; Android is the client side.
- Orchestrator prepares the ADB reverse tunnel before launching the Android app.
- Android tries `localhost:<PORT>` first and only falls back to UDP discovery if needed.
- Release packaging is split by platform:
  - Qt releases sync into `dist_qt/`
  - Android releases sync into `dist_android/`
- Android deployment to devices is done from `dist_android` via `deploy_android.ps1`.

---

## Common Qt Look & Feel

Key rules summarised here.

### Aesthetic
Dark, technical, cyber, sober. All apps share `CyberBackgroundWidget`:
deep black-blue base, faint grid, subtle glows at borders, clean center.
Two screen families: **operative** (dashboards, logs, data) and **scenic**
(public-facing: large elements, QR, radar, metrics).

### Color palette
| Role | Color |
|---|---|
| Deep background | `#050608` |
| Panel | `#101318` |
| Panel elevated | `#151922` |
| Subtle border | `#293241` |
| Active border | `#2EA8FF` |
| Main text | `#F2F5F8` |
| Secondary text | `#8D96A3` |
| Action / primary (blue) | `#1688E8` |
| OK / connected (green) | `#00FF55` |
| Info / network (cyan) | `#00D1FF` |
| Warning (amber) | `#FFB000` |
| Error / critical (red) | `#FF3347` |

### Typography
- UI: `Inter`, `Segoe UI`, `Arial`
- Logs / terminal: `JetBrains Mono`, `Consolas`
- Screen titles: 24–32 px | Scenic titles: 36–56 px | Large metrics: 48–88 px

### Navigation (Qt apps)
- Bottom bar: fixed, format `[1 · Name] [2 · Name] ...`, active tab in blue/cyan
- Arrows left/right: cycle screens. Digits 1–9: jump directly. No letter shortcuts.
- `Esc` in `--configure` only: return to setup. `Alt+F4`: close.
- Orchestrator exception: uses mode selector (CONFIGURAR / DISEÑO / SHOW),
  no bottom nav bar, no scene navigation.

### Common components
- `CyberPanel`: dark panel, border `#293241`; `critical` variant with red border
- `MetricCard`: large-value card for scenic screens
- `AlertBanner`: info / warning / critical / success states
- `BottomNavBar`: shared bottom navigation bar

### Language
- All UI visible to operator or audience: **Spanish**
- English allowed only in: simulated logs, unavoidable technical names,
  system traces that are part of the fiction
- Enforce correct Spanish: accents and tildes are mandatory
  (`año` not `ano`, `configuración` not `configuracion`, etc.)
- Android look & feel standards: **pending definition**
