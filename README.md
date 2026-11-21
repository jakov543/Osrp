<p align="center"><img src="branding/logo.png" width="520" alt="OSRP"></p>

# OSRP Launcher — V1

A free launcher for **OSRP (Osijek Roleplay)**, a GTA V server (it runs on FiveM).
It uses the player's **own installed GTA V** (`GTA5.exe`). Players have to own a legal copy of the game.

> **Version:** 1.0.0 (V1). Stays at V1 until V2 is approved.

## What V1 does

- **Its own startup loading window** (OSRP logo + real checks: settings, finding GTA V, server status)
- **OSRP logo** everywhere: app icon, installer, title bar, sidebar, in-game loading screen
- **Google login**: players sign in with their Google account (name + picture in the launcher)
- **Ownership check**: the player has to confirm they own GTA V before going further
- **Store links** for players without the game: Steam, Epic Games, Rockstar
- **Finds GTA V automatically** (registry, Steam libraries, common folders), or the player can pick `GTA5.exe` by hand
- Checks that the file really is `GTA5.exe` / `GTA5_Enhanced.exe`
- **PLAY** installs the multiplayer client by itself (one time, after the player accepts the Cfx.re license) and connects straight to OSRP. Players never have to visit fivem.net
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
git remote add origin https://github.com/jakov543/Osrp.git
git push -u origin main
git tag v1.0.0
git push origin v1.0.0
```
GitHub Actions builds the Windows installer and puts it on the **Releases** page.

## Google login setup (free, about 5 minutes)
1. Go to **console.cloud.google.com** and create a project named `OSRP`.
2. *APIs & Services → OAuth consent screen* → **External** → app name `OSRP Launcher`, your email → Save. Then click **Publish app** so every player can sign in.
3. *APIs & Services → Credentials → Create credentials → OAuth client ID* → type **Desktop app** → Create.
4. Copy the **Client ID** and **Client secret** into `launcher/config.json`:
```json
"google": { "clientId": "xxxx.apps.googleusercontent.com", "clientSecret": "GOCSPX-xxxx" }
```
5. Push to GitHub and the installer rebuilds with Google login turned on.

Until a Client ID is set, the launcher shows a "Continue as guest" button so nothing breaks.

## Osijek map in Blender
Starter city script and full guide: [`map/BLENDER-MAP.md`](map/BLENDER-MAP.md)

![Osijek starter map](map/blender/preview.png)

## Requirements for players
- Windows 10/11
- A legal copy of GTA V (Steam / Epic / Rockstar)
- Nothing else: the launcher installs the multiplayer client by itself

## Osijek map
`osrp_core` renames the map to **Osijek** (server list, pause menu, map labels).
To build actual Osijek streets and buildings, put `.ymap/.ydr/.ytd` files in `osrp_core/stream/`.
Free tools for that: **CodeWalker** and **Blender + Sollumz**.

## Legal
This project is not affiliated with Rockstar Games or Take-Two. GTA V is not included. Every player must buy the game.
