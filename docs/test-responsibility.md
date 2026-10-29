# テストの責務と実行方法

[テスト契約](verification.md) に初期条件・手順・独立した期待値を定める。[検証記録](evidence/README.md) は対象SHA・日時・ログを持つ過去の実行証拠であり、最新buildの合格判定とは分けて扱う。

## 実行経路

| 経路 | 対象と入口 | 判定範囲 |
|---|---|---|
| モデル回帰 | [model_test.gd](../tests/model_test.gd) | 取引・納品・期限・保存の純粋な状態遷移。モデル用fixtureの直接設定を使う。実UI/EXEの証明にはしない |
| 固定UI回帰 | [GuildTests.cs](../tests/Guild.Regression/GuildTests.cs) の `SourceRegression` | 正式 `Gua.Testing.Godot` / `Gua.Testing` 1.1.2で **source scene** をheadless起動し、通常ボタン操作を検証 |
| 限定配布smoke | [smoke-exe.ps1](../scripts/smoke-exe.ps1) とexplicitの `DistributionSmoke` | 配布EXEのversion/titleと起動プロセスへの帰属のみ。プレイ、保存、探索は扱わない |
| Playtest E2E | [引継ぎメタデータ](playtest-handoff.json) | 配布EXEのlaunch/attach、Scenario、探索、予算、cleanup、Trace/Recording/Replayの統合。サンプル内に汎用runnerを置かない |

ゲームはGDScript。source回帰のプロセス起動・接続・破棄は `GodotSceneTestHost.Load("res://main.tscn")` が担い、操作は公式locatorの相関付き完了で判定する。Observeは公式 `GuaWebSocketContext.GetObserveSnapshotJson` を読取スコープごとにdisposeし、独自wire clientは使わない。

## ローカル実行

Windows x64、Godot 4.7 stable、.NET 10 SDK、Windows export templatesを用意し、repo rootで実行する。

```powershell
./scripts/bootstrap.ps1
$env:GODOT_EXECUTABLE='C:/path/to/Godot_v4.7-stable_win64.exe'
$env:DOTNET_GENERATE_ASPNET_CERTIFICATE='false'
dotnet restore tests/Guild.Regression/Guild.Regression.csproj
dotnet test tests/Guild.Regression/Guild.Regression.csproj --filter TestCategory=SourceRegression --logger 'trx;LogFileName=source-regression.trx'
./scripts/build.ps1 -Godot $env:GODOT_EXECUTABLE
./scripts/smoke-exe.ps1
```

`build.ps1` はモデル回帰とrelease exportを含む。モデルだけを実行する場合は `Godot --headless --path . --script tests/model_test.gd` を使う。`Godot` は利用環境の実行ファイルのパスに置き換える。

port8793を他プロセスと共有せず、同一PCではこれらのテストを同時実行しない。sourceのAPPDATA/saveは `output/source-regression/<test-id>-<unique-id>/`、配布smokeは `output/smoke-*` に分離する。sourceの保存復元は、同じテストのsaveだけを引き継いで別のsourceプロセスを開く。配布EXEの再起動E2Eとは区別する。

通常の `dotnet test` では配布smokeはexplicit指定で除外される。配布物をビルド後、`smoke-exe.ps1` が明示選択して実行する。除外を配布検証成功には数えない。

## CIと証拠

[Windows workflow](../.github/workflows/windows.yml) の `source-regression` は公式 `gua-project/gua-tester/godot@v3.1`、Godot4.7、addon tag `gua-v1.1.2` を使う。NuGetも1.1.2に固定する。`distribution-smoke` は別jobでビルドと限定smokeを行う。

判定はTRXの実行件数とassert、各stageの終了コード、エラーログ、配布物の存在を使う。sourceは12件、限定smokeは1件の実行・合格を要求する。これはsuiteの構成に対する条件であり、特定日時の成功報告ではない。

sourceの `version.json`、`final-ui.json`、`last-observe.json` と失敗診断は `output/source-regression/`、TRXはテストのresultsディレクトリへ保存する。`last-observe.json` は最後に実際にassertした観測で、そのframe metadataを保持し、teardown時の新規観測とは呼ばない。smokeはTRXと `output/smoke-process.json` に起動PID、bridge所有PID、EXE SHA256を保存する。CI artifactは `guild-source-regression` / `guild-windows`。

## 設計上の理由と制限

- ゲームはcallbackでControlを再構築する。clickの相関完了後、公式 `WaitUntil` で次のUI frame公開も待ってから次の操作を選ぶ。5秒の操作timeoutは固定回帰の待機上限であり、Playtestの探索予算ではない。
- 複数接続を常駐させた構成で完了timeoutの再現記録があり、**根本原因は未確定**。短い公式Observe読取スコープを使う構成を、一般的な複数接続問題の修正や保証とは扱わない。詳細は[API比較の記録](evidence/test-responsibility.md)を参照。
- Godotの初回import直後の終了でaccess violationの再現記録がある。`build.ps1` は180フレーム・最大60fpsの初期化と明示的なプロセス終了待ちを使い、終了コードとstderrを確認する。この実行手順は原因修正を意味しない。
- GUI画面、キーボード/マウス、実画面JA/EN/resizeは未検証。headlessのsemantic到達やbounds確認で代替しない。音は未実装、他ハードウェア互換性やオンライン同期も対象外。
- Playtest Scenario ID/revision、実行budget、Trace/Recording/Replayは未実行・未割当。実行時のbuild hash、commit、環境、独立期待値を結び、過去のsource/smoke/EXE記録を新E2Eの成功へ転用しない。
