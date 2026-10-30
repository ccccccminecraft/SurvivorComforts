# Steam ワークショップのページ

ワークショップのページ（https://steamcommunity.com/sharedfiles/filedetails/?id=3829529741 ）に載せる文章の原稿です。

- ページの「編集」→「説明」に、下のコードブロックの中身をそのまま貼り付けます
- ワークショップの説明は BBCode で書きます（`[h1]` `[b]` `[list]` など。Markdown は使えません）
- 説明は 8000 文字までです。日本語と英語の両方を載せても収まります
- 機能を追加・変更したら、README と一緒にここも直してから、ページに貼り直してください

## タイトル

```
Survivor Comforts
```

## 説明（日本語＋英語）

```
[h1]Survivor Comforts[/h1]
Project Zomboid（Build 42.21 以降）用の、ちょっとした便利機能をまとめた MOD です。
身内のマルチプレイサーバー向けに作っていますが、一人で遊ぶときにも使えます。

[list]
[*]機能ごとに「オプション」→「MOD」→「Survivor Comforts」で ON/OFF できます
[*]新しいアイテム・レシピ・ゲームのルールは追加しません（ゲームバランスは変わりません）
[*]セーブデータに書き込むのは「みんなのウィッシュリスト」と、プレイヤー一覧の最終ログインだけです
[/list]

[h2]機能[/h2]
[list]
[*][b]読書の残り時間[/b]
本を読んでいる間、読み終わるまでの時間をキャラクターの足元に表示します。ゲーム内の時間はオレンジ、現実の時間は緑で表示します。

[*][b]ウィッシュリスト[/b]
欲しいアイテムを右クリックで登録すると、インベントリや周りの容器で色付きで表示されます（自分のリストはオレンジ）。
自分のリストのアイテムを「共有する」と、サーバー全員が見られる「みんなのリスト」（水色）に出ます。両方に入っているアイテムは赤で表示されます。「追加して共有する」で、追加と共有を一度にできます。
共有を外せるのは共有した本人と管理者だけです。同じアイテムを何人でも共有でき、ほかの人の共有を巻き込んで消すことはありません。
制作・建築の画面のレシピや材料からも登録できます。リストは画面左の星のボタンから開けます。
自分のリストは100件、共有は1人30種類、みんなのリストは300種類までです。

[*][b]料理の食材をまとめる[/b]
スープやサラダに食材を加えるメニューで、同じ食材を1行にまとめ、残りが少ないものから使います。

[*][b]スキルウィンドウ[/b]
スキルの一覧を、大きさを変えられる独立したウィンドウで表示します。画面左のボタンで開きます。オプションでキーを決めると、キーでも開けます。

[*][b]プレイヤー一覧[/b]
サーバーにオンラインの人と、7日以内に来ていたオフラインの人を一覧で表示します。オフラインの人には「3時間前」のように最終ログインが出ます。画面左の人のボタンから開けます。マルチプレイのときだけ使えます。

[*][b]PvP の切り替えボタンを隠す[/b]
画面左のドクロのボタンを隠し、PvP を常にオフにします。G キーでの切り替えも無効になります。

[*][b]ユーザーパネルのボタンを隠す[/b]
画面左のユーザーパネル（派閥・セーフハウスなど）のボタンを隠し、下のボタンを詰めます。ボタンを隠すだけで、派閥などの機能はそのまま使えます。管理者には常に表示します。

[*][b]アイテムからレシピを見る[/b]
アイテムを右クリック →「レシピを見る」で、そのアイテムを作れるレシピに絞り込んだ制作の画面を開きます。作れるレシピがないときは赤く表示されます。

[*][b]材料のレシピをたどる[/b]
制作・建築の画面で材料を右クリック →「レシピを見る」で、その材料を作れるレシピに絞り込みます。検索欄の左の「戻る」で、たどる前の表示に戻れます。
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
[*][b]Reading time left[/b]
While reading, shows the time left under your character: in-game time in orange, real time in green.

[*][b]Wishlist[/b]
Right-click an item to add it to your wishlist. Wanted items are highlighted in your inventory and in nearby containers (your list in orange).
Share an item from your list to show it on a shared list everyone on the server can see (light blue). Items on both are shown in red. "Add and share" does both in one step.
Only the player who shared an item, or an admin, can take it off. Any number of players can share the same item, and unsharing never removes someone else's share.
You can also add items from recipes and ingredients in the crafting and building windows. Open the list with the star button on the left of the screen.
Your list holds up to 100 items; each player can share up to 30 kinds, and the shared list holds up to 300.

[*][b]Group cooking ingredients[/b]
In the menu for adding ingredients to soups and salads, the same ingredient is shown on one line, and the item with the least left is used first.

[*][b]Skills window[/b]
Shows your skills in a separate, resizable window. Open it with the button on the left of the screen, or set a key for it in the options.

[*][b]Player list[/b]
Lists who is online on the server, and who was online in the last 7 days with when they were last online ("3 h ago"). Open it with the people button on the left of the screen. Multiplayer only.

[*][b]Hide the PvP button[/b]
Hides the skull button on the left of the screen and keeps PvP off. The G key no longer toggles PvP.

[*][b]Hide the user panel button[/b]
Hides the user panel button (factions, safehouses and more) on the left of the screen and moves the buttons below up. Only the button is hidden; factions and the rest still work. Admins always see it.

[*][b]Show recipes for an item[/b]
Right-click an item and choose "Show recipes" to open the crafting window filtered to recipes that make it. The option is shown in red when no recipe makes the item.

[*][b]Follow ingredient recipes[/b]
In the crafting and building windows, right-click an ingredient and choose "Show recipes" to see the recipes that make it. The Back button left of the search box returns to what was shown before.
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

### 0.2.0

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
