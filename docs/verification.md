# issue #1 対応と証拠

> 以下は初期実装の検証履歴です。現行の責務・全テスト移管先・正式APIへの変更範囲は [test-responsibility.md](test-responsibility.md) を参照してください。旧EXE 7ケースの成功は、新しいsource回帰やPlaytest E2Eの成功へ転用しません。GUI未検証は維持します。

シナリオ `guild-v1`、乱数なし、Godot 4.7.stable、Gua 1.1.2。ビルドは `scripts/bootstrap.ps1` → release export。実行ログ・Observe応答・各クリックと完了応答を `output/evidence-<mode>/transcript.json`、version と final-state を同ディレクトリに保存する。PNG は実際に取得できたときのみ作成する。headless の screenshot unavailable は成功扱いしない。

| テストID・目的 | 初期条件・操作 | 期待結果・判定根拠 | 実装 / 検証 | 実際の状態 |
|---|---|---|---|---|
| D01 会話・分岐・取消 | 新規、会話前受注、各分岐、戻る | 受注拒否、既読と分岐保持、戻るで未操作 | guild.accept / main talk / model + EXE | prerequisite・supplies分岐・戻る通過、rewards分岐 GUI未検証 |
| S01/S02 取引取消 | 60G、薬草購入確認を取消 | 残高60、在庫12、品0、選択維持 | guild.trade / EXE | normalとcancel_charge差分検出 |
| S03〜S08 境界 | 鞄3種、9個、残高不足、在庫0/20、数量上下限 | 全拒否がatomic、数量1〜9 | guild.trade / model_test + EXE boundaries | モデルと実EXE通過。直接0/10指定の拒否はモデル、通常ボタンの1/9飽和はEXEで確認 |
| Q01 部分納品 | 薬草3、受注、1個納品 | delivered1、残2、報酬未発生 | guild.deliver / model + EXE | 通過 |
| Q02/Q03 売却と再試行 | 部分納品後残2個売却、納品、再購入 | 未所有時拒否、再入手で完了 | guild.trade/deliver / model | 通過、EXE未検証 |
| Q04 二重報酬 | 同依頼を再claim | 正常版残高不変、bug版+20 | guild.claim / model + EXE | 正常版・double_reward差分検出 |
| I01 スタック・並べ替え | crystal/herb/rope所持、herb選択しsort | 選択herb維持、bug版ropeへずれ | main inventory / EXE | 実行結果を evidence-sort_target で記録 |
| N01 期限・順序 | day1受注、3回翌日 | day4期限切れ、在庫補充、金不変 | guild.next_day / model + EXE boundaries | 通過、期限切れ後のclaimで経済状態不変 |
| N02 待機 | 新規、入力せず1.2秒 | day1維持、翌日ボタンでday2 | main / EXE | headless通過、長時間未検証 |
| P01〜P03 保存復元 | 部分納品後・報酬後保存/再開 | 正確な納品数、二重受領なし、完了後結果復元 | restore + save/load / model + EXE | headlessと別プロセス復元通過、82Gと全done保持 |
| P04 不正保存 | schema不一致 | invalid_save、現状態保持 | guild.restore / model | schema拒否通過、破損型の全網羅なし |
| F01 一巡・再プレイ | 会話→仕入れ→受注→納品→claim3件 | result、全done、再プレイ60G day1 | main / EXE | headless通過、人間GUI操作未検証 |
| U01 ポーズ・戻る・背面入力 | 確認画面とpauseへ | confirm/cancelのみ、resumeで復帰 | main / EXE tree | treeで背面操作不存在確認、実キーボード未検証 |
| U02 言語・画面サイズ | settingsで英語と880 | 読める、はみ出しなし、操作可能 | main / EXE | semantic操作通過、画像と実画面未検証 |
| X01 探索的プレイ | 目的=全納品、制約=通常操作、日付進行なし、seed137で依頼順・受注/購入順を選ぶ | 仕入れ/売却の別順序でも整合、売却不足拒否後の再入手で全done | tests/exe-test.ts explore / EXE | headless通過、初期条件・探索順・全操作をtranscriptへ保存 |

