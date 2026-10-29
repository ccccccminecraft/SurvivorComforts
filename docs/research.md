# Project Zomboid UI MOD 調査メモ

- 調査日: 2026-10-27
- 対象: Build 42.21.0（ローカル環境 `4a0e9546ec`）
- 方針: UIを便利にするMOD / B42以降 / マルチプレイでクライアントのみ導入 / Steam Workshop公開

---

## 1. 重要な結論：マルチプレイでは「クライアントだけに入れたMOD」は読み込まれない

ゲーム本体（`projectzomboid.jar`）を `javap` で逆アセンブルして確認した。

### 接続の流れ
1. `ConnectToServerState.CheckMods()`
   サーバーから受け取ったMODリストで `GameClient.serverMods` を上書きする。
   足りないMODがあると `UI_OnConnectFailed_ModRequired` で接続が失敗する。
2. `ConnectToServerState.receiveServerOptions()`
   `Core.ResetLua("client", "ConnectedToServer")` を呼び、Lua環境をすべて作り直す（`LuaManager.init()`）。
3. `ZomboidFileSystem.loadMods(String)`
   `GameClient.client == true` のとき、読み込むMODは次の2つだけになる。
   - `loadTranslationMods()`：自分で有効にしたMODのうち、翻訳専用のもの
   - `GameClient.serverMods`：サーバーが指定したMOD

### 翻訳専用MODの条件（`isValidTranslationModSubDir`）
`media/` 以下のファイルがすべて `media/lua/shared/translate/` 配下の `.txt` または `.json` であること。

### 意味すること
| 種類 | サーバーに入っていないとき、マルチプレイで動くか |
|---|---|
| ゲーム内UIを変更するLuaのMOD | **動かない**（接続時のResetLuaで読み込まれない） |
| 翻訳だけのMOD | 動く |
| メインメニューだけで動くMOD（例：MOD一覧画面の改善） | 接続前の画面なので動く |
| ゲーム本体のLuaを直接書き換える方法 | `NetChecksum`（lua=true）で接続が拒否される。Workshopで配布もできないので採用できない |

> Web上の「UIのMODはクライアント側だけで使える」という情報（ホスティング会社のブログなど）は、
> 「サーバー側の処理を持たない」という意味であり、**サーバーのMODリストへの登録は必要**。

### 現実的な方針
- **A. サーバーのMODリストに入れてもらう前提で作る（一般的な「クライアントサイドMOD」）**
  - コードは `media/lua/client/` だけに置き、サーバー側の処理やデータ同期は持たない。
  - サーバー管理者は `Mods=` と `WorkshopItems=` に追加するだけで済み、他のプレイヤーは接続時に自動でダウンロードされる。
  - 個人ごとのON/OFFは、Mod Optionsで機能ごとに無効化できるようにして対応する。
- **B. メインメニューや翻訳に限定する**：ゲーム内UIを改善できないため、今回の目的とは合わない。

---

## 2. B42のMODの構成

ゲーム内の `ZomboidFileSystem` / `ChooseGameInfo` から確認した内容。

```
MyUIMod/                      ← Workshopの場合は Contents/mods/MyUIMod/
├── common/                   ← 必須（無いと認識されない）。全バージョン共通のファイル
│   └── media/...
└── 42/                       ← バージョンフォルダ。ゲームのバージョン以下で最も新しいものが選ばれる
    ├── mod.info
    ├── poster.png
    ├── icon.png
    └── media/
        └── lua/
            ├── client/       ← UIのコードはここ
            ├── shared/       ← 共通コード、translate/
            └── server/
```
- バージョンフォルダは `42`、`42.13` などの名前にでき、ゲームのバージョン以下で最も新しいものが使われる（`getModVersionDirName`）。
- `mod.info` で使えるキー：`name` `id` `author` `description` `poster` `icon` `url` `modversion` `require` `incompatible` `loadModAfter` `loadModBefore` `versionMin` `versionMax` `category` `pack` `tiledef`
- 同梱されている `examplemod` と `Workshop/ModTemplate` はB41形式（`common/` が無い）なので、そのままではお手本にならない。

### Workshopで公開するときの構成
```
%USERPROFILE%\Zomboid\Workshop\MyUIMod\
├── preview.png         (256x256)
├── workshop.txt
└── Contents\mods\MyUIMod\  (上記の構成)
```
公開はゲーム内のメインメニュー →「Workshop」からアップロードする。

---

## 3. UIのMODを実装するための基礎

- **言語**：Lua（Kahlua）。Javaのクラスは公開されている範囲だけLuaから呼べる。
- **UIの部品**：`media/lua/client/ISUI/`（122ファイル）。`ISPanel`、`ISButton`、`ISCollapsableWindow`、`ISInventoryPane`、`ISContextMenu` など。
  - 既存UIの拡張は、関数を差し替える方法（元の関数を保存してから上書きして呼び出す）が基本。
