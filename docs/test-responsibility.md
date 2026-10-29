# サンプル回帰と Playtest E2E の境界

この文書が現在の実行責務を定める。`verification.md` の従来のEXE記録は履歴として保持する。過去のEXEスクリプト成功を Playtest の完成や、新しいsource sceneテストの成功へ読み替えない。

## 現在の実行経路

- 純粋なゲーム状態の26項目: `tests/model_test.gd`。既存の軽量モデル回帰。
- 固定UI回帰: `tests/Guild.Regression`。NuGet **Gua.Testing.Godot 1.1.2** の `GodotSceneTestHost.Load("res://main.tscn")` が **Godot 4.7 のsource scene** をheadless起動・接続・破棄する。ゲームはGDScriptのまま。
- 操作と観測: 公式 **Gua.Testing 1.1.2** の `GuaAssertions.Query(host.Context).ById(...).Click` と `GuaWebSocketContext.GetObserveSnapshotJson`。locatorの相関付き完了確認を利用し、独自WebSocket wire clientは削除。状態JSONは公式Observe envelopeから読み、未観測を成功にしない。Godotホストの操作接続を保持し、Observeは読取ごとに公式Contextをdisposeする短いスコープを使う。
- CI: `gua-project/gua-tester/godot@v3.1`（tag commit `7bff041a7275363583fdb52a3445ba24601abdab`）。addon tagは `gua-v1.1.2`、NuGetも1.1.2に固定。source回帰jobと配布smoke jobは別。
- 限定配布smoke: `scripts/smoke-exe.ps1` が1プロセスを起動し、公式 `Gua.Testing` で **バージョンとタイトルの開始/ロードボタン存在だけ**を確認して終了する。プレイ、保存、探索、Scenario、予算、Trace/Recording/Replayを扱わない。

ポート8793、テスト保存とAPPDATAは `output/source-regression/` / `output/smoke-*` に分離する。公式ホストへ渡すのはゲームのscene、引数、保存先、環境だけであり、サンプル独自の汎用runnerは作らない。source用の `DistributionSmoke` はexplicitテストなので、公式CI部品の通常test実行では意図的に除外される。別のsmoke jobで明示選択し、その結果を別TRXへ出す。除外を配布検証成功とは数えない。

## 全旧テストの移動先

旧実装はcommit `0bbeceff503cfbd6c6e4e75778af7df0a1131791` の `tests/exe-test.ts` / `scripts/test-exe.ps1` で参照できる。証拠ZIPは削除しない。

| 旧ケース / ID | 現在のサンプル回帰 | 限定smoke | 将来Playtest E2E（今回未実行） |
|---|---|---|---|
| model D01/S01〜08/Q01〜04/N01/P01〜06/B01〜02 | `model_test.gd` 26項目を維持 | 対象外 | モデル成功を実EXEへ転用しない |
| normal / F01 会話→仕入れ→受注→納品→報酬→結果→再プレイ | `StartCompleteReplayAndSettings`、初期60G、薬草3/ロープ2/水晶2、完了82G | タイトル到達のみ | 同じ独立期待値を配布buildとScenarioへ結ぶ |
| normal / D01, U01, U02 分岐、取消、ポーズ、言語/サイズ | `SoldSuppliesRecoverAndDeadlinesAdvanceOnlyExplicitly`、`EconomicBoundariesAndCancelledConfirmation`、`StartCompleteReplayAndSettings`。semantic到達のみ | 対象外 | 実画面/実入力/フォーカス/JA-EN/resize。GUI未承認のまま |
| restore / P01〜03 | `SavePartialAndClaimAcrossSourceProcesses`。部分納品1/3、残2、最初の報酬後68G、再ロード後二重claim不可 | 対象外 | 配布EXEの再起動・build識別付きsave再開、完了82G/全doneも維持 |
| boundaries / S03〜08, N01〜02 | `EconomicBoundariesAndCancelledConfirmation`、`StockZeroSaleAndReacquisition`、`SoldSuppliesRecoverAndDeadlinesAdvanceOnlyExplicitly`。数量1/9、鞄3種、stack9、残高不足、stock0/20、売却再購入、期限、待機時日付固定 | 対象外 | 同条件の実EXE Scenarioと独立期待値を移管 |
| cancel_charge / S02 | `CancelBugComparison` 正常と個別bug比較。薬草1の購入取消: 正常60G、bug56G、在庫/品数は変わらない | 不具合版を起動しない | 同初期条件の正常版/個別bug版、結果にIDを結ぶ |
| double_reward / Q04 | `RewardBugComparison`。薬草3購入後初回報酬68G、二度目は正常68G/bug88G | 対象外 | 同条件の配布版比較。旧全完了のbug102Gも履歴保持 |
| sort_target / I01 | `SortBugComparison`。薬草/ロープを所持、薬草選択、sortで正常herb/bugrope | 対象外 | 旧3種所持でもherb→rope。納品拒否/誤対象と紐付ける |
| explore / X01 | ランダム探索をsource回帰へ全量移植しない | 対象外 | **Playtest担当**。seed137、依頼順/受注購入順、購入取消、売却不足拒否→再入手、day1の全done。旧操作履歴を保持するが新E2E未実行 |
| version/title/get_screenshot | 正式version照合、UI存在はsourceで確認 | version/titleだけ | 実EXEのlaunch/attach、描画、録画、Trace/Replay、cleanup/予算の統合はPlaytest担当 |

