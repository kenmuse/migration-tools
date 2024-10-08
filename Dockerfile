# syntax=docker/dockerfile:1.9.0
FROM ubuntu:latest

ARG GIT_FILTER_VERSION=2.45.0
ARG PWSH_VERSION=7.4.5
ARG JAVA_VERSION=21-tem
ARG NVM_VERSION=0.39.3
ARG NODE_VERSION=22
ARG BFG_VERSION=1.14.0

# Native packages
RUN export DEBIAN_FRONTEND=noninteractive \
  && apt update \
  && apt-get upgrade -y -qq \
  && apt-get install -y -qq apt-transport-https ca-certificates tar zip unzip jq curl git git-lfs yq python3 xz-utils coreutils wget software-properties-common dotnet-sdk-8.0 \
  && apt clean \
  && rm -rf /var/lib/apt/lists/*

# Language runtime managers (Java SDKMan, Node NVM) and versions
RUN curl -s "https://get.sdkman.io" | bash \
  && curl -s https://raw.githubusercontent.com/nvm-sh/nvm/v${NVM_VERSION}/install.sh | bash \
  && bash -c "source /root/.sdkman/bin/sdkman-init.sh && sdk install java ${JAVA_VERSION}" \
  && bash -c "export NVM_DIR=~/.nvm && source ~/.nvm/nvm.sh && nvm install v${NODE_VERSION} && npm install -g npm@latest" \
  && dotnet tool install --global PowerShell \
  && echo 'export PATH="$PATH:/root/.dotnet/tools"' >> ~/.bash_profile

# BFG Jar
RUN mkdir /usr/local/bin/bfg-app \
    && curl -sSLo /usr/local/bin/bfg.jar https://repo1.maven.org/maven2/com/madgag/bfg/${BFG_VERSION}/bfg-${BFG_VERSION}.jar \
    && echo '#!/bin/bash' > /usr/local/bin/bfg \
    && echo 'java -jar /usr/local/bin/bfg.jar "$@"' >> /usr/local/bin/bfg \
    && chmod +x  /usr/local/bin/bfg

# Git-filter-repo
RUN cd /tmp \
    && curl -sLo git-filter-repo-${GIT_FILTER_VERSION}.tar.xz https://github.com/newren/git-filter-repo/releases/download/v${GIT_FILTER_VERSION}/git-filter-repo-${GIT_FILTER_VERSION}.tar.xz \
    && tar -xf git-filter-repo-${GIT_FILTER_VERSION}.tar.xz \
    && install git-filter-repo-${GIT_FILTER_VERSION}/git-filter-repo /usr/local/bin/
    
# GH CLI
RUN export DEBIAN_FRONTEND=noninteractive \
    && mkdir -p -m 755 /etc/apt/keyrings \
  && wget -qO- https://cli.github.com/packages/githubcli-archive-keyring.gpg | tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null \
  && chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg \
  && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
  && apt update \
  && apt-get install -y -qq gh \
    && apt clean \
    && rm -rf /var/lib/apt/lists/*

# GH extensions
# Have to install manually because the `gh extension install` command requires authentication
# Manually compiling the gh-migration-audit so it's available on ARM64 and AM64 platforms
RUN mkdir -p ~/.local/share/gh/extensions \
    && cd ~/.local/share/gh/extensions \
    && git clone https://github.com/mona-actions/gh-repo-stats \
    && PROCESSOR_ARCHITECTURE=$(uname -m) \ 
    && if [ "${PROCESSOR_ARCHITECTURE}" = "arm64" ] || [ "${PROCESSOR_ARCHITECTURE}" = "aarch64" ]; then\
        export PLATFORM=arm64\
        && git clone https://github.com/timrogers/gh-migration-audit \
        && cd gh-migration-audit \
        && bash -c "export NVM_DIR=~/.nvm && source ~/.nvm/nvm.sh && nvm install v18 && npm install && node build.js && npx pkg dist/migration-audit.cjs --out-path bin --targets node20-linux-${PLATFORM}" \
        && cp bin/migration-audit ./gh-migration-audit;\
      else \
        export PLATFORM=x64 \
        && mkdir gh-gei \
        && curl -SLo gh-gei/gh-gei https://github.com/github/gh-gei/releases/download/latest/gei-linux-amd64 && chmod +x gh-gei/gh-gei \
        && mkdir gh-ado2gh \
        && curl -SLo gh-ado2gh/gh-ado2gh https://github.com/github/gh-ado2gh/releases/download/latest/ado2gh-linux-amd64 && chmod +x gh-ado2gh/gh-ado2gh \
        && mkdir gh-bbs2gh \
        && curl -SLo gh-bbs2gh/gh-bbs2gh https://github.com/github/gh-bbs2gh/releases/download/latest/bbs2gh-linux-amd64 && chmod +x gh-bbs2gh/gh-bbs2gh \
        && mkdir gh-migration-audit \
        && curl -sLo gh-migration-audit/gh-migration-audit https://github.com/timrogers/gh-migration-audit/releases/download/latest/gh-migration-audit-linux-amd64 && chmod +x gh-migration-audit/gh-migration-audit; \
      fi
