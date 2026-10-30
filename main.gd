extends Control

const Model = preload("res://guild.gd")
const Adapter = preload("res://addons/gua/gua_auto_adapter.gd")
var game = Model.new()
var gua = Adapter.new()
var screen = "title"
var previous = "desk"
var lang = "ja"
var selected = "herb"
var quantity = 1
var sell = false
var reversed = false
var message = ""
var content: VBoxContainer
var modal: VBoxContainer
var overlay: Control
var pending: Dictionary = {}
var selected_before_sort = ""
var save_path = "user://guild-save.json"
var observe_owner: RefCounted

func t(ja: String, en: String) -> String: return ja if lang == "ja" else en
func item_name(id: String) -> String:
	return t({"herb":"薬草","rope":"ロープ","crystal":"水晶","map":"地図"}.get(id,id),id.capitalize())

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--bug="):
			var flag = arg.trim_prefix("--bug=")
			if flag in ["double_reward","cancel_charge","sort_target"]: game.bugs.append(flag)
		if arg.begins_with("--save-path="): save_path=arg.trim_prefix("--save-path=")
	var theme_new = Theme.new()
	theme_new.default_font_size=20
	theme=theme_new
	render()
	gua.attach(self)
	gua.update(screen)
	observe_owner=gua.create_observe_owner(1,"root",self)
	observe_owner.observe("state",func(): return {"type":"string","value":JSON.stringify(game.snapshot())})
	observe_owner.observe("selection",func(): return {"type":"string","value":selected})
	var port = int(OS.get_environment("GUA_BRIDGE_PORT"))
	if port==0: port=8793
	if not gua.start_inspector_bridge(port): push_error("Gua bridge failed")
	print("GUILD Gua 1.1.2 bridge: ",gua.inspector_bridge_url()," bugs=",game.bugs)

func _process(_delta: float) -> void: gua.update(screen)
func _exit_tree() -> void:
	if observe_owner: observe_owner.dispose()
	gua.dispose()
func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if screen=="confirmation": finish_trade(false)
		elif screen=="pause": go(previous)
		elif screen not in ["title","result"]: previous=screen; go("pause")
		get_viewport().set_input_as_handled()

func label_text(text: String, parent: Node = null) -> Label:
	var node=Label.new(); node.text=text; node.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	(parent if parent else content).add_child(node)
	return node
func button(id: String, text: String, action: Callable, parent: Node = null) -> Button:
	var node=Button.new(); node.text=text; node.set_meta("gua_id",id); node.custom_minimum_size.y=42
	(parent if parent else content).add_child(node); node.pressed.connect(action)
	return node
func go(target: String) -> void:
	screen=target; message=""; render()
func result(text: String) -> void: message=text; render()
func reset_game() -> void:
	var flags=game.bugs.duplicate(); game=Model.new(); game.bugs=flags
	selected="herb"; quantity=1; reversed=false; selected_before_sort=""; go("desk")

