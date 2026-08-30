-- ############################################################
-- ## Config de usuario de Hyprland (se carga al final de todo)
-- ## Migrado de .conf a Lua el 2026-07-27 (Hyprland 0.57 elimina hyprlang)
-- ##
-- ## Todo lo *aditivo* vive aquí a propósito, para que actualizar los dots
-- ## de caelestia (git pull) no genere conflictos. Los únicos parches que
-- ## quedan dentro del repo están en hypr/hyprland/execs.lua (cosas que hay
-- ## que QUITAR de upstream, no se pueden deshacer desde aquí).
-- ############################################################

-- ############### Autostart extra ###############

hl.on("hyprland.start", function()
    -- Cursor para las apps que NO son hijas de Hyprland (servicios de systemd --user,
    -- app2unit, activación D-Bus). uwsm finaliza XCURSOR_* demasiado tarde, así que
    -- Brave/quickshell arrancaban sin tema y caían al heredado (Bibata).
    -- Redundante con ~/.config/environment.d/50-cursor.conf a propósito: aquí el valor
    -- sale de hypr-vars.lua, así que sigue el tema aunque el .conf se quede viejo.
    local vars = require("variables")
    hl.exec_cmd(
        "systemctl --user set-environment XCURSOR_THEME=" .. vars.cursorTheme ..
        " XCURSOR_SIZE=" .. vars.cursorSize ..
        " && dbus-update-activation-environment --systemd XCURSOR_THEME XCURSOR_SIZE"
    )

    -- Automontaje de USB + notificaciones (se integra con la barra lateral de Nemo)
    hl.exec_cmd("udiskie --automount --notify --no-tray")

    -- Tray con el conteo de updates de pacman + AUR (clic izq = actualizar)
    hl.exec_cmd("pacman-updates-tray")
end)


-- ############### Ajustes generales ###############

hl.config({
    ecosystem = {
        -- Oculta el popup "Hyprland updated to X.Y.Z!" al iniciar tras actualizar
        no_update_news = true,
    },

    cursor = {
        -- Fire-Force-Burning-Skull es un tema XCursor puro (PNGs de sweezy, sin
        -- manifest.hl) y su index.theme lleva Inherits=Bibata-Modern-Ice.
        -- Bibata SÍ es tema hyprcursor, así que hyprcursor seguía la herencia y
        -- terminaba cargando Bibata: la calavera se veía en SDDM (XCursor puro)
        -- pero dentro de la sesión salía el cursor blanco de Bibata.
        -- Con esto Hyprland usa XCursor directo y respeta el tema elegido.
        -- Quitar solo si algún día el tema se convierte con hyprcursor-util.
        enable_hyprcursor = false,
    },
})


-- ############### Keybinds ###############

-- Selector de wallpapers skwd-wall
hl.bind("SUPER + SHIFT + T", hl.dsp.exec_cmd("skwd wall toggle"))

-- Reinicio de la shell de caelestia (cuando el módulo de workspaces se queda invisible)
hl.bind(
    "CTRL + SUPER + B",
    hl.dsp.exec_cmd(
        "systemctl --user restart caelestia-shell.service && " ..
        "notify-send -u low 'Caelestia shell' 'Reiniciada'"
    )
)

-- ## Gaming ##
-- UN SOLO atajo. Sustituye a los tres que había antes:
--   SUPER + G          abría Steam          -> el launcher ya lleva al juego
--   SUPER + SHIFT + B  abría Big Picture    -> el launcher hace lo mismo y va más rápido
--   SUPER + SHIFT + G  Game Mode a mano     -> ahora se activa solo al lanzar
-- El juego no se abre con xdg-open sino con `caelestia-game-run`, que enciende
-- Game Mode, lanza el juego y lo apaga al detectar que ya no hay ventanas de
-- juego (por clase, NO por el workspace 10: ahí también cae steamwebhelper).
--
-- El toggle usa `pkill -x -f`, que compara el cmdline COMPLETO de forma literal.
-- Con `pkill -f 'qs -c gamelauncher'` a secas el patrón casaba con el propio
-- `sh -c` que lo ejecuta: se mataba a sí mismo y el bind no hacía nada.
-- (`qs -c gamelauncher kill` tampoco vale de toggle: devuelve 0 aunque no
-- hubiera ninguna instancia, así que el `||` nunca llegaba a lanzar.)
hl.bind("SUPER + G", hl.dsp.exec_cmd(
    [[sh -c 'pkill -x -f "qs -c gamelauncher" || qs -c gamelauncher']]
))