- **イベント**：`Events.OnGameStart`、`OnCreatePlayer`、`OnKeyPressed`、`OnFillInventoryObjectContextMenu`、`OnFillWorldObjectContextMenu`、`OnRefreshInventoryWindowContainers` など。
- **設定画面**：B42では本体に `PZAPI.ModOptions` が入っている（`client/PZAPI/ModOptions.lua`）。チェックボックス、キーバインド、スライダーなどを外部のMODに頼らず作れる。
- **調べ方**：ゲーム本体の `media/lua/client` を読むのが最も確実（公式のドキュメントは少ない）。

---

## 4. 既存のB42向けUI/QoL MOD（Workshopのまとめコレクションから）

マルチプレイでの動作や、最新バージョン（42.21）への対応は個別に確認が必要。

| 分野 | MOD（Workshop ID） | 内容 |
|---|---|---|
| インベントリ | Better Containers (3586216562) | コンテナの並び順、検索、ロック、入れ子の表示 |
| | [B42] Item Details (3477237184) | アイテム情報の拡張、並べ替え |
| | [B42] More Item Information (3494474677) | ツールチップの拡張 |
| | Comically Organised Literature and Media (3490232325) | 本やメディアの並び順 |
| | Proximity Inventory B42.20+ (2847184718) | 周囲のコンテナをまとめて表示 |
| | Inventory Tetris | グリッド式のインベントリ（好みが分かれる） |
| ホットバー・操作 | Clean HotBar [B42] (3461263912) | ホットバーの改善 |
| | The Shortcut [B42] (3470659758) | アイテム、レシピ、建築のショートカットバー |
| | Smart Radial Menu (3494108029) | ラジアルメニュー（コントローラー対応） |
| クラフト・建築 | Neat Crafting (3502080466) / Neat Building (3536052310) | クラフト画面と建築画面の作り直し |
| | [B42] Intuitive Crafting (3486217110) | カテゴリ分けと検索の改善 |
| | Project Cook (3490188370) | 料理専用の画面 |
| マップ | TwisTonFire - minimap (3572564421) / Minimap Style Options (3526517370) | ミニマップの改善 |
| | Quick'n'Auto Mark (3579410548) | 建物に自動でマークを付ける |
| | Darker Map & Satellite View (3571222611) | 地図の見た目、音の届く範囲の表示 |
| HUD・情報 | [B42] Survival HUD (3495906499) | ステータスのHUD |
| | Better Generator Info (3576056135) | 発電機の燃料と範囲 |
| | Improved Farming Info Window (3470852353) | 作物の状態 |
| | Weapon Condition Indicator (3412262177) | 武器の耐久度と弾数 |
| | Has Been Read (2544353492) | 既読の本にマークを付ける |
| 見た目 | CleanUI（NeatUI Frameworkが必要） | UI全体の見た目の変更 |
| その他 | Washing Menus Improved (3460812542) | 洗濯関連のメニュー整理 |
| | Wiki That! (3567109091) | 右クリックからWikiを開く |
| | [B42] Mod Folders (3779201168) | MOD一覧をフォルダで整理（メインメニューのみ） |

