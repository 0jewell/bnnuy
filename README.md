# bnnuy

bnnuy (bãnni) is a CLI tool for managing roblox experience assets through configuration files

## Info
bnnuy provides a declarative YAML configuration for badges, game passes, and developer products. It also has state tracking to avoid duplicate uploads.

## Installation

- Rokit:
```sh
rokit add 0jewell/bnnuy
```

## Usage

### Configuration

Create a `bnnuy.yml` file in your project root:

```yaml
experience:
  id: 424242424

  badges:
    firstHop:
      name: First Hop
      description: Your very first bunny jump!
      icon: assets/badges/first-hop.png
      enabled: true

  passes:
    floppyEars:
      name: Floppy Ears
      description: Cosmetic ears.
      icon: assets/passes/floppy-ears.png
      price: 299

  products:
    carrotBundle:
      name: Carrot Bundle
      description: A small crate of fresh carrots.
      icon: assets/products/carrots-small.png
      price: 25
```

### Environment Setup

Create a `.env` file:

```env
ROBLOX_API_KEY=your-api-key-here
ROBLOX_COOKIE=your-cookie-here-optional
```

### Commands

Upload/sync all assets:

```sh
bnnuy upload
```

Upload with explicit API key:

```sh
bnnuy upload --api-key your-key-here
```

Import all existing assets from an experience:

```sh
bnnuy import 424242424 --api-key your-key-here
```

Import to a different manifest file:

```sh
bnnuy import 424242424 --output imported.yml --api-key your-key-here
```

Force overwrite current manifest/state with imported data:

```sh
bnnuy import 424242424 --force --api-key your-key-here
```

## Authentication

### API Key (for badges)
get from: [Roblox Creator Dashboard](https://create.roblox.com/dashboard/credentials)

### Cookie (for passes & products)
- auto-detected from Roblox Studio
- or set `ROBLOX_COOKIE` in `.env`

## Required API Scopes

| Resource            | Scopes                                                                 | Documentation |
|---------------------|------------------------------------------------------------------------|---------------|
| Game Passes         | `game-pass:read`, `game-pass:write`                                   | https://create.roblox.com/docs/cloud/api/game-passes |
| Developer Products  | `developer-product:read`, `developer-product:write`                   | https://create.roblox.com/docs/cloud/api/developer-products |
| Badges              | `legacy-universe.badge:read`, `legacy-universe.badge:write`, `legacy-universe.badge:manage-and-spend-robux` | https://create.roblox.com/docs/cloud/api/badges |
| Assets (Icons)      | `legacy-asset:manage`                                                  | https://create.roblox.com/docs/cloud/features/assets#/ |