-- Toggle del inhibidor de idle (modo cine / leer)
-- El IPC de caelestia NO sirve aquí: su singleton `idleInhibitor` es lazy y no
-- se instancia hasta abrir el panel de utilidades, así que el bind respondía
-- "Target not found" y no hacía nada. Lo lleva gamepad-idle-inhibit, que
-- entiende SIGUSR1 como "inhibir siempre / volver a automático".
hl.bind("SUPER + ALT + I", hl.dsp.exec_cmd(
    "systemctl --user kill -s SIGUSR1 gamepad-idle-inhibit.service"
))


-- ############### Reglas de ventana ###############

-- Transparencia de Brave: activa 0.80 / inactiva 0.68
hl.window_rule({
    name    = "user-brave-opacity",
    match   = { class = "brave-browser" },
    opacity = "0.80 0.68",
})

-- ## Gaming: todo al workspace 10 ##
local game_ws = "10"

-- Juegos de Steam / gamescope
for _, class in ipairs({ "^(steam_app_.*)$", "^(gamescope)$", "^(steamwebhelper)$" }) do
    hl.window_rule({ match = { class = class }, workspace = game_ws })
end

-- Pantalla completa real para los juegos de Steam.
-- Sin esto, un juego en modo "ventana sin bordes" se queda floating a 1920x1080
-- pero desplazado por el área que reserva la barra de caelestia (at = -60,-10):
-- se come 60px por la izquierda (fuera de pantalla) y deja una franja de
-- escritorio a la derecha. Fullscreen de verdad también lo pone por encima de
-- la barra, que es una capa `top`.
-- Solo steam_app_<número>: gamescope ya gestiona su propio fullscreen y los
-- emuladores abren primero una ventana de biblioteca que no debe maximizarse.
hl.window_rule({
    name       = "user-steam-games-fullscreen",
    match      = { class = "^(steam_app_[0-9]+)$" },
    fullscreen = true,
})

-- Juegos lanzados vía wine (Heroic, Proton fuera de Steam)
for _, class in ipairs({ "^(wine|wine64|wineserver)$", "^(heroic-game)$" }) do
    hl.window_rule({ match = { initial_class = class }, workspace = game_ws })
end

-- Juegos de Heroic: se listan uno a uno a propósito. Una regla genérica
-- ^(.*\.exe)$ mandaría también a Fusion 360 al ws 10.
hl.window_rule({
    match     = { initial_class = [[^(wwzRetailEgs\.exe|Arranger\.exe)$]] },
    workspace = game_ws,
})

-- Emuladores (los launchers como Heroic NO van al ws 10, solo los juegos)
hl.window_rule({
    match     = { class = "^(dolphin-emu|pcsx2-qt|pcsx2|rpcs3|cemu|yuzu|ryujinx|duckstation|ppsspp)$" },
    workspace = game_ws,
})

-- ## Modo consola: Steam Big Picture ##
-- Que entre a pantalla completa solo, como una consola.
hl.window_rule({
    name         = "user-steam-big-picture",
    match        = { title = "^(Steam Big Picture Mode)$" },
    workspace    = game_ws,
    fullscreen   = true,
    opaque       = true,
    idle_inhibit = "always",
})

-- Sin decoración en el ws 10 (mejor rendimiento en juegos)
hl.workspace_rule({ workspace = game_ws, decorate = false, no_rounding = true })

-- Sin blur ni sombra para lo que haya en el ws 10.
-- En pcall porque el match por workspace es la parte menos documentada de la
-- API Lua: si cambia de forma, se pierde solo esta regla y no la config entera.
local ok, err = pcall(function()
    hl.window_rule({
        name      = "user-ws10-no-effects",
        match     = { workspace = tonumber(game_ws) },
        no_blur   = true,
        no_shadow = true,
    })
end)
if not ok then
    hl.exec_cmd("notify-send -u low 'hypr-user.lua' 'Regla no_blur del ws 10 omitida: " .. tostring(err) .. "'")
end
