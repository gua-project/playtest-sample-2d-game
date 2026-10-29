# テスト責務移行の独立レビュー

| 枠 | 回数 | 対象 |
|---|---:|---|
| 初回ゲーム実装レビュー | 1回（既存・保持） | ゲーム実装、初期テスト、当時の実EXE証拠。既存3指摘の修正履歴は verification.md |
| 今回の移行レビュー | 1回（別枠） | `0bbecef..2ec5573`。公式API/CI、旧期待値・bug検出、通常操作、smoke規模、Playtest移管 |

`migration_review` によるread-onlyレビュー。開始前のモデル混雑エラーは未実施であり回数に含めず、同じ依頼を再開した。レビュー担当は編集・GUI・再委譲・正式Approveを行っていない。今回の指摘修正・追加smoke照合は担当が再検証し、別の独立再レビューを実施したとは主張しない。

## 確認された指摘と修正

1. **P2 購入確認の背面操作検証が脱落。** 旧JSには `screen == confirmation` と `back` 不在のassertがあり、移行時点ではbuy/cancelの効果だけだった。確認画面に背面backが混入しても通る差だった。`CancelPurchaseConfirmation` で通常購入ボタンを押し、公式UI treeからscreenとback不在を確認してから取消を押す。経済境界および正常/bug取消比較で使う。
2. **P2 初期bug設定の厳密一致検証が脱落。** 旧JSは正常`[]`/個別`[ID]`を厳密比較していた。複数flagを同時有効化しても対象操作の効果だけでは検出できなかった。`AssertBugMode` で公式Observeのbugsを厳密比較し、初期画面と開始/リセット/再プレイ後も検証する。version取得は既存ホストContextを使い、初期Observe公開を待ってから読む。

両方とも旧JSの該当assertと移行先を担当が独立照合し、具体的な検出漏れとして確認した。ゲーム本体の仕様や初期状態注入で回避せず、通常操作と観測にassertを復元している。新たな意図的ゲーム変異試験を実行したとは主張しない。

ほかに公式API/CIの利用、通常操作、未実行Playtest E2Eの表記、smoke規模について確定指摘はなかった。

## 残余リスクと追加確認

- GUI画面・実入力・実画面JA/EN/resizeは未検証。今回は承認を再要求しない。
- Gua複数接続timeoutの根本原因は未確定。短い公式Observe読取スコープで通過しているという範囲に限定する。
- レビューで残余リスクに挙がった固定ポートsmokeの対向identityについて、起動したEXEがport8793の唯一のLISTEN所有PIDであることを、EXEが存命のうちに照合する検査を追加した。version/titleだけの古い別プロセスへ接続した結果を、このbuildの成功にしない。smokeにシナリオや探索・Recording等は追加しない。
- Playtest Scenario/revision/budget/Trace/Replayは未実行であり、sourceや限定smokeの成功で代替しない。

修正後のローカルsource回帰12件、限定smoke1件が成功した。[修正証拠ZIP](evidence/migration-review-fixes.zip) にTRX、起動PID/bridge所有PID/EXE hash、修正ソースhashを保存した。ローカルsmokeでは起動PIDとbridge PIDがともに41512で一致した。2ec5573時点の移行証拠は上書きしていない。最新commitのCIはPRへ記録する。
