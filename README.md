# 小さな冒険者ギルド

[仕様 issue #1](https://github.com/gua-project/playtest-sample-2d-game/issues/1) の非リアルタイム 2D サンプル。Windows x64、Godot **4.7.stable.official.5b4e0cb0f**、正式 **Gua 1.1.2** を使用する。素材は文字・標準 UI による仮素材。音声は未実装。

## 起動・ビルド・配布

Godot 4.7 stable と同版 Windows export templates を用意する。PowerShell で checkout から実行する。

```powershell
./scripts/bootstrap.ps1
./scripts/build.ps1 -Godot C:/path/to/Godot_v4.7-stable_win64.exe
./output/guild.exe
```

`bootstrap.ps1` は正式 release `gua-v1.1.2` の addon ZIP の SHA256 `19f89058ca60e48c74a7327da31c0e011b4c053acfda8e5b8e2e2b1fc90ae8c4` を照合して checkout 内だけに展開する。Git に DLL やビルド成果物は含めない。配布時は `output/guild.exe` と export が配置した DLL を同じ構成で ZIP にまとめる。EXE は PCK 内蔵で、署名はない。CI artifact `guild-windows` にEXE/DLLと検証ログを保存する。

## 遊び方

タイトルから開始 → ミナとの会話で情報を聞く → 店で薬草3個・ロープ2個・水晶2個を購入 → 依頼を受注 → インベントリで品を選択 → 依頼一覧で1個ずつ納品 → 報酬を受領。3件完了すると結果画面から再プレイできる。最初の60Gで必要品を揃えられる。受注前の仕入れも可能。

マウス、Tab／方向キーでフォーカス、Enter／Spaceで決定。Esc は画面の中断・復帰、確認画面ではキャンセル。店と依頼の「戻る」は受付に戻る。確認画面へは内容を切り替えるため背面ボタンは存在しない。スクロールで画面下部へ移動できる。

各品最大9個、鞄は3種類。数量は1〜9、売却は購入価格の半額。失敗取引は正常版では数量・残高・在庫を変更しない。部分納品は取り消さない。報酬受領は1回。

「翌日へ」だけが日付を進める。薬草3日、ロープ5日、水晶7日まで。当日の納品・報酬受領は有効。翌日処理は日付加算 → 未完了依頼の期限切れ → 各在庫を2補充（上限20）。期限切れの依頼は復活しないため、ポーズのリセットで再試行する。納品完了済みの報酬は翌日以降も受領できる。乱数は使わず `guild-v1 / deterministic` と記録する。

ポーズから保存・ロード・初期化・設定。ゲームは自動時間進行しない。保存は状態・会話の既読と分岐・部分納品・報酬・不具合ID・履歴・言語を含む JSON、同ディレクトリの一時ファイルから rename。保存先は `%APPDATA%/GuaSampleGuild2D/guild-save.json`。保存エラーは `save_failed`、不正データは `invalid_save`。画面サイズと画面位置は保存しない。再開は受付または結果、選択品と数量は薬草・1へ戻す。設定は日本語／英語と 880×608、1100×760、1320×912。

## Gua と不具合比較

標準 auto adapter が UI と通常ボタンを収集する。独自の公開フィルタや専用クリア操作は追加しない。Observe v1 の root owner に `state`（JSON文字列）と `selection` を標準既定の profile で登録する。公開可否は Gua の観測プロトコルが処理する。既定 bridge は `ws://127.0.0.1:8793`。`GUA_BRIDGE_PORT` で変更可能。別ゲームと固有ポート・保存先を使う。

```powershell
$env:GUA_BRIDGE_PORT='8793'
./output/guild.exe -- --bug=cancel_charge --save-path=C:/absolute/path/save.json
```

`--bug=` は次のIDを個別指定。指定なしが正常版。開始・リセット・再プレイは現在のフラグを引き継ぐ。ロードは保存したフラグを復元し、画面と実行証拠にIDを残す。テスト用の初期条件変更は引数・新規開始／リセットに限定し、通常納品を迂回しない。

| ID | 再現条件 | 正しい期待結果 | 有効時 |
|---|---|---|---|
| `cancel_charge` | 店で1個の購入確認をキャンセル | 所持金・在庫・品数不変 | 所持金のみ購入額減少 |
| `double_reward` | 納品後に同じ依頼の報酬を再度受領 | 二度目は unavailable、残高不変 | 報酬を再加算 |
| `sort_target` | 2種類以上所持し品を選択、並べ替え、納品 | 品目IDを保持 | 次の品目へ選択がずれ、誤納品または品違い拒否 |

## テストと判定範囲

[テストの責務・実行方法](docs/test-responsibility.md) と [テスト契約](docs/verification.md) を参照してください。固定UI回帰は正式NuGet `Gua.Testing.Godot` / `Gua.Testing` **1.1.2** を使い、GDScriptの **source scene** を起動します。CIは公式 `gua-project/gua-tester/godot@v3.1` を使い、addonのtagも `gua-v1.1.2` に固定しています。

```powershell
$env:GODOT_EXECUTABLE='C:/path/to/Godot_v4.7-stable_win64.exe'
$env:DOTNET_GENERATE_ASPNET_CERTIFICATE='false'
dotnet restore tests/Guild.Regression/Guild.Regression.csproj
dotnet test tests/Guild.Regression/Guild.Regression.csproj --filter TestCategory=SourceRegression
./scripts/smoke-exe.ps1
```

最後のsmokeは既にビルドされたEXEの **公式versionとタイトルのUI存在だけ** を確認し、接続先の所有PIDと起動PIDを照合してから1プロセスを終了します。source回帰と配布smokeの結果は分けて扱います。

配布EXEのlaunch/attach、探索、Scenario、予算、cleanup、Trace/Recording/Replayの統合は **Gua Playtest** 側の責務です。サンプルに第二のE2E実行基盤は設けません。[引継ぎ情報](docs/playtest-handoff.json) は未実行のメタデータであり、実行可能Scenario形式や成功結果ではありません。

[検証記録の索引](docs/evidence/README.md) から、対象SHA・日時・ログと意図的な履歴文書を参照できます。最新の実行結果はPR/CIとTRXで確認してください。モデル/source/smokeの成功は GUI の視覚・入力検証やPlaytest E2Eの完了を意味しません。通常入力・実画面JA/EN/resizeは未検証です。複数接続timeoutの根本原因も未確定で、詳細と現在の実行方式はテスト責務文書に記載しています。音、他ハードウェア、オンライン同期、QA全般の網羅は対象外です。

