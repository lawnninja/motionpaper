# Motionpaper

Hardware-accelerated dynamic video and image wallpaper manager for Noctalia v5 on Wayland, powered by GStreamer and the lightweight `gslapper` layer-shell daemon.

## Features

- **Hardware Acceleration**: High-performance video decoding via VA-API, NVDEC, or VDPAU through GStreamer.
- **Zero Black Flashes**: Pre-extracts and caches full-resolution still frames from video files, seamlessly holding the surface until decoding begins.
- **Independent Multi-Monitor Support**: Assign unique videos or static images to individual monitors, or synchronize across all outputs.
- **Smart Power Efficiency**: Optional auto-pause or auto-stop when windows or fullscreen surfaces obscure the desktop.
- **Timer Slideshow & Shuffle**: Automatic timed rotation across folder contents with shuffle support, preserving intervals across reboots.
- **Persistent State & Recovery**: Saved last-known wallpaper and slideshow intervals survive restarts and unexpected process termination.
- **Unified Controls**: One-click toggle stop / restore in both the UI panel and IPC interface.

## Comparison with Other Video Wallpaper Solutions

| Feature / Dimension | **Motionpaper** (This Plugin) | **mpvpaper** | **swww** | **hyprpaper** | **linux-wallpaperengine** |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Supported Media** | **MP4 / WebM / MKV Video + Still Images** | Video only | Static Images & Animated GIFs | Static Images only | Scene, Web & Video Wallpapers |
| **Backend Engine** | **`gSlapper`** (C / GStreamer layer-shell) | `mpv` library / player wrapper | `swww` Wayland daemon | Native Hyprland daemon | Steam Wallpaper Engine runtime |
| **Hardware Decoding** | **VA-API / NVDEC / VDPAU** via GStreamer | VA-API via mpv | N/A (software GIF decoding) | N/A | OpenGL / Vulkan GPU shaders |
| **Black Frame Prevention** | **Zero black-flash**: Pre-extracts still frame before video start | Black flash on wallpaper load/switch | N/A (instant image flip) | N/A | Long initial compilation delay |
| **Multi-Monitor Setup** | **Independent per-output**: Mix video on one display and image on another | Per-output video | Per-output image | Per-output image | Per-output scene |
| **Power & Battery Efficiency** | **Smart auto-pause / auto-stop**: Suspends rendering when windows cover the monitor | None (runs continuously unless externally scripted) | Low idle draw (static images only) | Very low (static) | High GPU/battery draw |
| **Integrated Slideshow** | **Built-in timer rotation with shuffle** (preserves interval across restarts) | Requires external bash loop | Built-in timed rotation | External script required | Built-in playlist |
| **State Persistence & Recovery** | **Automatic state persistence**: Restores wallpapers & slideshows after restart/crash with unified toggle | None (stateless process) | In-memory cache only | Config file only | Stored in application profile |
| **Native Noctalia Integration** | **Rich UI Panel**: Visual thumbnail grid, search, directory browser, status badges, unified toggle | Basic / External | CLI only | CLI only | Separate GUI / Tray |
| **Scriptability & IPC** | **Rich IPC API** (`toggle-stop`, `toggle`, `pause`, `resume`, `next`, `slideshow`) | Named pipe / UNIX socket | UNIX socket CLI | Socket IPC | Command line arguments |

## Installation

Install dependencies (`gslapper`, `gst-launch-1.0`, `find`, `socat`, `pkill`) and enable the plugin:

```sh
noctalia msg plugins enable lawnninja/motionpaper
```

## Credits & Acknowledgements

Motionpaper is built upon and inspired by the original **gSlapper** wallpaper plugin created by **[Nomadcxx](https://github.com/Nomadcxx)** ([gSlapper](https://github.com/Nomadcxx/gSlapper) / [noctalia-gslapper](https://github.com/Nomadcxx/noctalia-gslapper)).

We extend special thanks and full credit to **Nomadcxx** for creating the lightweight C/GStreamer Wayland layer-shell daemon and the initial integration architecture that made this project possible.
