# Steam ワークショップのページ

ワークショップのページ（https://steamcommunity.com/sharedfiles/filedetails/?id=3829529741 ）に載せる文章の原稿です。

- ページの「編集」→「説明」に、下のコードブロックの中身をそのまま貼り付けます
- ワークショップの説明は BBCode で書きます（`[h1]` `[b]` `[list]` など。Markdown は使えません）
- 説明は 8000 文字までです。日本語と英語の両方を載せても収まります
- 機能を追加・変更したら、機能の一覧（[feature-list.md](feature-list.md)）と一緒にここも直してから、ページに貼り直してください

## タイトル

```
Survivor Comforts
```

## 説明（日本語＋英語）

```
[h1]Survivor Comforts[/h1]
Project Zomboid（Build 42.21 以降）用の、ちょっとした便利機能をまとめた MOD です。

[list]
[*]機能ごとに「オプション」→「MOD」→「Survivor Comforts」で ON/OFF できます
[*]新しいアイテム・レシピ・ゲームのルールは追加しません（ゲームバランスは変わりません）
[*]セーブデータに書き込むのは「みんなのウィッシュリスト」と、プレイヤー一覧の最終ログインだけです
[/list]

[h2]機能[/h2]
[list]
[*][b]インベントリ検索[/b]
インベントリと周りの容器の一覧の検索欄で、名前で一覧を絞り込みます。合うアイテムが上にまとまり、ほかは暗く表示されます（オプションで隠すこともできます）。ひらがなとカタカナは区別せず、英語名（hammer など）でも見つかります。検索中の「すべて取る」「すべて移す」は、合うアイテムだけを移します。itsu07 さんの Inventory Search を元にしています。

[*][b]アイテムからレシピを見る[/b]
アイテムを右クリック →「レシピを見る」で、そのアイテムを作れるレシピに絞り込んだ制作の画面を開きます。作れるレシピがないときは赤く表示されます。

[*][b]材料のレシピをたどる[/b]
制作・建築の画面で材料を右クリック →「レシピを見る」で、その材料を作れるレシピに絞り込みます。検索欄の左の「戻る」で、たどる前の表示に戻れます。

[*][b]ウィッシュリスト[/b]
欲しいアイテムを右クリックで登録すると、インベントリや周りの容器で色付きで表示されます（自分のリストはオレンジ）。
自分のリストのアイテムを「共有する」と、サーバー全員が見られる「みんなのリスト」（水色）に出ます。両方に入っているアイテムは赤で表示されます。「追加して共有する」で、追加と共有を一度にできます。
共有を外せるのは共有した本人と管理者だけです。同じアイテムを何人でも共有でき、ほかの人の共有を巻き込んで消すことはありません。
制作・建築の画面のレシピや材料からも登録できます。リストは画面左の星のボタンから開けます。
自分のリストは100件、共有は1人30種類、みんなのリストは300種類までです。

[*][b]料理の食材をまとめる[/b]
スープやサラダに食材を加えるメニューで、同じ食材を1行にまとめ、残りが少ないものから使います。

[*][b]プレイヤー一覧[/b]
サーバーにオンラインの人と、7日以内に来ていたオフラインの人を一覧で表示します。オフラインの人には「3時間前」のように最終ログインが出ます。画面左の人のボタンから開けます。マルチプレイのときだけ使えます。

[*][b]読書の残り時間[/b]
本を読んでいる間、読み終わるまでの時間をキャラクターの足元に表示します。ゲーム内の時間はオレンジ、現実の時間は緑で表示します。

[*][b]ほかの人のスキルを見る[/b]
プレイヤー一覧でオンラインの人をクリックすると、その人のスキルのレベルをウィンドウで表示します。スキルはサーバーで読むので、ごまかせません。マルチプレイのときだけ使えます。itsu07 さんの Skill Viewer を元にしています。

[*][b]スキルウィンドウ[/b]
スキルの一覧を、大きさを変えられる独立したウィンドウで表示します。画面左のボタンで開きます。オプションでキーを決めると、キーでも開けます。

[*][b]PvP の切り替えボタンを隠す[/b]
画面左のドクロのボタンを隠し、PvP を常にオフにします。G キーでの切り替えも無効になります。

[*][b]ユーザーパネルのボタンを隠す[/b]
画面左のユーザーパネル（派閥・セーフハウスなど）のボタンを隠し、下のボタンを詰めます。管理者には常に表示します。隠している間は、パネルの中の画面（派閥、チケットなど）も開けません。使うときはオプションで OFF にしてください。

[*][b]英語名でも検索する[/b]
日本語でプレイしていても、制作・建築の画面の検索で、英語名（plank、saw logs など）でもレシピが見つかります。空白で区切った語は、全部入っているものが出ます。オプションで、英語名を含めるかを選べます。
[/list]

[h2]導入[/h2]
[b]サーバー[/b]
サーバーの設定（<サーバー名>.ini）に次を追加します。ほかの MOD がある場合は ; で区切ります。
[code]
WorkshopItems=3829529741
Mods=SurvivorComforts
[/code]
プレイヤーはサーバーに接続すると自動でダウンロードされます。

[b]一人で遊ぶ[/b]
サブスクライブして、メインメニュー →「MOD」で Survivor Comforts を有効にします。

[h2]注意[/h2]
[list]
[*]Build 42.21 以降が必要です。Build 41 では動きません
[*]機能の ON/OFF は、各プレイヤーが自分のオプションで切り替える設定です
[*]「PvP の切り替えボタンを隠す」は初期状態で ON です。PvP を使うサーバーでは OFF にしてください
[*]MOD を外しても、セーブデータに残るのは「みんなのウィッシュリスト」の中身と最終ログインの記録だけで、ゲームには影響しません
[/list]

[hr][/hr]

[h1]Survivor Comforts (English)[/h1]
A small collection of quality-of-life features for Project Zomboid (Build 42.21 or later).
Made for a private multiplayer server, but it also works in single player.

[list]
[*]Each feature can be turned on or off in Options > Mods > Survivor Comforts
[*]No new items, recipes or game rules (the game balance does not change)
[*]Only the shared wishlist and the player list's last-online times are saved to the world
[/list]

[h2]Features[/h2]
[list]
[*][b]Inventory search[/b]
A search box on the inventory and nearby container lists narrows the list by name. Matching items move to the top and the others are dimmed (or hidden, in the options). Hiragana and katakana are treated as the same, and English names (hammer and so on) work too. While searching, "Loot all" and "Transfer all" move only the matching items. Based on Inventory Search by itsu07.

[*][b]Show recipes for an item[/b]
Right-click an item and choose "Show recipes" to open the crafting window filtered to recipes that make it. The option is shown in red when no recipe makes the item.

[*][b]Follow ingredient recipes[/b]
In the crafting and building windows, right-click an ingredient and choose "Show recipes" to see the recipes that make it. The Back button left of the search box returns to what was shown before.

[*][b]Wishlist[/b]
Right-click an item to add it to your wishlist. Wanted items are highlighted in your inventory and in nearby containers (your list in orange).
Share an item from your list to show it on a shared list everyone on the server can see (light blue). Items on both are shown in red. "Add and share" does both in one step.
Only the player who shared an item, or an admin, can take it off. Any number of players can share the same item, and unsharing never removes someone else's share.
You can also add items from recipes and ingredients in the crafting and building windows. Open the list with the star button on the left of the screen.
Your list holds up to 100 items; each player can share up to 30 kinds, and the shared list holds up to 300.

[*][b]Group cooking ingredients[/b]
In the menu for adding ingredients to soups and salads, the same ingredient is shown on one line, and the item with the least left is used first.

[*][b]Player list[/b]
Lists who is online on the server, and who was online in the last 7 days with when they were last online ("3 h ago"). Open it with the people button on the left of the screen. Multiplayer only.

[*][b]Reading time left[/b]
While reading, shows the time left under your character: in-game time in orange, real time in green.

[*][b]Members' skills[/b]
Click an online player in the player list to see their skill levels in a window. The skills are read on the server, so they cannot be faked. Multiplayer only. Based on Skill Viewer by itsu07.

[*][b]Skills window[/b]
Shows your skills in a separate, resizable window. Open it with the button on the left of the screen, or set a key for it in the options.

[*][b]Hide the PvP button[/b]
Hides the skull button on the left of the screen and keeps PvP off. The G key no longer toggles PvP.

[*][b]Hide the user panel button[/b]
Hides the user panel button (factions, safehouses and more) on the left of the screen and moves the buttons below up. Admins always see it. While it is hidden, the windows in the user panel (factions, tickets and more) cannot be opened; turn it off in the options when you need them.

[*][b]Search by English name too[/b]
When the game is in another language, the search in the crafting and building windows also finds recipes by English name (plank, saw logs and so on). Recipes with every word you type are shown. You can turn English names off in the options.
[/list]

[h2]Installation[/h2]
[b]Server[/b]
Add these lines to your server settings (<server name>.ini). Separate other mods with ;.
[code]
WorkshopItems=3829529741
Mods=SurvivorComforts
[/code]
Players download the mod automatically when they join.

[b]Single player[/b]
Subscribe, then enable Survivor Comforts in Main Menu > Mods.

[h2]Notes[/h2]
[list]
[*]Requires Build 42.21 or later. Does not work on Build 41
[*]Each player turns features on or off in their own options
[*]"Hide the PvP button" is on by default. Turn it off on servers that use PvP
[*]If you remove the mod, only the shared wishlist and the last-online times stay in the save, and they do not affect the game
[/list]
```

