extends SceneTree
func _initialize():
 var probe=UPNP.new()
 var result=probe.discover(2000,2,"InternetGatewayDevice")
 var gateway=probe.get_gateway()
 var receipt={"discover_result":result,"devices":probe.get_device_count(),"gateway_valid":gateway!=null and gateway.is_valid_gateway(),"external_address":""}
 if gateway!=null and gateway.is_valid_gateway(): receipt.external_address=probe.query_external_address()
 print(JSON.stringify(receipt))
 quit()
