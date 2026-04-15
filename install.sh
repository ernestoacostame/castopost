#!/usr/bin/env bash
# ============================================================
#  CastoPOST — Instalador para Linux
#  Uso: bash install.sh
# ============================================================
set -euo pipefail

APP_NAME="CastoPOST"
REPO_URL="https://github.com/ernestoacostame/castopost"
BINARY="castopost-bin"
INSTALL_BIN="/usr/local/bin/castopost"
DESKTOP_DIR="${HOME}/.local/share/applications"
ICON_DIR="${HOME}/.local/share/icons/hicolor/scalable/apps"
ICON_NAME="castopost.svg"

# ── Colores ───────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

info()    { echo -e "${CYAN}▸ $*${RESET}"; }
success() { echo -e "${GREEN}✓ $*${RESET}"; }
warn()    { echo -e "${YELLOW}⚠ $*${RESET}"; }
error()   { echo -e "${RED}✕ $*${RESET}"; exit 1; }
header()  { echo -e "\n${BOLD}$*${RESET}\n"; }

# ── Limpieza de Caché (NUEVO) ─────────────────────────────
header "0/4  Limpiando entorno"
BUILD_DIR_CACHE="${HOME}/.cache/castopost-build"

if [ -d "$BUILD_DIR_CACHE" ]; then
    info "Eliminando caché antigua en $BUILD_DIR_CACHE..."
    rm -rf "$BUILD_DIR_CACHE"
fi
success "Entorno limpio"

# ── Banner ────────────────────────────────────────────────
echo -e "${CYAN}"
cat << 'BANNER'
  ____          _        ____   ___  ____ _____
 / ___|__ _ ___| |_ ___ |  _ \ / _ \/ ___|_   _|
