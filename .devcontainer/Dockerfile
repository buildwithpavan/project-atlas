FROM mcr.microsoft.com/devcontainers/base:ubuntu-24.04

RUN apt-get update && apt-get install -y \
    build-essential \
    git \
    curl \
    libpq-dev \
    postgresql-client \
    redis-tools \
    vim \
    unzip \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /workspaces/project-atlas

ENV BUNDLE_PATH=/usr/local/bundle
ENV BUNDLE_JOBS=4
ENV BUNDLE_RETRY=3