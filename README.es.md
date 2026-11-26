# Binsen (便箋)

[简体中文](README.md) | [English](README.en.md) | [繁體中文](README.zh-TW.md) | [日本語](README.ja.md) | **Español**

Escribe una línea rápida en tu iPhone y, en unos segundos, aparecerá en silencio como una nota nueva en **Stickies**, la app de notas adhesivas que viene con macOS.

https://github.com/user-attachments/assets/12b98983-d6f9-4837-83bc-dde8d83b0335

**Binsen** toma su nombre de la palabra japonesa **便箋 (*binsen*)**, que significa «papel de cartas» o «nota». Esa idea que se te ocurre en la calle, una tarea pendiente o un fragmento que quieres guardar: ya no hace falta enviártelo por mensaje a ti mismo ni abrir una app de notas pesada. Cuando vuelvas al Mac, ya estará pegado en tu escritorio.

```text
Atajo «Binsen» en el iPhone
  └─ se guarda como .txt ──▶ iCloud Drive/Atajos/Binsen
                        └─ el proceso en segundo plano del Mac detecta el archivo
                              ├─ crea en silencio una nota nueva en Stickies y escribe el texto
                              └─ archiva el original en Binsen/已处理
```

## Por qué existe

* **Totalmente nativo**: escribe directamente en la app **Stickies** integrada en macOS, no en una ventana flotante que la imita.
* **Sin interrupciones**: todo ocurre en segundo plano y nunca roba el foco de la ventana activa, así que puedes seguir escribiendo en el Mac. Si Stickies no está abierta, Binsen la inicia y reutiliza la nota en blanco que crea al arrancar, sin dejar notas vacías de más.
* **No toca tu portapapeles**: ni lo lee ni lo modifica.
* **Cero dependencias externas**: sin servidor, sin registro de cuenta y sin puertos de red abiertos; todo se sincroniza a través de tu propio iCloud Drive.
* **Mínimo y auditable**: toda la lógica está en un único archivo Swift, sin dependencias de terceros.

## Requisitos

* macOS 13 o posterior
* Xcode o las herramientas de línea de comandos (`xcode-select --install`)
* El Mac y el iPhone con la misma cuenta de Apple y **iCloud Drive** activado

## Primeros pasos

### 1. Instalar en el Mac

```bash
git clone https://github.com/Qinov5/Binsen.git
cd Binsen
zsh install.sh
```

El script de instalación se encarga de todo: **compila la app → la instala en `~/Applications/Binsen.app` → crea la carpeta de entrada en iCloud → registra el inicio automático al iniciar sesión → envía un mensaje de prueba**.

Si en el escritorio aparece una nota que dice **«Binsen 已接通 ✅»** («Binsen conectado»), la instalación ha salido bien.

> **Actualizar**: en la carpeta del proyecto, ejecuta `git pull && zsh install.sh`.
>
> **Sobre la firma**: el script usa primero el certificado `Apple Development` de tu llavero (si la primera vez macOS pregunta si `codesign` puede acceder al llavero, elige «Permitir siempre»); así los permisos se conservan entre actualizaciones. Si no tienes certificado de desarrollador, usa una firma ad hoc y tendrás que volver a conceder el permiso después de cada actualización.
>
> **Idioma**: por ahora, los mensajes del script de instalación y del registro están solo en chino simplificado.

### 2. Conceder permiso de control (muy recomendable)

La primera vez que se ejecuta la prueba, macOS pide permiso de control. Basta con permitir que Binsen controle **una sola app: Stickies**. Con ese permiso, Binsen crea las notas desde el menú sin interrumpirte, no roba el foco y no deja notas en blanco de más cuando Stickies arranca.

| Versión de macOS | Cómo concederlo |
| :--- | :--- |
| **macOS 27.3 o posterior** | En el aviso, haz clic en **Choose Apps**, añade solo **Stickies** y cambia la opción de la derecha a **At Any Time** (con *Ask First* te preguntará cada vez). Puedes cambiarlo después en `Ajustes del Sistema → Privacidad y seguridad → System & App Protection Override`. |
| **Versiones anteriores** | Ve a `Ajustes del Sistema → Privacidad y seguridad → Accesibilidad` (en las primeras versiones de macOS 27 se llama *Device Control and Data Access*) y activa **Binsen**. |

*Nota: Binsen también funciona sin este permiso. En ese caso usa el servicio del sistema (Make Sticky), que trae Stickies al frente al crear la nota y, si Stickies no estaba abierta, puede dejar una nota en blanco de más.*

