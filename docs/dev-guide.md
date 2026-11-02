# 開発ガイド（SurvivorComforts）

## フォルダ構成

```
SurvivorComforts\           リポジトリのルート（git clone した場所）
├── LICENSE                   MIT ライセンス（deploy.ps1 が MOD の中にも LICENSE.txt としてコピーする）
├── README.md                 MOD の紹介と、各ドキュメントへのリンク
├── docs\                     遊ぶ人向けのページ（feature-list.md、install.md、install-server.md）、開発手順（development.md）、テスト（testing.md）、フォルダ構成（folders.md）、調査メモ、機能一覧（features.md）、このガイド、点検の結果（review-日付.md）
│   └── features\             機能ごとの要望・調査結果・仕様・確認項目（Fxx_名前.md）
├── tools\
│   ├── check.ps1             Luaの構文チェック（ゲーム本体のコンパイラを使う）と、翻訳キー・ゲームのLuaにない関数の点検
│   ├── deploy.ps1            開発用のフォルダ（%USERPROFILE%\PZDev\Workshop）へMODをコピーする（LICENSE も MOD の中へ LICENSE.txt として入れる）
│   ├── dev_game.ps1          deploy.ps1 でコピーして、開発用のフォルダでゲームを Steam ありで起動する（試す・アップロード）
│   ├── test_server.ps1       テスト用のサーバーとゲーム2つを Steam なしで起動する（1台で複数人を試す）
│   ├── test_debug.ps1        ゲームをデバッグモードで Steam なしで起動する（アイテムを出して試す）
│   ├── TestLaunch.ps1        test_server.ps1・test_debug.ps1・dev_game.ps1 の共通処理
│   ├── GameDir.ps1           ゲームのフォルダを探す共通処理
│   ├── make_icons.ps1        左のアイコン用の画像（media\ui\SurvivorComforts）を作り直す
│   ├── make_english_names.ps1 英語名の表（EnglishNames.lua）を作り直す。ゲームを更新したら実行する
│   ├── make_preview.ps1      Workshopの画像（preview.png）とMOD一覧の画像（poster.png、icon.png）を作り直す
│   ├── LuaSyntaxCheck.java   check.ps1 が使う構文チェッカー
│   └── ModRules.java         check.ps1 が使う点検（翻訳キー、ゲームのLuaにない関数）
├── mod-tests\SurvivorComfortsTests\  テスト用の MOD（Workshop には上げない。docs\testing.md）
└── mod\SurvivorComforts\           Workshopにアップロードする単位
    ├── preview.png                Workshopに表示する画像（256x256ちょうど、1000KB以下）
    └── Contents\mods\SurvivorComforts\
        ├── common\                    B42で必須（空でも置いておく）
        └── 42\
            ├── mod.info
            ├── poster.png             ゲームのMOD一覧に表示する画像
            ├── icon.png               ゲームのMOD一覧で名前の横に出すアイコン（64x64）
            └── media\lua\
                ├── client\SurvivorComforts\
                │   ├── Commands.lua       サーバーとのやり取り（画面側）。サーバーに送る、サーバーから届いたものを機能に渡す（F06・F09で共通）
                │   ├── Core.lua           共通処理とMod Options
                │   ├── EnglishNames.lua   英語名の表（F14。tools\make_english_names.ps1 で作る。手で直さない）
                │   ├── CraftMenu.lua      制作・建築の画面の右クリックメニュー（F03・F06で共通）
                │   ├── F02_InventorySearch.lua
                │   ├── F03_RecipeTrail.lua
                │   ├── F04_ReadingTime.lua
                │   ├── F06_Wishlist.lua
                │   ├── F07_CookingStack.lua
                │   ├── F08_SkillsWindow.lua
                │   ├── F09_PlayerList.lua
                │   ├── F15_MemberSkills.lua
                │   ├── F10_HidePvP.lua
                │   ├── F12_ItemRecipes.lua
                │   ├── F13_HideUserPanel.lua
                │   ├── F14_EnglishSearch.lua
                │   ├── Recipes.lua        「レシピを見る」の処理と「戻る」の履歴（F03・F06・F12で共通）。レシピの材料・完成品のアイテムを1つずつ調べる処理（制作の画面の右クリック・F14でも使う）
                │   ├── Search.lua         検索の決まり（語の区切り方、ひらがなとカタカナを区別しない、英語名・日本語名で比べる）。F14・F02で共通
                │   ├── Sidebar.lua        画面左のアイコンにボタンを並べる。画面の下に近づいたら次の列へ。本体のボタンを隠して詰める（F06・F08・F09・F10・F13で共通）
                │   └── Window.lua         機能のウィンドウの作り（プレイヤーごとに作る・開閉・閉じたら画面から外す・位置と大きさを覚える）と、それを開く画面左のボタン・キー・その2つの設定。F06・F08・F09で共通
                ├── server\SurvivorComforts\
                │   ├── CommandLimit.lua        1人が送れるコマンドの回数の制限（F06・F09で共通）
                │   ├── F06_SharedWishlist.lua  みんなのウィッシュリストの保存と配信（サーバーで動く）
                │   ├── F09_PlayerList.lua      最終ログインの記録と配信（サーバーで動く。シングルでは動かない）
                │   ├── F15_MemberSkills.lua    頼まれたプレイヤーのスキルを読んで返す（サーバーで動く。シングルでは動かない）
                │   └── ServerCommands.lua      サーバーとのやり取り（サーバー側）。届いたものを回数の制限を通して機能に渡す、送る（シングルプレイでは画面側に直接渡す）。F06・F09で共通
                └── shared\
                    ├── SurvivorComforts\
                    │   ├── Admin.lua           管理者の判定（キックできる人）。画面側とサーバー側の両方で使う（F06・F13で共通）
                    │   ├── PlayerName.lua      プレイヤー名の取り方（ユーザー名。なければ表示名）。画面側とサーバー側の両方で使う（F06・F09・回数の制限で共通）
                    │   └── Skills.lua          スキルを順に見る・レベルを集める。画面側とサーバー側の両方で使う（F15）
                    └── Translate\
                        ├── EN\UI.json
                        └── JP\UI.json
```

