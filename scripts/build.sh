#!/usr/bin/env bash
# 在 macOS 上本地编译 Super Web（输出未签名 IPA）
set -euo pipefail

cd "$(dirname "$0")/.."

APP_PATH="build/Build/Products/Release-iphoneos/SuperWeb.app"

xcodebuild \
  -project SuperWeb.xcodeproj \
  -scheme SuperWeb \
  -configuration Release \
  -sdk iphoneos \
  -derivedDataPath build \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY="" \
  build

rm -rf Payload
mkdir -p Payload
cp -R "$APP_PATH" Payload/
zip -qry SuperWeb-unsigned.ipa Payload

echo "已生成 $(pwd)/SuperWeb-unsigned.ipa"
