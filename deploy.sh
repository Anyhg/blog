#!/usr/bin/env bash
set -euo pipefail

cd /srv/blog

if [ -d .git ]; then
  git fetch --all --prune
  git reset --hard origin/main
fi

hugo --gc --minify
nginx -t
systemctl reload nginx
