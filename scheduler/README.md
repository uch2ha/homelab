# Scheduler

Systemd-timer-driven scripts for periodic homelab tasks.

|                         |                    |                                                                        |
| ----------------------- | ------------------ | ---------------------------------------------------------------------- |
| `beszel-token-refresh/` | Weekly (Mon 02:00) | Refresh Beszel API token for Glance dashboard                          |
| `image-update-check/`   | Daily              | Check if running container images have newer versions, notify via ntfy |
