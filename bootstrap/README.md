# Bootstrap

This directory contains reusable scripts and templates used to bootstrap Project Atlas.

## Goals

- Standardize project setup
- Automate repetitive tasks
- Keep the development environment reproducible
- Reduce onboarding time

## Contents

### rails-template.rb

Rails application template.

Will configure:

- RSpec
- RuboCop
- Brakeman
- FactoryBot
- Shoulda Matchers
- dotenv
- UUID
- Sidekiq
- GitHub Actions

### bootstrap.sh

Bootstraps the complete monorepo.

### setup-devcontainer.sh

Configures the development container.

### validate-environment.sh

Checks required tools and versions.