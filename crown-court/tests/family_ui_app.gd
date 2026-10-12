extends "res://tests/controller_app.gd"

var preview_equipment: Dictionary = {}

func save_settings() -> void:
	# Family UI tests never write the household settings file.
	pass

func make_bean_preview(parent: Node, equipment: Dictionary, dimensions: Vector2) -> SubViewportContainer:
	preview_equipment = equipment.duplicate(true)
	return super.make_bean_preview(parent, equipment, dimensions)
