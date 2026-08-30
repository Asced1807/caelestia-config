#!/usr/bin/env bash
# Mis ajustes sobre una instalacion de Caelestia ya existente.
#
# No instala Caelestia ni Hyprland: los da por hechos y solo escribe encima
# lo mio, siempre con copia de seguridad. Idempotente: se puede (y se debe)
# volver a ejecutar despues de cada actualizacion de caelestia-shell, porque
# los QML parcheados hay que regenerarlos sobre el nuevo original.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
CAE_DIR="$CONFIG_HOME/caelestia"
OVERLAY="$CONFIG_HOME/quickshell/caelestia"
UPSTREAM="${CAELESTIA_QML:-/etc/xdg/quickshell/caelestia}"
DOTS="${XDG_DATA_HOME:-$HOME/.local/share}/caelestia"
STAMP="$(date +%Y%m%d-%H%M%S)"

c_ok()   { printf '\033[1;32m==>\033[0m %s\n' "$*"; }
c_warn() { printf '\033[1;33m==>\033[0m %s\n' "$*"; }
c_err()  { printf '\033[1;31m==>\033[0m %s\n' "$*" >&2; }

copia_con_backup() {
  local src="$1" dst="$2"
  if [ -f "$dst" ] && ! cmp -s "$src" "$dst"; then
    cp "$dst" "$dst.bak-$STAMP"
    c_ok "Backup: $(basename "$dst").bak-$STAMP"
  fi
  install -Dm644 "$src" "$dst"
}

# ------------------------------------------------------------ 0. Utilidades
# AUTO_YES=1 (o -y) instala lo que falte sin preguntar. Sin terminal
# interactiva se asume que no: no se instala nada a escondidas.
AUTO_YES="${AUTO_YES:-}"
case "${1:-}" in -y|--yes) AUTO_YES=1 ;; esac

confirmar() {
  [ -n "$AUTO_YES" ] && return 0
  [ -t 0 ] || return 1
  printf '    %s [S/n] ' "$1"
  local resp
  read -r resp || resp=""
  case "$resp" in [nN]*) return 1 ;; *) return 0 ;; esac
}

helper_aur() {
  local h
  for h in yay paru; do
    if command -v "$h" >/dev/null 2>&1; then echo "$h"; return 0; fi
  done

  c_warn "No tienes ningun helper del AUR (yay o paru), y hace falta"  >&2
  c_warn "para instalar Caelestia."                                     >&2
  if ! confirmar "Instalo yay?" >&2; then return 1; fi

  sudo pacman -S --needed --noconfirm git base-devel >&2 || return 1
  local tmp
  tmp="$(mktemp -d)"
  git clone -q https://aur.archlinux.org/yay-bin.git "$tmp/yay-bin" >&2 || { rm -rf "$tmp"; return 1; }
  ( cd "$tmp/yay-bin" && makepkg -si --noconfirm >&2 ) || { rm -rf "$tmp"; return 1; }
  rm -rf "$tmp"
  command -v yay >/dev/null 2>&1 && { echo yay; return 0; }
  return 1
}

instalar_repo() { sudo pacman -S --needed --noconfirm "$@"; }

instalar_aur() {
  local helper
  helper="$(helper_aur)" || return 1
  "$helper" -S --needed "$@"
}

# ---------------------------------------------------------------- 1. Requisitos
if [ ! -d "$UPSTREAM" ]; then
  c_warn "No encuentro la shell de Caelestia en $UPSTREAM."

  if ! command -v pacman >/dev/null 2>&1; then
    c_err "No es Arch: instalala a mano y vuelve a ejecutarme."
    c_err "    https://github.com/caelestia-dots/shell"
    exit 1
  fi

  # caelestia-shell trae los QML; caelestia-cli, el comando 'caelestia'.
  FALTA="caelestia-shell"
  command -v caelestia >/dev/null 2>&1 || FALTA="$FALTA caelestia-cli"

  c_warn "Paquetes del AUR que hacen falta: $FALTA"
  if confirmar "Los instalo ahora?"; then
    # shellcheck disable=SC2086
    instalar_aur $FALTA || { c_err "No he podido instalarla. A mano:  yay -S $FALTA"; exit 1; }
    [ -d "$UPSTREAM" ] || { c_err "Instalada, pero sigue sin haber $UPSTREAM."; exit 1; }
    c_ok "Caelestia instalada."
  else
    c_err "Estos ajustes van encima de Caelestia: sin ella no hay nada que ajustar."
    exit 1
  fi
