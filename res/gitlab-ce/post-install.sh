#!/bin/sh

# Check if bundler is installed, since we need it.
command -v bundle >/dev/null 2>&1 || { echo >&2 "The Ruby gem 'bundler' is required to install GitLab. Aborting."; exit 1; }

# Create the 'git' user.
adduser --system git

# Install required Ruby gems.
cd /opt/gitlab-ce
bundle install --deployment --without development mysql test aws
