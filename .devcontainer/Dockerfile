FROM python:3.15-slim

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && apt-get install --yes --no-install-recommends \
        bash \
        ca-certificates \
        curl \
        git \
        gnupg \
    && curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
    && apt-get update \
    && apt-get install --yes --no-install-recommends nodejs \
    && curl -fsSL https://gh.io/copilot-install | bash \
    && groupadd --gid 1000 vscode \
    && useradd --uid 1000 --gid vscode --create-home --shell /bin/bash vscode \
    && rm -rf /var/lib/apt/lists/*

USER vscode
WORKDIR /workspace
