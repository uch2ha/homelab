# Image Update Check

Checks running containers against registry tags and sends ntfy notifications when updates are available.

## How it works

1. Lists all running containers
2. For each container: pulls `:latest` (or falls back to the container's own tag, e.g. `:v3`)
3. Compares the pulled image ID against the running container's image ID
4. If different: sends an ntfy notification
5. Clean up: reverts the tag and removes pulled image — all image updates happen manually
6. Two ntfy topics — `critical` (always notify) and `info` (once per version, tracked in `temp/state.txt`)

## Env Config

<table>
  <tr>
    <td><code>CMD</code></td>
    <td><code>docker</code> or <code>podman</code></td>
  </tr>
  <tr>
    <td><code>SERVER_NAME</code></td>
    <td>Identifies notifications per machine</td>
  </tr>
  <tr>
    <td><code>NTFY_*</code></td>
    <td>Base URL, topics, and priority levels</td>
  </tr>
  <tr>
    <td><code>CRITICAL_CONTAINERS</code></td>
    <td>Comma-separated container names that always notify</td>
  </tr>
</table>

## Systemd

- `systemd/image-update-check.service` — oneshot, runs `check-updates.sh`
- `systemd/image-update-check.timer` — triggers daily, `Persistent=true`
