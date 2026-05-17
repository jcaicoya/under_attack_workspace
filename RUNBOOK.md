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
- sincroniza `dist_qt/`
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

- `released`: se ha generado una nueva version, se ha actualizado `releases.json`, se ha sincronizado `dist_qt` y se ha hecho push.
- `synced`: ya no hacia falta una nueva version; solo se ha sincronizado `dist_qt` y se ha hecho push si hacia falta.
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

- en `dist_qt/`
- extraidos en `dist_qt/<proyecto>/`

### Script Principal

[manage_qt_releases.ps1](C:/Users/caico/Desktop/CUARZOPOLAR/bajo-ataque/manage_qt_releases.ps1)

### Preparar `dist_qt` Para El Portatil De Ensayo

Si en otro ordenador solo mantienes `dist_qt/` con zips y carpetas ya desplegadas, puedes normalizarlo desde la raiz con:

```powershell
.\refresh_backup_qt_dist.ps1
```

Ese script:

- conserva solo el zip mas reciente de cada proyecto Qt
- borra los zips antiguos
- desbloquea los zips conservados para evitar avisos de seguridad al abrirlos
- vuelve a desplegar cada proyecto en `dist_qt/<proyecto>/`
- desbloquea tambien los archivos extraidos
- deja las carpetas sin sufijo de version

Para probarlo sobre una copia:

```powershell
Copy-Item .\dist_qt .\dist_qt_copy -Recurse
.\refresh_backup_qt_dist.ps1 -DistQtDir .\dist_qt_copy
```

Modo simulacion:

```powershell
.\refresh_backup_qt_dist.ps1 -WhatIf
```

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
- sincroniza `dist_android/`
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

- en `dist_android/`
- publicados en `dist_android/<app>`

Cada carpeta estable de `dist_android` contiene:

- `app-release.apk`
- `version.json`
- `BUILD_INFO.txt`

### Despliegue En Dispositivos

Primero, comprobar que el dispositivo esta visible por `adb`:

```powershell
.\deploy_android.ps1 -Action status
```

Para instalar las tres apps en un dispositivo limpio:

```powershell
.\deploy_android.ps1 -Action install -All
```

Para actualizar una instalacion existente manteniendo datos:

```powershell
.\deploy_android.ps1 -Action update -All
```

Para actuar solo sobre una app:

```powershell
.\deploy_android.ps1 -Action update -App permission_android
```

Para desinstalar todas las apps:

```powershell
.\deploy_android.ps1 -Action uninstall -All
```

Para desinstalar una sola:

```powershell
.\deploy_android.ps1 -Action uninstall -App permission_android
```

### Permisos Reales Recomendados

Despues de instalar:

- `password_android`
  - notificaciones
- `phishing_android`
  - notificaciones
- `permission_android`
  - notificaciones
  - mostrar sobre otras apps
  - `Device Admin`
  - camara
  - microfono
  - bateria sin restricciones si el dispositivo lo separa

### Regla Operativa Importante Sobre Firma

Se asume una unica firma `release` estable para las tres apps Android.

Con esta firma estable:

- `install` instala desde cero
- `update` actualiza encima sin desinstalar

Solo hay que desinstalar antes si se arrastra una app antigua firmada con otra clave.

### Desinstalar Una App Antigua Con `Device Admin`

Caso tipico:

- la app antigua es `com.cuarzopolar.companion`
- tiene `Device Admin`
- `adb uninstall` falla aunque ya no se use

Procedimiento:

1. localizar el paquete si hace falta:

```powershell
& 'C:\Users\caico\AppData\Local\Android\Sdk\platform-tools\adb.exe' shell pm list packages | findstr cuarzopolar
```

2. comprobar el admin activo:

```powershell
& 'C:\Users\caico\AppData\Local\Android\Sdk\platform-tools\adb.exe' shell dumpsys device_policy | findstr /i cuarzopolar
```

3. quitar el admin activo:

```powershell
& 'C:\Users\caico\AppData\Local\Android\Sdk\platform-tools\adb.exe' shell dpm remove-active-admin com.cuarzopolar.companion/.CompanionDeviceAdminReceiver
```

4. desinstalar la app antigua para el usuario principal:

```powershell
& 'C:\Users\caico\AppData\Local\Android\Sdk\platform-tools\adb.exe' shell pm uninstall --user 0 com.cuarzopolar.companion
```

5. verificar que ya no queda instalada:

```powershell
& 'C:\Users\caico\AppData\Local\Android\Sdk\platform-tools\adb.exe' shell pm list packages | findstr cuarzopolar
```

### Flujo Operativo Recomendado

1. generar releases:

```powershell
.\manage_android_releases.ps1
```

2. comprobar `adb`:

```powershell
.\deploy_android.ps1 -Action status
```

3. si es una instalacion nueva:

```powershell
.\deploy_android.ps1 -Action install -All
```

4. si ya estaban instaladas con la firma actual:

```powershell
.\deploy_android.ps1 -Action update -All
```

5. conceder los permisos reales necesarios, sobre todo en `permission_android`

### Scripts Principales

- [manage_android_releases.ps1](C:/Users/caico/Desktop/CUARZOPOLAR/bajo-ataque/manage_android_releases.ps1)
- [deploy_android.ps1](C:/Users/caico/Desktop/CUARZOPOLAR/bajo-ataque/deploy_android.ps1)
