# Bajo Ataque

Workspace principal del show teatral de ciberseguridad **Bajo Ataque**.

Este directorio no corresponde a una sola app, sino al conjunto del show: agrupa subproyectos Qt, apps Android, scripts globales de releases y carpetas de distribución compartidas.

## Qué es este directorio

La raíz de `bajo-ataque` sirve para documentar:

- la estructura general del show
- cómo se relacionan los proyectos entre sí
- qué convenciones comparten
- qué scripts globales existen para releases y despliegues

La documentación específica de cada app debe vivir en su propio subdirectorio.

## Estructura general

### Director del show

| Directorio | Tipo | Rol |
|---|---|---|
| `orchestrator` | Qt/C++ | coordina y supervisa el resto de apps |

### Parejas Qt + Android

| Qt | Android | Escena |
|---|---|---|
| `permission_qt` | `permission_android` | permisos / radar / takeover |
| `password_qt` | `password_android` | contraseñas |
| `phishing_qt` | `phishing_android` | phishing |

### Apps Qt independientes

| Directorio | Rol |
|---|---|
| `public_wifi` | escena de Wi‑Fi público |
| `qr` | control y proyección QR |
| `pulse_console` | consola escénica |
| `cuarzito_race` | minijuego / preshow |

## Cómo se relacionan los proyectos

### Orchestrator

`orchestrator` es el punto central del show:

- lanza apps Qt
- lanza apps Android por ADB
- prepara túneles `adb reverse` cuando una app Android necesita conectar con su par Qt
- mantiene la lógica de modos de show

### Patrón Qt + Android

Las parejas `permission`, `password` y `phishing` comparten este patrón:

1. La app Qt abre un servidor WebSocket local.
2. Orchestrator prepara `adb reverse tcp:<puerto> tcp:<puerto>`.
3. Android intenta conectar primero a `localhost:<puerto>`.
4. Si no hay túnel o falla, Android puede caer a discovery por UDP.

Puertos actuales documentados a nivel raíz:

| Pareja | Puerto |
|---|---|
| `permission_qt` / `permission_android` | `8765` |
| `password_qt` / `password_android` | `8767` |
| `phishing_qt` / `phishing_android` | ver configuración propia |

## Scripts y carpetas globales

### Scripts principales

- `manage_qt_releases.ps1`: genera y publica releases Qt; sincroniza `dist_qt/`
- `manage_android_releases.ps1`: genera y publica releases Android; sincroniza `dist_android/`
- `deploy_android.ps1`: instala, actualiza o desinstala apps Android por ADB

### Distribuciones compartidas

- `dist_qt/`: releases Qt publicadas
- `dist_android/`: releases Android publicadas
- `dist_media/`: vídeos y audios consumidos por Orchestrator

## Convenciones del workspace

- Los nombres técnicos estables van en inglés.
- Los directorios locales usan guiones bajos.
- Las apps Qt y Android deben documentarse en su propio subdirectorio.
- La raíz solo debe contener contexto transversal o compartido.
- Los patrones de navegación, look and feel y orquestación comunes deben mantenerse alineados entre proyectos.

## Qué no debe vivir aquí

No conviene duplicar aquí documentación detallada de un proyecto concreto.

Sí debe vivir aquí:

- relaciones entre repos
- convenciones comunes
- flujos globales de releases y despliegues
- scripts transversales

No debe vivir aquí:

- detalles internos de una sola app
- instrucciones operativas exclusivas de un subproyecto
- backlog específico de un único módulo
