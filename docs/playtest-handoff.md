# Playtest引継ぎ

[テスト責務と実行方法](testing.md)・[テスト契約](test-matrix.md)と合わせて使う。source回帰と限定配布smokeの成功は配布EXEのPlaytest E2Eの完了を意味しない。

## 接続・環境・対象build

Windows x64、Godot `4.7.stable.official.5b4e0cb0f`、正式Gua `1.1.2` を使用する。配布物はCI artifact `guild-windows` の `guild.exe` と同梱DLL。CI artifactには保持期限があり、恒久保存された証拠とは扱わない。実行対象のEXE SHA256とcommitを取得し、Scenario ID/revision・環境・独立期待値と結び付ける。過去のbuild hashは現在の対象の証拠ではない。

bridgeは `ws://127.0.0.1:8793`（`GUA_BRIDGE_PORT`で変更可）。別サンプルとportを共有しない。保存先は `%APPDATA%/GuaSampleGuild2D/guild-save.json`、検証時は `--save-path=C:/absolute/path/save.json` で固有のsave/outputを用意する。通常版はbug引数なし、個別比較は `--bug=cancel_charge` / `--bug=double_reward` / `--bug=sort_target` のいずれか1つ。新規開始・リセット・再プレイはフラグを引き継ぎ、ロードは保存時のフラグを復元するため、初期条件と有効bug配列を照合する。

EXEのlaunch/attach、探索、Scenario、予算、cleanup、Trace/Recording/Replayの統合はGua Playtestの責務。サンプル内に第二のE2E runnerを設けない。標準auto adapterとObserve v1を使用し、独自公開フィルタや専用クリア操作で通常プレイを迂回しない。

## Playtestへ引き継ぐE2E条件

[playtest-handoff.json](playtest-handoff.json) は引継ぎメタデータであり、実行可能Scenarioや実行結果ではない。Scenario ID/revision、budget、実build SHA256/commitは実行対象を決めて記録する。通常完了の独立期待値は、初期60Gから仕入れ52G・報酬74Gを経た82G、全3依頼done。期限は薬草/ロープ/水晶でday3/5/7、報酬20/24/30、必要数3/2/2。

X01の探索条件はseed137、目的は全3件done、制約は通常操作のみ・日付を進めない・購入取消を挟む・納品予定品の売却不足を確認して再入手すること。依頼順と受注/購入順を探索側で選ぶ。配布版の保存再起動（部分納品後/報酬後/全完了後）、個別bug比較、実画面JA/EN/resize、入力、Trace/Replayの統合はPlaytest側で検証する。いずれも現行の受入完了とは扱わない。

## 未実行範囲と判定制約

Scenario ID/revision、実行budget、対象build hash/commitは未割当で、Playtest E2E・Trace/Recording/Replayは未実行。GUIの通常入力・実画面JA/EN/resizeも未検証。音は未実装である。source sceneのsemantic確認や限定smokeをこれらの合格へ転用しない。

複数接続timeoutの根本原因は未確定。[同期・判定制約](testing.md)と[比較記録](evidence/test-responsibility.md)を参照する。[証拠索引](evidence/README.md)の旧境界ZIP単独ではゲームEXE SHAが記録されておらず、別runのhashを帰属させない。観測値から期待値を自己生成せず、画像・物理入力・実機を要する項目は対応する証拠がなければ未検証とする。
