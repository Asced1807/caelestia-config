-- Overrides de variables de caelestia (~/.config/hypr/variables.lua)
-- Migrado desde hypr-vars.conf / los parches locales en variables.conf (2026-07-27)
-- Todo lo que se define aquí pisa el valor por defecto de upstream.

return {
    -- Apps por defecto (upstream trae foot / firefox / codium / thunar)
    terminal     = "kitty",
    browser      = "brave",
    editor       = "codium",
    fileExplorer = "nemo",

    -- Cursor (upstream trae sweet-cursors, que ni siquiera está instalado)
    cursorTheme  = "Fire-Force-Burning-Skull",
    cursorSize   = 32,
}
