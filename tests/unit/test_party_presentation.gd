extends "res://addons/gut/test.gd"

const MODULE: String = "res://prototypes/physics_party/party_presentation.gd"

func _buffer() -> RefCounted:
	assert_true(FileAccess.file_exists(MODULE), "Shared presentation buffer exists")
	return load(MODULE).new() if FileAccess.file_exists(MODULE) else null

func _frame(stamp: float, x: float, run: String = "run-a") -> Dictionary:
	var bones: Array = []
	for index: int in range(10):
		bones.append(Transform3D(Basis.IDENTITY, Vector3(x, index * 0.1, 0)))
	return {"run_id": run, "pose_msec": stamp, "puppets": {"crew_1": bones}, "props": {"held": Transform3D(Basis.IDENTITY, Vector3(x + 2.0, 0, 0))}}

func test_uneven_arrivals_keep_linear_motion_and_shared_hand_prop_time() -> void:
	var buffer: RefCounted = _buffer()
	if buffer == null: return
	buffer.push(_frame(1000.0, 1.0), 5000.0)
	buffer.push(_frame(1033.0, 1.033), 5045.0)
	buffer.push(_frame(1066.0, 1.066), 5068.0)
	for now: float in [5077.0, 5087.0, 5097.0, 5107.0, 5117.0]:
		var shown: Dictionary = buffer.sample(now)
		var expected_x: float = (now - 4000.0 - 67.0) / 1000.0
		assert_almost_eq(shown.puppets.crew_1[0].origin.x, expected_x, 0.00001)
		assert_almost_eq(shown.props.held.origin.x - shown.puppets.crew_1[0].origin.x, 2.0, 0.00001)
		assert_almost_eq(shown.puppets.crew_1[9].origin.y, 0.9, 0.00001)

func test_delayed_packet_does_not_change_established_clock_offset() -> void:
	var buffer: RefCounted = _buffer()
	if buffer == null: return
	buffer.push(_frame(1000.0, 1.0), 5000.0)
	buffer.push(_frame(1033.0, 1.033), 5080.0)
	buffer.push(_frame(1066.0, 1.066), 5083.0)
	assert_almost_eq(buffer.sample(5120.0).puppets.crew_1[0].origin.x, 1.053, 0.00001)

func test_interleaved_delivery_and_render_frames_keep_velocity_with_jitter() -> void:
	var buffer: RefCounted = _buffer()
	if buffer == null: return
	var arrival_times: Array[int] = [0, 51, 70, 124, 132, 182]
	var delivered: int = 0
	for now: int in range(0, 241, 10):
		while delivered < arrival_times.size() and arrival_times[delivered] <= now:
			buffer.push(_frame(float(delivered * 33), delivered * 0.033), float(4000 + arrival_times[delivered]))
			delivered += 1
		var shown: Dictionary = buffer.sample(float(4000 + now))
		var expected: float = clampf((now - 67.0) / 1000.0, 0.0, 0.165)
		assert_almost_eq(shown.puppets.crew_1[0].origin.x, expected, 0.00001, "Render frame %d follows source time" % now)
		assert_almost_eq(shown.props.held.origin.x, expected + 2.0, 0.00001)

func test_out_of_order_and_duplicate_snapshots_cannot_rewind_or_change_clock() -> void:
	var buffer: RefCounted = _buffer()
	if buffer == null: return
	buffer.push(_frame(1000.0, 1.0), 5000.0)
	buffer.push(_frame(1066.0, 1.066), 5066.0)
	buffer.push(_frame(1033.0, 99.0), 1033.0)
	buffer.push(_frame(1066.0, 99.0), 1066.0)
	assert_almost_eq(buffer.sample(5117.0).puppets.crew_1[0].origin.x, 1.05, 0.00001)

func test_empty_and_exhausted_buffer_hold_without_extrapolating() -> void:
	var buffer: RefCounted = _buffer()
	if buffer == null: return
	assert_eq(buffer.sample(100.0), {})
	buffer.push(_frame(1000.0, 1.0), 5000.0)
	assert_almost_eq(buffer.sample(4900.0).puppets.crew_1[0].origin.x, 1.0, 0.00001)
	assert_almost_eq(buffer.sample(9000.0).puppets.crew_1[0].origin.x, 1.0, 0.00001)

func test_new_run_and_explicit_reset_discard_previous_timeline() -> void:
	var buffer: RefCounted = _buffer()
	if buffer == null: return
	buffer.push(_frame(1000.0, 1.0), 5000.0)
	buffer.push(_frame(20.0, 90.0, "run-b"), 6000.0)
	var shown: Dictionary = buffer.sample(6000.0)
	assert_eq(shown.run_id, "run-b")
	assert_almost_eq(shown.puppets.crew_1[0].origin.x, 90.0, 0.00001)
	buffer.reset()
	assert_eq(buffer.sample(7000.0), {})

func test_large_teleport_changes_at_snapshot_boundary_without_sweeping() -> void:
	var buffer: RefCounted = _buffer()
	if buffer == null: return
	buffer.push(_frame(1000.0, 0.0), 5000.0)
	buffer.push(_frame(1033.0, 30.0), 5033.0)
	var before: Dictionary = buffer.sample(5099.0)
	assert_almost_eq(before.puppets.crew_1[0].origin.x, 0.0, 0.00001)
	assert_almost_eq(before.props.held.origin.x, 2.0, 0.00001)
	var after: Dictionary = buffer.sample(5100.0)
	assert_almost_eq(after.puppets.crew_1[0].origin.x, 30.0, 0.00001)
	assert_almost_eq(after.props.held.origin.x, 32.0, 0.00001)

func test_snapshot_queue_is_bounded_and_inputs_outputs_are_detached() -> void:
	var buffer: RefCounted = _buffer()
	if buffer == null: return
	for index: int in range(200):
		buffer.push(_frame(float(index * 33), float(index) * 0.033), float(4000 + index * 33))
	assert_lte(buffer.get("_snapshots").size(), 12, "A stopped renderer cannot grow the queue forever")
	var input: Dictionary = _frame(7000.0, 7.0)
	buffer.push(input, 11000.0)
	input.puppets.crew_1.clear()
	var shown: Dictionary = buffer.sample(12000.0)
	assert_eq(shown.puppets.crew_1.size(), 10)
	shown.puppets.crew_1.clear()
	assert_eq(buffer.sample(12001.0).puppets.crew_1.size(), 10)

func test_invalid_snapshot_cannot_replace_valid_motion() -> void:
	var buffer: RefCounted = _buffer()
	if buffer == null: return
	buffer.push(_frame(1000.0, 1.0), 5000.0)
	var invalid: Dictionary = _frame(1033.0, 2.0)
	invalid.puppets.crew_1[0].origin.x = NAN
	buffer.push(invalid, 5033.0)
	buffer.push({"run_id": "invalid"}, 5040.0)
	var shown: Dictionary = buffer.sample(6000.0)
	assert_eq(shown.run_id, "run-a")
	assert_almost_eq(shown.puppets.crew_1[0].origin.x, 1.0, 0.00001)
