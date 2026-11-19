# 学習状況の計測

Firebase Analyticsに接続したビルドでは、計測設定が未保存の場合に確認画面を表示します。画面の初期選択はオンで、「協力して続ける」を押すと計測を開始します。「協力しない」を選べば計測はオフのままです。保存済みの設定は引き継ぎ、iアイコンの「このアプリについて」からいつでも変更できます。設定ファイルがないビルドでも学習できます。

## イベント

- `normal_study_day` は、その日に初めて通常問題の自己評価を保存した時点で記録します。
- `normal_30_reached` は、その日の通常問題の回答が30問に達した時点で記録します。
- `normal_after_30_start` は、30問到達後に同じ日付で新しい通常練習を始めた時点で記録します。到達したセットの残りに答えても、このイベントは発生しません。

冒険・修行モードの通常練習を合算し、復習と挑戦は除きます。同じ問題でも回答するたびに加算します。端末の現地日付を `study_day` に入れ、回答の記録に成功した場合のみ加算します。計測開始前の学習履歴はさかのぼって送信しません。独自イベントに問題文、解答、自己評価の内容は含めません。Firebase Analyticsの自動収集項目も公開前に確認します。

## Androidで接続と動作確認

1. Firebase Consoleでプロジェクトを作成し、Google Analyticsを有効にします。
2. Androidアプリをパッケージ名 `biz.wisemap.encre` で登録します。`google-services.json` を取得し、このプロジェクトの `android/app/` に置きます。
3. APKをビルドし、端末にインストールします。DebugViewで確認する場合は、テスト端末で `adb shell setprop debug.firebase.analytics.app biz.wisemap.encre` を実行します。
4. アプリの計測をオンにします。通常練習の1問目、30問目、次の通常セットの開始で上記3イベントを確認します。復習・挑戦と、計測オフ時の動作も確認します。
5. 確認後は `adb shell setprop debug.firebase.analytics.app .none.` でデバッグモードを解除します。

iOSで接続する際は、実際の配布用Bundle IDを確定し、対応する `GoogleService-Info.plist` をXcodeでRunnerターゲットに追加します。

## 集計

GA4では日次のイベント別利用者数を比較します。端末の日付を基準に厳密に集計する場合は、GA4のBigQueryエクスポートを有効にし、`study_day` と `user_pseudo_id` の組で重複を除きます。アプリのインストール単位で集計されるため、複数端末を使う利用者は別に数えられます。

- 分母は、通常問題を1問以上解いた端末数です。
- 到達率は、分母のうち30問に達した端末数の割合です。
- 継続率は、分母のうち30問到達後に次の通常セットを開始した端末数の割合です。

公開前に、収集項目に合わせてプライバシーポリシーとGoogle Playの「データ セーフティ」を更新します。

- [FirebaseのAndroid設定](https://firebase.google.com/docs/android/setup?hl=ja)
- [DebugView](https://firebase.google.com/docs/analytics/debugview?hl=ja)
- [BigQueryエクスポートの項目](https://support.google.com/analytics/answer/7029846?hl=ja)
