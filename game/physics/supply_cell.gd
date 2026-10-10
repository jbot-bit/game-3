class_name SupplyCell
extends "res://game/fishing/physical_fish.gd"
## Shares stable host carry, toss, pause, recovery and network poses with fish.

var cell_id: String=""

func setup_cell(id: String) -> void:
	cell_id=id
	super.setup(id,"penny_perch",false)
	name="Supply_"+id.validate_node_name()
	flop_enabled=false
	_shape.size=Vector3(0.9,0.7,0.65)
	_visual.free()
	_visual=Node3D.new()
	_visual.name="BatteryVisual"
	var art: GDScript=preload("res://game/world/block_art.gd")
	art.box(_visual,Vector3.ZERO,Vector3(0.86,0.62,0.62),Color("202d3a"))
	art.box(_visual,Vector3(0,0.29,0),Vector3(0.9,0.1,0.66),Color("e4d4af"))
	art.box(_visual,Vector3(0,-0.29,0),Vector3(0.9,0.1,0.66),Color("e4d4af"))
	art.box(_visual,Vector3(0,0.37,0),Vector3(0.25,0.1,0.25),Color("ffd071"))
	for side: float in [-1.0,1.0]:
		art.box(_visual,Vector3(0,0,side*0.318),Vector3(0.12,0.36,0.035),Color("ffd071"))
		art.box(_visual,Vector3(0,0,side*0.32),Vector3(0.34,0.12,0.04),Color("ffd071"))
	_visual_offset=Transform3D.IDENTITY
	add_child(_visual)
