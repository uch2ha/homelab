# start-config.yaml

Controls which services `start-services.sh` runs. `stop-services.sh` and `down-services.sh` ignore config and act on all found compose files.

### Structure

```yaml
action: "up --pull never -d" # docker compose command + args

base: # always-on services (no group controls these)
  - infrastructure/zerobyte # exact dir path
  - media/* # all dirs under media/ (one level)

groups: # toggle subsets of services
  <name>:
    path: <category> # dir under repo root
    value: <preset-name> # which preset to use
    presets:
      <name>: [<dir>, ...] # list of service subdirs within path
```

## Usage

```bash
./script/container/start-services.sh      # runs base + selected group presets
./script/container/stop-services.sh       # stops ALL discovered services
./script/container/down-services.sh       # brings down ALL discovered services
```

## Base rules

| Pattern                      | Behavior                                                                                                 |
| ---------------------------- | -------------------------------------------------------------------------------------------------------- |
| `infrastructure/zerobyte`    | Runs `zerobyte` always. Errors if dir has no compose file.                                               |
| `media/*`                    | Runs every immediate subdir under `media/` that has a compose file (e.g. `media/immich`, `media/papra`). |
| `media/immich` and `media/*` | **Error** — wildcard already covers `media/`. Caught by validation.                                      |

## Group rules

- **`value: light`** → runs only services in the `light` preset
- **`value: all`** → runs all presets combined, deduped
- **`value: none`** or `value: null` or `value: ''` → skip this group entirely
- **`value: foo`** → **Error** — preset `foo` not found. Caught by validation.

```yaml
groups:
  monitoring:
    path: monitoring
    value: light
    presets:
      light: [beszel]
      high: [grafana, prometheus, loki]
```

## Base vs group overlap

A service cannot be in both `base` and a selected group preset. Both forms are caught:

```yaml
base:
  - media/* # covers media/immich
groups:
  photos:
    path: media
    value: instagram
    presets:
      instagram: [immich] # ERROR: media/immich is already in base via media/*
```
