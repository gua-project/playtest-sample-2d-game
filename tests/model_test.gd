extends SceneTree
const Model=preload("res://guild.gd")
var failures=0
var checks=0
func check(value: bool, id: String) -> void:
	checks+=1
	if not value: failures+=1; printerr("FAIL ",id)
	else: print("PASS ",id)
func _initialize() -> void:
	var g=Model.new()
	check(g.accept(0)=="talk_first","D01 conversation prerequisite")
	g.read=true
	check(g.trade("herb",3,false)=="ok" and g.gold==48,"S01 pre-accept purchase")
	check(g.accept(0)=="ok" and g.deliver(0,"herb",1)=="ok","Q01 partial delivery")
	var restored=Model.new()
	check(restored.restore(JSON.parse_string(JSON.stringify(g.snapshot()))),"P01 partial restore")
	g=restored
	check(g.quests[0].delivered==1 and g.bag.herb==2,"P02 exact partial state")
	check(g.trade("herb",2,true)=="ok" and g.deliver(0,"herb",1)=="wrong_item_or_quantity","Q02 sold supplies cannot deliver")
	check(g.trade("herb",2,false)=="ok" and g.deliver(0,"herb",2)=="ok" and g.claim(0)=="ok","Q03 recover and claim")
	var gold=g.gold
	check(g.claim(0)=="unavailable" and g.gold==gold,"Q04 no double reward")
	check(g.trade("rope",1,false,false)=="cancelled" and g.gold==gold,"S02 cancel atomic")
	for i in [1,2]:
		g.accept(i); g.trade(Model.REQUESTS[i].item,2,false); g.deliver(i,Model.REQUESTS[i].item,2); g.claim(i)
	check(g.complete(),"F01 three requests complete")
	var done=Model.new(); done.restore(g.snapshot()); gold=done.gold
	check(done.claim(2)=="unavailable" and done.gold==gold,"P03 reward restore no duplicate")
	g=Model.new(); g.gold=1000
	check(g.trade("herb",9,false)=="ok" and g.trade("herb",1,false)=="bag_full","S03 stack limit")
	g.trade("rope",1,false); g.trade("crystal",1,false); gold=g.gold
	check(g.trade("map",1,false)=="bag_full" and g.gold==gold,"S04 capacity atomic")
	check(g.trade("herb",0,false)=="invalid_quantity" and g.trade("rope",10,false)=="invalid_quantity","S05 quantity bounds")
	g=Model.new(); g.gold=0
	check(g.trade("rope",1,false)=="gold_low" and g.stock.rope==8,"S06 insufficient gold")
	g.gold=100; g.stock.rope=0
	check(g.trade("rope",1,false)=="stock_low" and g.gold==100,"S07 stock bound")
	g=Model.new(); g.trade("herb",9,false)
	for i in range(9): g.next_day()
	gold=g.gold
	check(g.trade("herb",9,true)=="stock_full" and g.gold==gold and g.bag.herb==9 and g.stock.herb==20,"S08 reject sale above shop capacity atomically")
	check(Model.new().restore(g.snapshot()),"P06 normal expired save reloads after rejected sale")
	g=Model.new(); g.read=true; g.accept(0); g.deliver(0,"herb",1)
	for i in range(3): g.next_day()
	check(g.day==4 and g.quests[0].status=="expired" and g.gold==60,"N01 deadline priority")
	var invalid=g.snapshot(); invalid.version=2
	check(not g.restore(invalid),"P04 reject invalid save")
	for bad in ["three", null, 1.5, true]:
		invalid=g.snapshot(); invalid.bag={"herb":bad}
		check(not g.restore(invalid),"P05 reject invalid item count "+str(bad))
	g=Model.new(); g.bugs=["cancel_charge"]; g.trade("herb",1,false,false)
	check(g.gold==56,"B01 cancel defect detected against 60G expectation")
	g=Model.new(); g.bugs=["double_reward"]; g.quests[0]={"status":"done","delivered":3}; g.claim(0)
	check(g.gold==80,"B02 duplicate defect detected against 60G expectation")
	print("MODEL CHECKS ",checks," FAILURES ",failures)
	quit(1 if failures else 0)
