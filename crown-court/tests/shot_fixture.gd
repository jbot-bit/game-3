extends RefCounted

# Test driver only: choose a deliberate physical shot, never called by gameplay.
static func aimed_charge(g, id: int, yaw_offset: float = 0.0, target: Vector3 = Vector3.INF) -> float:
	if not target.is_finite(): target=g.hoop(id)
	var offset: Vector3 = target-g.hand_position(id)
	var flat = Vector3(offset.x,0,offset.z)
	# Close shots need a steeper entry to clear the raised rim's near tube.
	var angle = deg_to_rad(78.0 if flat.length()<6 else (70.0 if flat.length()<12 else 58.0))
	var speed = sqrt(g.BALL_GRAVITY*flat.length_squared()/(2*cos(angle)*cos(angle)*(flat.length()*tan(angle)-offset.y)))
	var velocity = flat.normalized()*speed*cos(angle)+Vector3.UP*(speed*sin(angle)+g.BALL_GRAVITY/120.0)
	g.set_shot_aim(id,velocity.normalized().rotated(Vector3.UP,yaw_offset))
	return (velocity.length()-12)/34
