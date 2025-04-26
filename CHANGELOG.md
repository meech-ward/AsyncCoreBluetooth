# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.3.2] - 2025-04-25

### Added
- Add RSSI value to Peripheral `readRSSI()`

## [0.3.1] - 2025-03-10

### Fixed
- Fix package dependency for AsyncObservable

## [0.3.0] - 2025-03-10

### Changed
- Changed the API to use `AsyncObservable` for notifications and values. This changed quite a bit of the `AsyncCoreBluetooth` API but check the README and examples for the new API.

## [0.2.0] - 2025-03-07

### Added
- New documentation in `Sources/AsyncCoreBluetooth/AsyncCoreBluetooth.docc` ([2fea786](https://github.com/meech-ward/AsyncCoreBluetooth/commit/2fea7860a82112ca6fa8afa2b130239674761c81))

### Changed
- Make sure all characteristic continuations are canceled on peripheral disconnect
- Make sure notifications can't be enabled or disabled if they are already in that state
- Make data for read and notify not optional ([78629a6](https://github.com/meech-ward/AsyncCoreBluetooth/commit/78629a694a84165df5959ff916ea564c86bfdfd4))
- Make sure a new peripheral actor is created for each new peripheral instance

### Fixed
- Remove nonisolated lazy property from Peripheral actor

## [0.1.x] - 2024-XX-XX

- Initial releases with core functionality
