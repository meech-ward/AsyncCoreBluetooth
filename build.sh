#!/usr/bin/env bash
set -e

# 1. Clean build artifacts
rm -rf .build
rm -rf ./swift-docs
mkdir ./swift-docs

# 2. Generate symbol graphs only for 'AsyncCoreBluetooth' target
swift build \
  --target AsyncCoreBluetooth \
  -Xswiftc -emit-symbol-graph \
  -Xswiftc -emit-symbol-graph-dir \
  -Xswiftc .build/symbol-graphs

# 3. Remove any leftover symbol graphs from dependencies
find .build/symbol-graphs -type f \
  ! -name "*AsyncCoreBluetooth*" -delete

# 4. Convert DocC, pointing only to our target’s doc catalog and symbol graphs
xcrun docc convert Sources/AsyncCoreBluetooth/AsyncCoreBluetooth.docc \
  --fallback-display-name AsyncCoreBluetooth \
  --fallback-bundle-identifier com.meech-ward.AsyncCoreBluetooth \
  --fallback-bundle-version 1 \
  --additional-symbol-graph-dir .build \
  --additional-symbol-graph-dir .build/symbol-graphs \
  --output-dir AsyncCoreBluetooth.doccarchive

# 5. Transform for static hosting
xcrun docc process-archive \
  transform-for-static-hosting AsyncCoreBluetooth.doccarchive \
  --hosting-base-path "" \
  --output-path "./swift-docs"