- 機能ごとに `client\SurvivorComforts\Fxx_機能名.lua` を1ファイル作る。仕様と確認項目は `docs\features\Fxx_名前.md` に書く（[features.md の「新しい機能を足すとき」](features.md#新しい機能を足すとき)）。
- 各機能は `SurvivorComforts.registerFeature()` で Mod Options に「有効にする」のチェックボックスを登録し、処理の入口で `SurvivorComforts.isEnabled("Fxx")` を確認する。
  - 機能だけの設定は、`registerFeature` の `addOptions` の中で足す。順番は「左のアイコンにボタンを表示する」→ 開く/閉じるキー → その機能だけの設定、にそろえる。
  - 設定画面の並びと中項目（見出し）は、`Core.lua` の `OPTION_GROUPS` で決める（ファイル名の順ではない。2026-11-01 に整理）
    - 自分の設定がある機能は、機能の名前を中項目の見出しにし、その下に「有効にする」と自分の設定を並べる
    - 「有効にする」だけの機能は、見出しを作らない。機能の名前をそのままチェックボックスの名前にして、近い機能と1つの中項目にまとめる（自分の設定がある機能の中項目に入れてもよい。例：F15 は「プレイヤー一覧」の中）
    - 区切り線は中項目の間だけ
    - 今は「スキルウィンドウ（F08）」「ウィッシュリスト（F06）」「プレイヤー一覧（F09・F15）」「検索（F02・F14）」「読書の残り時間（F04）」「レシピと料理（F12・F03・F07）」「画面左のボタンを隠す（F10・F13）」の順。どこにも入れていない機能は、最後に自分の中項目で出る。新しい機能を足したら、近い中項目に入れる
    - 設定の ID（`F15_enabled` など）は並びと関係ないので、並びを変えても保存した値は引き継がれる
- 処理は `SurvivorComforts.safeCall()` で囲み、エラーがほかの機能に波及しないようにする。
- 表示する文字列は `UI.json`（EN と JP）に追加し、`getText("UI_SurvivorComforts_...")` で使う。

## 変更してから試すまで

1. 構文チェックと点検
   ```
   powershell -File tools\check.ps1
   ```
   - 構文のほかに、次を自動で点検する。どれかに引っかかると、最後に `ERROR` の行が出て失敗する
     - 翻訳キー：日本語（JP）と英語（EN）の `UI.json` に、同じキーがそろっているか。コードで使っているキー（`"UI_SurvivorComforts_..."`）が、両方にあるか。同じキーが2回書かれていないか
     - 使っていない翻訳キー：コードのどこにも出てこないキー。`"UI_SurvivorComforts_" .. 機能のID .. "_Key"` のように組み立てて使うキーは、最後の部分（`"_Key"`）がコードにあれば使っているとみなす。これは `WARN` で、失敗にはしない
     - ゲームの Lua（Kahlua）にない関数：標準の Lua 5.1 にはあるが、ゲームの Lua にはない関数（`next`、`xpcall`、`math.random`、`io` など）を使っていないか。ゲームの Lua にあるものは、ゲーム本体から毎回読み取るので、ゲームの更新で増えたり減ったりしても追いかける。`require` はゲームが別に用意しているので対象外。コメントと文字列の中は見ない
   - JDK（13以降）が必要。チェッカーをコンパイルするのに使う（実行にはゲーム本体のJavaを使う）
   - ゲームと javac の場所は自動で探す
     - ゲーム：Steamのライブラリフォルダ（レジストリと `libraryfolders.vdf`）の `steamapps\common\ProjectZomboid`
     - javac：`JAVA_HOME`、PATH上の `javac`、`C:\Program Files\Java\jdk*` の順
   - 見つからないときや別の場所を使うときは、引数か環境変数で指定する
     ```
     powershell -File tools\check.ps1 -GameDir "E:\Games\ProjectZomboid" -Javac "C:\jdk\bin\javac.exe"
     ```
     （環境変数なら `PZ_GAME_DIR` と `JAVAC`）
2. 開発用のフォルダにコピーして、そのフォルダでゲームを起動する（[開発用のフォルダ](#開発用のフォルダ)）
   ```
   powershell -File tools\dev_game.ps1
   ```
   - `deploy.ps1` で `%USERPROFILE%\PZDev\Workshop\SurvivorComforts` にコピーし、MOD を有効にした状態で、Steam ありでゲームを起動する
   - コピーだけなら `powershell -File tools\deploy.ps1`
3. シングルプレイ（またはホストしたマルチプレイ）で確認する。
   - エラーは `%USERPROFILE%\PZDev\console.txt` に出る。`[SurvivorComforts]` で検索する。
   - デバッグモード（`tools\dev_game.ps1 -Debug`）なら、ゲーム内でLuaを再読み込みできる。Steam なしのデバッグモードなら `tools\test_debug.ps1`（[デバッグモードで試す](#デバッグモードで試す)）
4. 機能ごとの確認項目は、[features/](features/) のその機能のファイルの「確認項目」にある。

## 開発用のフォルダ

いつも遊ぶゲーム（`%USERPROFILE%\Zomboid`）と、開発（試す・ワークショップに上げる）のデータを分けている（2026-11-01）。

| 使い道 | データのフォルダ | この MOD |
| --- | --- | --- |
| いつも遊ぶ（ほかのプレイヤーと同じ版） | `%USERPROFILE%\Zomboid` | Steam で購読したもの（ワークショップから自動で入る） |
| 開発・ワークショップへのアップロード | `%USERPROFILE%\PZDev` | `deploy.ps1` でコピーしたもの（`PZDev\Workshop\SurvivorComforts`） |
| テスト（Steam なし） | `%USERPROFILE%\PZTest` | `test_debug.ps1`・`test_server.ps1` でコピーしたもの |

- 分けている理由：ゲームは同じ MOD ID が2か所にあると、最初に見つかった方を使う。探す順は「ワークショップ用のフォルダ（`<データのフォルダ>\Workshop`）→ Steam で購読したもの → `<データのフォルダ>\mods`」。前は `deploy.ps1` で `%USERPROFILE%\Zomboid\Workshop` にコピーしていたので、いつものゲームでも、Steam で購読した版ではなく、開発中の版が使われていた。マルチプレイでサーバーと版が違うと、入れなかったり、気づかないまま違う版で遊んだりする
- `tools\dev_game.ps1` は、ゲームを Steam ありで `-cachedir=%USERPROFILE%\PZDev` を付けて起動する（Steam を起動しておく）。セーブ・オプション・ログ（`console.txt`）も `PZDev` に分かれる
- ワークショップのアイテムの ID を書いた `workshop.txt` も、`PZDev\Workshop\SurvivorComforts` にある。消すと、次のアップロードで別のアイテムが新しく作られてしまう
- `%USERPROFILE%\Zomboid\Workshop\SurvivorComforts` は使わない。そこに置くと、いつものゲームで開発中の版が使われてしまう
- 開発用のフォルダは、環境変数 `PZ_DEV_DIR` で変えられる

## デバッグモードで試す

確かめるのに食材や道具などのアイテムが要るときは、次のコマンドでゲームをデバッグモード（`-debug`）で起動し、デバッグのメニューからアイテムを出す。
```
powershell -File tools\test_debug.ps1
```
- MOD をコピーし、MOD を有効にした状態で起動する。メインメニューから「ソロ」で新しく始める
  - セーブは、始めたときの MOD の一覧を覚えている。MOD なしで始めたセーブを続けても、MOD は読み込まれない
- Steam なしで動かすので、データ（セーブ、オプション、ログの `console.txt`）は `%USERPROFILE%\PZTest\debug` に分けて置かれ、普段のセーブやオプションには触れない
- MOD を直したら、ゲームを閉じてもう一度実行する（ゲーム内で Lua を読み直すこともできる）
- マルチプレイでデバッグモードを使うときは、`tools\test_server.ps1 -Debug`（ゲームだけデバッグモードで起動する）
  - サーバーは、デバッグモードのゲームを管理者しか入れない（ゲームの文：「Debug connection is not allowed for non admin.」）。新しいユーザー名で入ろうとすると、接続の途中で止まる
  - 1人目は、サーバーの管理者のアカウント（ユーザー名 `admin`、パスワード `admin`）で入る
  - 2人目からは、入る前にサーバーの画面で管理者のアカウントを作り、そのユーザー名とパスワードで入る
    ```
    adduser "test2" "test"
    setaccesslevel "test2" admin
    ```
  - スキルを上げるだけなら、デバッグモードを使わなくても、サーバーの画面で `addxp "ユーザー名" Woodwork=1000` のようにして上げられる

## 1台で複数人を試す

マルチプレイの機能（F06 のみんなのリスト、F09 など）を1台で2人分試すときは、次のコマンドでテスト用のサーバーとゲーム2つを起動し、それぞれ別のユーザー名で `127.0.0.1`（ポート `16261`）に入る。MODを直したら、サーバーを止めて（サーバーの画面で `quit`）もう一度実行する。
```
powershell -File tools\test_server.ps1
```
- Steam なしで動かすので、データは `%USERPROFILE%\PZTest` の下に分けて置かれ、普段のセーブやオプションには触れない
- サーバーのログは `%USERPROFILE%\PZTest\server\server-console.txt`、設定は `server\Server\sctest.ini`（管理者のパスワードは `admin`）
- サーバー・ゲームとも最大3GBずつメモリを使う。合わせて10GB前後空けておく
- 2人目に入ってもらえるなら、ゲーム内の「ホスト」で立てたサーバーでもよい

## ブランチとリリース

0.4.0 の公開（2026-11-01）から、ブランチを次のように分けている。

| ブランチ | 中身 | プッシュ |
| --- | --- | --- |
| `main` | ワークショップに上げた状態だけ。GitHub で保護していて、直接はプッシュしない | リリースのときに、`dev` からの Pull Request をマージする |
| `dev` | ふだんの開発。テストの途中など、半端な状態でもよい | 直接コミットしてプッシュする |

- 公開した版には、`main` にタグ（`v0.4.0` など）を付ける。`v0.4.0` は、ワークショップに上げたファイルと同じ状態のコミット（`4631f18`）に付けている。その後の、テストのための変更（動きは変わらない）は、`main` にあってもまだワークショップには上げていない
- ほかの人からコードを受け取るときも、`dev` への Pull Request にしてもらう

### リリースの手順

1. `dev` で、版を上げる（`mod.info` の `modversion`）。`docs\workshop.md` に、その版の更新内容を書く（説明を変えたなら、説明も直す。8000 バイトまで）
2. `tools\check.ps1` を通し、テスト用の MOD のテスト（[testing.md](testing.md)）と、変えた機能の確認項目をゲームで確かめる
3. GitHub で、`dev` から `main` への Pull Request を作ってマージする
4. `main` に切り替えて、ワークショップにアップロードする（[更新するとき](#更新するとき)）。終わったら、`main` にタグを付けて、`dev` に戻る
5. `docs\workshop.md` の更新内容の見出しに、公開日を書く（`dev` でコミット）

### main を保護する設定（GitHub）

リポジトリの Settings → Branches（または Rules → Rulesets）で、`main` に次を設定する。

- Require a pull request before merging（Pull Request を通さないとマージできない）。1人で開発しているので、承認の数（Required approvals）は 0 にする。1以上にすると、自分の Pull Request をマージできない
- Block force pushes（強制プッシュを禁止）
- ブランチの削除を禁止（Restrict deletions）

## ゲームを更新したとき

Project Zomboid のアップデートが来たら、次を行う。

1. 英語名の表を作り直す（F14 の英語名での検索に使う）
   ```
   powershell -File tools\make_english_names.ps1
   ```
   - ゲームの英語の翻訳ファイル（`media\lua\shared\Translate\EN\Recipes.json`、`ItemName.json`）から、`client\SurvivorComforts\EnglishNames.lua` を作り直す
   - 前の表と比べて、増えた・消えた・変わった名前の数と例を表示する。全部 0 なら、更新は要らない（ファイルも変わらない）
   - 増えていたら、`git diff` で中身を見て、おかしな名前がないことを確かめてからコミットする。作り直すまでの間も、新しいレシピやアイテムは内部名の単語で検索に当たる
2. 構文チェック（`tools\check.ps1`）をして、ゲームを起動し、エラーが出ないか確かめる。B42 はまだ不安定版なので、本体の関数の名前や作りが変わって、MODが動かなくなることがある
3. 何か直したら、Workshop を更新する（下の「更新するとき」）

## Workshopへのアップロード（限定公開）

公開範囲は **「未掲載」（Unlisted）** にする。Workshopの検索や一覧には出ず、URLを知っている人だけがサブスクライブできる。「非公開」（Private）にすると、サーバーやほかのプレイヤーがダウンロードできないので使わない。

### 事前の準備
- アップロードする前に、構文チェック・確認項目のテストを済ませておく。
- 画像はリポジトリに入っている（`preview.png`、`poster.png`、`icon.png`）。デザインを変えたときだけ作り直す。
  ```
  powershell -File tools\make_preview.ps1
  ```
- Steamのアカウントで、Steamワークショップの利用規約に同意している必要がある（初めてのときはアップロード画面に案内が出る）。

### 初回のアップロード
1. 最新の状態を開発用のフォルダへコピーして、そのフォルダでゲームを起動する（[開発用のフォルダ](#開発用のフォルダ)。Steam を起動しておく）。
   ```
   powershell -File tools\dev_game.ps1
   ```
2. メインメニュー →「WORKSHOP」→「アイテムの作成と更新」を選ぶ。
3. 「アイテムのディレクトリを選択」で **SurvivorComforts** を選ぶ（`%USERPROFILE%\PZDev\Workshop\` の中のフォルダが並ぶ）。
4. 「アイテム詳細を編集」で次を入力する。
   - タイトル：`Survivor Comforts`
   - 説明：機能の一覧（`docs/feature-list.md`）の内容を元に書く（後からSteamのページでも直せる）
   - タグ：Build 42、Interface など
   - 公開設定：**未掲載**
   - 画像プレビューに `preview.png` が表示されていることを確かめる
5. 「新規もしくは既存のアイテムですか?」で「新規のWORKSHOPアイテムです」を選ぶ。
6. 「アイテムの公開準備」で、必要なら「変更履歴の編集」に内容を書き、「Steam WORKSHOPにアップロード!」を押す。
7. 終わると、ゲームが `%USERPROFILE%\PZDev\Workshop\SurvivorComforts\workshop.txt` に **Workshop ID**（数字）を書き込む。
   - deploy.ps1 はこのファイルを上書きしない。消すと次回「新規」扱いになり、別のアイテムができてしまうので注意。
   - リポジトリには入れない（`.gitignore` 済み）。IDはメンバーに伝える。
8. 「作成したアイテムをSteamオーバーレイで開く」でページを開き、公開範囲が「未掲載」になっていること、URL（`https://steamcommunity.com/sharedfiles/filedetails/?id=<Workshop ID>`）を確かめる。

### 更新するとき
アップロードは、`main` に切り替えてから行う（[ブランチとリリース](#ブランチとリリース)）。

1. `git switch main` で `main` にし、`git pull` で最新にする。`tools\check.ps1` → `tools\dev_game.ps1` を実行する（開発用のフォルダへコピーして、Steam ありでゲームを起動する）。
   - `deploy.ps1`（`dev_game.ps1` の中で動く）は手元のファイルをそのままコピーするので、`dev` のままだと、公開していない途中の変更まで上がってしまう
2. ゲームのメインメニュー →「WORKSHOP」→「アイテムの作成と更新」→ SurvivorComforts を選ぶ。`workshop.txt` があるので、既存のアイテムの更新になる。
3. 「変更履歴の編集」に変更内容（`docs\workshop.md` の、その版のコードブロック）を貼ってアップロードする。
4. サーバーは再起動すると新しい版をダウンロードする。プレイヤーも、接続時に新しい版が自動で入る。
   - `mod.info` の `modversion` を上げておくと、どの版か分かりやすい。
5. アップロードできたら、`main` に版のタグを付けてプッシュし、`dev` に戻る。
   ```
   git tag -a v0.5.0 -m "Survivor Comforts 0.5.0 (Workshop, 公開日)"
   git push origin v0.5.0
   git switch dev
   ```

### アルファ版

開発中の機能を、選んだ人だけが先に試せるようにする版（2026-11-02 に決定）。Steam ワークショップには版の分け方（ベータ版など）がないので、別のアイテムとして上げる。

| | 安定版 | アルファ版 |
| --- | --- | --- |
| 名前 | Survivor Comforts | Survivor Comforts (Alpha) |
| Workshop ID | `3829529741` | `3832140066`（2026-11-02 に初めて公開） |
| MOD ID | `SurvivorComforts` | `SurvivorComfortsAlpha` |
| 開発用のフォルダ | `PZDev\Workshop\SurvivorComforts` | `PZDev\Workshop\SurvivorComfortsAlpha` |
| 上げるブランチ | `main` | `dev`（この決まりの例外） |
| ページの文 | [workshop.md](workshop.md) | [workshop-alpha.md](workshop-alpha.md) |

- 中身は `dev` のそのままで、`deploy.ps1 -Alpha` がコピーするときに `mod.info` だけ書き換える（MOD ID、名前、版の後ろに `-alpha` と `dev` のコミット、「一緒に使えない MOD」に安定版）
- 中身のファイルの場所（`media/lua/client/SurvivorComforts/...`）は安定版と同じなので、2つを同時に有効にすると壊れる。`mod.info` の `incompatible=` に互いの MOD ID を書いて、ゲームの MOD の画面で止める（安定版の `mod.info` にも書いた。安定版のページに出るのは、次の安定版から）
- コードの中の MOD ID（`Core.lua` の `MOD_ID`、オプションの保存名）は `SurvivorComforts` のまま。オプションの設定は安定版と共通になる
- マルチプレイでは、サーバーの MOD の一覧どおりの MOD が使われるので、一人だけアルファ版にはできない。シングルプレイか、アルファ版を入れた別のサーバーで試してもらう
- アルファ版の機能を安定版に入れたら（リリースの手順）、アルファ版も同じ内容で更新しておく

アップロードの手順：

1. `dev` で `tools\check.ps1` を通す
2. アルファ版をコピーして、開発用のフォルダでゲームを起動する（Steam を起動しておく）
   ```
   powershell -File tools\dev_game.ps1 -Alpha
   ```
   - 初めてのときは、`workshop-alpha.md` の説明から `workshop.txt` が作られる
3. メインメニュー →「WORKSHOP」→「アイテムの作成と更新」→ **SurvivorComfortsAlpha** を選ぶ
   - 初めてのとき：「新規のWORKSHOPアイテムです」を選ぶ。公開設定が「未掲載」になっていることを確かめる。終わると `workshop.txt` に Workshop ID が書き込まれる（アルファ版は `3832140066`。この表と [workshop-alpha.md](workshop-alpha.md) に書いた）
   - 2回目から：既存のアイテムの更新になる。「変更履歴の編集」に、`workshop-alpha.md` の更新内容を貼る
4. タグは付けない（アルファ版は何度も上げ直すため）

### サーバーに入れる
- サーバーの設定（`servertest.ini` などの `<サーバー名>.ini`）に次の2つを書く。
  - `WorkshopItems=` に Workshop ID（ほかのMODがあれば `;` で区切って追加）
  - `Mods=` に MOD の ID `SurvivorComforts`（同じく `;` 区切り）
- ゲーム内の「ホスト」→ サーバー設定の編集画面の「Steamワークショップ」「MOD」から選ぶと、正しい形で書き込まれるので確実。
- 書き方が合っているかは、サーバーを起動したときの `console.txt` に `SurvivorComforts` を読み込んだ記録が出ることで確かめる。
