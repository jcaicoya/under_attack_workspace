# NEXT_STEPS — Bajo Ataque

## Hecho

- [x] Crear `~/.claude/CLAUDE.md` con reglas globales
- [x] Crear `.claude/CLAUDE.md` de raíz con contexto del proyecto
- [x] Crear `CODEX.md` de raíz
- [x] Estandarizar la estructura documental en raíz y subproyectos:
  - `README.md`
  - `RUNBOOK.md`
  - `NEXT_STEPS.md`
  - `.claude/CLAUDE.md`
  - `CODEX.md`
- [x] Crear `phishing_android`
- [x] Renombrar `phising` a `phishing_qt`
- [x] Renombrar proyectos y repositorios históricos a `permission_*`
- [x] Unificar los `CODEX.md`
- [x] Hacer que los empaquetadores Qt incluyan `RUNBOOK.md` y no `README.md`

## Pendiente

- [ ] Evolucionar `phishing_qt` (pantallas builder y clímax).
- [ ] Integrar `phishing_qt` y `phishing_android` en Orchestrator.
- [ ] Verificar la integración efectiva de `password_qt` y `password_android` en Orchestrator.
- [ ] Implementar el canal de comandos Orchestrator -> apps Qt por stdin si se confirma como siguiente paso.
- [ ] Decidir si `cuarzito_race` debe integrarse o no en Orchestrator.

## Nota de arquitectura

La línea de trabajo más relevante a nivel raíz sigue siendo el canal de comandos de Orchestrator hacia las apps Qt por stdin:

- comandos del tipo `CYBERSHOW_CMD ...`
- apps escuchando con `QSocketNotifier`
- mantenimiento del comportamiento standalone cuando stdin no se use
