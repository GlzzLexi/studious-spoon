<div align="center">
  <img src="Company/logo.png" alt="GlzzLexi Logo" width="120" />

  # GlzzLexi

  ### studious-spoon
  A collection of reusable Luau tools, modules, and starter templates for rapid Roblox game development. Copy, paste, build.

  [![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
  [![Language](https://img.shields.io/badge/Language-Luau-00A2FF.svg)](https://luau.org/)
  [![Platform](https://img.shields.io/badge/Platform-Roblox%20Studio-black.svg)](https://create.roblox.com/)
</div>

---

## Overview

**studious-spoon** serves as an internal modular library developed under **GlzzLexi** to speed up Roblox prototyping and production systems. It contains battle-tested, plug-and-play Luau code designed for clean separation of concerns across client, server, and shared modules.

While built primarily for internal projects, this repository is open for public use and adaptation.

---

## Repository Structure

The repository mirrors a standard Roblox service architecture, split cleanly between shared libraries, server execution, and client logic:

```text
studious-spoon/
├── Company/
│   └── logo.png
├── Modules/                  # ReplicatedStorage / Shared Modules
│   ├── DataStore             # Session locking, profile wrappers, retry logic
│   ├── ScoringSystem/        # Leaderboards, score multipliers, combo logic
│   └── ...                   # Utility classes, math helpers, net wrappers
├── Server script/            # ServerScriptService
│   ├── DataStore             # Database listeners, autosave loops, session handlers
│   ├── ScoringSystem/        # Server-side authority, score validation, awards
│   └── ...
└── local script/             # StarterPlayerScripts / StarterGui
    ├── DataStore             # UI data bindings, loading screens, local state mirrors
    ├── ScoringSystem/        # HUD renderers, visual popups, animations
    └── ...