正常版・個別bug版の EXE は `tests/exe-test.ts` が Gua `get_version`、`get_ui_tree`、`click_node`、`poll_events`、`get_observe_snapshot` を使用する。requestId に対応する完了を要求し、timeout と観測欠落は失敗。専用クリア操作やメモリ書換はない。headless は画面サイズを物理検証できないため、この行は semantic到達のみ。

実行時に初回 bug 試験が旧残存プロセスの desk に接続したため `missing start on desk` で失敗した。無効な実行として扱い、担当EXEのPID確認・終了後に新規プロセスで再実行。各runの初期bugs一致をassertする修正を加えた。

最終 headless 実行は [evidence/headless-windows.zip](evidence/headless-windows.zip) に保存。build hash と source commit は [manifest.json](evidence/manifest.json)。モデル26項目、正常版・別プロセス復元・探索・3不具合版の6ケースは全通過。I01 は正常herb保持／sort_targetのropeずれを確認済み。headless画像は unavailable。

独立read-onlyレビューを1回実施し、3件の具体的指摘を修正した。

1. 店在庫が補充で20になった後の売却で20超となり正常保存が復元不能: `stock_full` のatomic拒否、S08/P06回帰を追加。
2. 数量LabelがHBox内で幅1px: autowrap解除と最小幅150、EXE tree boundsの検証を追加。
3. requestId欠落時の完了確認省略: 正の安全整数receiptを必須とし、完了requestIdとnodeIdを照合。

修正後のモデル26項目と最終再exportした EXE の全4モードで確認した。隔離APPDATAにtemplateがなくexport失敗→古いEXEで数量幅検証が失敗した試行は成功扱いしない。既存templateを担当APPDATAへコピーした上でexport成功と更新を確認し、その後の証拠を保存した。

クリーンキャッシュで `--headless --editor --import --quit` は Windows 2025/2022 CIとローカルで import 終了時access violation (-1073741819、stderr空) を再現した。既存キャッシュでは再現しなかった。初回を `--headless --editor --quit-after 180 --max-fps 60` に置き換えた新規コピーは終了0。失敗無視や自動成功化はせず、build.ps1 は全stageの終了0・stderr・モデル完了・配布物を必須確認する。GUI型GodotはPowerShell直接呼出しが完了待機しないため明示Processを使用。先行runの緑は受入証拠から除外。

## 2026-10-29 再開検証

再起動後に古いPIDを停止せず、process pathと現在identityを照合し、担当EXEの残存なしを確認してGUIを起動した。正規Computer Useのアプリ選択は返ったが、続く画像取得はギルド画面ではなく `Allow Codex to use guild?` の承認UIだった。承認完了と正しい対象画面を確認できないため通常入力を実施せず停止した。承認UIは操作せず、別の画面取得・入力経路にも切り替えていない。担当プロセスはpath照合で停止し、その後の別読み取りで残存なしを確認、GUI枠を解放した。GUI画面・キーボード/マウス・目視の言語/サイズ検証は未完了。

非GUIは `boundaries` ケースを追加し、通常操作だけで会話前受注拒否、購入残高不足、1/9数量飽和、鞄3種、9個スタック、在庫0、売却→再購入、在庫20で売却拒否、拒否後保存ロード、day4期限切れと報酬拒否を実EXE/Guaで確認した。各拒否で残高・品数・在庫が不変なことをassert。操作とObserveの生証拠は [boundaries-windows.zip](evidence/boundaries-windows.zip)。保存状態はゲーム本来の操作で生成し、注入や専用クリアは使っていない。

承認された空mainの初期commitは `8a51b044d3268257b25b82c16d027b3715c811fb`、treeは空tree `4b825dc642cb6eb9a060e54bf8d69288fbee4904`。既存の実装履歴を保持し、別PR用ブランチに空mainをmergeして共通祖先を設ける。default設定変更、ゲーム実装のmainマージ、自動マージ、正式Approve投稿、Release公開は行わない。

未完了条件は GUI承認と正しい対象画面、画像・人間入力・実画面でのJA/EN/resize。音は仮素材段階で未実装。headlessの成功はこれらの代わりにしない。結果の更新時に未実施を成功へ読み替えない。
