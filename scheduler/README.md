# Scheduler

Systemd-timer-driven scripts for periodic homelab tasks.

<table>
  <tr>
    <td><code>beszel-token-refresh/</code></td>
    <td>Weekly (Mon 02:00)</td>
    <td>Refresh Beszel API token for Glance dashboard</td>
  </tr>
  <tr>
    <td><code>image-update-check/</code></td>
    <td>Daily</td>
    <td>Check if running container images have newer versions, notify via ntfy</td>
  </tr>
</table>
