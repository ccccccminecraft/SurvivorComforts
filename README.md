# Survivor Comforts

Project Zomboid（Build 42.21 以降）用の MOD です。身内のマルチプレイサーバーで使う、ちょっとした便利機能をまとめています。

- Steam ワークショップ（限定公開）：https://steamcommunity.com/sharedfiles/filedetails/?id=3829529741
- Workshop ID：`3829529741` / MOD ID：`SurvivorComforts`

- 1つの MOD に複数の機能が入っていて、機能ごとに「オプション」→「MOD」→「Survivor Comforts」で ON/OFF できます
- 新しいアイテム・レシピ・ゲームのルールは追加しません（ゲームバランスを変えません）
- 基本的にワールド（セーブデータ）には書き込みません。例外は「みんなのウィッシュリスト」と、プレイヤー一覧の最終ログインだけで、MOD を外してもデータが残るだけで害はありません

## ドキュメント

| ページ | 内容 |
| --- | --- |
| [機能](docs/feature-list.md) | 入っている機能の一覧（インベントリ検索、ウィッシュリスト、スキルウィンドウ、プレイヤー一覧など） |
| [導入（一人で遊ぶ）](docs/install.md) | ワークショップでサブスクライブして有効にする |
| [導入（サーバー）](docs/install-server.md) | サーバーの設定に追加する2行 |
| [開発手順](docs/development.md) | 手元で構文チェックをして、ゲームで試すまで |
| [フォルダ構成](docs/folders.md) | リポジトリのフォルダとドキュメントの一覧 |

## ライセンス

[MIT ライセンス](LICENSE)です。著作権の表示とライセンスの文を残せば、改造・再配布・ほかの MOD への取り込みも自由です。

F02 インベントリ検索は itsu07 さんの [Inventory Search](https://github.com/itsu07/pz-inventory-search)、F15 ほかの人のスキルを見るは itsu07 さんの [Skill Viewer](https://github.com/itsu07/SkillViewer) を元に（どちらも MIT ライセンス）、この MOD に合わせて書き換えたものです。元の著作権表示は [LICENSE](LICENSE) に入れています。

ただし、F14 の英語名の表（`EnglishNames.lua`）に入っているアイテムやレシピの名前は、ゲーム本体の翻訳ファイルから作ったもので、このライセンスの対象外です（Project Zomboid の権利は The Indie Stone にあります）。
