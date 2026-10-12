extends SceneTree
func _initialize():
    inspect.call_deferred()
func inspect():
    await create_timer(3.0).timeout
    var pads = []
    for id in Input.get_connected_joypads():
        pads.append({'device':id,'name':Input.get_joy_name(id),'guid':Input.get_joy_guid(id),'known_mapping':Input.is_joy_known(id)})
    print('CONTROLLER_INVENTORY ', JSON.stringify(pads))
    quit()