| |   / _` / __| __/ _ \| |_) | | | \___ \ | |
| |__| (_| \__ \ || (_) |  __/| |_| |___) || |
 \____\__,_|___/\__\___/|_|    \___/|____/ |_|
BANNER
echo -e "${RESET}"
echo -e "${BOLD}Instalador para Linux${RESET}"
echo "────────────────────────────────────────"

# ── Detectar distro ───────────────────────────────────────
detect_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        echo "${ID_LIKE:-$ID}"
    else
        echo "unknown"
    fi
}

DISTRO=$(detect_distro)

# ── Comprobar dependencias ────────────────────────────────
header "1/4  Comprobando dependencias"

check_cmd() {
    command -v "$1" &>/dev/null
}

need_qt=false
need_ffmpeg=false
need_build=false

check_cmd ffmpeg   || need_ffmpeg=true
check_cmd cmake    || need_build=true
check_cmd ninja    || need_build=true
check_cmd g++      || need_build=true

# Comprobar Qt6 (buscamos qmake6 o qmake de Qt6)
if ! pkg-config --exists Qt6Core 2>/dev/null && \
   ! check_cmd qmake6 && \
   ! [ -f /usr/lib/cmake/Qt6/Qt6Config.cmake ] && \
   ! [ -f /usr/lib/x86_64-linux-gnu/cmake/Qt6/Qt6Config.cmake ]; then
    need_qt=true
fi

if $need_qt || $need_ffmpeg || $need_build; then
    warn "Faltan dependencias. Intentando instalar automáticamente..."

    if [[ "$DISTRO" == *"debian"* ]] || [[ "$DISTRO" == *"ubuntu"* ]] || check_cmd apt-get; then
        info "Detectado: Ubuntu / Debian / Mint"
        sudo apt-get update -qq
        $need_build   && sudo apt-get install -y cmake ninja-build g++
        $need_ffmpeg  && sudo apt-get install -y ffmpeg
        $need_qt      && sudo apt-get install -y \
            qt6-base-dev qt6-declarative-dev qt6-multimedia-dev \
            libqt6quick6 libqt6quickcontrols2-6 libqt6widgets6 \
            qml6-module-qtquick-controls qml6-module-qtquick-layouts \
            qml6-module-qtmultimedia || \
            warn "No se pudieron instalar todos los módulos Qt6 del repositorio."

    elif [[ "$DISTRO" == *"arch"* ]] || check_cmd pacman; then
        info "Detectado: Arch / Manjaro"
        sudo pacman -Sy --needed --noconfirm cmake ninja gcc \
            qt6-base qt6-declarative qt6-multimedia ffmpeg

    elif [[ "$DISTRO" == *"fedora"* ]] || check_cmd dnf; then
        info "Detectado: Fedora"
        sudo dnf install -y cmake ninja-build gcc-c++ \
            qt6-qtbase-devel qt6-qtdeclarative-devel \
            qt6-qtmultimedia-devel ffmpeg

    elif [[ "$DISTRO" == *"opensuse"* ]] || check_cmd zypper; then
        info "Detectado: openSUSE"
        sudo zypper install -y cmake ninja gcc-c++ \
            qt6-base-devel qt6-quick-devel qt6-multimedia-devel ffmpeg

    else
        error "Distribución no reconocida. Instala manualmente: cmake, ninja, g++, Qt 6.5+, ffmpeg"
    fi
fi

success "Dependencias listas"

# ── Descargar / actualizar código ─────────────────────────
header "2/4  Obteniendo el código fuente"

# Lógica inteligente: ¿Estamos ya en la carpeta del proyecto?
if [ -f "CMakeLists.txt" ] && grep -q "CastoPOST" "CMakeLists.txt"; then
    BUILD_DIR="$(pwd)"
    info "Se ha detectado el código local. Usando: $BUILD_DIR"
else
    BUILD_DIR="$BUILD_DIR_CACHE"
    info "No se detectó código local. Clonando de GitHub..."
    git clone --depth=1 "$REPO_URL" "$BUILD_DIR"
fi


success "Código listo en $BUILD_DIR"

# ── Compilar ──────────────────────────────────────────────
header "3/4  Compilando"

cd "$BUILD_DIR"
rm -rf build
cmake -B build -G Ninja \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=/usr/local \
    -Wno-dev

CPU_CORES=$(nproc 2>/dev/null || echo 4)
info "Usando $CPU_CORES núcleos..."
cmake --build build --parallel "$CPU_CORES"

success "Compilación completada"

# ── Instalar ──────────────────────────────────────────────
header "4/4  Instalando"

# Binario
info "Instalando binario en $INSTALL_BIN..."
sudo cmake --install build

# El binario se llama castopost-bin — crear enlace simbólico más limpio
if [ -f /usr/local/bin/castopost-bin ] && [ ! -f /usr/local/bin/castopost ]; then
    sudo ln -s /usr/local/bin/castopost-bin /usr/local/bin/castopost
fi

# Icono
info "Instalando icono..."
mkdir -p "$ICON_DIR"
cp "$BUILD_DIR/resources/icons/$ICON_NAME" "$ICON_DIR/"

# Entrada .desktop
info "Creando entrada en el menú de aplicaciones..."
mkdir -p "$DESKTOP_DIR"
cat > "$DESKTOP_DIR/castopost.desktop" << DESKTOP
[Desktop Entry]
Version=1.0
Type=Application
Name=CastoPOST
GenericName=Publicador de podcasts
Comment=Publica episodios en Castopod desde tu escritorio Linux
Exec=/usr/local/bin/castopost-bin
Icon=$ICON_DIR/castopost.svg
Categories=AudioVideo;Audio;Network;
Keywords=podcast;castopod;audio;publicar;
StartupNotify=true
StartupWMClass=CastoPOST
DESKTOP

# Actualizar caché de iconos y menú
update-desktop-database "$DESKTOP_DIR" 2>/dev/null || true
gtk-update-icon-cache -f -t "$ICON_DIR/../.." 2>/dev/null || true

success "¡Instalación completada!"
echo ""
echo -e "${BOLD}Puedes iniciar CastoPOST:${RESET}"
echo -e "  • Desde el menú de aplicaciones: busca ${CYAN}CastoPOST${RESET}"
echo -e "  • Desde el terminal: ${CYAN}castopost-bin${RESET}"
echo ""
