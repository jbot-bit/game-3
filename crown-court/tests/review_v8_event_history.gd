extends SceneTree
const Sim = preload("res://sim.gd")
var failures := 0
var checks := 0

func _initialize() -> void:
	run()

func expect(ok: bool, label: String, detail: Variant = null) -> void:
	checks += 1
	if not ok: failures += 1
	print("PASS " if ok else "FAIL ",label," ",detail if detail != null else "")

func events(sim: RefCounted) -> Array:
	return sim.snapshot().get("recent_events",[])

func run() -> void:
	var sim := Sim.new()
	sim.reset("coop")
	sim.reset_time = 0
	sim.ball.owner = 1
	sim.action(1,"throw",.6)
	var throw_id: int = sim.event_id
	sim.action(4,"jump")
	var history := events(sim)
	expect(history.size() >= 2 and history[-2][0] == throw_id and history[-2][1] == "throw" and history[-1][1] == "jump","Multiple accepted actions survive in chronological snapshot history",history)
	expect(history.size() >= 2 and history[-2][3] == 1 and history[-1][3] == 4,"Retained events preserve their source player")
	expect(sim.snapshot().has("event_clock"),"Snapshot carries an explicit event-age clock")
	for i in 24: sim.emit("jump","",Vector3(i,0,0),1)
	history = events(sim)
	expect(history.size() == 16 and history[0][0] == sim.event_id-15 and history[-1][0] == sim.event_id,"Event history is strictly bounded to newest16")
	if not history.is_empty(): history[-1][1] = "mutated"
	expect(not events(sim).is_empty() and events(sim)[-1][1] == "jump","Snapshot event records cannot mutate authority")
	var original_id: int = sim.event_id
	sim.reset("coop")
	history = events(sim)
	expect(history.size() == 1 and history[0][1] == "tip" and history[0][0] > original_id,"Rematch clears old history while preserving monotonically increasing IDs")
	expect(float(sim.snapshot().get("event_clock",-1)) == 0 and not history.is_empty() and history[0][4] == 0,"New round event clock starts at zero")
	sim.celebration_time = 1
	for frame in 8: sim.step(.05)
	expect(events(sim).is_empty(),"Event history expires after350ms even during score celebration")
	var before := float(sim.snapshot().get("event_clock",0))
	sim.celebration_time = 0
	sim.winner = 0
	sim.emit("win","",Vector3.ZERO,1)
	for frame in 8: sim.step(.05)
	expect(events(sim).is_empty() and float(sim.snapshot().get("event_clock",0)) > before,"Final result freeze still ages out transient sounds")
	print("EVENT HISTORY: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
