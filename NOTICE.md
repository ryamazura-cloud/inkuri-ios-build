# 同梱資材

Noto Sans JPの可変フォントを同梱しています。

- 配布元：[Google Fonts / Noto Sans JP](https://github.com/google/fonts/tree/main/ofl/notosansjp)
- ライセンス：SIL Open Font License 1.1
- ライセンス原文：`assets/fonts/OFL.txt`

Flutter、Flutterプラグイン、Material / Cupertinoアイコンの各ライセンスは、それぞれのパッケージおよびアプリ内「このアプリについて」→ライセンスから確認できます。

教材1,733問は本プロジェクト向けに作成したものです。公開前に校閲を行ってください。

## 同梱したAI音声
3,467例文の音声はKokoro-82M v1.0（fp32）を使い、af_heartの声でPC上で生成しました。AIが合成した声です。モデル本体はアプリに含めていません。

- モデル：[Kokoro-82M](https://huggingface.co/hexgrad/Kokoro-82M)
- 推論形式：[ONNXモデル](https://huggingface.co/onnx-community/Kokoro-82M-v1.0-ONNX)
- 生成ライブラリー：[kokoro-js](https://github.com/hexgrad/kokoro/tree/main/kokoro.js)
- モデル・生成ライブラリーのライセンス：Apache License 2.0
- 同梱ライセンス原文：`assets/audio/LICENSE-Kokoro.txt`
- 英文・音声の対応、生成条件、ハッシュ：`assets/audio/manifest.json`

音声再生にはaudioplayersを使います。ライセンスはアプリのライセンス画面から確認できます。
