FROM mcr.microsoft.com/devcontainers/python:1-3.12-bullseye

USER vscode

# Configure Poetry to use an in-project .venv so that the interpreter path does not change between containers
RUN mkdir -p /home/vscode/.config/pypoetry && \
  echo "[virtualenvs]" > /home/vscode/.config/pypoetry/config.toml && \
  echo "in-project = true" >> /home/vscode/.config/pypoetry/config.toml
