# PrismML llama.cpp runtime

This directory contains a slim iOS-only XCFramework created from PrismML's official `llama.cpp` release.

- Upstream: `https://github.com/PrismML-Eng/llama.cpp`
- Release: `prism-b9570-0ad1dab`
- Original archive: `llama-prism-b9570-0ad1dab-xcframework.zip`
- Original archive SHA-256: `7f0416f14494eb88c8075e74501823d1092ad5ba0424c73316378575f2a37d16`
- Included slices: `ios-arm64`, `ios-arm64_x86_64-simulator`
- Runtime license: MIT

The model weights are not stored in the repository or application bundle. Lippi downloads the pinned Apache-2.0 `Bonsai-4B-Q1_0.gguf` artifact directly to the app's Application Support directory after explicit user action.

Third-party notices shipped with the app are in `Lippi/Resources/ThirdParty/PrismML-Bonsai-NOTICES.txt`.
