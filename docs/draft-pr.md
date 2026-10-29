# 非リアルタイム2Dギルドと公式Guaによるサンプル回帰を実装

Refs #1

Godot 4.7 / 正式 Gua 1.1.2 で、会話・仕入れ・売却・受注・部分納品・報酬受領から3件完了、結果、再プレイへ進むWindows向けゲームを追加します。日付は翌日操作だけで進み、日本語/英語、画面サイズ、ポーズ、保存/復元、リセットと3種の個別不具合を備えます。素材は仮素材です。

## テストの責務

- ゲーム自身のモデル回帰26項目は維持。
- 固定UI回帰は正式NuGet `Gua.Testing.Godot` / `Gua.Testing` **1.1.2** に整理。`GodotSceneTestHost` が **source scene** をheadlessで起動し、公式locatorの相関完了と公式Observeで検証します。ゲームはGDScriptのままです。
- CIは公式 `gua-project/gua-tester/godot@v3.1`、Godot4.7、addon tag `gua-v1.1.2` に固定。
- 自作JS wire clientと7モードEXE runnerを削除。EXEは `smoke-exe.ps1` による1プロセスの **version/title確認だけ** とし、プレイや探索を組み込みません。
- 配布EXEのlaunch/attach、Scenario、探索、予算、cleanup、Trace/Recording/Replayの統合は **Playtest担当**。今回それを新設・実行したとは主張しません。

[全旧テストの移管表](test-responsibility.md) と [Playtest引継ぎ情報](playtest-handoff.json) に、旧ID、期待値、初期条件、bug ID、seed137、旧証拠、build/Scenario/Environment/独立期待値の接続を保持しています。Scenario ID/revisionと新build hashは未割当で、未実行E2Eは成功にしていません。

## 再検証と証拠

source回帰は開始/一巡/再プレイ、部分保存と報酬後の別sourceプロセス復元、残高・鞄・スタック・在庫0/20・数量の境界、売却不足と再購入、日付・期限、正常版/個別bug比較を対象にしています。正式ホスト単独の最小navigationを含め12項目、限定配布smokeは別の1項目です。CIはTRXの実行件数を検査します。

初期の常駐第二Observe接続では完了timeoutを再現。公式ホスト単独・短い公式Observe読取スコープの比較で切り分け、source操作はホストContextに統一しました。Godot保存JSONの `1.0` は整数性を検証して扱います。失敗/比較TRXも保存し、無条件retryや独自transportで埋めていません。根本原因の一般化や依存ライブラリ修正はこのPRの範囲外です。

現行結果はsource-regression / distribution-smokeのCIとTRXへ記録。旧 [実EXE証拠](evidence/headless-windows.zip) と [境界証拠](evidence/boundaries-windows.zip)、[旧build manifest](evidence/manifest.json) は履歴として保持し、現source回帰やPlaytest E2Eへ成功を流用しません。

## 未検証とレビュー範囲

GUIは正規Computer Useでギルド画面ではなく承認UIが返り、承認完了/正しい対象を確認できず停止しました。通常入力・実画面のJA/EN/resizeは未検証で、今回は承認を再要求していません。音は未実装です。

独立レビューは、初回ゲーム実装1回を保持し、今回の移行差分 `0bbecef..2ec5573` に別枠1回を実施しました。[移行レビュー記録](migration-review.md) のP2指摘2件（購入確認screen/背面back不在、初期bug設定の厳密一致）を修正し、source12件を再検証しました。smokeの起動PIDとLISTEN所有PIDも照合し、限定smoke1件が通過しています。[修正証拠](evidence/migration-review-fixes.zip) を保存。修正・追加照合を別の独立再レビュー済みとは主張しません。GitHub正式Approveは未投稿です。

空mainは明示承認された空tree初期commit `8a51b044` のみ。既存実装ブランチを保持し、PRブランチへ空mainをmergeして共通祖先を設けました。ゲーム実装のmainマージ、自動マージ、default設定変更、Release公開はしていません。GUIとPlaytest受入が残るためDraftを維持します。
