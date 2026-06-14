#!/usr/bin/env bash
set -eu

cd "$(dirname "$0")"
PROJECT_ROOT="$(cd ../.. && pwd)"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log()  { echo -e "${GREEN}[build]${NC} $1"; }
warn() { echo -e "${YELLOW}[warn]${NC} $1"; }
err()  { echo -e "${RED}[error]${NC} $1"; }

# ─── Linux ───────────────────────────────────────────────
build_linux() {
  log "Building for Linux x86_64..."
  cargo build --release --target x86_64-unknown-linux-gnu
  mkdir -p "$PROJECT_ROOT/assets/native/linux/x86_64"
  cp target/x86_64-unknown-linux-gnu/release/libkreepto.so \
     "$PROJECT_ROOT/assets/native/linux/x86_64/"
  log "Linux done"
}

# ─── Windows ─────────────────────────────────────────────
build_windows() {
  if ! command -v x86_64-w64-mingw32-gcc &>/dev/null; then
    warn "Skipping Windows: mingw-w64-gcc not found (pacman -S mingw-w64-gcc)"
    return
  fi
  log "Building for Windows x86_64..."
  cargo build --release --target x86_64-pc-windows-gnu
  mkdir -p "$PROJECT_ROOT/assets/native/windows/x86_64"
  cp target/x86_64-pc-windows-gnu/release/kreepto.dll \
     "$PROJECT_ROOT/assets/native/windows/x86_64/"
  log "Windows done"
}

# ─── Android ─────────────────────────────────────────────
build_android() {
  if [ -z "${ANDROID_NDK_HOME:-}" ]; then
    warn "Skipping Android: ANDROID_NDK_HOME not set"
    return
  fi

  local TOOLCHAIN="$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/linux-x86_64/bin"
  if [ ! -d "$TOOLCHAIN" ]; then
    warn "Skipping Android: NDK toolchain not found at $TOOLCHAIN"
    return
  fi

  # Add toolchain to PATH so clang is found
  export PATH="$TOOLCHAIN:$PATH"

  local JNILIBS="$PROJECT_ROOT/android/app/src/main/jniLibs"

  for ARCH_TRIPLE in aarch64-linux-android armv7-linux-androideabi x86_64-linux-android i686-linux-android; do
    case "$ARCH_TRIPLE" in
      aarch64-linux-android)    ANDROID_ARCH=arm64-v8a ;;
      armv7-linux-androideabi)  ANDROID_ARCH=armeabi-v7a ;;
      x86_64-linux-android)     ANDROID_ARCH=x86_64 ;;
      i686-linux-android)       ANDROID_ARCH=x86 ;;
    esac

    log "Building for Android $ANDROID_ARCH..."
    cargo build --release --target "$ARCH_TRIPLE"

    mkdir -p "$JNILIBS/$ANDROID_ARCH"
    cp "target/$ARCH_TRIPLE/release/libkreepto.so" \
       "$JNILIBS/$ANDROID_ARCH/"
  done

  log "Android done"
}

# ─── Main ────────────────────────────────────────────────
log "Building kreepto native crypto library"
echo ""

build_linux
build_windows
build_android

echo ""
log "All builds complete. Libraries placed in:"
ls -la "$PROJECT_ROOT/assets/native/"*/  2>/dev/null || true
ls -la "$PROJECT_ROOT/android/app/src/main/jniLibs/"*/ 2>/dev/null || true
