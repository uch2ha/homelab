# homelab

Personal homelab running on a single server. All services are Docker containers.

## Sections

- [Architecture](#architecture)
- [Services](#services)
- [Dashboard](#dashboard)
- [Roadmap](#roadmap)
- [Scripts](#scripts)

## Network <or something> Architecture

Two access paths:

- **External**: device → NetBird VPN → home network → NPM → services
- **Local**: device → Pi-hole DNS → home network → NPM → services

![Network Architecture](assets/screenshots/homelab-overview.png)

## Services

| Infrastructure       |                      |
| -------------------- | -------------------- |
| Backup management    | ZeroByte             |
| Container management | Dockhand / Portainer |

| Media                    |        |
| ------------------------ | ------ |
| Document management      | Papra  |
| Photo / video management | Immich |

| Monitoring        |             |
| ----------------- | ----------- |
| Server monitoring | Beszel      |
| Service uptime    | Uptime Kuma |

| Networking              |                     |
| ----------------------- | ------------------- |
| Local DNS (ad-blocking) | Pi-hole             |
| Mesh VPN                | Netbird             |
| Reverse proxy + SSL     | Nginx Proxy Manager |

| Security         |             |
| ---------------- | ----------- |
| Password manager | Vaultwarden |

| Tool     |        |
| -------- | ------ |
| Homepage | Glance |

## Homepage

![Glance Homepage](assets/screenshots/homepage.png)

## Roadmap

#### Service

- [ ] Add notification service
- [ ] DDNS setup

#### Infrastructure

- [ ] Try containered OS (core-os)
- [ ] Try podman setup instead of docker

##### Other <rename me>

- [ ] `config.yaml` for service orchestration (which services to start/stop)
- [ ] Add run/stop/down scripts