## 更新内容（変更履歴）

アップデートをアップロードするときの「変更内容」の欄に書く文です。版（`mod.info` の `modversion`）ごとに分けて、新しいものを下に足していきます。

### 0.1.0（初回公開）

```
・ワークショップ初回公開（読書の残り時間、ウィッシュリスト、料理の食材をまとめる、スキルウィンドウ、PvP の切り替えボタンを隠す、アイテムからレシピを見る）
```

### 0.2.0（2026-10-30 公開）

```
0.2.0
・プレイヤー一覧を追加（オンラインの人と、7日以内に来ていた人を最終ログイン付きで表示。マルチプレイのみ）
・材料のレシピをたどるを追加（制作・建築の画面で材料を右クリック →「レシピを見る」、検索欄の左の「戻る」で前の表示に戻る）
・ユーザーパネルのボタンを隠すを追加（派閥などを使わないサーバー向け。管理者には常に表示）
・ウィッシュリストの共有を変更（自分のリストのアイテムを「共有する」と、みんなのリストに出る。共有を外せるのは本人と管理者だけ。「追加して共有する」で一度に登録できる。両方に入っているアイテムは赤で表示）
・ウィッシュリストに上限を追加（自分のリストは100件、共有は1人30種類、みんなのリストは300種類まで。いっぱいのときはメニューが赤くなり、理由が出る）
・設定画面の並び順を、使う場所ごとにまとめた順に変更
・スキルウィンドウを開くキーの初期値を「キーなし」に変更（すでにキーを設定している人はそのまま）
・画面左のボタンが画面の下に届くときは、右の列に並ぶように変更
```

