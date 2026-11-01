# Survivor Comforts

Project Zomboid（Build 42.21 以降）用の MOD です。

- Steam ワークショップ：https://steamcommunity.com/sharedfiles/filedetails/?id=3829529741
- Workshop ID：`3829529741` / MOD ID：`SurvivorComforts`

## 概要

- 全体的に、UIを改善します
- 新しいアイテム・レシピ・ゲームのルールは追加しません（ゲームバランスを変えません）
- 全機能、オプションで有効化無効化設定可能
- できること
  - インベントリ内検索
  - アイテムからレシピ確認
  - 各画面のアイテムレシピ確認
  - ウィッシュリスト作成、共有
  - 料理に加える食材をまとめる
  - プレイヤー一覧表示
  - 読書残り時間表示
  - 他プレイヤーのスキル表示
  - スキルウィンドウを改善
  - PvPボタン非表示
  - ユーザーパネル非表示
  - 日本語でプレイしていても、英語名で検索できる

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
