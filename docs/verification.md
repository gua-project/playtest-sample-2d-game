# issue #1 対応と証拠

シナリオ `guild-v1`、乱数なし、Godot 4.7.stable、Gua 1.1.2。ビルドは `scripts/bootstrap.ps1` → release export。実行ログ・Observe応答・各クリックと完了応答を `output/evidence-<mode>/transcript.json`、version と final-state を同ディレクトリに保存する。PNG は実際に取得できたときのみ作成する。headless の screenshot unavailable は成功扱いしない。

| テストID・目的 | 初期条件・操作 | 期待結果・判定根拠 | 実装 / 検証 | 実際の状態 |
|---|---|---|---|---|
| D01 会話・分岐・取消 | 新規、会話前受注、各分岐、戻る | 受注拒否、既読と分岐保持、戻るで未操作 | guild.accept / main talk / model + EXE | prerequisite・supplies分岐・戻る通過、rewards分岐 GUI未検証 |
| S01/S02 取引取消 | 60G、薬草購入確認を取消 | 残高60、在庫12、品0、選択維持 | guild.trade / EXE | normalとcancel_charge差分検出 |
| S03〜S07 境界 | 鞄3種、9個、金0、在庫0、数量0/10 | 全拒否がatomic、数量1〜9 | guild.trade / model_test | 20モデル項目に含み通過、境界EXE未検証 |
| Q01 部分納品 | 薬草3、受注、1個納品 | delivered1、残2、報酬未発生 | guild.deliver / model + EXE | 通過 |
| Q02/Q03 売却と再試行 | 部分納品後残2個売却、納品、再購入 | 未所有時拒否、再入手で完了 | guild.trade/deliver / model | 通過、EXE未検証 |
| Q04 二重報酬 | 同依頼を再claim | 正常版残高不変、bug版+20 | guild.claim / model + EXE | 正常版・double_reward差分検出 |
| I01 スタック・並べ替え | crystal/herb/rope所持、herb選択しsort | 選択herb維持、bug版ropeへずれ | main inventory / EXE | 実行結果を evidence-sort_target で記録 |
| N01 期限・順序 | day1受注、3回翌日 | day4期限切れ、在庫補充、金不変 | guild.next_day / model | 通過、期限EXE未検証 |
| N02 待機 | 新規、入力せず1.2秒 | day1維持、翌日ボタンでday2 | main / EXE | headless通過、長時間未検証 |
| P01〜P03 保存復元 | 部分納品後・報酬後保存/再開 | 正確な納品数、二重受領なし、完了後結果復元 | restore + save/load / model + EXE | headless通過、プロセス跨ぎ復元未検証 |
| P04 不正保存 | schema不一致 | invalid_save、現状態保持 | guild.restore / model | schema拒否通過、破損型の全網羅なし |
| F01 一巡・再プレイ | 会話→仕入れ→受注→納品→claim3件 | result、全done、再プレイ60G day1 | main / EXE | headless通過、人間GUI操作未検証 |
| U01 ポーズ・戻る・背面入力 | 確認画面とpauseへ | confirm/cancelのみ、resumeで復帰 | main / EXE tree | treeで背面操作不存在確認、実キーボード未検証 |
| U02 言語・画面サイズ | settingsで英語と880 | 読める、はみ出しなし、操作可能 | main / EXE | semantic操作通過、画像と実画面未検証 |
| X01 探索的プレイ | 目的=全納品、制約=通常操作、速度制限なし | 仕入れ/売却の別順序でも整合 | 未実施 | 固定手順とは別の探索未実施 |

正常版・個別bug版の EXE は `tests/exe-test.ts` が Gua `get_version`、`get_ui_tree`、`click_node`、`poll_events`、`get_observe_snapshot` を使用する。requestId に対応する完了を要求し、timeout と観測欠落は失敗。専用クリア操作やメモリ書換はない。headless は画面サイズを物理検証できないため、この行は semantic到達のみ。

実行時に初回 bug 試験が旧残存プロセスの desk に接続したため `missing start on desk` で失敗した。無効な実行として扱い、担当EXEのPID確認・終了後に新規プロセスで再実行。各runの初期bugs一致をassertする修正を加えた。

未完了条件は main の base commit 不在による PR 作成、GUI調整待ち、画像・人間入力、プロセス跨ぎ再開、境界の実EXE、探索試験、独立レビューおよびCI結果。結果の更新時に未実施を成功へ読み替えない。
