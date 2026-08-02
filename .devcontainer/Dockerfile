FROM mcr.microsoft.com/devcontainers/base:ubuntu-24.04

# Install packages
RUN apt-get update && apt-get install -y \
    curl \
    git \
    build-essential \
    libpq-dev \
    postgresql-client \
    redis-tools \
    vim \
    unzip \
    && rm -rf /var/lib/apt/lists/*

# Install mise
RUN curl https://mise.run | sh

ENV PATH="/root/.local/bin:${PATH}"

# Install runtime versions
COPY mise.toml /tmp/mise.toml

WORKDIR /tmp

RUN mise install -f /tmp/mise.toml

WORKDIR /workspace