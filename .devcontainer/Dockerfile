FROM mcr.microsoft.com/devcontainers/python:1-3.12-bullseye

ADD https://github.com/doy/rbw/releases/download/1.10.1/rbw_1.10.1_linux_amd64.tar.gz /tmp/rbw.tar.gz

RUN tar -xvf /tmp/rbw.tar.gz -C /usr/local/bin/ && \
  chmod +x /usr/local/bin/rbw && \
  chmod +x /usr/local/bin/rbw-agent && \
  rm /tmp/rbw.tar.gz

USER vscode

# Configure Poetry to use an in-project .venv so that the interpreter path does not change between containers
RUN mkdir -p /home/vscode/.config/pypoetry && \
  echo "[virtualenvs]" > /home/vscode/.config/pypoetry/config.toml && \
  echo "in-project = true" >> /home/vscode/.config/pypoetry/config.toml
