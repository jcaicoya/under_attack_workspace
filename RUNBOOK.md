# Release Runbook

Este documento resume el flujo recomendado para generar, publicar y desplegar versiones de los proyectos de `bajo-ataque`.

## Qt

### Comando Normal

Desde la raiz:

```powershell
.\manage_qt_releases.ps1
```

Ese comando:

- recorre los proyectos Qt configurados
- detecta si hay una release pendiente
- bloquea proyectos con cambios locales sin commit
- genera la nueva release cuando corresponde
- actualiza `releases.json`
- sincroniza `dist-qt/`
- hace `git push origin <branch>`
- hace `git push --tags`

### Flujo Recomendado

1. Hacer cambios en uno o varios proyectos Qt.
2. Crear los commits normales de esos cambios.
3. Volver a la raiz `C:\Users\caico\Desktop\CUARZOPOLAR\bajo-ataque`.
4. Ejecutar:

```powershell
.\manage_qt_releases.ps1
```

### Ejecutar Solo Algunos Proyectos

```powershell
.\manage_qt_releases.ps1 -Project qr,password_qt,phishing_qt
```

Tambien se puede pasar un solo proyecto:

```powershell
.\manage_qt_releases.ps1 -Project qr
```

### Flags Utiles

Permitir release aunque el repo tenga cambios sin commit:

```powershell
.\manage_qt_releases.ps1 -AllowDirty
```

No recomendado salvo caso excepcional.

Desactivar el push automatico:

```powershell
.\manage_qt_releases.ps1 -SkipPush
```

### Estados Del Reporte

- `released`: se ha generado una nueva version, se ha actualizado `releases.json`, se ha sincronizado `dist-qt` y se ha hecho push.
- `synced`: ya no hacia falta una nueva version; solo se ha sincronizado `dist-qt` y se ha hecho push si hacia falta.
- `blocked_dirty`: el proyecto tiene cambios locales sin commit y el script no ha actuado.
- `blocked_tag_conflict`: el siguiente tag esperado ya existe en otro commit y el script se detiene para evitar una release incoherente.

### Regla Operativa Importante

No lanzar releases con cambios sin commit salvo que sea intencional y se use `-AllowDirty`.

El flujo normal debe ser siempre:

1. cambiar codigo
2. hacer commit
3. ejecutar `.\manage_qt_releases.ps1`

### Salidas Esperadas

Los zips nuevos usan el prefijo `bajo-ataque-...` y quedan:

- en `dist\` dentro de cada proyecto
- extraidos en `dist-qt/`

### Script Principal

[manage_qt_releases.ps1](C:/Users/caico/Desktop/CUARZOPOLAR/bajo-ataque/manage_qt_releases.ps1)

## Android

### Generar Releases

Desde la raiz:

```powershell
.\manage_android_releases.ps1
```

Ese comando:

- recorre `password_android`, `permission_android` y `phishing_android`
- detecta si hay una release pendiente
- bloquea proyectos con cambios locales sin commit
- genera `assembleRelease` cuando corresponde
- actualiza `releases.json`
- sincroniza `dist-android/`
- puede hacer `git push origin <branch>` y `git push --tags`

### Flujo Recomendado

1. Hacer cambios en una o varias apps Android.
2. Crear los commits normales de esos cambios.
3. Volver a la raiz `C:\Users\caico\Desktop\CUARZOPOLAR\bajo-ataque`.
4. Ejecutar:

```powershell
.\manage_android_releases.ps1
```

### Ejecutar Solo Algunas Apps

```powershell
.\manage_android_releases.ps1 -Project password_android,phishing_android
```

Tambien se puede pasar una sola:

```powershell
.\manage_android_releases.ps1 -Project permission_android
```

### Flags Utiles

Permitir release aunque el repo tenga cambios sin commit:

```powershell
.\manage_android_releases.ps1 -AllowDirty
```

Desactivar el push automatico:

```powershell
.\manage_android_releases.ps1 -SkipPush
```

### Salidas Esperadas

Los APKs release versionados quedan:

- en `dist\` dentro de cada proyecto Android
- sincronizados en `dist-android/<app>`

Cada carpeta estable de `dist-android` contiene:

- `app-release.apk`
- `version.json`
- `BUILD_INFO.txt`

### Despliegue En Dispositivos

Para instalar o actualizar desde `dist-android`:

```powershell
.\deploy_android.ps1 -Action update -All
```

Para instalar limpio:

```powershell
.\deploy_android.ps1 -Action install -All
```

Para desinstalar todas las apps:

```powershell
.\deploy_android.ps1 -Action uninstall -All
```

Para consultar estado del dispositivo y de las apps:

```powershell
.\deploy_android.ps1 -Action status
```

### Regla Operativa Importante

Android usa builds `release` firmadas. Si cambia la firma, Android no permite actualizar encima y hay que desinstalar e instalar de nuevo.

### Scripts Principales

- [manage_android_releases.ps1](C:/Users/caico/Desktop/CUARZOPOLAR/bajo-ataque/manage_android_releases.ps1)
- [deploy_android.ps1](C:/Users/caico/Desktop/CUARZOPOLAR/bajo-ataque/deploy_android.ps1)
