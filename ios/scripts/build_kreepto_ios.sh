#!/usr/bin/env bash
# Builds a universal (device + simulator) static library for iOS:
#   ios/build/ios/libkreepto.a
#
# Invoked by CocoaPods via kreepto.podspec prepare_command, or manually:
#   sh ios/scripts/build_kreepto_ios.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
CRATE_DIR="$PROJECT_ROOT/native/kreepto-rust"
OUT_DIR="$SCRIPT_DIR/../build/ios"

# iOS deployment target; keep in sync with Podfile / kreepto.podspec.
export IPHONEOS_DEPLOY_TARGET="13.0"

# Architectures: device (arm64) + simulator (arm64, x86_64).
TARGETS=(
  "aarch64-apple-ios"
  "aarch64-apple-ios-sim"
  "x86_64-apple-ios-sim"
)

mkdir -p "$OUT_DIR"

for target in "${TARGETS[@]}"; do
  echo "==> cargo build --release --target $target"
  (cd "$CRATE_DIR" && cargo build --release --target "$target")
done

DEVICE_LIB="$CRATE_DIR/target/aarch64-apple-ios/release/libkreepto.a"
SIM_ARM_LIB="$CRATE_DIR/target/aarch64-apple-ios-sim/release/libkreepto.a"
SIM_X86_LIB="$CRATE_DIR/target/x86_64-apple-ios-sim/release/libkreepto.a"

# Combine the two simulator slices into one simulator lib.
echo "==> lipo create simulator lib"
lipo -create -output "$OUT_DIR/libkreepto_sim.a" "$SIM_ARM_LIB" "$SIM_X86_LIB" || \
  cp "$SIM_ARM_LIB" "$OUT_DIR/libkreepto_sim.a"

# Combine device + simulator into the final universal lib.
echo "==> lipo create universal lib"
lipo -create -output "$OUT_DIR/libkreepto.a" "$DEVICE_LIB" "$OUT_DIR/libkreepto_sim.a" || \
  cp "$DEVICE_LIB" "$OUT_DIR/libkreepto.a"

# Static archives can also carry a module map; not required for FFI-by-symbol.
echo "==> done: $OUT_DIR/libkreepto.a"