### 0.3.0

```
0.3.0
・英語名でも検索するを追加（日本語でプレイしていても、制作・建築の画面の検索で英語名でもレシピが見つかる。オプションで英語名を含めるかを選べる）
```

### 0.4.0

```
0.4.0
・インベントリ検索を追加（インベントリと周りの容器の一覧に検索欄。合うアイテムが上にまとまり、ほかは暗く表示。ひらがなとカタカナは区別せず、英語名でも見つかる。検索中の「すべて取る」「すべて移す」は合うアイテムだけを移す。itsu07 さんの Inventory Search を元にしています）
・ほかの人のスキルを見るを追加（プレイヤー一覧でオンラインの人をクリックすると、その人のスキルを表示。マルチプレイのみ。itsu07 さんの Skill Viewer を元にしています）
・英語名でも検索するで、ひらがなとカタカナを区別しないように変更
・設定画面を整理（7つの中項目にまとめ、ON/OFF だけの機能は見出しなしの1行に。今までの設定はそのまま引き継がれます）
・ユーザーパネルのボタンを隠すの説明に、隠している間はパネルの中の画面（派閥、チケットなど）も開けないことを追記
・料理の食材をまとめるを、ゲーム本体のメニューの作りを使う形に変更（ほかの MOD との競合を減らすため）
・設定画面の読み込みでエラーが出ても、ほかの MOD の設定が止まらないように修正
・管理者の判定を「キックできる人」にそろえた（ウィッシュリストの管理者の操作と、ユーザーパネルのボタン）
・プレイヤー一覧の開閉を連打しても、サーバーへの問い合わせが増えすぎないように修正
・動作を軽くする修正（ウィッシュリストの色付け、読書の残り時間の表示、英語名の検索、材料のレシピをたどるの「戻る」ボタン）
・Build 42.21 より前のゲームでは有効にできないように変更
・ライセンスを MIT に
```