### 3. Añadir el atajo en el iPhone

Abre este enlace en el iPhone y añade el atajo ya preparado:

👉 **[Añadir el atajo «Binsen»](https://www.icloud.com/shortcuts/22b6bb3e26b046278a8ee42ee9dd0edd)**

Solo hace dos cosas: muestra un campo de texto y guarda lo que escribas en `iCloud Drive › Atajos › Binsen`. Después de añadirlo, ejecútalo una vez y escribe algo para probar.

💡 **Truco**: si tu iPhone tiene **botón de acción**, ve a `Ajustes → Botón de acción → Atajo` y elige **Binsen**; así podrás pegar una nota con solo pulsar el botón lateral. También puedes añadirlo como widget de la pantalla de bloqueo o activarlo con «Tocar atrás».

<details>
<summary>¿Prefieres crearlo a mano?</summary>

1. Abre la app **Atajos**, toca **＋** arriba a la derecha y llámalo `Binsen`.
2. Añade la acción **Solicitar entrada** con el tipo «Texto».
3. Añade la acción **Guardar archivo**:
   * Contenido: «Entrada proporcionada»
   * **Desactiva** «Preguntar dónde guardar»
   * Subruta: `/Binsen/`

*(También puedes crearlo en la app Atajos del Mac; se sincroniza con el iPhone a través de iCloud.)*
</details>

## Ajustes avanzados

Puedes cambiar el comportamiento por defecto con `defaults`:

```bash
# Dejar Stickies al frente tras crear la nota (por defecto se devuelve el foco a la ventana anterior)
defaults write io.github.qinov5.binsen RestoreFocus -bool false

# Usar otra carpeta de entrada
defaults write io.github.qinov5.binsen InboxPath "~/una-carpeta"

# Reiniciar el servicio en segundo plano para aplicar los cambios
launchctl kickstart -k gui/$(id -u)/io.github.qinov5.binsen
```

## Solución de problemas

| Síntoma | Qué hacer |
| :--- | :--- |
| No aparece ninguna nota | Revisa el registro: `tail -20 ~/Library/Logs/Binsen.log` |
| El iPhone guardó el texto, pero la carpeta del Mac está vacía | Suele deberse a un retraso de iCloud o a que el Mac está en reposo; comprueba si el archivo ha llegado a `Finder › iCloud Drive › Atajos › Binsen` |
| El registro dice `没有控制「便笺」的权限` (sin permiso para controlar Stickies) | Consulta «Conceder permiso de control» más arriba |
| Tras crear la nota, el foco no vuelve a la ventana anterior | Comprueba primero el permiso; si sigue ocurriendo, abre un Issue con la línea del registro que empieza por `焦点没能还给…` |
| Comprobar si el servicio está en ejecución | `launchctl print gui/$(id -u)/io.github.qinov5.binsen \| grep state` |

## Desinstalar

```bash
zsh uninstall.sh
```

El script solo elimina la app en segundo plano y su inicio automático. **La carpeta de entrada de iCloud y todas las notas que ya tienes en el escritorio se conservan.**

## Cómo funciona y estructura

* **Residente y ligero**: `Binsen.app` es una app en segundo plano sin icono en el Dock; un `LaunchAgent` la inicia al iniciar sesión y revisa la carpeta de entrada cada 2 segundos.
* **Descarga bajo demanda**: un `.txt` recién sincronizado desde el iPhone puede ser, en el Mac, solo un marcador de posición todavía sin descargar. El programa activa la descarga bajo demanda con `setiopolicy_np` y, si el archivo aún no está listo, la solicita con `brctl download`.
* **Escritura invisible**: tras leer el texto, usa la API de accesibilidad para pulsar «Nueva nota» (`⌘N`) en el menú de Stickies y escribir el contenido, sin activar la ventana de Stickies. Si Stickies no está abierta, la inicia en segundo plano y escribe en su nota inicial en blanco. Sin permiso, recurre a `NSPerformService("Make Sticky", …)` e intenta devolver el foco.

```text
Sources/main.swift   lógica de vigilancia y escritura (un solo archivo, sin dependencias)
Info.plist           configuración de la app en segundo plano sin interfaz
Icon/                icono de la app (AppIcon.svg es el original; install.sh elige el .icns según la versión de macOS)
install.sh           compilación, firma, instalación, inicio automático y prueba de extremo a extremo (se puede repetir para actualizar)
uninstall.sh         elimina la app y el servicio de inicio automático
```

## Licencia

[MIT](LICENSE)
