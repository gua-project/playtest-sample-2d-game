# 検証記録の索引

ここは対象SHA・実行日時・成否・診断・レビュー等の履歴を保持する場所である。[現行テスト契約](../verification.md) と [実行責務](../test-responsibility.md) から分離する。過去の成功、source回帰、限定smokeを、別buildの合格やGUI/Playtest E2Eの完了へ転用しない。

## 実行証拠

日時はmanifestの `date`、TRXの `Times`、CI runの時刻を一次情報とする。EXE hash、テストソースhash、レビュー対象SHAは別の識別子であり、混同しない。

| 記録 | 対象・出典 | 内容と判定制約 |
|---|---|---|
| [headless-windows.zip](headless-windows.zip) / [manifest.json](manifest.json) | manifestのsource commit `5d17c505c5f3eef6de8cd2f4423d8c4e7931ef0f`、date、EXE/DLL SHA256 | 旧EXEのnormal/restore/explore/3個別bug、操作/Observe/version/final-state。探索seed137。headless画像は未取得で、GUIやPlaytest実行ではない |
| [boundaries-windows.zip](boundaries-windows.zip) | raw操作/Observe/version。テスト定義は [0bbecef の旧JS](https://github.com/gua-project/playtest-sample-2d-game/blob/0bbeceff503cfbd6c6e4e75778af7df0a1131791/tests/exe-test.ts) | 旧EXE境界ケース。このZIP単独にゲームEXE SHAは記録されていないため、他runのbuild hashを自動的に帰属させない |
| [source-migration.zip](source-migration.zip) / [manifest](source-migration-manifest.json) | 定義 `2ec5573c9f91b4adc03220749f4dc2778bba6ece`。manifestのテストソース/プロジェクトhash、正式NuGet参照commitと版、local smoke EXE hash。日時は各TRX | source移行の失敗比較と最終実行を含む。記録上のmodel26/source12/smoke1はそのrunに限定し、修正後やE2Eへ流用しない |
| [migration-review-fixes.zip](migration-review-fixes.zip) | 修正定義 `0577d04b2bd216b85cdf519d9062964a85f5798b`。内部manifestのlocal source/script hash、TRXのTimes、smoke-processのEXE hash/PID | 移行レビュー指摘修正後のsource12/smoke1のローカル記録。内部のreviewBase/reviewHeadはレビュー範囲 `0bbecef..2ec5573` を示し、修正後の実行対象SHAとは異なる |

## CI実行の出典

| 対象SHA | 実行記録 | run開始（UTC、APIのrun_started_at） | 範囲 |
|---|---|---|---|
| `0bbeceff503cfbd6c6e4e75778af7df0a1131791` | [PR run 40794669575](https://github.com/gua-project/playtest-sample-2d-game/actions/runs/40794669575) | 2026-10-29T00:31:59Z | 旧7モードEXEスクリプトの実行履歴。現行source回帰やPlaytest E2Eではない |
| `2ec5573c9f91b4adc03220749f4dc2778bba6ece` | [PR run 40805648545](https://github.com/gua-project/playtest-sample-2d-game/actions/runs/40805648545)、[push run 40805642961](https://github.com/gua-project/playtest-sample-2d-game/actions/runs/40805642961) | PR 2026-10-29T02:19:20Z、push 2026-10-29T02:19:17Z | 公式gua-testerによるsource回帰と分離smokeへの移行時点 |
| `0577d04b2bd216b85cdf519d9062964a85f5798b` | [PR run 40810223336](https://github.com/gua-project/playtest-sample-2d-game/actions/runs/40810223336)、[push run 40810218252](https://github.com/gua-project/playtest-sample-2d-game/actions/runs/40810218252) | PR 2026-10-29T03:06:16Z、push 2026-10-29T03:06:13Z | モデル26、source12、限定smoke1の成功を記録した修正後run。GUI/Playtest E2Eは未実行 |

CI artifactの保持期限とrepo内ZIPの保存は別である。リンク先が利用できない場合も、証拠欠落を成功へ読み替えない。

## 保存した文書記録

各文書の出典は移設前の `0577d04` snapshotへ結び付けてある。実装・移行時のレビュー回数、開始前エラー、提出/承認調整、失敗試行は履歴として保持し、現行仕様に混ぜない。

- [初期実装と再開時の検証記録](verification.md)：実EXEの経緯、初回レビュー、初回importの失敗比較、GUI未検証、空mainの調整。
- [移行対応・API比較の記録](test-responsibility.md)：旧テストからの移管対応、期待値・seed・bug ID、複数接続timeoutの比較と当時の実行結果。根本原因は未確定。
- [移行差分の独立レビュー記録](migration-review.md)：初回実装レビューとは別枠の1回、2件の指摘、修正と再検証。回数は当時の範囲の記録である。
- [実装PR #2](https://github.com/gua-project/playtest-sample-2d-game/pull/2)：提出用本文、レビュー範囲、確認結果・調整の記録。repoのPR下書きと同内容が本文に保持されていることを確認した保存先である。
