extends GutTest
const Game=preload("res://game/main.gd")

func candidates(interfaces: Array[Dictionary]) -> Array:
	var game:=Game.new()
	autofree(game)
	assert_true(game.has_method("_lan_address_candidates"),"LAN candidates must use adapter identity, not raw enumeration order")
	if not game.has_method("_lan_address_candidates"): return []
	return game._lan_address_candidates(interfaces)

func test_wifi_is_first_when_windows_lists_hyper_v_first() -> void:
	var result: Array=candidates([
		{"friendly":"vEthernet (WSL (Hyper-V firewall))","name":"virtual-id","addresses":["172.22.48.1"]},
		{"friendly":"WiFi","name":"wifi-id","addresses":["192.168.20.15"]}
	])
	assert_eq(result.size(),2)
	if result.size()!=2: return
	assert_eq(result[0],"192.168.20.15 (WiFi)")
	assert_string_contains(result[1],"172.22.48.1")
	assert_string_contains(result[1],"virtual")

func test_ipv4_candidates_filter_unusable_addresses_and_duplicates() -> void:
	var result: Array=candidates([
		{"friendly":"Ethernet","addresses":["127.0.0.1","169.254.1.3","::1","fe80::12","0.0.0.0","224.0.0.5","255.255.255.255","999.1.2.3","host.local","192.168.1.25","192.168.1.25"]},
		{"friendly":"VPN","addresses":["192.168.1.25","10.8.0.2"]}
	])
	assert_eq(result,["192.168.1.25 (Ethernet)","10.8.0.2 (virtual: VPN)"])

func test_unknown_adapter_remains_available_ahead_of_virtual_fallback() -> void:
	var result: Array=candidates([
		{"friendly":"WireGuard","addresses":["10.8.0.2"]},
		{"friendly":"","name":"Dock network","addresses":["10.1.2.3"]}
	])
	assert_eq(result,["10.1.2.3 (Dock network)","10.8.0.2 (virtual: WireGuard)"])