fi

for cmd in patch python3; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    pkg="$cmd"; [ "$cmd" = "python3" ] && pkg="python"
    if command -v pacman >/dev/null 2>&1 && confirmar "Falta '$cmd'. Lo instalo?"; then
      instalar_repo "$pkg" || { c_err "No he podido instalar '$cmd'."; exit 1; }
    else
      c_err "Falta '$cmd' y hace falta para aplicar los parches."
      exit 1
    fi
  fi
done

# ------------------------------------------------------------------ 2. Config
mkdir -p "$CAE_DIR"
copia_con_backup "$REPO_DIR/config/shell.json"  "$CAE_DIR/shell.json"
copia_con_backup "$REPO_DIR/hypr/hypr-user.lua" "$CAE_DIR/hypr-user.lua"
copia_con_backup "$REPO_DIR/hypr/hypr-vars.lua" "$CAE_DIR/hypr-vars.lua"
c_ok "shell.json y los overrides de Hyprland en su sitio."

# cli.json puede traer un postHook tuyo: solo se toca enableChromium.
python3 - "$CAE_DIR/cli.json" <<'PY'
import json, os, sys

path = sys.argv[1]
try:
    with open(path) as fh:
        cfg = json.load(fh)
except FileNotFoundError:
    cfg = {}
except json.JSONDecodeError as exc:
    sys.exit(f"cli.json no es JSON valido ({exc}); arreglalo o borralo y repite.")

if not isinstance(cfg, dict):
    sys.exit("cli.json no contiene un objeto JSON; arreglalo y repite.")

cfg.setdefault("theme", {})["enableChromium"] = False

os.makedirs(os.path.dirname(path), exist_ok=True)
with open(path, "w") as fh:
    json.dump(cfg, fh, indent=4)
    fh.write("\n")
PY
c_ok "theme.enableChromium = false (ver el README: proceso de Brave residente)."

# ----------------------------------------------------------------- 3. Overlay
# quickshell carga ~/.config/quickshell/caelestia ENTERO si existe: no hay
# mezcla automatica con /etc/xdg. Por eso el overlay replica el arbol con
# symlinks (que siguen a upstream y se actualizan solos con el paquete) y solo
# los archivos parcheados son copias reales.
mkdir -p "$OVERLAY"

enlazados=0
while IFS= read -r -d '' src; do
  rel="${src#"$UPSTREAM"/}"
  dst="$OVERLAY/$rel"
  if [ -e "$dst" ] || [ -L "$dst" ]; then continue; fi
  mkdir -p "$(dirname "$dst")"
  ln -s "$src" "$dst"
  enlazados=$((enlazados + 1))
done < <(find "$UPSTREAM" -type f -print0)

# Symlinks que apuntan a archivos que ya no existen (tipico tras un update que
# renombra modulos): sobran y ademas revientan el arranque de la shell.
rotos=0
while IFS= read -r -d '' link; do
  rm -f "$link"
  rotos=$((rotos + 1))
done < <(find "$OVERLAY" -xtype l -print0)

c_ok "Overlay: $enlazados enlaces nuevos, $rotos rotos eliminados."

# ----------------------------------------------------------------- 4. Parches
# Cada parche se aplica SIEMPRE sobre el original actual de /etc/xdg, para que
# tras un update de caelestia el archivo parcheado no se quede en la version
# vieja (eso es lo que rompe el arranque de la shell).
aplicados=0
fallidos=0

aplicar_parche() {
  local patch_file="$1" rel="$2"
  local orig="$UPSTREAM/$rel" dst="$OVERLAY/$rel"

  if [ ! -f "$orig" ]; then
    c_warn "Upstream ya no trae $rel: parche omitido."
    return 0
  fi

  local tmp
  tmp="$(mktemp)"
  cp "$orig" "$tmp"

  if ! patch -s -p0 "$tmp" < "$patch_file" >/dev/null 2>&1; then
    rm -f "$tmp"
    c_warn "El parche $(basename "$patch_file") ya no aplica sobre esta version."
    c_warn "Dejo $rel sin parchear (comportamiento de serie)."
    if [ -f "$dst" ] && [ ! -L "$dst" ]; then
      cp "$dst" "$dst.bak-$STAMP"
      c_warn "Tu copia anterior queda en $(basename "$dst").bak-$STAMP"
    fi
    ln -sfn "$orig" "$dst"
    fallidos=$((fallidos + 1))
    return 0
  fi

  # Si ya habia una copia real distinta, se guarda antes de pisarla.
  if [ -f "$dst" ] && [ ! -L "$dst" ] && ! cmp -s "$tmp" "$dst"; then
    cp "$dst" "$dst.bak-$STAMP"
  fi

  rm -f "$dst"
  mkdir -p "$(dirname "$dst")"
  mv "$tmp" "$dst"
  chmod 644 "$dst"
  aplicados=$((aplicados + 1))
}

