extends RefCounted

const ITEMS = ["herb", "rope", "crystal", "map"]
const PRICE = {"herb": 4, "rope": 8, "crystal": 12, "map": 6}
const REQUESTS = [
	{"item":"herb", "need":3, "reward":20, "deadline":3},
	{"item":"rope", "need":2, "reward":24, "deadline":5},
	{"item":"crystal", "need":2, "reward":30, "deadline":7}]
var day = 1
var gold = 60
var bag = {}
var stock = {"herb":12,"rope":8,"crystal":6,"map":5}
var quests = [{"status":"open","delivered":0},{"status":"open","delivered":0},{"status":"open","delivered":0}]
var read = false
var branch = ""
var bugs: Array = []
var history: Array = []

func log_action(action: String, result: String) -> String:
	history.append({"day":day,"action":action,"result":result,"bugs":bugs.duplicate()})
	return result

func trade(item: String, qty: int, sell: bool, confirm: bool = true) -> String:
	if not ITEMS.has(item) or qty < 1 or qty > 9:
		return log_action("trade", "invalid_quantity")
	if not confirm:
		if bugs.has("cancel_charge") and not sell:
			gold -= PRICE[item] * qty
		return log_action("cancel_purchase", "cancelled")
	if sell:
		if bag.get(item,0) < qty: return log_action("sell", "not_owned")
		if stock[item]+qty>20: return log_action("sell", "stock_full")
		bag[item] -= qty
		if bag[item] == 0: bag.erase(item)
		gold += int(PRICE[item] / 2) * qty
		stock[item] += qty
	else:
		if stock[item] < qty: return log_action("buy", "stock_low")
		if gold < PRICE[item] * qty: return log_action("buy", "gold_low")
		if (not bag.has(item) and bag.size() >= 3) or bag.get(item,0)+qty > 9:
			return log_action("buy", "bag_full")
		bag[item] = bag.get(item,0)+qty
		gold -= PRICE[item]*qty
		stock[item] -= qty
	return log_action("sell" if sell else "buy", "ok")

func accept(index: int) -> String:
	if index < 0 or index >= 3 or quests[index].status != "open": return log_action("accept", "unavailable")
	if not read: return log_action("accept", "talk_first")
	if day > REQUESTS[index].deadline: return log_action("accept", "expired")
	quests[index].status = "active"
	return log_action("accept", "ok")

func deliver(index: int, item: String, qty: int) -> String:
	if index < 0 or index >= 3 or quests[index].status != "active": return log_action("deliver", "unavailable")
	if item != REQUESTS[index].item or qty < 1 or qty > REQUESTS[index].need-quests[index].delivered or bag.get(item,0)<qty:
		return log_action("deliver", "wrong_item_or_quantity")
	bag[item] -= qty
	if bag[item] == 0: bag.erase(item)
	quests[index].delivered += qty
	if quests[index].delivered == REQUESTS[index].need: quests[index].status = "ready"
	return log_action("deliver", "ok")

func claim(index: int) -> String:
	if index < 0 or index >= 3: return "unavailable"
	if quests[index].status != "ready" and not (bugs.has("double_reward") and quests[index].status == "done"):
		return log_action("claim", "unavailable")
	gold += REQUESTS[index].reward
	quests[index].status = "done"
	return log_action("claim", "ok")

func next_day() -> String:
	day += 1
	for i in range(3):
		if day > REQUESTS[i].deadline and quests[i].status in ["open","active"]: quests[i].status = "expired"
	for item in ITEMS: stock[item] = mini(stock[item]+2,20)
	return log_action("next_day", "ok")

func complete() -> bool:
	return quests.all(func(q): return q.status == "done")

func snapshot() -> Dictionary:
	return {"version":1,"scenario":"guild-v1","day":day,"gold":gold,"bag":bag.duplicate(true),"stock":stock.duplicate(true),"quests":quests.duplicate(true),"read":read,"branch":branch,"bugs":bugs.duplicate(),"history":history.duplicate(true)}

func valid_integer(value: Variant, minimum: int, maximum: int) -> bool:
	return typeof(value) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(value)) and value>=minimum and value<=maximum and value==int(value)

func restore(data: Dictionary) -> bool:
	if data.get("version") != 1 or data.get("scenario") != "guild-v1": return false
	if not valid_integer(data.get("day"),1,1000000) or not valid_integer(data.get("gold"),0,1000000000): return false
	if not data.get("bag") is Dictionary or data.bag.size()>3 or not data.get("stock") is Dictionary: return false
	for item in data.bag:
		if not ITEMS.has(item) or not valid_integer(data.bag[item],1,9): return false
	for item in ITEMS:
		if not valid_integer(data.stock.get(item),0,20): return false
	if data.stock.size()!=4: return false
	if not data.get("quests") is Array or data.quests.size()!=3: return false
	for i in range(3):
		var q = data.quests[i]
		if not q is Dictionary or not q.get("status") in ["open","active","ready","done","expired"]: return false
		if not valid_integer(q.get("delivered"),0,REQUESTS[i].need): return false
		if q.status in ["ready","done"] and q.delivered!=REQUESTS[i].need: return false
		if q.status=="open" and q.delivered!=0: return false
		if q.status=="active" and (q.delivered>=REQUESTS[i].need or data.day>REQUESTS[i].deadline): return false
	if not data.get("bugs") is Array or not data.get("history") is Array: return false
	for flag in data.bugs:
		if flag not in ["double_reward","cancel_charge","sort_target"]: return false
	if not data.get("read") is bool or data.get("branch") not in ["","supplies","rewards"]: return false
	if data.get("language","ja") not in ["ja","en"]: return false
	day=int(data.day); gold=int(data.gold); bag=data.bag.duplicate(true); stock=data.stock.duplicate(true); quests=data.quests.duplicate(true)
	read=data.get("read",false); branch=str(data.get("branch","")); bugs=data.bugs.duplicate(); history=data.history.duplicate(true)
	return true
