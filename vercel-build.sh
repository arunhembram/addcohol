#!/bin/bash
set -e

echo "=== Installing Flutter SDK on Vercel ==="
if [ ! -d "_flutter" ]; then
  git clone https://github.com/flutter/flutter.git --depth 1 -b stable _flutter
fi

export PATH="$PATH:$(pwd)/_flutter/bin"

echo "=== Building Company Web Platform ==="
cd apps/company_app
flutter pub get
flutter build web --release --dart-define-from-file=../../.env.dev

cp vercel.json build/web/vercel.json || true

echo "=== Build finished successfully ==="
