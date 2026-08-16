# CI environment for the homelab repo.
# Contains the lint/validation tools used by .github/workflows/ci.yaml.
# Build: docker build -t homelab-ci script/ci
# Run:   docker run --rm -v "$PWD:/repo" homelab-ci <command>

FROM python:3.12-slim

ARG GITLEAKS_VERSION=v8.30.1

# docker CLI + compose plugin (offline `docker compose config` needs no daemon)
# from Docker's apt repo; shellcheck + git from Debian.
RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates \
      curl \
      git \
      gnupg \
      shellcheck \
    && install -m 0755 -d /etc/apt/keyrings \
    && curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc \
    && chmod a+r /etc/apt/keyrings/docker.asc \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian bookworm stable" \
       > /etc/apt/sources.list.d/docker.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends docker-ce-cli docker-compose-plugin \
    && rm -rf /var/lib/apt/lists/*

# python linters
RUN pip install --no-cache-dir ruff pyyaml

# gitleaks secret scanner
RUN case "$(dpkg --print-architecture)" in \
      amd64) GL_ARCH=x64 ;; \
      arm64) GL_ARCH=arm64 ;; \
      *) echo "unsupported arch: $(dpkg --print-architecture)" >&2; exit 1 ;; \
    esac \
    && curl -fsSL "https://github.com/gitleaks/gitleaks/releases/download/${GITLEAKS_VERSION}/gitleaks_${GITLEAKS_VERSION#v}_linux_${GL_ARCH}.tar.gz" \
       -o /tmp/gitleaks.tar.gz \
    && tar -xzf /tmp/gitleaks.tar.gz -C /usr/local/bin gitleaks \
    && chmod +x /usr/local/bin/gitleaks \
    && rm /tmp/gitleaks.tar.gz

WORKDIR /repo