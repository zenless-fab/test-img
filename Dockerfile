ARG BASE_IMAGE_NAME=nvcr.io/nvidia/cuda
ARG BASE_IMAGE_TAG=12.4.1-cudnn-devel-ubuntu22.04

ARG UV_VERSION=0.8.3
FROM ghcr.io/astral-sh/uv:${UV_VERSION} AS uv


FROM ${BASE_IMAGE_NAME}:${BASE_IMAGE_TAG} AS base

ENV DEBIAN_FRONTEND=noninteractive \
    SHELL=/bin/zsh

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        zsh \
        tmux \
        git \
        wget \
        curl \
        ca-certificates \
        build-essential \
    && sh -c "$(wget -O- https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended \
    && git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions \
    && rm -rf /var/lib/apt/lists/*

COPY .zshrc /root/.zshrc
COPY --from=uv /uv /uvx /bin/

WORKDIR /workspace
SHELL [ "/bin/zsh", "-c" ]
ENTRYPOINT []

FROM base AS deps

COPY requirements.txt /workspace/requirements.txt
ARG PYTHON_VERSION=3.12
RUN uv venv -p ${PYTHON_VERSION} \
    && echo "source /workspace/.venv/bin/activate" >> /root/.zshrc \
    && echo "source /workspace/.venv/bin/activate" >> /root/.bashrc \
    && uv pip install --no-cache-dir \
        -r /workspace/requirements.txt

FROM deps AS notebook

RUN uv pip install --no-cache-dir \
        jupyterlab \
        ipywidgets \
        ipydatagrid \
        bokeh

ENV SHELL=/bin/zsh
CMD ["uv", "run", "jupyter", "lab", "--ip='*'", "--port=8888", "--no-browser", "--allow-root", "--NotebookApp.token=''", "--NotebookApp.password=''"]
EXPOSE 8888
VOLUME [ "/workspace" ]

FROM deps AS vscode

RUN curl -fsSL https://code-server.dev/install.sh | sh \
    && code-server --install-extension ms-python.python \
    && code-server --install-extension ms-toolsai.jupyter \
    && code-server --install-extension ms-vscode.hexeditor \
    && code-server --install-extension EditorConfig.EditorConfig \
    && code-server --install-extension charliermarsh.ruff \
    && code-server --install-extension tamasfe.even-better-toml \
    && code-server --install-extension redhat.vscode-yaml

ENV SHELL=/bin/zsh
CMD ["code-server", "--bind-addr=0.0.0.0:8080", "--auth=none", "--disable-telemetry", "--disable-update-check"]
EXPOSE 8080
VOLUME [ "/workspace" ]

FROM base AS vscode-pure

RUN curl -fsSL https://code-server.dev/install.sh | sh \
    && code-server --install-extension ms-python.python \
    && code-server --install-extension ms-toolsai.jupyter \
    && code-server --install-extension ms-vscode.hexeditor \
    && code-server --install-extension EditorConfig.EditorConfig \
    && code-server --install-extension charliermarsh.ruff \
    && code-server --install-extension tamasfe.even-better-toml \
    && code-server --install-extension redhat.vscode-yaml

ENV SHELL=/bin/zsh
CMD ["code-server", "--bind-addr=0.0.0.0:8080", "--auth=none", "--disable-telemetry", "--disable-update-check", "/workspace"]
EXPOSE 8080
VOLUME [ "/workspace" ]
