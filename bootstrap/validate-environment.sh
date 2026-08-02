#!/usr/bin/env bash

set -e

echo "Checking development environment..."

echo "Ruby:"
ruby -v

echo "Node:"
node -v

echo "Python:"
python3 --version

echo "Docker:"
docker --version

echo "Git:"
git --version

echo "Environment looks good."