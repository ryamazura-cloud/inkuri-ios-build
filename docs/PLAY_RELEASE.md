# Google Play公開の準備

対象は Android 版インクリ（`biz.wisemap.encre`）。Google Playのアプリは作成済み。有料プランは買い切りで、日本の設定価格は980円。アプリ内の購入画面にはGoogle Playが返した価格を表示する。

## Play ConsoleとAdMobの設定

1. Play Consoleで既存アプリのパッケージ名、これまでにアップロードした最大のversionCode、Play App Signingの登録状態を確認する。登録済みのアップロード鍵があれば使う。初回ならPlay App Signingとアップロード鍵を設定する。鍵とパスワードはローカルで管理し、チャットやソース管理に載せない。
2. Play Consoleで買い切り商品 `inkuri_unlimited` を作成する。表示名は「インクリ 無制限プラン」。説明は「通常練習を回数無制限・広告なしで利用できます。」とし、日本の価格を980円に設定する。通常の購入オプションを用い、消費型・レンタル・定期購入として設定しない。
3. Android版のAdMobアプリIDと4つの広告ユニットIDは `android/admob.production.json` に反映済み。バナーは「TOP下部」「学習記録」「10問終了後」、リワード広告は「追加練習チケット」。AdMob側でリワードの量が1、項目が追加練習チケットになっていることを確認する。
4. AdMobの「プライバシーとメッセージ」で配信地域に応じたメッセージを公開する。Play掲載後にストアと連携し、AdMobが発行した `app-ads.txt` の行を開発者サイトの指定URLに置いて審査状況を確認する。

## 購入検証の接続

既存のAndroid Firebaseプロジェクトを使う想定。Cloud Functionsのデプロイ前に、対象プロジェクトの課金プランと運用費用を確認する。

1. Play Consoleから本番のアプリ署名証明書のSHA-256を確認し、FirebaseのAndroidアプリへ登録する。App CheckでPlay Integrityを設定する。
2. Google Play Android Developer APIを有効化し、購入確認と確定に必要な最小権限を持つ専用サービスアカウントをPlay Consoleで対象アプリに割り当てる。Cloud Functionsの実行IDとして使う。サービスアカウント鍵をアプリに埋め込まない。
3. Firebase CLIで既存プロジェクトにログインしたうえで、このFlutterプロジェクトのルートから `firebase deploy --only functions:verifyPlayPurchase --project <PROJECT_ID>` を実行する。初回の設定にはFirebase AndroidアプリID `INKURI_FIREBASE_ANDROID_APP_ID` と専用サービスアカウントのメールアドレス `INKURI_PLAY_SERVICE_ACCOUNT` が必要。
4. デプロイされたHTTPS URLを本番ビルドに渡す。アプリはApp CheckのトークンとGoogle Playの購入トークンを送る。検証APIは購入商品・支払い状態・返金状態を照合し、未確定なら確定する。購入済みの権利は端末に7日間キャッシュし、起動・復帰・復元時に照合する。Google Playや検証サーバーに接続できない場合は、期限内の確認済み権利を使用する。

## 署名付きAndroid App Bundle

`android/key.properties.example` と同じ形式でアップロード鍵を設定する。このPCでは署名設定を `%LOCALAPPDATA%/Inkuri/signing/key.properties` に保存し、環境変数 `INKURI_SIGNING_PROPERTIES` で指定する。公開バージョン名と、Play Consoleの既存versionCodeより大きい番号を使う。

```powershell
$env:INKURI_SIGNING_PROPERTIES = Join-Path $env:LOCALAPPDATA 'Inkuri/signing/key.properties'
flutter build appbundle --release --build-name=<VERSION> --build-number=<VERSION_CODE> `
  --dart-define-from-file=android/admob.production.json `
  --dart-define=INKURI_PLAY_VERIFY_URL=<HTTPS_URL>
```

本番モードはAndroidのリリースビルドで有効。必須設定が欠ける場合はビルドを止める。試用版と本番版の広告IDは分離する。

## Play掲載文案

**アプリ名**　インクリ - 瞬間英作文トレーニング

**短い説明**　日本語を見てすぐ英語に。音声・解説・復習で、毎日続ける瞬間英作文。

**詳しい説明**

日本語を読んで、英語でどう言うか考える。インクリは、短い練習を積み重ねて英語の表現を身につける瞬間英作文アプリです。

冒険モードでは、旅行や仕事、料理など、興味のあるテーマを選べます。修行モードでは、中学1〜3年生の文法を学年と単元から選んで復習できます。解答例はAI音声で聞け、問題によって別の言い方やニュアンスの解説も確認できます。

苦手な問題を復習しながら、クエストやバッジで学習を続けられます。学習記録では、取り組んだ問題数や学習時間の推移を振り返れます。教材と音声は端末に同梱しています。

無料版では通常練習を1日3セット利用でき、クエストなどで獲得したチケットで追加練習できます。買い切りの無制限プランでは、通常練習の回数制限が解除され、広告が表示されなくなります。

## テストから公開まで

- Playのテストトラックから配布して、インストール、無料枠、テスト広告、ライセンステスターによる購入・復元、キャンセルと返金時の扱いを実機で確認する。デバッグ署名の試用版とは署名が異なるため、既存の学習データを保持する必要がある端末では、入れ替え方法を先に確認する。
- 本番SDKの設定に基づいて広告の有無、プライバシーポリシー、データ セーフティ、対象年齢、コンテンツのレーティングを設定する。掲載画像は公開候補の画面で確認する。
- 対象の新規個人デベロッパーアカウントでは、12人以上が連続14日参加するクローズドテストと製品版へのアクセス申請が必要。アカウントの実際の状態はPlay Consoleで確認する。

- [Play Consoleのリリース手順](https://support.google.com/googleplay/android-developer/answer/9859348?hl=ja)
- [AdMobのアプリ登録](https://support.google.com/admob/answer/9989980?hl=ja)
- [Firebase App Check](https://firebase.google.com/docs/app-check/flutter/default-providers?hl=ja)
- [買い切り商品の購入ライフサイクル](https://developer.android.com/google/play/billing/lifecycle/one-time)
