FROM python:3.15-slim

# Android SDK versions; override with build args to match a project's compileSdk and build tools.
ARG ANDROID_CMDLINE_TOOLS_BUILD=16111833
ARG ANDROID_CMDLINE_TOOLS_SHA1=e025545c62a8e64c7559119566a569fb1dec5f60
ARG ANDROID_PLATFORM=android-37.0
ARG ANDROID_BUILD_TOOLS=37.0.0

ENV DEBIAN_FRONTEND=noninteractive
ENV JAVA_HOME=/usr/lib/jvm/java-25-openjdk
ENV ANDROID_HOME=/opt/android-sdk
ENV ANDROID_SDK_ROOT=/opt/android-sdk
ENV PATH="${JAVA_HOME}/bin:${ANDROID_HOME}/cmdline-tools/latest/bin:${ANDROID_HOME}/platform-tools:${PATH}"

RUN mkdir -p /usr/share/man/man1 \
    && apt-get update \
    && apt-get install --yes --no-install-recommends \
        bash \
        ca-certificates \
        curl \
        dbus \
        git \
        gnome-keyring \
        gnupg \
        jq \
        libsecret-1-0 \
        libsecret-tools \
        openjdk-25-jdk-headless \
        unzip \
        wget \
    && ln -s "/usr/lib/jvm/java-25-openjdk-$(dpkg --print-architecture)" /usr/lib/jvm/java-25-openjdk \
    && curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
    && apt-get update \
    && apt-get install --yes --no-install-recommends nodejs \
    && curl -fsSL https://gh.io/copilot-install | bash \
    && groupadd --gid 1000 vscode \
    && useradd --uid 1000 --gid vscode --create-home --shell /bin/bash vscode \
    && install -d -o vscode -g vscode -m 0755 /home/vscode/.local /home/vscode/.local/bin /home/vscode/.local/share \
    && install -d -o vscode -g vscode -m 0700 /home/vscode/.local/share/keyrings \
    && install -d -o vscode -g vscode -m 0700 /home/vscode/.claude \
    && install -d -o vscode -g vscode -m 0755 /opt/android-sdk \
    && rm -rf /var/lib/apt/lists/*

COPY .devcontainer/keyring-entrypoint.sh /usr/local/bin/keyring-entrypoint
RUN chmod 0755 /usr/local/bin/keyring-entrypoint

ENTRYPOINT ["/usr/local/bin/keyring-entrypoint"]

USER vscode
RUN curl -fsSL https://claude.ai/install.sh | bash
ENV PATH="/home/vscode/.local/bin:${PATH}"

# Installed as vscode so Gradle can add SDK components the project requests.
RUN curl -fsSL -o /tmp/cmdline-tools.zip "https://dl.google.com/android/repository/commandlinetools-linux-${ANDROID_CMDLINE_TOOLS_BUILD}_latest.zip" \
    && echo "${ANDROID_CMDLINE_TOOLS_SHA1}  /tmp/cmdline-tools.zip" | sha1sum --check --strict - \
    && unzip -q /tmp/cmdline-tools.zip -d /tmp/cmdline-tools \
    && mkdir -p "${ANDROID_HOME}/cmdline-tools" \
    && mv /tmp/cmdline-tools/cmdline-tools "${ANDROID_HOME}/cmdline-tools/latest" \
    && rm -rf /tmp/cmdline-tools /tmp/cmdline-tools.zip \
    && yes | sdkmanager --licenses >/dev/null \
    && sdkmanager --install platform-tools "platforms;${ANDROID_PLATFORM}" "build-tools;${ANDROID_BUILD_TOOLS}"

WORKDIR /workspace
