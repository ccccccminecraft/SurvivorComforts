# tools

MOD の開発に使うスクリプトです。MOD 本体には含まれません。どれもリポジトリのルートから実行します。

| ファイル | 説明 |
| --- | --- |
| `check.ps1` | MOD の Lua ファイルすべての構文を、ゲームと同じ Lua コンパイラでチェックします。続けて、翻訳キー（日本語と英語でそろっているか、コードで使っているキーがあるか）と、ゲームの Lua にない関数を使っていないかを点検します。JDK（13 以降）が必要です |
| `LuaSyntaxCheck.java` | `check.ps1` が使う構文チェッカーです。直接実行する必要はありません |
| `ModRules.java` | `check.ps1` が使う点検（翻訳キー、ゲームの Lua にない関数）です。直接実行する必要はありません |
| `deploy.ps1` | MOD を開発用のフォルダ `%USERPROFILE%\PZDev\Workshop\SurvivorComforts` にコピーし、開発用のゲームから読み込んだりアップロードしたりできるようにします。いつも遊ぶゲーム（`%USERPROFILE%\Zomboid`）には置きません（そこでは Steam で購読した版を使うため。[dev-guide.md の「開発用のフォルダ」](../docs/dev-guide.md#開発用のフォルダ)） |
| `dev_game.ps1` | `deploy.ps1` でコピーしてから、開発用のフォルダ（`-cachedir=%USERPROFILE%\PZDev`）で、Steam ありでゲームを起動します。MOD は有効にした状態で起動します。試すときと、ワークショップにアップロードするときに使います。`-Debug` でデバッグモード |
| `test_server.ps1` | このPCでテスト用のサーバーとゲーム（初期値2つ）を Steam なしで起動し、1台で複数人のマルチプレイを試せるようにします。データは `%USERPROFILE%\PZTest` に分けて置き、普段のセーブには触れません。`-Debug` を付けると、ゲームをデバッグモードで起動します（管理者のアカウントでしか入れません。ユーザー名 `admin`、パスワード `admin`。詳しくは [dev-guide.md](../docs/dev-guide.md)）。`-Test` を付けると、テスト用の MOD（[docs/testing.md](../docs/testing.md)）もサーバーとゲームに入れます |
| `test_debug.ps1` | ゲームをデバッグモード（`-debug`）で、Steam なしで1つ起動します。シングルプレイで、デバッグのメニューからアイテムを出して試すときに使います。MOD は有効にした状態で起動し、データは `%USERPROFILE%\PZTest\debug` に分けて置きます。`-Test` を付けると、テスト用の MOD も入れて有効にします。テストはデバッグメニューの「ユニットテスト」から始めます（[docs/testing.md](../docs/testing.md)） |
| `TestLaunch.ps1` | `test_server.ps1`・`test_debug.ps1`・`dev_game.ps1` の共通処理です（起動のコマンドの組み立て、MOD のコピーなど） |
| `GameDir.ps1` | ゲームのフォルダを Steam のライブラリから探す共通処理です。`check.ps1`・`test_server.ps1`・`test_debug.ps1`・`make_english_names.ps1` が使います |
| `make_icons.ps1` | 画面左のボタンのアイコン（スキル、ウィッシュリスト、プレイヤー一覧）を描きます。デザインを変えるときだけ実行します |
| `make_english_names.ps1` | ゲームの英語の翻訳ファイルから、F14 の英語名の表（`EnglishNames.lua`）を作り直します。ゲームを更新したら実行し、増えた名前を確かめます |
| `make_preview.ps1` | ワークショップのプレビュー画像（`preview.png`）と、MOD 一覧の画像（`poster.png`）・アイコン（`icon.png`）を描きます。デザインを変えるときだけ実行します |
| `build/` | `check.ps1` がコンパイルしたチェッカーの置き場所です。自動で作られ、Git には含めません |

```
powershell -File tools\check.ps1
powershell -File tools\dev_game.ps1
powershell -File tools\test_server.ps1
powershell -File tools\test_debug.ps1
```

詳しい使い方は [docs/dev-guide.md](../docs/dev-guide.md) を見てください。
