#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
# Older Intel-only Git installations can shadow macOS's native Git.
if ! git --version >/dev/null 2>&1 && [ -x /usr/bin/git ]; then
  export PATH="/usr/bin:/bin:$PATH"
fi
if command -v flutter >/dev/null 2>&1; then
  nexus_flutter_bin="$(command -v flutter)"
elif [ -x "$HOME/development/flutter/bin/flutter" ]; then
  nexus_flutter_bin="$HOME/development/flutter/bin/flutter"
elif [ -x /private/tmp/nexus-flutter-sdk/bin/flutter ]; then
  nexus_flutter_bin=/private/tmp/nexus-flutter-sdk/bin/flutter
else
  echo 'Install Flutter from https://docs.flutter.dev/install/manual and add it to PATH.'
  exit 1
fi
exec "$nexus_flutter_bin" --no-version-check run -d web-server --web-hostname 127.0.0.1 --web-port 8081
