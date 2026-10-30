# 開発ガイド（SurvivorComforts）

## フォルダ構成

```
SurvivorComforts\           リポジトリのルート（git clone した場所）
├── docs\                     調査メモ、機能一覧（features.md）、このガイド
│   └── features\             機能ごとの要望・調査結果・仕様・確認項目（Fxx_名前.md）
├── tools\
│   ├── check.ps1             Luaの構文チェック（ゲーム本体のコンパイラを使う）
│   ├── deploy.ps1            ゲームから読める場所へMODをコピーする
│   ├── test_server.ps1       テスト用のサーバーとゲーム2つを Steam なしで起動する（1台で複数人を試す）
│   ├── GameDir.ps1           ゲームのフォルダを探す共通処理
│   ├── make_icons.ps1        左のアイコン用の画像（media\ui\SurvivorComforts）を作り直す
│   ├── make_preview.ps1      Workshopの画像（preview.png）とMOD一覧の画像（poster.png）を作り直す
│   └── LuaSyntaxCheck.java   check.ps1 が使うチェッカー
└── mod\SurvivorComforts\           Workshopにアップロードする単位
    ├── preview.png                Workshopに表示する画像（256x256ちょうど、1000KB以下）
    └── Contents\mods\SurvivorComforts\
        ├── common\                    B42で必須（空でも置いておく）
        └── 42\
            ├── mod.info
            ├── poster.png             ゲームのMOD一覧に表示する画像
            └── media\lua\
                ├── client\SurvivorComforts\
                │   ├── Core.lua           共通処理とMod Options
                │   ├── CraftMenu.lua      制作・建築の画面の右クリックメニュー（F03・F06で共通）
                │   ├── F03_RecipeTrail.lua
                │   ├── F04_ReadingTime.lua
                │   ├── F06_Wishlist.lua
                │   ├── F07_CookingStack.lua
                │   ├── F08_SkillsWindow.lua
                │   ├── F09_PlayerList.lua
                │   ├── F10_HidePvP.lua
                │   ├── F12_ItemRecipes.lua
                │   ├── F13_HideUserPanel.lua
                │   ├── Recipes.lua        「レシピを見る」の処理と「戻る」の履歴（F03・F06・F12で共通）
                │   └── Sidebar.lua        画面左のアイコンにボタンを並べる。画面の下に近づいたら次の列へ。本体のボタンを隠して詰める（F06・F08・F09・F10・F13で共通）
                ├── server\SurvivorComforts\
                │   ├── F06_SharedWishlist.lua  みんなのウィッシュリストの保存と配信（サーバーで動く）
                │   └── F09_PlayerList.lua      最終ログインの記録と配信（サーバーで動く。シングルでは動かない）
                └── shared\Translate\
                    ├── EN\UI.json
                    └── JP\UI.json
```

