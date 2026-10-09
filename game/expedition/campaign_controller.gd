extends RefCounted
## A run-local mission. Only the durable settlement may reveal its ending.
var armed: bool=false
var signalled: bool=false
var departing: bool=false
var completed: bool=false

func reset() -> void:
	armed=false
	signalled=false
	departing=false
	completed=false

func arm(repairs_ready: bool, elapsed: float) -> Dictionary:
	if departing: return {"ok":false,"code":"already_departing"}
	if not repairs_ready: return {"ok":false,"code":"finish_repairs_first"}
	if elapsed<240 or elapsed>=630: return {"ok":false,"code":"wait_for_night"}
	armed=true
	return {"ok":true,"code":"escape_armed"}

func signal_beacon(elapsed: float) -> Dictionary:
	if not armed or departing or elapsed<240 or elapsed>=630: return {"ok":false,"code":"arm_escape_at_moth_first"}
	signalled=true
	return {"ok":true,"code":"beacon_signalled"}

func depart(elapsed: float) -> bool:
	departing=armed and signalled and elapsed>=240 and elapsed<630
	return departing

func settled() -> void:
	completed=departing

func snapshot(repairs_ready: bool, elapsed: float) -> Dictionary:
	var description: String="Repair Moth and the beacon to reach open water."
	if repairs_ready: description="After sunset, arm the escape at Moth."
	if armed: description="Reach the Beacon and signal the channel."
	if signalled: description="Return to Moth together. Everyone boards and readies to escape."
	if departing: description="The channel is open. Last Light is falling behind."
	if completed: description="You made it off Last Light. Every catch, tool and repair is saved."
	return {"armed":armed,"signalled":signalled,"departing":departing,"completed":completed,
		"can_arm":repairs_ready and not armed and elapsed>=240 and elapsed<630,
		"can_signal":armed and not signalled and not departing,"description":description}
