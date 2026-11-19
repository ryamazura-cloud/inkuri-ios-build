# インクリ iOS公開準備

2026年11月7日時点。対象ソースは0.16.7+34。

## 現在の準備状況

- 所有者の環境はWindows。Macなし、iPhoneあり、Apple Developer Program未登録。
- iOSのBundle IDは `biz.wisemap.encre`。テスト用は `biz.wisemap.encre.RunnerTests`。
- 通常の学習、同梱音声、学習記録、チュートリアルはFlutter共通コード。iPhoneでの動作は未検証。
- iOS用のアプリアイコンとローカル通知のネイティブ設定は存在する。
- Xcodeの署名チームは未設定。署名済みIPA、TestFlightのビルドは未作成。
- このプロジェクトはSwift Package Managerの参照を使用する。Mac上で依存パッケージの解決とビルドを確認する。

## 1. 法人名義の登録

販売元を法人名義にするため、WiseMap合同会社でApple Developer Programに登録する方針。
法人名、住所、連絡先は登記およびD-U-N-S登録内容に合わせ、英語表記を推測して入力しない。

- 二要素認証を有効にしたApple Accountを用意する。
- AppleのD-U-N-S検索から既存番号を確認する。見つからなければ無料発行を申請する。
- 組織として登録する。連絡用に会社ドメインのメールと `https://wisemap.biz/` を使用する。
- 本人・法人確認、契約同意、会費支払いをアカウント所有者が完了する。
- 登録完了後にTeam IDを確認し、Bundle IDをApple側で登録する。ローカルの設定変更はApple側での登録を意味しない。

Apple Developer Programの年会費は99米ドル相当。実際の地域別価格は申込画面で確認する。

## 2. Macビルド環境と署名

所有Macがないため、macOSとXcodeを使用できるクラウドビルド環境を選ぶ。
サービス利用料、ソース保管先、署名情報の管理方法を確認してから接続する。
Apple Developer Programへの登録完了後に署名設定を行う。

Mac環境にソースを用意し、Flutter・XcodeのバージョンとApp Storeの提出要件を確認する。
`ios/Runner.xcworkspace` のRunnerに所属チームを設定する。
署名用証明書・プロファイル・API秘密鍵は公開リポジトリに保存しない。

Mac上でプロジェクトルートから順に実行する。

```sh
flutter doctor -v
flutter pub get
flutter test
flutter build ios --release --no-codesign
flutter build ipa --release
```

最後のコマンドには有効な署名設定が必要。標準のIPA出力先は `build/ios/ipa/`。
クラウド環境での証明書読み込みや書き出し設定は、採用サービスに合わせて追加する。

## 3. 本番機能の接続

- FirebaseにiOSアプリを登録し、Bundle IDを合わせてGoogleService-Info.plistを組み込む。現在はiOS用の設定ファイルがないため、学習計測の接続は完了していない。
- AdMobにiOS版を登録し、iOS用のアプリIDと広告ユニットを設定する。Info.plistの現在の値はGoogleのサンプルID。
- 現在、リリース版の収益化を有効にする分岐はAndroid向け。iOSには本番広告・課金を接続する実装が必要。
- 広告の同意フローとAppleのプライバシー要件を、実際に利用するSDK・設定に合わせて確認する。
- 有料プランはApp Store Connectで非消耗型の商品を作り、購入確認、広告非表示、無制限化、復元、失敗時の再試行をiOS用に実装・検証する。既存の購入確認サーバーはGoogle Play向け。
- 販売価格の希望は買い切り980円。Apple側で選べる価格、契約、税務・銀行情報を登録時に確認する。
- SDKのプライバシーマニフェストとApp Store Connectのプライバシー回答を実際の動作に合わせる。
- 起動時の更新案内は現在Android向け。iOSで同じ機能を提供する場合は別途対応する。

## 4. App Store Connect登録候補

- アプリ名候補は「2秒で瞬間英作文 インクリ」。　　　　　　　　　　　　　　　　　　　　　　
- サブタイトル候補は「短時間×高反復で、使える英語を増やす」。
- 主言語は日本語。カテゴリ候補は教育。
- Bundle IDは `biz.wisemap.encre`。SKU候補は `inkuri-ios`。
- サポート連絡先は `info@wisemap.biz`。
- サポート・マーケティングURLは `https://encre.wisemap.biz/`。
- プライバシーポリシーは `https://encre.wisemap.biz/privacy-policy-2/`。
- 利用規約は `https://encre.wisemap.biz/terms/`。
- 年齢区分、輸出コンプライアンス、広告・課金・プライバシーの回答はiOS完成版の挙動に基づいて入力する。
- スクリーンショットはiPhone版で撮影する。iPad向けに配信する場合はiPadでも検証し、必要な画像を用意する。

## 5. TestFlightから審査へ

IPAをApp Store Connectへアップロードし、処理後にTestFlightへ配信する。
所有iPhoneで初回案内、学習、音声、復習、通知、共有、記録保存と再起動、課金・復元・広告の動作を確認する。
不具合を修正し、必要な掲載画像・説明・審査情報を整えてApp Reviewへ提出する。
Androidのクローズドテストと並行して進める。

## 公式資料

- [Apple Developer Programへの登録](https://developer.apple.com/help/account/membership/program-enrollment/)
- [D-U-N-S番号の確認と無料申請](https://developer.apple.com/help/account/membership/D-U-N-S/)
- [FlutterのiOSビルド・配布手順](https://docs.flutter.dev/deployment/ios)
- [TestFlight概要](https://developer.apple.com/help/app-store-connect/test-a-beta-version/testflight-overview/)
