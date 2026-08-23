# Beszel Token Refresh

Fetches a fresh Beszel API token and injects it into Glance's `.env.beszel-token` so the dashboard can display server metrics.

## How it works

1. Authenticates against the Beszel API with user credentials
2. Extracts the token from the JSON response
3. Writes `BESZEL_TOKEN=<token>` to `tool/glance/.env.beszel-token`
4. Restarts the Glance container to pick up the new env var

## Systemd

- `systemd/beszel-token-refresh.service` — oneshot, runs `refresh.sh`
- `systemd/beszel-token-refresh.timer` — triggers every Monday at 02:00, `Persistent=true`
