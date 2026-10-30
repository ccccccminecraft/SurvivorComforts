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
[*]セーブデータに書き込むのは「みんなのウィッシュリスト」だけです
[/list]

[h2]機能[/h2]
[list]
[*][b]読書の残り時間[/b]
本を読んでいる間、読み終わるまでの時間をキャラクターの足元に表示します。ゲーム内の時間はオレンジ、現実の時間は緑で表示します。

[*][b]ウィッシュリスト[/b]
欲しいアイテムを右クリックで登録すると、インベントリや周りの容器で色付きで表示されます。
自分だけのリスト（オレンジ）と、サーバー全員で共有する「みんなのリスト」（水色）があります。
制作・建築の画面のレシピや材料からも登録できます。リストは画面左の星のボタンから開けます。

[*][b]料理の食材をまとめる[/b]
スープやサラダに食材を加えるメニューで、同じ食材を1行にまとめ、残りが少ないものから使います。

[*][b]スキルウィンドウ[/b]
スキルの一覧を、大きさを変えられる独立したウィンドウで表示します。画面左のボタンか [b]K[/b] キーで開きます（キーは変更できます）。

[*][b]PvP の切り替えボタンを隠す[/b]
画面左のドクロのボタンを隠し、PvP を常にオフにします。G キーでの切り替えも無効になります。

[*][b]アイテムからレシピを見る[/b]
アイテムを右クリック →「レシピを見る」で、そのアイテムを作れるレシピに絞り込んだ制作の画面を開きます。作れるレシピがないときは赤く表示されます。
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
[*]MOD を外しても、セーブデータに残るのは「みんなのウィッシュリスト」の中身だけで、ゲームには影響しません
[/list]

[hr][/hr]

[h1]Survivor Comforts (English)[/h1]
A small collection of quality-of-life features for Project Zomboid (Build 42.21 or later).
Made for a private multiplayer server, but it also works in single player.

[list]
[*]Each feature can be turned on or off in Options > Mods > Survivor Comforts
[*]No new items, recipes or game rules (the game balance does not change)
[*]Only the shared wishlist is saved to the world
[/list]

[h2]Features[/h2]
[list]
[*][b]Reading time left[/b]
While reading, shows the time left under your character: in-game time in orange, real time in green.

[*][b]Wishlist[/b]
Right-click an item to add it to your wishlist. Wanted items are highlighted in your inventory and in nearby containers.
There is a personal list (orange) and a shared list for everyone on the server (light blue).
You can also add items from recipes and ingredients in the crafting and building windows. Open the list with the star button on the left of the screen.

[*][b]Group cooking ingredients[/b]
In the menu for adding ingredients to soups and salads, the same ingredient is shown on one line, and the item with the least left is used first.

[*][b]Skills window[/b]
Shows your skills in a separate, resizable window. Open it with the button on the left of the screen or the [b]K[/b] key (the key can be changed).

[*][b]Hide the PvP button[/b]
Hides the skull button on the left of the screen and keeps PvP off. The G key no longer toggles PvP.

[*][b]Show recipes for an item[/b]
Right-click an item and choose "Show recipes" to open the crafting window filtered to recipes that make it. The option is shown in red when no recipe makes the item.
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
[*]If you remove the mod, only the shared wishlist stays in the save, and it does not affect the game
[/list]
```

## 更新内容（変更履歴）

アップデートをアップロードするときの「変更内容」の欄に書く文の例です。

```
・ワークショップ初回公開（読書の残り時間、ウィッシュリスト、料理の食材をまとめる、スキルウィンドウ、PvP の切り替えボタンを隠す、アイテムからレシピを見る）
```