func render() -> void:
	for child in get_children(): remove_child(child); child.queue_free()
	overlay=null
	var margin=MarginContainer.new(); margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left",30); margin.add_theme_constant_override("margin_right",30)
	margin.add_theme_constant_override("margin_top",18); margin.add_theme_constant_override("margin_bottom",18); add_child(margin)
	var scroll=ScrollContainer.new(); margin.add_child(scroll)
	content=VBoxContainer.new(); content.size_flags_horizontal=Control.SIZE_EXPAND_FILL; content.add_theme_constant_override("separation",8); scroll.add_child(content)
	label_text(t("小さな冒険者ギルド", "LITTLE ADVENTURER GUILD")).add_theme_font_size_override("font_size",32)
	label_text(t("受付ノート / 日数は「翌日へ」でのみ進行", "RECEPTION NOTE / Days advance only with Next day"))
	label_text(t("日付 %d  |  所持金 %d G  |  鞄 %d / 3 種（各9個）", "Day %d  |  Gold %d G  |  Bag %d / 3 types (9 each)") % [game.day,game.gold,game.bag.size()])
	label_text("guild-v1 | seed: deterministic | bugs: "+str(game.bugs))
	if message!="": label_text("» "+message)
	match screen:
		"confirmation":
			label_text(t("取引確認", "CONFIRM TRANSACTION"))
			label_text((t("売却 ","Sell ") if pending.sell else t("購入 ","Buy "))+item_name(pending.item)+" × "+str(pending.qty))
			button("confirm_trade",t("確定","Confirm"),func(): finish_trade(true))
			button("cancel_trade",t("キャンセル","Cancel"),func(): finish_trade(false))
		"title":
			label_text(t("冒険者と話し、品を仕入れ、3件の依頼を完了しましょう。制限時間はありません。", "Talk to the adventurer, trade supplies and complete three requests. No time limit."))
			button("start",t("開始","Start"),reset_game)
			button("load",t("保存から再開","Load saved game"),load_game)
			button("settings",t("設定","Settings"),func(): previous="title"; go("settings"))
		"desk":
			label_text(t("◇ 受付 / 冒険者ミナが依頼を持って待っています。", "◇ RECEPTION / Mina is waiting with supply requests."))
			button("talk",t("ミナと会話","Talk to Mina"),func(): go("talk"))
			button("shop",t("道具屋","Shop"),func(): go("shop"))
			button("inventory",t("インベントリ","Inventory"),func(): go("inventory"))
			button("quests",t("依頼一覧","Requests"),func(): go("quests"))
			button("next_day",t("翌日へ（期限判定 → 在庫補充）","Next day (expiry → restock)"),func(): result(game.next_day()))
			button("pause",t("ポーズ / 保存 / 設定","Pause / save / settings"),func(): previous="desk"; go("pause"))
		"talk":
			label_text(t("ミナ：薬草3個、ロープ2個、水晶2個が必要です。品物は受注前に集めても大丈夫。", "Mina: I need 3 herbs, 2 ropes and 2 crystals. You may gather them before accepting."))
			label_text(t("既読: ","Read: ")+str(game.read)+" | "+game.branch)
			button("talk_supplies",t("必要な道具を聞く","Ask about supplies"),func(): game.read=true; game.branch="supplies"; result(t("ミナ：薬草は3日、ロープは5日、水晶は7日まで。部分納品もできます。","Mina: Herbs by day 3, ropes by day 5, crystals by day 7. Partial delivery is welcome.")))
			button("talk_reward",t("報酬を聞く","Ask about rewards"),func(): game.read=true; game.branch="rewards"; result(t("ミナ：報酬は20 / 24 / 30G。納品が終わったら受け取ってね。","Mina: Rewards are 20 / 24 / 30G. Claim after delivery.")))
			back()
		"shop":
			label_text(t("道具屋 / 売却価格は購入価格の半額", "SUPPLIES / Sell for half the purchase price"))
			for item in Model.ITEMS:
				button("select_"+item,("● " if selected==item else "○ ")+item_name(item)+"  %dG  / stock %d / owned %d" % [Model.PRICE[item],game.stock[item],game.bag.get(item,0)],func(): selected=item; render())
			var row=HBoxContainer.new(); content.add_child(row)
			button("qty_minus","−",func(): quantity=maxi(1,quantity-1); render(),row)
			var quantity_label=label_text(t("数量: ","Quantity: ")+str(quantity),row)
			quantity_label.autowrap_mode=TextServer.AUTOWRAP_OFF
			quantity_label.custom_minimum_size.x=150
			button("qty_plus","+",func(): quantity=mini(9,quantity+1); render(),row)
			button("buy",t("購入確認","Buy: review"),func(): confirm_trade(false))
			button("sell",t("売却確認","Sell: review"),func(): confirm_trade(true))
			back()
		"inventory":
			label_text(t("納品する品を選択（並べ替えても品目を保持）", "Select delivery item (sorting preserves selection)"))
			var keys=game.bag.keys(); keys.sort()
			if reversed: keys.reverse()
			for item in keys:
				button("bag_"+item,("● " if selected==item else "○ ")+item_name(item)+" × "+str(game.bag[item]),func(): selected=item; selected_before_sort=""; render())
			label_text(t("選択中: ","Selected: ")+item_name(selected))
			button("sort",t("並べ替え","Sort"),func():
				selected_before_sort=selected
				reversed=not reversed
				if game.bugs.has("sort_target") and keys.size()>1:
					selected=keys[(keys.find(selected)+1)%keys.size()]
				render())
			button("to_requests",t("依頼へ / 選択品を納品","Requests / deliver selected item"),func(): go("quests"))
			back()
		"quests":
			label_text(t("依頼一覧 / 選択品: ","REQUESTS / selected: ")+item_name(selected))
			for i in range(3):
				var q=game.quests[i]; var spec=Model.REQUESTS[i]
				label_text("%d. %s %d/%d | %s | day ≤ %d | %dG" % [i+1,item_name(spec.item),q.delivered,spec.need,q.status,spec.deadline,spec.reward])
				var row=HBoxContainer.new(); content.add_child(row)
				button("accept_"+str(i),t("受注","Accept"),func(): result(game.accept(i)),row)
				button("deliver_"+str(i),t("選択品を1個納品","Deliver 1 selected"),func(): result(game.deliver(i,selected,1)),row)
				button("claim_"+str(i),t("報酬受領","Claim reward"),func():
					message=game.claim(i)
					if game.complete(): screen="result"
					render(),row)
			button("choose_item",t("インベントリで品を選ぶ","Choose inventory item"),func(): go("inventory"))
			back()
		"pause":
			label_text(t("中断中 / 時間経過・自動処理なし", "PAUSED / No elapsed-time simulation"))
			button("resume",t("復帰","Resume"),func(): go(previous))
			button("save",t("保存","Save"),save_game)
			button("load",t("保存から再開","Load saved game"),load_game)
			button("settings",t("設定","Settings"),func(): go("settings"))
			button("reset",t("初期状態にリセット","Reset to initial state"),reset_game)
			button("title",t("タイトルへ","Title"),func(): go("title"))
		"settings":
			button("language",t("言語: 日本語 → English","Language: English → 日本語"),func(): lang="en" if lang=="ja" else "ja"; render())
			for size in [Vector2i(880,608),Vector2i(1100,760),Vector2i(1320,912)]:
				button("size_"+str(size.x),str(size.x)+" × "+str(size.y),func(): DisplayServer.window_set_size(size))
			button("settings_back",t("戻る","Back"),func(): go("title" if previous=="title" else "pause"))
		"result":
			label_text(t("全3件完了！ ギルドに物資が揃いました。", "ALL THREE COMPLETE! The guild is supplied."))
			button("replay",t("再プレイ","Play again"),reset_game)
			button("pause",t("記録を保存 / 設定","Save record / settings"),func(): previous="result"; go("pause"))
	var first=content.find_children("*","Button",true,false)
	if not first.is_empty(): first[0].grab_focus()

func back() -> void: button("back",t("戻る / キャンセル","Back / cancel"),func(): go("desk"))

func confirm_trade(is_sell: bool) -> void:
	pending={"item":selected,"qty":quantity,"sell":is_sell}
	go("confirmation")

func finish_trade(confirmed: bool) -> void:
	screen="shop"
	result(game.trade(pending.item,pending.qty,pending.sell,confirmed))

func cancel_trade() -> void: render()

func save_game() -> void:
	var data=game.snapshot(); data["language"]=lang
	var file=FileAccess.open(save_path+".tmp",FileAccess.WRITE)
	if not file: result("save_failed"); return
	file.store_string(JSON.stringify(data,"\t")); file.close()
	var error=DirAccess.rename_absolute(save_path+".tmp",save_path)
	result("saved" if error==OK else "save_failed")

func load_game() -> void:
	if not FileAccess.file_exists(save_path): result("no_save"); return
	var data=JSON.parse_string(FileAccess.get_file_as_string(save_path))
	var candidate=Model.new()
	if not data is Dictionary or not candidate.restore(data): result("invalid_save"); return
	game=candidate; lang=data.get("language","ja"); selected="herb"; quantity=1; reversed=false
	go("result" if game.complete() else "desk")
