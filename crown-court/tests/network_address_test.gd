extends SceneTree

const Address = preload("res://network_address.gd")
var checks = 0
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		push_error(message)
		quit(1)

func _initialize() -> void:
	for value in ["192.168.1.20", "100.88.99.20", "friend-pc", "friend-pc.tailabc.ts.net", "LOCALHOST", "127.0.0.1"]:
		var parsed = Address.endpoint(" " + value + " ")
		check(parsed.get("host") == value and parsed.get("port") == 28888, "Accept endpoint " + value)
	check(Address.endpoint("friend-pc:30000").get("port") == 30000, "Custom port")
	for value in ["", "https://friend-pc", "192.168.999.1", "1.2.3", "1.2.3.4:0", "host:65536", "host:no", "a..b", "-host", "host-", "host name", "host\nname", "0.0.0.0", "255.255.255.255", "host/path"]:
		check(Address.endpoint(value).has("error"), "Reject malformed endpoint " + value)
	for value in ["100.64.0.1", "100.127.255.254"]: check(Address.kind(value) == "internet", "Overlay boundary " + value)
	for value in ["100.63.255.255", "100.128.0.1", "172.15.1.1", "172.32.1.1", "127.0.0.1", "169.254.1.1", "8.8.8.8", "::1"]:
		check(Address.kind(value).is_empty(), "Do not advertise nonprivate " + value)
	for value in ["10.0.0.1", "172.16.0.1", "172.31.255.254", "192.168.1.1"]: check(Address.kind(value) == "lan", "LAN boundary")
	var listed = Address.available(PackedStringArray(["172.22.1.1", "100.80.1.1", "192.168.1.2", "100.80.1.1", "::1", "10.0.0.2"]))
	check(listed.internet == ["100.80.1.1"], "Overlay unique")
	check(listed.lan == ["192.168.1.2", "10.0.0.2", "172.22.1.1"], "WiFi first without hiding other adapters")
	print("NETWORK ADDRESS PASS: %d checks" % checks)
	quit()