- 機能ごとに `client\SurvivorComforts\Fxx_機能名.lua` を1ファイル作る。仕様と確認項目は `docs\features\Fxx_名前.md` に書く（[features.md の「新しい機能を足すとき」](features.md#新しい機能を足すとき)）。
- 各機能は `SurvivorComforts.registerFeature()` で Mod Options に「有効にする」のチェックボックスを登録し、処理の入口で `SurvivorComforts.isEnabled("Fxx")` を確認する。
  - 機能だけの設定は、`registerFeature` の `addOptions` の中で足す。順番は「左のアイコンにボタンを表示する」→ 開く/閉じるキー → その機能だけの設定、にそろえる。
  - 設定画面での機能の並び順は、`Core.lua` の `OPTIONS_ORDER` で決める（ファイル名の順ではない）。今は「画面左のボタン（F08・F06・F09。ボタンと同じ順）」「レシピ（F12・F03）」「普段の行動（F07・F04）」「マルチプレイ（F10・F13）」の順。新しい機能を足したら、近い機能の隣に入れる。
- 処理は `SurvivorComforts.safeCall()` で囲み、エラーがほかの機能に波及しないようにする。
- 表示する文字列は `UI.json`（EN と JP）に追加し、`getText("UI_SurvivorComforts_...")` で使う。

## 変更してから試すまで

1. 構文チェック
   ```
   powershell -File tools\check.ps1
   ```
   - JDK（13以降）が必要。チェッカーをコンパイルするのに使う（実行にはゲーム本体のJavaを使う）
   - ゲームと javac の場所は自動で探す
     - ゲーム：Steamのライブラリフォルダ（レジストリと `libraryfolders.vdf`）の `steamapps\common\ProjectZomboid`
     - javac：`JAVA_HOME`、PATH上の `javac`、`C:\Program Files\Java\jdk*` の順
   - 見つからないときや別の場所を使うときは、引数か環境変数で指定する
     ```
     powershell -File tools\check.ps1 -GameDir "E:\Games\ProjectZomboid" -Javac "C:\jdk\bin\javac.exe"
     ```
     （環境変数なら `PZ_GAME_DIR` と `JAVAC`）
2. ゲームから読める場所へコピー（`%USERPROFILE%\Zomboid\Workshop\SurvivorComforts`）
   ```
   powershell -File tools\deploy.ps1
   ```
3. ゲームを起動し、メインメニューの「MOD」で **Survivor Comforts** を有効にする。
4. シングルプレイ（またはホストしたマルチプレイ）で確認する。
   - エラーは `%USERPROFILE%\Zomboid\console.txt` に出る。`[SurvivorComforts]` で検索する。
   - デバッグモード（起動オプション `-debug`）なら、ゲーム内でLuaを再読み込みできる。
5. 機能ごとの確認項目は、[features/](features/) のその機能のファイルの「確認項目」にある。

## 1台で複数人を試す

マルチプレイの機能（F06 のみんなのリスト、F09 など）を1台で2人分試すときは、次のコマンドでテスト用のサーバーとゲーム2つを起動し、それぞれ別のユーザー名で `127.0.0.1`（ポート `16261`）に入る。MODを直したら、サーバーを止めて（サーバーの画面で `quit`）もう一度実行する。
```
powershell -File tools\test_server.ps1
```
- Steam なしで動かすので、データは `%USERPROFILE%\PZTest` の下に分けて置かれ、普段のセーブやオプションには触れない
- サーバーのログは `%USERPROFILE%\PZTest\server\server-console.txt`、設定は `server\Server\sctest.ini`（管理者のパスワードは `admin`）
- サーバー・ゲームとも最大3GBずつメモリを使う。合わせて10GB前後空けておく
- 2人目に入ってもらえるなら、ゲーム内の「ホスト」で立てたサーバーでもよい

## Workshopへのアップロード（限定公開）

公開範囲は **「未掲載」（Unlisted）** にする。Workshopの検索や一覧には出ず、URLを知っている人だけがサブスクライブできる。「非公開」（Private）にすると、サーバーやほかのプレイヤーがダウンロードできないので使わない。

### 事前の準備
- アップロードする前に、構文チェック・確認項目のテストを済ませておく。
- 画像はリポジトリに入っている（`preview.png`、`poster.png`）。デザインを変えたときだけ作り直す。
  ```
  powershell -File tools\make_preview.ps1
  ```
- Steamのアカウントで、Steamワークショップの利用規約に同意している必要がある（初めてのときはアップロード画面に案内が出る）。

### 初回のアップロード
1. 最新の状態をゲームから読める場所へコピーする。
   ```
   powershell -File tools\deploy.ps1
   ```
2. ゲームを起動し、メインメニュー →「WORKSHOP」→「アイテムの作成と更新」を選ぶ。
3. 「アイテムのディレクトリを選択」で **SurvivorComforts** を選ぶ（`%USERPROFILE%\Zomboid\Workshop\` の中のフォルダが並ぶ）。
4. 「アイテム詳細を編集」で次を入力する。
   - タイトル：`Survivor Comforts`
   - 説明：README の「機能」の内容を元に書く（後からSteamのページでも直せる）
   - タグ：Build 42、Interface など
   - 公開設定：**未掲載**
   - 画像プレビューに `preview.png` が表示されていることを確かめる
5. 「新規もしくは既存のアイテムですか?」で「新規のWORKSHOPアイテムです」を選ぶ。
6. 「アイテムの公開準備」で、必要なら「変更履歴の編集」に内容を書き、「Steam WORKSHOPにアップロード!」を押す。
7. 終わると、ゲームが `%USERPROFILE%\Zomboid\Workshop\SurvivorComforts\workshop.txt` に **Workshop ID**（数字）を書き込む。
   - deploy.ps1 はこのファイルを上書きしない。消すと次回「新規」扱いになり、別のアイテムができてしまうので注意。
   - リポジトリには入れない（`.gitignore` 済み）。IDはメンバーに伝える。
8. 「作成したアイテムをSteamオーバーレイで開く」でページを開き、公開範囲が「未掲載」になっていること、URL（`https://steamcommunity.com/sharedfiles/filedetails/?id=<Workshop ID>`）を確かめる。

### 更新するとき
1. `tools\check.ps1` → `tools\deploy.ps1` を実行する。
2. メインメニュー →「WORKSHOP」→「アイテムの作成と更新」→ SurvivorComforts を選ぶ。`workshop.txt` があるので、既存のアイテムの更新になる。
3. 「変更履歴の編集」に変更内容を書いてアップロードする。
4. サーバーは再起動すると新しい版をダウンロードする。プレイヤーも、接続時に新しい版が自動で入る。
   - `mod.info` の `modversion` を上げておくと、どの版か分かりやすい。

### サーバーに入れる
- サーバーの設定（`servertest.ini` などの `<サーバー名>.ini`）に次の2つを書く。
  - `WorkshopItems=` に Workshop ID（ほかのMODがあれば `;` で区切って追加）
  - `Mods=` に MOD の ID `SurvivorComforts`（同じく `;` 区切り）
- ゲーム内の「ホスト」→ サーバー設定の編集画面の「Steamワークショップ」「MOD」から選ぶと、正しい形で書き込まれるので確実。
- 書き方が合っているかは、サーバーを起動したときの `console.txt` に `SurvivorComforts` を読み込んだ記録が出ることで確かめる。
