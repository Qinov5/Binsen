# Binsen (便箋)

[简体中文](README.md) | [English](README.en.md) | [繁體中文](README.zh-TW.md) | [日本語](README.ja.md) | **Español**

Escribe una línea rápida en tu iPhone y, en unos segundos, aparecerá en silencio como una nota nueva en **Stickies**, la app de notas adhesivas que viene con macOS.

https://github.com/user-attachments/assets/12b98983-d6f9-4837-83bc-dde8d83b0335

**Binsen** toma su nombre de la palabra japonesa **便箋 (*binsen*)**, que significa «papel de cartas» o «nota». Esa idea que se te ocurre en la calle, una tarea pendiente o un fragmento que quieres guardar: ya no hace falta enviártelo por mensaje a ti mismo ni abrir una app de notas pesada. Cuando vuelvas al Mac, ya estará pegado en tu escritorio.

```text
Atajo «Binsen» en el iPhone
  ├─ recomendado: se añade a la lista de Recordatorios «Binsen» ──▶ iCloud, en segundos
  └─ versión antigua: se guarda como .txt ──▶ iCloud Drive/Atajos/Binsen
                        └─ Binsen, en segundo plano en el Mac, recibe el texto
                              ├─ crea en silencio una nota nueva en Stickies y escribe el texto
                              └─ marca el recordatorio como completado; el archivo va a Binsen/已处理
```

## Por qué existe

* **Totalmente nativo**: escribe directamente en la app **Stickies** integrada en macOS, no en una ventana flotante que la imita.
* **Sin interrupciones**: todo ocurre en segundo plano y nunca roba el foco de la ventana activa, así que puedes seguir escribiendo en el Mac. Si Stickies no está abierta, Binsen la inicia y reutiliza la nota en blanco que crea al arrancar, sin dejar notas vacías de más.
* **No toca tu portapapeles**: ni lo lee ni lo modifica.
* **Cero dependencias externas**: sin servidor, sin registro de cuenta y sin puertos de red abiertos; todo se sincroniza a través de tu propio iCloud (Recordatorios o iCloud Drive).
* **Mínimo y auditable**: toda la lógica está en un único archivo Swift, sin dependencias de terceros.

## Requisitos

* macOS 13 o posterior
* Xcode o las herramientas de línea de comandos (`xcode-select --install`)
* El Mac y el iPhone con la misma cuenta de Apple y **Recordatorios** activado en iCloud (para la versión antigua con archivos, también **iCloud Drive**)

## Primeros pasos

### 1. Instalar en el Mac

```bash
git clone https://github.com/Qinov5/Binsen.git
cd Binsen
zsh install.sh
```

El script de instalación se encarga de todo: **compila la app → la instala en `~/Applications/Binsen.app` → crea la carpeta de entrada en iCloud → registra el inicio automático al iniciar sesión → prueba por separado el canal de iCloud Drive y el de Recordatorios**.

Si en el escritorio aparecen las notas **«Binsen 已接通 ✅»** («Binsen conectado») y **«Binsen 提醒事项通道已接通 ✅»** («canal de Recordatorios conectado»), la instalación ha salido bien.

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

**Permiso de Recordatorios**: durante la instalación aparecerá un aviso para acceder a **Recordatorios**; haz clic en **Permitir**. Binsen solo lee y escribe en la lista «Binsen» (si no existe, la crea en iCloud) y, después de pegar cada recordatorio como nota, lo marca como completado. Si no lo concediste, ve a `Ajustes del Sistema → Privacidad y seguridad → Recordatorios`, activa Binsen y vuelve a ejecutar `zsh install.sh`.

### 3. Añadir el atajo en el iPhone

Recomendamos la versión con **Recordatorios**: se sincroniza al instante y, en las pruebas, la nota tardó unos 10 segundos en aparecer en el Mac.

