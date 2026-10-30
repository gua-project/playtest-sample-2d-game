# テスト契約

[実行方法・責務](testing.md) と合わせて使う。ここには再現条件と判定基準を置き、実行日時・対象SHA・成否は[検証記録](evidence/README.md)から確認する。GUIとPlaytest E2Eは未検証のままである。

## 共通初期条件

ゲーム仕様版は `guild-v1`。新規開始はday1、60G、空bag、未読会話、全依頼open/納品0、在庫は薬草12・ロープ8・水晶6・地図5。価格は順に4/8/12/6G、売値は半額。鞄は3種類・各9個まで、店在庫上限は20、数量は1〜9。sourceテストは新規プロセスと専用save/APPDATA、日本語から開始する。

通常版の有効bug配列は `[]`、個別比較は `[対象ID]` と厳密に一致させる。初期画面と開始/リセット/再プレイ後に照合し、別bugの混入を許さない。テスト用bug引数やモデルfixtureと、通常プレイの操作を区別する。source回帰では専用クリア操作や状態書換で進行を迂回しない。

ゲームに乱数・シード入力はない。初期条件は決定的である。探索seed137は[Playtest引継ぎ](playtest-handoff.md)の探索側の条件であり、ゲームの乱数ではない。

## 固定source UI回帰

実装は [GuildTests.cs](../tests/Guild.Regression/GuildTests.cs)。操作は通常のUIボタン、判定は公式UI tree/Observeで行う。missing、timeout、未完了、欠落Observeは失敗とする。

| テスト / 対応ID | 初期条件・手順 | 独立した期待結果・判定対象 |
|---|---|---|
| `StartCompleteReplayAndSettings` / F01, U01, U02 | 通常版。会話→薬草3/ロープ2/水晶2を仕入れ→3件受注→1個ずつ納品/報酬→設定で英語と880→復帰/再プレイ | 仕入れ後8G、全完了でresult/82G、再プレイ60G/day1。英語ボタンのsemantic存在。物理的な画面サイズ・文字欠け・入力は判定しない |
| `SavePartialAndClaimAcrossSourceProcesses` / P01〜03 | 薬草3を購入して受注、1個納品後に保存しsourceプロセス終了・再開。残り納品と報酬後にも保存・再開して再claim | 部分納品1/3と残2個を復元。初回報酬後68G、再開後の二度目claimでも68G・doneを保持 |
| `EconomicBoundariesAndCancelledConfirmation` / S01〜08, U01 | 購入確認を取消。水晶6/9購入を試す。3種類所持後の地図購入、薬草9所持後の追加購入、day10で在庫20の店へ売却、拒否後保存/ロード | 確認画面は `confirmation` で背面 `back` が存在しない。取消・各拒否でgold/bag/stock不変。残高不足は `gold_low`、数量は1/9で飽和、数量label幅は150以上。拒否後保存復元でも経済状態を保持 |
| `SoldSuppliesRecoverAndDeadlinesAdvanceOnlyExplicitly` / D01, Q02〜03, N01〜02 | 通常版。1.2秒待機、会話前受注、会話後に薬草3を仕入れて1個売却、2個納品と不足納品、1個再購入して完了。ロープ受注後に翌日を5回進める | 待機でday1/60G/空bagを保持。会話前はopen。未所持の追加納品は進まずactive、経済状態不変。再入手で復帰。day6のロープはexpiredでclaimによる経済変化なし |
| `StockZeroSaleAndReacquisition` / S07 | 薬草9購入→3個納品→追加3購入→在庫0で追加購入→1個売却/再購入 | 在庫0時は `stock_low`、gold/bag/stock不変。売却で在庫1、再購入で在庫0・bag薬草9へ戻る |
| `CancelBugComparison` / S02, B01（2ケース） | 正常/`cancel_charge`を別々に起動。薬草1の購入確認を検証して取消 | 正常60G、bug56G。確認screenとback不在、bug配列の厳密一致も検証する |
| `RewardBugComparison` / Q04, B02（2ケース） | 正常/`double_reward`。薬草3購入→受注/納品→同じ報酬を2回claim | 正常68G、bug88G。正常の二重受領防止と、個別bugの追加20Gを区別する |
| `SortBugComparison` / I01（2ケース） | 正常/`sort_target`。薬草1/ロープ1を購入し、薬草を選択して並べ替え | 正常の選択はherbを保持、bugではropeへずれる。個別bug配列と比較する |
| `OfficialHostOnlyNavigation` / 接続最小経路 | 第二のObserve接続を置かず、公式ホストで開始→店→購入確認→取消 | 通常ボタンの相関完了と、戻り先screenがshopであること |

## モデル回帰

[model_test.gd](../tests/model_test.gd) のfixture設定は純粋なモデルテストに限定する。UI/EXEで同じ状態を注入したという意味ではない。

| ID | 初期条件・操作 | 期待結果 |
|---|---|---|
| D01, S01, Q01 | 未読で受注、既読後に薬草3を受注前購入して1個納品 | 未読は `talk_first`、購入後48G、受注と部分納品が成立 |
| P01/P02, Q02/Q03 | 部分状態をJSON往復し、残2個売却→納品→2個再購入/納品/報酬 | 1/3と残2を復元、未所持納品は拒否、再入手で完了可能 |
| Q04, S02, F01, P03 | 報酬再claim、購入取消、全3件完了、報酬後restore/reclaim | 正常版は二重報酬なし、取消で残高不変、全done、復元後も重複なし |
| S03/S04/S05 | モデルfixtureで1000G、薬草9、3種類所持、数量0/10 | stack/種類上限の拒否と経済状態保持、0/10は `invalid_quantity` |
| S06/S07 | モデルfixtureで金0、または在庫0/100G | `gold_low` / `stock_low`、在庫・残高不変 |
| S08/P06 | 薬草9購入後に翌日9回、在庫20へ売却/restore | `stock_full` でgold/bag/stock不変、正常保存を復元可能 |
| N01 | 既読/受注した薬草依頼で翌日3回 | day4でexpired、60G保持。期限判定は日付加算後・在庫補充前 |
| P04/P05 | 保存version不一致、品数がstring/null/1.5/bool | restoreを拒否。保存破損全般やI/O障害を網羅したとは扱わない |
| B01/B02 | モデルfixtureで個別bugを有効化し取消、またはdoneの報酬claim | `cancel_charge`は56G、`double_reward`の追加claimは80G。正常期待値60Gとの差を検出 |

## 限定配布smokeの契約

`scripts/smoke-exe.ps1` が通常版EXEをheadlessで1つ起動し、公式 `Gua.Testing` でcore/plugin versionが1.1.2、screenがtitle、開始/ロードがvisibleであることを確認する。明示選択した1テストのTRXがexecuted=1/passed=1であることと、port8793の唯一のLISTEN所有PIDが起動したEXEのPIDと一致することを要求する。EXE hashとPIDを存命中に記録し、終了する。別プロセスの成功を対象buildへ帰属させない。

このsmokeはプレイ・保存復元・探索・GUI・Scenario・Trace/Recording/Replayを検証しない。

## 判定上の制約

観測値から期待値を自己生成しない。状態・semantic UIで判定できる項目と、画像・物理入力・実機環境を必要とする項目を区別する。GUIは未検証、音は未実装。短時間の待機確認は長時間安定性を保証しない。複数接続timeoutの根本原因は未確定で、source/smokeの成功もPlaytest E2Eや一般的なQA網羅を意味しない。
