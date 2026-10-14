extends "res://tests/active_network_peer.gd"
var draw_frames := 0
var capture_count := 0
var last_capture := -20.0
var first_draw_usec := 0
func boot():
	super.boot()
	if DisplayServer.get_name() != "headless":
		RenderingServer.frame_post_draw.connect(capture_frame)
func capture_frame():
	if not is_instance_valid(app) or app.phase != "match": return
	if first_draw_usec == 0: first_draw_usec = Time.get_ticks_usec()
	draw_frames += 1
	if played-last_capture >= 10.0 or (result_written and last_capture < played-1):
		last_capture = played
		capture_count += 1
		root.get_texture().get_image().save_png(output_dir.path_join("frame-%03d.png" % capture_count))
func _process(dt: float) -> bool:
	# Allow the remote CI machine to download and boot before the normal match
	# timeout starts. No production game state is modified.
	if role == "host" and ready_written and app.phase == "lobby" and app.seats.size() < 3: return false
	var result = super._process(dt)
	if role == "host" and result_written and not quitting and elapsed-result_wait > 8.0: shutdown()
	return result
func shutdown():
	if draw_frames > 0:
		write_json("rendering.json",{"frames":draw_frames,"captures":capture_count,"wall_seconds":(Time.get_ticks_usec()-first_draw_usec)/1000000.0,"adapter":RenderingServer.get_video_adapter_name(),"driver":RenderingServer.get_current_rendering_driver_name(),"processor":OS.get_processor_name(),"features_x86_64":OS.has_feature("x86_64")})
	super.shutdown()
