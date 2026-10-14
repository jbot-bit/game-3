extends "res://tests/active_network_peer.gd"

# The inherited driver normally waits for a separate rendered-video process.
# This public three-process test has no video process. Preserve every gameplay
# input/result check, then let peers finish before closing the host normally.
func _process(dt: float) -> bool:
	var result = super._process(dt)
	if role == "host" and result_written and not quitting and elapsed-result_wait > 8.0:
		shutdown()
	return result
