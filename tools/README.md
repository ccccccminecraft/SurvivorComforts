# tools

MOD の開発に使うスクリプトです。MOD 本体には含まれません。どれもリポジトリのルートから実行します。

| ファイル | 説明 |
| --- | --- |
| `check.ps1` | MOD の Lua ファイルすべての構文を、ゲームと同じ Lua コンパイラでチェックします。JDK（13 以降）が必要です |
| `LuaSyntaxCheck.java` | `check.ps1` が使う構文チェッカーです。直接実行する必要はありません |
| `deploy.ps1` | MOD を `%USERPROFILE%\Zomboid\Workshop\SurvivorComforts` にコピーし、ゲームから読み込んだりアップロードしたりできるようにします |
| `make_icons.ps1` | 画面左のボタンのアイコン（スキル、ウィッシュリスト）を描きます。デザインを変えるときだけ実行します |
| `make_preview.ps1` | ワークショップのプレビュー画像（`preview.png`）と、MOD 一覧の画像（`poster.png`）を描きます。デザインを変えるときだけ実行します |
| `build/` | `check.ps1` がコンパイルしたチェッカーの置き場所です。自動で作られ、Git には含めません |

```
powershell -File tools\check.ps1
powershell -File tools\deploy.ps1
```

詳しい使い方は [docs/dev-guide.md](../docs/dev-guide.md) を見てください。