aplicar_parche "$REPO_DIR/patches/Shortcuts.qml.patch" "modules/Shortcuts.qml"
aplicar_parche "$REPO_DIR/patches/Content.qml.patch"   "modules/bar/popouts/Content.qml"

c_ok "Parches QML: $aplicados aplicados, $fallidos omitidos."

# -------------------------------------------- 5. Parche de los dots (opcional)
# El clon de los dots solo existe si seguiste la instalacion "manual" de
# caelestia. Si no esta, no pasa nada: este parche es prescindible.
EXECS="$DOTS/hypr/hyprland/execs.lua"
if [ -f "$EXECS" ]; then
  if patch -s -p1 --dry-run -d "$DOTS" < "$REPO_DIR/patches/execs-polkit.lua.patch" >/dev/null 2>&1; then
    cp "$EXECS" "$EXECS.bak-$STAMP"
    patch -s -p1 -d "$DOTS" < "$REPO_DIR/patches/execs-polkit.lua.patch"
    c_ok "execs.lua: agente polkit -> hyprpolkitagent (backup al lado)."
  else
    c_ok "execs.lua ya parcheado (o cambiado upstream): lo dejo como esta."
  fi
else
  c_warn "No hay clon de los dots en $DOTS: me salto el parche de polkit."
fi

# ------------------------------------------------------------ 6. Recargar
echo
if systemctl --user is-active --quiet caelestia-shell.service; then
  c_warn "Para ver los cambios:  systemctl --user restart caelestia-shell.service"
else
  c_warn "Para ver los cambios reinicia la shell de Caelestia."
fi
c_warn "Y recuerda: vuelve a ejecutar este script despues de cada"
c_warn "actualizacion de caelestia-shell (los QML parcheados se regeneran)."

# ------------------------------------------------------- 7. Comprobacion
fallos=0
check() {
  if eval "$2" >/dev/null 2>&1; then
    printf '    \033[1;32m[ok]\033[0m   %s\n' "$1"
  else
    printf '    \033[1;31m[FALLA]\033[0m %s\n' "$1"
    fallos=$((fallos + 1))
  fi
}

echo
echo "------------------------------------------------------------------"
echo "  COMPROBACION"
echo "------------------------------------------------------------------"
check "shell.json en su sitio"        "[ -s '$CAE_DIR/shell.json' ]"
check "shell.json es JSON valido"     "python3 -c \"import json;json.load(open('$CAE_DIR/shell.json'))\""
check "cli.json es JSON valido"       "python3 -c \"import json;json.load(open('$CAE_DIR/cli.json'))\""
check "hypr-user.lua en su sitio"     "[ -s '$CAE_DIR/hypr-user.lua' ]"
check "hypr-vars.lua en su sitio"     "[ -s '$CAE_DIR/hypr-vars.lua' ]"
check "overlay montado"               "[ -d '$OVERLAY/modules' ]"
check "sin enlaces rotos en el overlay" "[ -z \"\$(find '$OVERLAY' -xtype l -print -quit)\" ]"
check "parche del launcher aplicado"  "grep -q launcherPressedAt '$OVERLAY/modules/Shortcuts.qml'"
check "popout de ethernet aplicado"   "grep -q '\"ethernet\"' '$OVERLAY/modules/bar/popouts/Content.qml'"

if command -v luac >/dev/null 2>&1; then
  check "hypr-user.lua parsea"        "luac -p '$CAE_DIR/hypr-user.lua'"
  check "hypr-vars.lua parsea"        "luac -p '$CAE_DIR/hypr-vars.lua'"
fi

echo "------------------------------------------------------------------"
if [ "$fallos" -eq 0 ]; then
  c_ok "Todo en orden."
else
  c_err "$fallos comprobacion(es) han fallado; mira las lineas [FALLA] de arriba."
  exit 1
fi