👉 **[Añadir el atajo «Binsen»](https://www.icloud.com/shortcuts/54ba2387d2b54ceebe1437aef3b34d47)**

Solo hace dos cosas: muestra un campo de texto y añade lo que escribas a la lista de Recordatorios «Binsen». Después de añadirlo, ábrelo una vez: si la lista no es «Binsen», vuelve a elegirla (aparece sola cuando instalas Binsen en el Mac).

💡 **Truco**: si tu iPhone tiene **botón de acción**, ve a `Ajustes → Botón de acción → Atajo` y elige **Binsen**; así podrás pegar una nota con solo pulsar el botón lateral. También puedes añadirlo como widget de la pantalla de bloqueo o activarlo con «Tocar atrás».

<details>
<summary>¿Prefieres crearlo a mano?</summary>

1. Abre la app **Atajos**, toca **＋** arriba a la derecha y llámalo `Binsen`.
2. Añade la acción **Solicitar entrada** con el tipo «Texto».
3. Añade la acción **Añadir recordatorio nuevo**: en el campo del recordatorio elige «Entrada proporcionada» (suele rellenarse solo) y como lista elige **Binsen** (si aún no aparece, abre una vez la app Recordatorios para que se sincronice).

*(También puedes crearlo en la app Atajos del Mac; se sincroniza con el iPhone a través de iCloud.)*
</details>

<details>
<summary>Versión antigua: guardar un archivo en iCloud Drive (puede tardar mucho)</summary>

👉 [Añadir el atajo antiguo](https://www.icloud.com/shortcuts/22b6bb3e26b046278a8ee42ee9dd0edd)

O créalo a mano: **Solicitar entrada** (Texto) → **Guardar archivo** (contenido: «Entrada proporcionada», desactiva «Preguntar dónde guardar», subruta `/Binsen/`).

> Atención: el iPhone a menudo no sube enseguida a iCloud los archivos que guarda el atajo; muchas veces la subida no empieza hasta que abres la app Archivos, así que puede tardar de minutos a horas. El Mac sigue vigilando esta carpeta, así que el atajo antiguo sigue funcionando.
</details>

## Ajustes avanzados

Puedes cambiar el comportamiento por defecto con `defaults`:

```bash
# Dejar Stickies al frente tras crear la nota (por defecto se devuelve el foco a la ventana anterior)
defaults write io.github.qinov5.binsen RestoreFocus -bool false

# Usar otra carpeta de entrada
defaults write io.github.qinov5.binsen InboxPath "~/una-carpeta"

# Cambiar la lista de Recordatorios que vigila Binsen (por defecto Binsen; si no existe, se crea)
defaults write io.github.qinov5.binsen RemindersList "otra-lista"

# Desactivar el canal de Recordatorios y usar solo archivos de iCloud Drive
defaults write io.github.qinov5.binsen UseReminders -bool false

# Reiniciar el servicio en segundo plano para aplicar los cambios
launchctl kickstart -k gui/$(id -u)/io.github.qinov5.binsen
```

## Solución de problemas

| Síntoma | Qué hacer |
| :--- | :--- |
| No aparece ninguna nota | Revisa el registro: `tail -20 ~/Library/Logs/Binsen.log` |
| Las notas tardan mucho en aparecer | Busca en el registro la línea que empieza por `收到：`: indica cuánto tardó iCloud en entregarlo a este Mac y cuánto tiempo estuvo el Mac en reposo mientras tanto. De `收到` a `已贴到便笺` suelen pasar solo 1–2 segundos, así que el retraso casi siempre está en iCloud |
| Las notas enviadas con el Mac cerrado o en reposo no aparecen | Un Mac en reposo no puede crear notas; al despertar, iCloud termina de sincronizar y la nota suele aparecer sola en unas decenas de segundos |
| Con el atajo antiguo (Guardar archivo), no llega hasta que abro la app Archivos | El iPhone no sube enseguida los archivos que guarda el atajo. Cambia al atajo con Recordatorios descrito más arriba |
| Con el Mac despierto y el texto ya enviado desde el iPhone, aún tarda minutos | Lo más probable es que un proxy o una VPN esté bloqueando las notificaciones push de iCloud y el Mac no se entere de los cambios. Si usas Shadowrocket, Clash u otra herramienta que configura un proxy del sistema, añade `*.push.apple.com` y `17.0.0.0/8` a su lista de exclusiones (skip-proxy) |
| El registro dice `没有控制「便笺」的权限` (sin permiso para controlar Stickies) | Consulta «Conceder permiso de control» más arriba |
| El registro dice `提醒事项：没有访问权限` (sin permiso para Recordatorios) | Ve a `Ajustes del Sistema → Privacidad y seguridad → Recordatorios`, activa Binsen y ejecuta `launchctl kickstart -k gui/$(id -u)/io.github.qinov5.binsen` |
| Tras crear la nota, el foco no vuelve a la ventana anterior | Comprueba primero el permiso; si sigue ocurriendo, abre un Issue con la línea del registro que empieza por `焦点没能还给…` |
| Comprobar si el servicio está en ejecución | `launchctl print gui/$(id -u)/io.github.qinov5.binsen \| grep state` |

## Desinstalar

```bash
zsh uninstall.sh
```

El script solo elimina la app en segundo plano y su inicio automático. **La carpeta de entrada de iCloud, la lista «Binsen» de Recordatorios y todas las notas que ya tienes en el escritorio se conservan.**

## Cómo funciona y estructura

* **Residente y ligero**: `Binsen.app` es una app en segundo plano sin icono en el Dock; un `LaunchAgent` la inicia al iniciar sesión. Vigila la carpeta de entrada con FSEvents y procesa cada archivo en cuanto llega, con una comprobación de respaldo cada 2 segundos. Si no logra crear la nota, lo reintenta a los 2, 4, 8… segundos hasta conseguirlo.
* **Canal de Recordatorios**: con EventKit vigila los cambios en la lista «Binsen» (y además pide una actualización cada minuto); al leer un recordatorio nuevo lo pega como nota y lo marca como completado. Los Recordatorios se sincronizan con CloudKit, así que el iPhone los sube al instante; en cambio, los archivos que guarda el atajo dependen de cuándo decida subirlos iCloud Drive.
* **Descarga bajo demanda**: un `.txt` recién sincronizado desde el iPhone puede ser, en el Mac, solo un marcador de posición todavía sin descargar. El programa activa la descarga bajo demanda con `setiopolicy_np` y, si el archivo aún no está listo, la solicita con `brctl download`. La lectura se hace en un hilo en segundo plano, así que un archivo que tarda en descargarse no retrasa a los demás.
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
