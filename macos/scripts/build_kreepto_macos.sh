#!/usr/bin/env bash
# Builds a universal (arm64 + x86_64) dynamic library for macOS:
#   macos/build/macos/libkreepto.dylib
#
# Invoked by CocoaPods via kreepto.podspec prepare_command, or manually:
#   sh macos/scripts/build_kreepto_macos.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
CRATE_DIR="$PROJECT_ROOT/native/kreepto-rust"
OUT_DIR="$SCRIPT_DIR/../build/macos"

# Minimum macOS version; keep in sync with Podfile / kreepto.podspec.
export MACOSX_DEPLOYMENT_TARGET="10.14"

TARGETS=(
  "aarch64-apple-darwin"
  "x86_64-apple-darwin"
)

mkdir -p "$OUT_DIR"

for target in "${TARGETS[@]}"; do
  echo "==> cargo build --release --target $target"
  (cd "$CRATE_DIR" && cargo build --release --target "$target")
done

ARM_LIB="$CRATE_DIR/target/aarch64-apple-darwin/release/libkreepto.dylib"
X86_LIB="$CRATE_DIR/target/x86_64-apple-darwin/release/libkreepto.dylib"

# Merge both slices into one universal dylib.
echo "==> lipo create universal dylib"
lipo -create -output "$OUT_DIR/libkreepto.dylib" "$ARM_LIB" "$X86_LIB" || \
  cp "$ARM_LIB" "$OUT_DIR/libkreepto.dylib"

# Set the install name to @rpath/libkreepto.dylib so that the loader resolves it
# from the app's Frameworks directory (CocoaPods copies vendored dylibs there).
echo "==> set install name to @rpath/libkreepto.dylib"
install_name_tool -id "@rpath/libkreepto.dylib" "$OUT_DIR/libkreepto.dylib"

echo "==> done: $OUT_DIR/libkreepto.dylib"
