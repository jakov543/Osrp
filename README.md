<p align="center"><img src="branding/logo.png" width="520" alt="OSRP"></p>

# OSRP Launcher — V1

A free launcher for **OSRP (Osijek Roleplay)**, a GTA V server (it runs on FiveM).
It uses the player's **own installed GTA V** (`GTA5.exe`). Players have to own a legal copy of the game.

> **Version:** 1.0.0 (V1). Stays at V1 until V2 is approved.

## What V1 does

- **Its own startup loading window** (OSRP logo + real checks: settings, finding GTA V, server status)
- **OSRP logo** everywhere: app icon, installer, title bar, sidebar, in-game loading screen
- **Ownership check**: the player has to confirm they own GTA V before going further
- **Store links** for players without the game: Steam, Epic Games, Rockstar
- **Finds GTA V automatically** (registry, Steam libraries, common folders), or the player can pick `GTA5.exe` by hand
- Checks that the file really is `GTA5.exe` / `GTA5_Enhanced.exe`
- **PLAY** connects to the OSRP server through FiveM (`fivem://connect/...`)
- **Singleplayer** starts GTA V through Steam, Epic or the Rockstar Launcher
- Shows whether the server is online and how many players are on
- News cards and a Discord link (set in `launcher/config.json`)

## Folders

```
launcher/              Electron app (Windows)
  config.json          server IP, Discord, news  <- edit this
  main.js              game detection + launching
  renderer/            UI (HTML/CSS/JS)
fivem-resources/
  osrp_core/           map name "Osijek", OSRP pause menu, keeps the GTA V HUD, stream/ for your map
  osrp_loading/        in-game loading screen with the OSRP logo
branding/              OSRP logo (svg + png)
.github/workflows/     builds the .exe automatically on GitHub
```

## Setup

### 1. Server
Copy `fivem-resources/osrp_core` and `osrp_loading` into your server's `resources/` folder and add to `server.cfg`:
```
ensure osrp_loading
ensure osrp_core
sets mapname "Osijek"
```

### 2. Launcher
Set your server IP in `launcher/config.json`:
```json
"serverAddress": "YOUR.IP:30120"
```

Run it locally:
```
cd launcher
npm install
npm start
```

Build the installer (.exe):
```
npm run dist
```
The installer ends up in `launcher/dist/`.

### 3. GitHub (free)
```
git remote add origin https://github.com/jakov543/OSRP-Launcher.git
git push -u origin main
git tag v1.0.0
git push origin v1.0.0
```
GitHub Actions builds the Windows installer and puts it on the **Releases** page.

## Requirements for players
- Windows 10/11
- A legal copy of GTA V (Steam / Epic / Rockstar)
- [FiveM](https://fivem.net) installed

## Osijek map
`osrp_core` renames the map to **Osijek** (server list, pause menu, map labels).
To build actual Osijek streets and buildings, put `.ymap/.ydr/.ytd` files in `osrp_core/stream/`.
Free tools for that: **CodeWalker** and **Blender + Sollumz**.

## Legal
This project is not affiliated with Rockstar Games or Take-Two. GTA V is not included. Every player must buy the game.
