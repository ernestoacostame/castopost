# CastoPOST

<p align="center">
  <img src="resources/icons/castopost.svg" width="80" alt="CastoPOST logo">
</p>

<p align="center">
  Panel nativo para Linux para publicar episodios en <a href="https://castopod.org">Castopod</a> vía su API REST.
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Qt-6.5+-41CD52?logo=qt" alt="Qt 6.5+">
  <img src="https://img.shields.io/badge/Linux-nativo-FCC624?logo=linux&logoColor=black" alt="Linux">
  <img src="https://img.shields.io/badge/C++-17-00599C?logo=cplusplus" alt="C++17">
  <img src="https://img.shields.io/badge/licencia-MIT-blue" alt="MIT">
</p>

---

## Características

- **Publicación de episodios** con metadatos completos: título, descripción (Markdown), número, temporada, tipo, portada
- **Grabadora de audio nativa** con VU-meter en tiempo real y reproductor para escuchar antes de publicar
- **Conversión a MP3** con normalización **EBU R128 a -16 LUFS** (2 pasadas, estándar Apple/Spotify) vía FFmpeg
- **Drag & drop** de archivos de audio
- **Borradores locales** — guarda el progreso incluyendo la ruta del audio
- **Plantillas de descripción** reutilizables
- **Multi-podcast** — gestiona varios podcasts desde una sola instancia
- **Número de episodio automático** — detecta el siguiente número global o por temporada
- **Temas** — oscuro y claro

## Capturas

![castopost_dash](https://github.com/user-attachments/assets/ca9843c0-1631-4a82-b7b7-a6a25e9ff044)
![castopost_dash2](https://github.com/user-attachments/assets/27a061ce-bf05-4c4d-b836-7c3b9da37e2e)


## Requisitos

| Dependencia | Versión mínima | Notas |
|---|---|---|
| Qt | 6.5 | Con módulos Quick, Multimedia, QuickControls2 |
| CMake | 3.21 | |
| GCC / Clang | C++17 | |
| FFmpeg | cualquiera | Con `libmp3lame`. `sudo apt install ffmpeg` |

## Instalación rápida

```bash
curl -fsSL https://raw.githubusercontent.com/ernestoacostame/castopost/main/install.sh | bash
```

O descarga el instalador manualmente:

```bash
wget https://raw.githubusercontent.com/ernestoacostame/castopost/main/install.sh
chmod +x install.sh
./install.sh
```

## Compilar desde el código fuente

### Ubuntu / Debian / Linux Mint

```bash
# Dependencias
sudo apt install cmake ninja-build g++ \
  qt6-base-dev qt6-declarative-dev qt6-multimedia-dev \
  libqt6quick6 libqt6quickcontrols2-6 libqt6widgets6 \
  ffmpeg

# Clonar y compilar
git clone https://github.com/ernestoacostame/castopost.git
cd castopost
cmake -B build -G Ninja -DCMAKE_BUILD_TYPE=Release -Wno-dev
cmake --build build --parallel
sudo cmake --install build
```

### Arch Linux / Manjaro

```bash
sudo pacman -S cmake ninja qt6-base qt6-declarative qt6-multimedia ffmpeg
git clone https://github.com/ernestoacostame/castopost.git
cd castopost
cmake -B build -G Ninja -DCMAKE_BUILD_TYPE=Release -Wno-dev
cmake --build build --parallel
sudo cmake --install build
```

### Fedora

```bash
sudo dnf install cmake ninja-build gcc-c++ \
  qt6-qtbase-devel qt6-qtdeclarative-devel qt6-qtmultimedia-devel ffmpeg
git clone https://github.com/ernestoacostame/castopost.git
cd castopost
cmake -B build -G Ninja -DCMAKE_BUILD_TYPE=Release -Wno-dev
cmake --build build --parallel
sudo cmake --install build
```

## Configuración inicial

Al ejecutar por primera vez se abre la pantalla de **Ajustes**. Necesitas:

1. **URL** de tu instancia Castopod (ej: `https://podcasts.tudominio.com`)
2. **Usuario y contraseña API** — en el `.env` de Castopod como `restapi.basicAuth`
3. **Handle del podcast** — el slug de tu podcast en Castopod
4. **ID de usuario** — Admin → Usuarios → editar → número en la URL (Si solo tienes un usuario, normalmente es el 1)

## Datos y configuración

| Ruta | Contenido |
|---|---|
| `~/.config/castopost/castopost.conf` | Configuración (URL, credenciales, tema) |
| `~/.local/share/castopost/local_drafts.json` | Borradores locales |
| `~/.local/share/castopost/templates.json` | Plantillas de descripción |
| `~/.local/share/castopost/podcasts.json` | Lista de podcasts |

## Flujo de publicación

```
Audio (grabado / subido / URL)
         │
         ▼
FFmpeg: 2 pasadas EBU R128 → MP3 192k a -16 LUFS
         │
         ▼
POST /api/rest/v1/episodes/   →  crea borrador en Castopod
         │
         ▼
POST /api/rest/v1/episodes/{id}/publish  →  publica
```

## Licencia

MIT — consulta [LICENSE](LICENSE) para más detalles.
