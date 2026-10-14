extends SceneTree
# Controlled outcome fixtures exercise production round/reward transitions.
# This is not a naturally completed match or a household playtest.
class Probe extends "res://main.gd":
	func save_settings() -> void: pass

const Series = preload("res://series.gd")
var checks = []
var app

func _initialize() -> void: run.call_deferred()

func check(ok: bool, label: String, detail = {}) -> void:
	checks.append({"passed":ok,"check":label,"detail":detail})
	if not ok: printerr("FAIL ",label," ",detail)

func outcome(winner: int) -> void:
	app.sim.winner = winner
	app.sim.celebration_time = 0
	app._physics_process(0)
	app.update_hud(0)

func run() -> void:
	var series = Series.new()
	series.record("inactive",0)
	check(series.wins == {0:0,1:0},"Inactive series ignores a single-match result")
	series.active = true
	series.record("a",0)
	series.record("a",0)
	series.record("",1)
	series.record("invalid",3)
	check(series.wins == {0:1,1:0} and series.recorded.size() == 1,"Duplicate and invalid outcomes cannot advance a series")
	series.record("b",0)
	series.record("c",1)
	check(series.finished() and series.wins == {0:2,1:0},"Two straight wins finish 2-0 and freeze the outcome")
	series.clear()
	series.active = true
	series.record("d",0)
	series.record("e",1)
	check(not series.finished() and series.wins == {0:1,1:1},"A split starts a deciding third round")
	series.record("f",0)
	check(series.finished() and series.wins == {0:2,1:1},"Decider finishes 2-1")

	app = Probe.new()
	app.manual_input_enabled = false
	app.profile = app.Profile.new("user://series_flow_%d.json" % Time.get_ticks_usec())
	root.add_child(app)
	app.set_process(false)
	app.set_physics_process(false)
	app.muted = true
	app.practice_game("coop")
	var first_id: String = app.match_id
	app.sim.players[1].stats.points = 4
	app.sim.players[4].stats.tackles = 18
	outcome(0)
	check(not app.rivalry.active and app.profile.data.bags == 1,"Finished single match awards its own reward before opting in")
	var summary: Dictionary = app.stats_summary()
	check(summary.mvp.id == 1,"Four-point scorer outranks scoreless opponent with eighteen hits for MVP",summary.mvp)
	var opponent: Dictionary = summary.rows.filter(func(row): return row.id == 4)[0]
	check(opponent.hits == 18 and opponent.steals == 0,"Result rows do not convert tackles into steals",opponent)
	var stats_label = app.result_panel.find_child("Stats",true,false) as Label
	check("0 steals  ·  18 hits" in stats_label.text,"Visible result labels distinguish hits from actual steals")
	app.sim.players[4].stats.steals = 2
	app._physics_process(0)
	summary = app.stats_summary()
	opponent = summary.rows.filter(func(row): return row.id == 4)[0]
	check(opponent.steals == 2 and opponent.hits == 18,"Actual steals remain exact when tackles also exist",opponent)
	var power_option = app.result_panel.find_child("NextPower",true,false) as OptionButton
	check(is_instance_valid(power_option),"Result panel exposes next-round power selector")
	if is_instance_valid(power_option):
		power_option.select(app.POWER_IDS.find("blast"))
		power_option.item_selected.emit(power_option.selected)
	app.runback_series()
	var second_id: String = app.match_id
	check(app.rivalry.active and app.rivalry.wins == {0:1,1:0} and app.rivalry.recorded == [first_id],"Opting in counts the finished single match as round one")
	check(second_id != first_id and app.sim.winner < 0,"Runback starts a fresh match identity")
	check(app.sim.players[1].power == "blast","Result power choice applies to the next round")
	outcome(0)
	outcome(0)
	check(app.rivalry.wins == {0:2,1:0} and app.rivalry.recorded.size() == 2,"Repeated outcome processing does not double count")
	check(app.profile.data.bags == 2 and app.profile.data.redeemed.size() == 2 and first_id in app.profile.data.redeemed and second_id in app.profile.data.redeemed,"Each round awards once using its unique match identity")
	check("SERIES WON" in app.series_text(),"Completed series result is presented")
	app.runback_series()
	check(app.rivalry.active and app.rivalry.wins == {0:0,1:0} and app.rivalry.recorded.is_empty(),"New best of three starts zeroed without importing the old final")
	outcome(0)
	app.runback_series()
	outcome(1)
	check(app.rivalry.wins == {0:1,1:1} and not app.rivalry.finished(),"Application keeps a 1-1 series active")
	app.runback_series()
	outcome(0)
	check(app.rivalry.wins == {0:2,1:1} and app.rivalry.finished(),"Application closes the deciding round 2-1")
	app.single_rematch()
	check(not app.rivalry.active and app.rivalry.wins == {0:0,1:0} and app.rivalry.recorded.is_empty(),"Single rematch clears the series")
	outcome(0)
	app.runback_series()
	await app.close_session()
	check(app.phase == "menu" and not app.rivalry.active and app.rivalry.recorded.is_empty(),"Closing the session clears the series")
	app.practice_game("versus")
	outcome(1)
	var ffa_id: String = app.match_id
	app.runback_series()
	check(not app.rivalry.active and app.match_id == ffa_id,"Free-for-all cannot start an unsupported team series")
	await app.close_session()
	app.queue_free()
	await process_frame
	var failed = checks.filter(func(row): return not row.passed).size()
	print("SERIES_FLOW_RESULT ",JSON.stringify({"checks":checks,"failures":failed}))
	quit(0 if failed == 0 else 1)
