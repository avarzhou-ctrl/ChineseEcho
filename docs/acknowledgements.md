---
layout: default
title: ChineseEcho Acknowledgements and Licenses
permalink: /acknowledgements/
---

# Acknowledgements and Licenses

ChineseEcho is built with open-source software, language data, and an optional
language model. We thank their authors and contributors.

This page provides attribution and links to the upstream license terms. The
license notices distributed with a ChineseEcho release govern the included
versions.

## CC-CEDICT

ChineseEcho includes data from
[CC-CEDICT](https://cc-cedict.org/wiki/), a community-maintained Chinese–English
dictionary published by [MDBG](https://www.mdbg.net/chinese/dictionary?page=cc-cedict).

The dictionary is licensed under the
[Creative Commons Attribution-ShareAlike 4.0 International License](https://creativecommons.org/licenses/by-sa/4.0/).
The bundled dictionary release is dated August 8, 2026.

## Optional language model

ChineseEcho can download
[mlx-community/Qwen3-4B-4bit](https://huggingface.co/mlx-community/Qwen3-4B-4bit),
an MLX-formatted quantization of Qwen 3 4B, from Hugging Face. The model page
contains its model card, attribution, and applicable license information.

Qwen is a trademark of its respective owner. ChineseEcho is not affiliated
with or endorsed by Qwen, MLX, or Hugging Face.

## Direct software dependencies

- [MLX Swift LM](https://github.com/ml-explore/mlx-swift-lm) — local model loading and generation; MIT License.
- [Swift Hugging Face](https://github.com/huggingface/swift-huggingface) — model downloads; Apache License 2.0.
- [Swift Transformers](https://github.com/huggingface/swift-transformers) — tokenization and model support; Apache License 2.0.

## Transitive software dependencies

The resolved dependency graph also includes the following projects. Their
copyright notices and license terms are available in their linked repositories:

- [EventSource](https://github.com/mattt/EventSource)
- [MLX Swift](https://github.com/ml-explore/mlx-swift)
- [Swift ASN.1](https://github.com/apple/swift-asn1)
- [Swift Atomics](https://github.com/apple/swift-atomics)
- [Swift Collections](https://github.com/apple/swift-collections)
- [Swift Crypto](https://github.com/apple/swift-crypto)
- [Swift Jinja](https://github.com/huggingface/swift-jinja)
- [SwiftNIO](https://github.com/apple/swift-nio)
- [Swift Numerics](https://github.com/apple/swift-numerics)
- [SwiftSyntax](https://github.com/swiftlang/swift-syntax)
- [Swift System](https://github.com/apple/swift-system)
- [yyjson](https://github.com/ibireme/yyjson)

Apple, macOS, and related Apple technologies are trademarks of Apple Inc.

For questions about these acknowledgements, email
[avarzhou@gmail.com](mailto:avarzhou@gmail.com).

[Return to the ChineseEcho homepage](../)
