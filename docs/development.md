# 開発手順（手元で試す）

- [README に戻る](../README.md)

1. JDK（13 以降）を入れておきます（構文チェックに使います）
2. 構文チェックをして、ゲームから読める場所（`%USERPROFILE%\Zomboid\Workshop\SurvivorComforts`）へコピーします
   ```
   powershell -File tools\check.ps1
   powershell -File tools\deploy.ps1
   ```
3. ゲームのメインメニュー →「MOD」で **Survivor Comforts** を有効にします

詳しい手順（デバッグモードで試す、1台で複数人を試す、ワークショップへのアップロードなど）は [dev-guide.md](dev-guide.md)、機能ごとの確認項目は [features/](features/) の各ファイルにあります。開発に使うスクリプトの一覧は [tools/README.md](../tools/README.md) にあります。
