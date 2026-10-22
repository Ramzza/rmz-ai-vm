FROM python:3.15-slim

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && apt-get install --yes --no-install-recommends \
        bash \
        ca-certificates \
        curl \
        dbus \
        git \
        gnome-keyring \
        gnupg \
        libsecret-1-0 \
    && curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
    && apt-get update \
    && apt-get install --yes --no-install-recommends nodejs \
    && curl -fsSL https://gh.io/copilot-install | bash \
    && groupadd --gid 1000 vscode \
    && useradd --uid 1000 --gid vscode --create-home --shell /bin/bash vscode \
    && install -d -o vscode -g vscode -m 0700 /home/vscode/.local/share/keyrings \
    && rm -rf /var/lib/apt/lists/*

COPY .devcontainer/keyring-entrypoint.sh /usr/local/bin/keyring-entrypoint
RUN chmod 0755 /usr/local/bin/keyring-entrypoint

ENTRYPOINT ["/usr/local/bin/keyring-entrypoint"]

USER vscode
WORKDIR /workspace
