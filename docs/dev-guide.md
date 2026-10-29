# 開発ガイド（SurvivorComforts）

## フォルダ構成

```
D:\Document\claude\Zomboid\
├── docs\                     調査メモ、機能リスト、このガイド
├── tools\
│   ├── check.ps1             Luaの構文チェック（ゲーム本体のコンパイラを使う）
│   ├── deploy.ps1            ゲームから読める場所へMODをコピーする
│   ├── make_icons.ps1        左のアイコン用の画像（media\ui\SurvivorComforts）を作り直す
│   └── LuaSyntaxCheck.java   check.ps1 が使うチェッカー
└── mod\SurvivorComforts\           Workshopにアップロードする単位
    └── Contents\mods\SurvivorComforts\
        ├── common\                    B42で必須（空でも置いておく）
        └── 42\
            ├── mod.info
            └── media\lua\
                ├── client\SurvivorComforts\
                │   ├── Core.lua           共通処理とMod Options
                │   ├── F07_CookingStack.lua
                │   └── F08_SkillsWindow.lua
                └── shared\Translate\
                    ├── EN\UI.json
                    └── JP\UI.json
```

- 機能ごとに `client\SurvivorComforts\Fxx_機能名.lua` を1ファイル作る。
- 各機能は `SurvivorComforts.registerFeature()` で Mod Options に「有効にする」のチェックボックスを登録し、処理の入口で `SurvivorComforts.isEnabled("Fxx")` を確認する。
- 処理は `SurvivorComforts.safeCall()` で囲み、エラーがほかの機能に波及しないようにする。
- 表示する文字列は `UI.json`（EN と JP）に追加し、`getText("UI_SurvivorComforts_...")` で使う。

## 変更してから試すまで

1. 構文チェック
   ```
   powershell -File tools\check.ps1
   ```
2. ゲームから読める場所へコピー（`%USERPROFILE%\Zomboid\Workshop\SurvivorComforts`）
   ```
   powershell -File tools\deploy.ps1
   ```
3. ゲームを起動し、メインメニューの「MOD」で **Survivor Comforts** を有効にする。
4. シングルプレイ（またはホストしたマルチプレイ）で確認する。
   - エラーは `%USERPROFILE%\Zomboid\console.txt` に出る。`[SurvivorComforts]` で検索する。
   - デバッグモード（起動オプション `-debug`）なら、ゲーム内でLuaを再読み込みできる。

## F08 スキルウィンドウの確認項目

- [ ] オプション →「MOD」タブに「Survivor Comforts」→「スキルウィンドウ」が表示される
- [ ] `K` キー（変更可）でウィンドウが開閉する
- [ ] ウィンドウの右下をドラッグして大きさを変えられ、勝手に縦に伸びない
- [ ] スキルが多いとスクロールできる（マウスホイール）
- [ ] 経験値やレベルが本体のスキル画面と同じように更新される
- [ ] ゲームを保存して再開すると、位置・大きさ・開いていたかどうかが元に戻る
- [ ] 死亡して新しいキャラクターで始めても、新しいキャラクターのスキルが表示される
- [ ] 「有効にする」を外すと、キーを押しても開かない
- [ ] 本体のキャラクター情報（スキルタブ）が今まで通り動く
- [ ] マルチプレイ（ローカルで立てたサーバー）でも同じように動く

左のアイコンのボタン（設定「左のアイコンにボタンを表示する」、初期値ON）
- [ ] 画面左のアイコンの一番下に棒グラフのボタンが出て、マウスを乗せると「スキル」と出る
- [ ] クリックでスキルウィンドウが開閉し、開いている間はボタンが色付きになる
- [ ] 設定をOFFにするとボタンが消え、アイコンの枠も縮む（ONに戻すと再び出る）
- [ ] オプションの「サイドバーの大きさ」を変えても、ボタンがほかのアイコンと同じ大きさで出る

スキルタブを隠す（設定「キャラクター情報のスキルタブを隠す」、初期値OFF）
- [ ] ONにすると、情報・健康・保護などのウィンドウからスキルのタブが消える
- [ ] 本体のスキルのキー（初期値 `L`）で、本体のタブではなくスキルウィンドウが開く
- [ ] スキルタブを開いた状態でONにしても、ほかのタブに切り替わって表示が崩れない
- [ ] OFFに戻すと、スキルのタブが元の位置（2番目）に戻る
- [ ] ONのまま保存して再開しても、スキルのタブが別ウィンドウとして出てこない

## F07 料理の食材をまとめるの確認項目

準備：鍋の水（スープ）やボウル（サラダ）などと、同じ食材を複数（食べかけを含む）、塩などの調味料を複数持っておく。

- [ ] オプション →「MOD」に「料理の食材をまとめる」が表示される
- [ ] 鍋などを右クリック →「スープ」などの中で、同じ食材が1行にまとまり、「（3個）」のように数が出る
- [ ] 調味料（塩、コショウなど）も1行にまとまる
- [ ] 選ぶと、食べかけなど残りが一番少ないものが使われる（何度か続けて加えて確かめる）
- [ ] 腐った食材・凍った食材・調理済みの食材は、普通の食材とは別の行になる
- [ ] 凍っていて加えられない食材は、本体と同じく選べない表示（理由のツールチップ付き）になる
- [ ] 床や棚の容器にある食材も、本体と同じく一覧に出て、選ぶと取ってきて加える
- [ ] 「ランダムに加える」（食材の種類ごと）は本体と同じように出る
- [ ] 「有効にする」を外すと、本体と同じ一覧に戻る
- [ ] マルチプレイ（ローカルで立てたサーバー）でも同じように動く

## Workshopへのアップロード（まだ行わない）

- `mod\SurvivorComforts\` に `preview.png`（256x256）と、必要なら `42\poster.png` を用意する。
- deploy した後、メインメニュー →「Workshop」から SurvivorComforts を選び、公開範囲を **限定公開（Unlisted）** にしてアップロードする。
- 初回のアップロード後、ゲームが `%USERPROFILE%\Zomboid\Workshop\SurvivorComforts\workshop.txt` にWorkshop IDを書き込む。deploy.ps1 はこのファイルを上書きしない。
