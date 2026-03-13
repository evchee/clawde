#!/bin/bash

# Check if gt CLI is installed
if ! command -v gt &>/dev/null; then
  exit 0
fi

# Check if we're in a git repo
if ! git rev-parse --is-inside-work-tree &>/dev/null; then
  exit 0
fi

# Check if Graphite is initialized in this repo
if ! gt repo info &>/dev/null 2>&1; then
  exit 0
fi

echo "This repo uses Graphite for branch stacking. Use gt instead of raw git for branch and PR workflows."
