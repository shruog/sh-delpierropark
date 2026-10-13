<img width="517" height="291" alt="image" src="https://github.com/user-attachments/assets/d7ee43f9-fd15-4213-9b83-552d894d14c0" />

## by shruog my Discord: [Join Discord](https://discord.gg/HaMdEPhDrG)

### [original author github](https://github.com/Bluscream/LunaPark-FiveM)

[🇺🇸 English](#-english) | [🇧🇷 Português](#-português) | [🇪🇸 Español](#-español)

![Demo Logo](upload://9LbIiNZXVD2GhRgPxHwlsLTOsgO.jpeg)

**Demonstration video:** [https://streamable.com/f8io04](https://streamable.com/f8io04)

| Feature | Info |
|-------------|------------|
| Code is accessible | Yes |
| Subscription-based | No |
| Lines (approximately)| ~1,500 |
| Requirements | None |
| Support | Yes |

---
## 🇺🇸 English

> ⚠️ **Note:** This is not a plug-and-play script. It needs some fixes but has open code in Lua.

A FiveM resource that adds realistic and synchronized functionality to the Ferris Wheel and Roller Coaster at Del Perro Pier.

### This script was converted to Lua OOP by me
I implemented some functions to improve performance. When there are no players near the Ferris wheels or roller coasters, the script puts the thread to "sleep". It still needs more testing and improvements.

### 🌟 Key Features
- **Fully Functional Roller Coaster:** Smooth cart movement, waiting times, and multi-seat support.
- **Accurate Ferris Wheel:** Cabins rotate simultaneously, respecting boarding and unboarding.
- **"Host-Based" (Server Authoritative) Synchronization:** To prevent desync issues, the active player with the lowest *server-id* acts as the physics *host*. The server flawlessly relays physics events to all other clients.
- **Object-Oriented Lua:** Source code structured in classes for better modularity, easy to iterate and expand.
- **Total Immersion:** Utilizes native audio sets (`AudioScenes` / `SoundSets`), custom camera transitions, and native animations.

### 🐛 Known Issues
- Players need to be attached to the Ferris wheel cabin and rollercoaster car.
- Needs more tests, but it has sync; it only needs players to be attached to the object positions.
- I tried improving performance by putting it in sleep mode, but I created a simple bug regarding instructional buttons (I prefer to use instructional buttons with a very simple NUI).

### 📋 How to Install
## `Goto [bob74_ipl]\gtav\base.lua at the bottom: and put -- on line 99 "RequestIpl("ferris_finale_anim")" so it looks like "--RequestIpl("ferris_finale_anim")"`

1. Download the script and place the `sh-delpierropark` folder inside your server's `resources` directory (or a subfolder).
2. Add `ensure sh-delpierropark` to your `server.cfg`.
3. Restart your server or start it via the admin console.

### ⚙️ Configuration
The entire script is configurable via the `shared/config.lua` file. You can adjust:
- Speed and wait times
- Interaction radius (proximity to enter the rides)
- Map Blips (Names, Sprites)
- Boarding and exit positions
- Cameras and prop model IDs

### 📌 Support & Links

**My Discord:** [Shruog Corphate Store](https://discord.gg/ydwuSA9Dwn)  
*Maybe I can help you with something more about this script...*

- **Download Here (Repository):** [shruog/sh-delpierropark](https://github.com/shruog/sh-delpierropark)
- **Original Author Repository:** [Bluscream/LunaPark-FiveM](https://github.com/Bluscream/LunaPark-FiveM)
