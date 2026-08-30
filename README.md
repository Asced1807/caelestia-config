# Mis ajustes de Caelestia

Lo que le cambio a [Caelestia](https://github.com/caelestia-dots/shell) encima
de la instalación de serie: la barra, mis atajos, las reglas de ventana para
jugar y dos parches de QML.

> **No es un fork ni una copia de los dots.** Son solo mis archivos de usuario,
> los que Caelestia deja justo para esto y que no se pierden al actualizar.

---

## Instalar

```bash
git clone https://github.com/Asced1807/caelestia-config.git
cd caelestia-config
./install.sh
```

**Si te falta algo, te lo instala.** Comprueba Caelestia (`caelestia-shell` y
`caelestia-cli` del AUR), `patch` y `python3`, y te pregunta antes de tocar
nada. Si no tienes `yay` ni `paru`, también se ofrece a poner `yay`. Con `-y`
no pregunta:

```bash
./install.sh -y
```

Al terminar hace una comprobación pieza por pieza —config, overlay, parches y
que los `.lua` parsean— y te la enseña con `[ok]` o `[FALLA]`. Si algo falla,
sale con error en vez de decirte que todo fue bien.

Todo lo que pisa lleva copia `.bak-<fecha>` al lado. Y se puede repetir cuantas
veces quieras — de hecho **hay que repetirlo después de cada actualización de
`caelestia-shell`**, porque los QML parcheados se regeneran sobre el original
nuevo. Si no, la shell puede no arrancar.

## Qué toca

| Archivo | Qué le hace |
|---|---|
| `~/.config/caelestia/shell.json` | Barra: workspaces con iconos, sin transparencia, Nemo como explorador, `uwsm stop` al cerrar sesión. |
| `~/.config/caelestia/cli.json` | `enableChromium: false`. Solo esa clave: si tienes un `postHook`, se respeta. |
| `~/.config/caelestia/hypr-vars.lua` | Apps por defecto (kitty, brave, codium, nemo) y el cursor. |
| `~/.config/caelestia/hypr-user.lua` | Atajos, autostart extra y reglas de ventana. |
| `~/.config/quickshell/caelestia/` | El overlay: 290+ symlinks a `/etc/xdg` y los 2 archivos parcheados. |
| `~/.local/share/caelestia/hypr/hyprland/execs.lua` | Solo si tienes el clon de los dots: cambia el agente polkit. |

## Los ajustes, uno a uno

**`enableChromium: false`** — al aplicar un tema, Caelestia lanza
`brave --refresh-platform-policy --no-startup-window` y **ese proceso se queda
residente** (~220 MB). Parece Brave abriéndose solo sin que lo toques.

**Cursor con `enable_hyprcursor = false`** — si tu tema es XCursor puro y su
`index.theme` hereda de uno que sí es hyprcursor (Bibata, por ejemplo),
hyprcursor sigue la herencia y acabas viendo el cursor heredado dentro de la
sesión aunque en SDDM se vea el tuyo.

**Reglas de gaming** — todo al workspace 10, sin decoración ni blur, y
`fullscreen = true` para `steam_app_<número>`: sin eso, un juego en "ventana sin
bordes" queda desplazado por el área que reserva la barra (se come 60 px por la
izquierda y deja una franja de escritorio a la derecha).

**`Shortcuts.qml.patch`** — workaround de la regresión
[hyprwm/Hyprland#15063](https://github.com/hyprwm/Hyprland/issues/15063): desde
0.55 el bind *catchall* dispara también con el propio `Super_L` del launcher, así
que el launcher se cerraba solo. Ignora los eventos que llegan a menos de 30 ms.
**Quítalo cuando Hyprland lo arregle.**

**`Content.qml.patch`** — añade el popout de **ethernet**, que la barra no expone
aunque su propio `Network.qml` ya lo soporta (`view: "ethernet"`).

**`execs-polkit.lua.patch`** — los dots arrancan
`/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1`, que en Arch no
existe salvo que instales `polkit-gnome`. Sin agente, cualquier cosa que pida
contraseña (gparted, `pkexec`) falla con *No authentication agent found*. Lo
cambia por `hyprpolkitagent.service`.

## Antes de copiarlo tal cual

`hypr-user.lua` tiene atajos que llaman a cosas **mías**. No rompen nada si no
las tienes (Hyprland ignora el comando y sigue), pero la tecla no hará nada:

| Atajo | Necesita |
|---|---|
| `Super + Shift + T` | [skwd-wall-setup](https://github.com/Asced1807/skwd-wall-setup) |
| `Super + G` | Mi Game Launcher (no está en este repo) |
| `Super + Alt + I` | Mi daemon `gamepad-idle-inhibit` |
| autostart `pacman-updates-tray` | Mi script de bandeja |

`Ctrl + Super + B` (reiniciar la shell) y las reglas de ventana sí funcionan
tal cual. Borra las líneas que no te sirvan.

## Qué NO está aquí

- **Los módulos propios de mi barra** (contador de updates de pacman). Los
  parches publicados son solo los que funcionan sobre una Caelestia limpia; los
  que dependen de esos módulos se quedan fuera para no romperte la barra.
- **El Game Launcher** y los scripts (watchdog, modo juego, bandeja).
- **El theming de Nemo y kitty**: eso vive en
  [skwd-wall-setup](https://github.com/Asced1807/skwd-wall-setup#colores-que-siguen-al-fondo-opcional).

## Desinstalar

```bash
rm ~/.config/caelestia/{shell.json,hypr-user.lua,hypr-vars.lua}
rm -rf ~/.config/quickshell/caelestia
systemctl --user restart caelestia-shell.service
```

Vuelve todo al comportamiento de serie. Tus `.bak-<fecha>` siguen donde estaban.

## Licencia

Mis archivos, MIT. Los `.patch` son diferencias sobre archivos de
[caelestia-dots/shell](https://github.com/caelestia-dots/shell) y el resultado
de aplicarlos queda bajo la licencia de ese proyecto.