旧証拠: `docs/evidence/headless-windows.zip`（normal/restore/explore/各bug、manifestは当時のEXE SHA）、`docs/evidence/boundaries-windows.zip`（境界の実EXE操作/Observe）。旧CI run `40794669575` は7ケース成功の履歴であり、Playtest E2Eではない。現行TRXとsourceのstate/diagnosticsは各CI artifactへ保存する。

## Playtestへの接続情報

`playtest-handoff.json` は**引継ぎメタデータ**であり、Playtestの実行可能Scenario形式を装わない。Scenario作成・バージョン・budget・attach・recording・trace・replay・cleanupの実装はPlaytest側で行う。

1. Build: Windows x64 `guild.exe` + addon DLL。受入時に実際のEXE SHA256、commit、Gua version/buildIdを採取し、旧hashを新buildへ流用しない。
2. Scenario: `guild-v1` はゲーム仕様版。Playtest Scenario ID/revisionは未割当。探索seed137はテスト側、ゲーム乱数はなし。
3. Environment: Windows、Godot4.7、Gua1.1.2、専用port8793、専用save/APPDATA。GUI承認/入力/実画面は未検証。
4. Independent expectations: 初期day1/60G/空bag、3依頼のneed3/2/2、報酬20/24/30、期限3/5/7、通常完了82G。観測値から期待値を自己生成しない。
5. Result: 旧run、現source regression、限定smoke、未実行Playtest E2Eを別々に報告する。未割当Scenarioや未取得Trace/Replayを成功にしない。

## 今回の検証範囲

公式ホストと第二のObserve用Contextを常駐させた初期構成では、`shop` / `buy` / `cancel_trade` の完了待ちが1秒・5秒ともtimeoutとなった。10ms/100ms polling、次frame待ち、両Contextの操作を比較し、失敗TRXとpending-requests/operations診断を保存した。第二接続なしのホスト単独最小navigationと限定EXE smokeは成功し、Observeを公式APIの読取スコープに限定した比較2件も成功した。これは同一環境での切り分け結果であり、Gua側の一般的な複数接続可否や根本原因を断定しない。サンプルから依存ライブラリを改変しない。

`OfficialHostOnlyNavigation` はその最小経路を回帰として残す。ゲーム側はcallback中にControlを再構築するため、各clickの公式相関完了後に公式 `WaitUntil` で次のUI frame公開も確認する。明示5秒budgetはテストの待機上限でありPlaytestの探索予算ではない。未完了、タイムアウト、欠落Observeは失敗にする。

独立レビューは、初回ゲーム実装1回を保持し、今回の移行差分 `0bbecef..2ec5573` へ別枠1回を実施した。[レビュー結果](migration-review.md) のP2検出漏れ2件を修正し、担当が再検証した。修正や追加smoke照合を別の独立再監査済みとは主張しない。

移行時点 `2ec5573` のローカル実行は **モデル26項目、source12項目、限定smoke1項目が成功**。source通常実行ではexplicitの配布smokeを実行しない。smokeは別実行でTRXのexecuted=1/passed=1を確認した。初期失敗・比較・最終成功のTRXは [source-migration.zip](evidence/source-migration.zip)、API版とファイルhashは [source-migration-manifest.json](evidence/source-migration-manifest.json)。最終sourceでは追加の未assert観測を「final」として取得せず、最後にassertしたObserve envelopeを `last-observe.json` として元のframe metadataごと保存する。GUIとPlaytest E2Eは依然未実行。