出典：
- [33 Quality Of Life Mods For Build 42!](https://steamcommunity.com/sharedfiles/filedetails/?id=3588855306)
- [Best Project zomboid quality of life mods for Build42](https://steamcommunity.com/sharedfiles/filedetails/?id=3593148596)
- [Unstable 42 MP Released（公式ブログ）](https://projectzomboid.com/blog/news/2025/12/unstable-42-mp-released/)

---

## 5. ZombieBuddyを前提MODにする案（2026-10-27 調査）

[ZombieBuddy](https://github.com/zed-0xff/ZombieBuddy)（Workshop 3619862853）は、Javaエージェントを使ってゲーム本体のJavaコードを実行中に書き換えるためのフレームワーク。

### 仕組み（ソースコードで確認した内容）
- `ZomboidFileSystem.loadMods(List)` にパッチを当て、読み込むMODの一覧からJava MOD（`mod.info` に `javaJarFile` と `javaPkgName` があるもの）を読み込む。
- **プリロードMOD**の仕組み：`javaPreload=true`、JARのマニフェストに `ZB-Preload: true`、署名、ユーザーの承認がそろったもの。これは**毎回の `loadMods` で、本来のMODリストより前に必ず差し込まれる**（`Loader.loadMods` の `mergedIds`）。
  → マルチプレイで、MODリストがサーバーのものに置き換わっていても、**Java部分は読み込まれる**。JVMは一度読み込んだクラスを破棄しないため、ResetLuaの後もパッチは残る。
- ZombieBuddy本体には「ステルスモード」があり、自分のLuaファイルだけをチェックサムの対象から外す（`Patch_NetChecksum`）。これにより、ZombieBuddyが入っていないサーバーにも接続できる。

### できるようになること
- サーバーに登録しなくても、クライアントのJavaパッチは動く（ソースコードから読み取った推測で、42.21での実地確認はまだ）。
- Luaからは触れない内部処理にも手を入れられ、実装できる範囲が広がる。

### 制約・リスク
1. **自分たちのMODのLuaは、やはり読み込まれない**。UIはJava側で作る必要がある（ImGuiを使う、Java側でUIを描画する、など）。Luaファイルを足してチェックサムから隠す方法は、サーバーが行う整合性チェックを回避することになるので採用しない。
2. **導入のハードルが高い**。Workshopで購読するだけでは足りない。各プレイヤーがゲームのフォルダにDLLとJARを置き、起動オプションに `-agentlib:zbNative --` を追加し、Java MODを承認する必要がある。プリロードには署名も必要。
3. **セキュリティ**：Java MODはPC全体に無制限にアクセスできる。配布先に信頼してもらう必要がある。
4. **サーバーのルールと不正対策**：サーバーが許可していないクライアントの改造にあたる。サーバーによっては禁止されていたり、BANされたりする恐れがある。
5. **壊れやすい**：ゲームの内部実装に直接依存するので、アップデートのたびに壊れやすい。ZombieBuddyの保守状況にも左右される。

## 6. サーバーへのMOD登録の仕組み（2026-10-27 調査）

### サーバー設定（`Zomboid/Server/<サーバー名>.ini`）
| キー | 役割 |
|---|---|
| `WorkshopItems=` | サーバーがダウンロードするWorkshopのID。`;` 区切りで書く |
| `Mods=` | 有効にするMODのID（`mod.info` の `id`）。`;` 区切りで書く |
| `DoLuaChecksum=` | `true` のとき、Luaファイルが一致しないクライアントを接続させない（標準は `true`） |

※B42では `Mods=\ModID` のようにIDの前に `\` を付けるという報告があるが、まだ確かめていない。

### 動作（`GameServer` / `LuaManager` を逆アセンブルして確認）
1. 起動時に `WorkshopItems` を `;` で分割し、`GameServerWorkshopItems.Install()` でSteamから**自動でダウンロード**する。
2. `ZomboidFileSystem.loadMods(Mods)` で、MODをサーバーに読み込む。
3. Luaの読み込み順は `shared` → `client` → `server`。
   - `client` は `LoadDirBase("client", true)` で読み込まれる。フラグが `true` のときは `RunLua` を飛ばすので、**実行はされないが、チェックサムの計算には含まれる**。
   - `shared` と `server` は実行される。
4. クライアントは接続時にサーバーのMODリストを受け取り、足りないWorkshopアイテムを自動でダウンロードする。その後、Luaのチェックサムを照合する。

### 結論
- サーバー側で手作業でファイルを置く必要は**ない**。設定ファイルの2行（`WorkshopItems=` と `Mods=`）を書き換えて再起動すれば、自動でダウンロードされる。
- ただし、**サーバーにもMODのファイル一式が必要**になる（チェックサムの照合のため）。Workshopを使わないサーバーでは、`Zomboid/mods/` に手作業で置く。
- UIだけのMOD（`client/` のみ）なら、サーバー上でコードは実行されない。サーバーの負荷や動作には影響しない。
- MODを更新したら、サーバーを再起動してファイルを揃える必要がある。揃っていないと、チェックサムが一致せず接続できない。

## 7. Workshopの公開範囲（2026-10-27 調査）

ゲーム内のアップロード画面（`WorkshopSubmitScreen.lua`）では、次の4つから公開範囲を選べる。公開後にSteamのWebページから変更することもできる。

| 公開範囲 | 検索・プロフィールに出るか | 専用サーバーが自動でダウンロードできるか | 身内用に使えるか |
|---|---|---|---|
| 公開（Public） | 出る | できる | ○（ただし誰でも見つけられる） |
| **限定公開（Unlisted）** | **出ない**（IDやリンクを知っていれば見られる） | **できる見込み** | **◎ おすすめ** |
| フレンドのみ（Friends Only） | フレンドにだけ出る | **できない**（サーバーは匿名でSteamにログオンするため） | × |
| 非公開（Private） | 本人にだけ出る | できない | × |

- 専用サーバーは `SteamGameServer.LogOnAnonymous()` で匿名でログオンしてからダウンロードする（`GameServer` で確認）。そのため、フレンドのみや非公開のアイテムは取得できない。
- 限定公開は「リンクを知っている人なら誰でも見られる」設定なので、匿名のサーバーからも取得できる見込み。ただし実際に試してはいない。
- 更新の義務はない。説明文に「身内向け・サポートなし」と書く、コメント欄を閉じる、といった対応で問い合わせの負担を減らせる。

## 8. 次にやること
1. 方針A（サーバーのMODリストに追加してもらう）で進めてよいか決める。
2. 普段のプレイで不便に感じているUIの操作を洗い出す。上の表で解決済みのものは除き、まだ無いものを要件の候補にする。
3. 候補ごとに、既存のMODが42.21のマルチプレイで動くかを確かめる（Workshopのページとコメントを確認する）。
