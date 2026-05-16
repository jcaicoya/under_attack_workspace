# Bajo Ataque

Workspace principal del show teatral de ciberseguridad **Bajo Ataque**.

Este directorio agrupa varios repositorios relacionados. Cada subproyecto debería mantener su propia documentación y contexto local: `README`, `.claude/CLAUDE.md`, `NEXT_STEPS`, `CODEX` y, cuando aplica, `RUNBOOK`.

El objetivo de este repo raíz es documentar:

- la visión general del conjunto
- cómo se relacionan los proyectos entre sí
- qué scripts globales existen para empaquetado y despliegue
- qué convenciones son comunes a todas las apps

## Estructura

### Director del show

| Directorio | Tipo | Rol |
|---|---|---|
| `orchestrator` | Qt/C++ | Lanza, coordina y supervisa el resto de apps durante el show |

### Parejas Qt + Android

Cada pareja combina una app Qt de operador con una app Android que actúa como dispositivo escénico. Cada pareja funciona de forma independiente.

| Qt | Android | Escena |
|---|---|---|
| `permission_qt` | `permission_android` | Permisos / radar / takeover |
| `password_qt` | `password_android` | Contraseñas |
| `phishing_qt` | `phishing_android` | Phishing |

### Apps Qt independientes

| Directorio | Rol |
|---|---|
| `public_wifi` | Escena de WiFi público |
| `qr` | Generación / proyección de QR |
| `pulse_console` | Consola / pulse display |
| `cuarzito_race` | Minijuego / preshow |

## Cómo se relacionan

### Orchestrator

`orchestrator` es el punto central del show:

- lanza apps Qt
- lanza apps Android por ADB
- configura túneles `adb reverse` cuando una app Android necesita conectar con su par Qt
- mantiene la lógica de CONFIGURAR / DISEÑO / SHOW

### Patrón Qt + Android

Las parejas `permission`, `password` y `phishing` siguen el mismo patrón general:

1. La app Qt abre un servidor WebSocket local.
2. El Orchestrator prepara `adb reverse tcp:<puerto> tcp:<puerto>`.
3. La app Android intenta conectar primero a `localhost:<puerto>`.
4. Si no hay túnel ADB o falla la conexión, Android puede caer a discovery por UDP.

Puertos actuales:

| Pareja | Puerto |
|---|---|
| `permission_qt` / `permission_android` | `8765` |
| `password_qt` / `password_android` | `8767` |
| `phishing_qt` / `phishing_android` | ver config propia del proyecto |

## Scripts globales

En la raíz hay scripts que operan sobre varios repositorios a la vez:

- `manage_qt_releases.ps1`
  Genera y publica releases de las apps Qt y sincroniza `dist-qt/`.

- `manage_android_releases.ps1`
  Genera y publica releases Android y sincroniza `dist-android/`.

- `deploy_android.ps1`
  Instala, actualiza o desinstala las apps Android en tablet o móvil vía `adb`.

- `dist-multimedia/`
  Carpeta local para vídeos y audios que consume Orchestrator. No necesita estar bajo control de versiones.

El flujo operativo completo está descrito en:

- [RUNBOOK.md](C:/Users/caico/Desktop/CUARZOPOLAR/bajo-ataque/RUNBOOK.md)

## Convenciones del workspace

- Los repositorios GitHub usan la convención `under_attack_*`.
- Los directorios locales usan guiones bajos.
- Los nombres técnicos estables están en inglés.
- Las distribuciones compartidas viven dentro del workspace:
  - `dist-qt/`
  - `dist-android/`
  - `dist-multimedia/`
- Cada subrepo debe contener su propia documentación específica.
- Este repo raíz solo debe contener contexto transversal o compartido.

## Qué no debe vivir aquí

No conviene usar este repo raíz para duplicar documentación detallada de un solo proyecto. Si una regla o explicación solo aplica a `permission_qt`, `password_android` o cualquier otro subrepo concreto, debe vivir en ese subrepo.

Sí merece la pena guardar aquí:

- relaciones entre repos
- convenciones comunes
- flujos de release y despliegue globales
- patrones compartidos entre Qt y Android
