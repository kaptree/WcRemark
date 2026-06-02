#!/bin/bash
set -e

PROJECT_ROOT="$(cd "$(dirname "$0")" && pwd)"
ANDROID_HOME="${PROJECT_ROOT}/android-sdk"
JAVA_HOME="/opt/homebrew/opt/openjdk@17"
FLUTTER_BIN="/opt/homebrew/opt/flutter/bin"
DIST_DIR="${PROJECT_ROOT}/dist"

APK_NAME="lalemeV7.apk"

export ANDROID_HOME
export JAVA_HOME
export PATH="${FLUTTER_BIN}:${ANDROID_HOME}/cmdline-tools/latest/bin:${ANDROID_HOME}/platform-tools:${PATH}"

echo "========================================="
echo "  拉了么 (LaLeMe) APK 构建脚本"
echo "========================================="
echo ""
echo "ANDROID_HOME: ${ANDROID_HOME}"
echo "JAVA_HOME:    ${JAVA_HOME}"
echo "Flutter:      $(flutter --version 2>&1 | head -1)"
echo ""

cd "${PROJECT_ROOT}/la-le-me-app"

echo "[1/3] 安装依赖..."
flutter pub get

echo ""
echo "[2/3] 构建 Release APK..."
flutter build apk --release

echo ""
echo "[3/3] 复制 APK 到 dist 目录..."
mkdir -p "${DIST_DIR}"
cp build/app/outputs/flutter-apk/app-release.apk "${DIST_DIR}/${APK_NAME}"

APK_SIZE=$(ls -lh "${DIST_DIR}/${APK_NAME}" | awk '{print $5}')
echo ""
echo "========================================="
echo "  ✅ 构建完成"
echo "  APK: ${DIST_DIR}/${APK_NAME}"
echo "  大小: ${APK_SIZE}"
echo "========================================="
