FROM mcr.microsoft.com/devcontainers/base:noble

# Activate Mise in ZSH and Bash
RUN printf 'eval "$(mise activate zsh)"\n' >> /etc/zsh/zshrc && \
  printf 'eval "$(mise activate bash)"\n' >> /etc/bash.bashrc

# Install deps
RUN apt-get update && apt-get install --no-install-recommends -y \
  libffi-dev \
  && rm -rf /var/lib/apt/lists/*

USER vscode

# Configure Poetry to use an in-project .venv so that the interpreter path does not change between containers
RUN mkdir -p /home/vscode/.config/pypoetry && \
  echo "[virtualenvs]" > /home/vscode/.config/pypoetry/config.toml && \
  echo "in-project = true" >> /home/vscode/.config/pypoetry/config.toml
