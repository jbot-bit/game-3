extends GutTest
const Game=preload("res://game/main.gd")

class RefusingStore extends SaveStore:
	var refuse: bool=true
	func commit(state: Dictionary) -> Error:
		return ERR_FILE_CANT_WRITE if refuse else super.commit(state)

func test_successful_settlement_retry_keeps_terminal_physics_frozen():
	var app=Game.new()
	app.game_port=24624
	app.save_path="user://tests/survival-review-"+str(Time.get_ticks_usec())+".json"
	app.settings_path="user://tests/survival-review-settings-"+str(Time.get_ticks_usec())+".json"
	add_child_autofree(app)
	app._host("Review")
	app.controller.set_physics_process(false)
	app.set_physics_process(false)
	app.set_process(false)
	await get_tree().physics_frame
	var controller: Node=app.controller
	var store=RefusingStore.new(app.save_path)
	controller.progression=Progression.new(store,controller.progression.snapshot())
	controller.run.phase="storm"
	controller.run.terminal=true
	controller._settle()
	assert_eq(controller.pending_write.get("kind",""),"settle")
	assert_true(controller.run.paused)
	assert_true(controller.supply_bodies.cell_1.freeze)
	store.refuse=false
	assert_true(controller.apply_intent(1,"pause",{"paused":false},"review-retry").ok)
	assert_true(controller.run.terminal)
	assert_false(controller.run.paused,"Recap countdown must resume after saving")
	assert_true(controller.supply_bodies.cell_1.freeze,"Ended-outing props must stay frozen while recap/ending is displayed")
	assert_true(controller.supply_bodies.cell_2.freeze)
	app.session.close()
