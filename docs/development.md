# 開発手順（手元で試す）

- [README に戻る](../README.md)

1. JDK（13 以降）を入れておきます（構文チェックに使います）
2. 構文チェックをして、開発用のフォルダ（`%USERPROFILE%\PZDev`）にコピーし、そのフォルダでゲームを起動します（Steam を起動しておきます）
   ```
   powershell -File tools\check.ps1
   powershell -File tools\dev_game.ps1
   ```
   - MOD は有効にした状態で起動します
   - いつも遊ぶゲーム（`%USERPROFILE%\Zomboid`）とは、セーブ・オプション・MOD が分かれています。いつものゲームでは、Steam で購読した版が使われます（[dev-guide.md の「開発用のフォルダ」](dev-guide.md#開発用のフォルダ)）

詳しい手順（デバッグモードで試す、1台で複数人を試す、ワークショップへのアップロードなど）は [dev-guide.md](dev-guide.md)、機能ごとの確認項目は [features/](features/) の各ファイルにあります。開発に使うスクリプトの一覧は [tools/README.md](../tools/README.md) にあります。
