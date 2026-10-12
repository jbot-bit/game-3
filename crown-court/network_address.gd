extends RefCounted

const DEFAULT_PORT = 28888

# ENet accepts DNS names too, including Tailscale's MagicDNS names.
static func endpoint(value: String) -> Dictionary:
	var host = value.strip_edges()
	var port = DEFAULT_PORT
	if host.is_empty(): return {"error": "Enter the address shown in your friend's host lobby."}
	if host.count(":") == 1:
		var parts = host.split(":")
		if not parts[1].is_valid_int(): return {"error": "Use a host address, optionally followed by :port."}
		port = int(parts[1])
		host = parts[0]
	if port < 1 or port > 65535: return {"error": "Port must be between 1 and 65535."}
	if host.length() > 253 or ":" in host or "/" in host or " " in host or "\n" in host or "\t" in host or "\r" in host:
		return {"error": "Use the host's IPv4 address or computer name, without http://."}
	var only_digits = true
	for character in host:
		if not character in "0123456789.": only_digits = false
	if only_digits:
		if not valid_ipv4(host): return {"error": "That IPv4 address is invalid. Check all four numbers."}
		if host == "0.0.0.0" or int(host.get_slice(".", 0)) >= 224:
			return {"error": "Use the host computer's address."}
	else:
		for label in host.trim_suffix(".").split("."):
			if label.is_empty() or label.length() > 63 or label.begins_with("-") or label.ends_with("-"):
				return {"error": "That computer name is invalid."}
			for character in label.to_lower():
				if not character in "abcdefghijklmnopqrstuvwxyz0123456789-": return {"error": "That computer name is invalid."}
	return {"host": host, "port": port}

static func valid_ipv4(value: String) -> bool:
	var parts = value.split(".")
	if parts.size() != 4: return false
	for part in parts:
		if part.is_empty() or part.length() > 3: return false
		for character in part:
			if not character in "0123456789": return false
		if int(part) > 255: return false
	return true

static func kind(address: String) -> String:
	if not valid_ipv4(address): return ""
	var p = address.split(".")
	var a = int(p[0])
	var b = int(p[1])
	if a == 100 and b >= 64 and b <= 127: return "internet"
	if a == 10 or (a == 172 and b >= 16 and b <= 31) or (a == 192 and b == 168): return "lan"
	return ""

static func available(addresses: PackedStringArray) -> Dictionary:
	var result = {"internet": [], "lan": []}
	for address in addresses:
		var group = kind(address)
		if not group.is_empty() and not address in result[group]: result[group].append(address)
	for group in result:
		result[group].sort_custom(func(a: String, b: String):
			var pa = 0 if a.begins_with("192.168.") else (1 if a.begins_with("10.") else 2)
			var pb = 0 if b.begins_with("192.168.") else (1 if b.begins_with("10.") else 2)
			return pa < pb if pa != pb else a < b)
	return result
