class_name SoundCues
extends Node
var player: AudioStreamPlayer

func _ready() -> void:
	player=AudioStreamPlayer.new()
	player.volume_db=-17
	add_child(player)

func play_cue(kind: String) -> void:
	if not is_instance_valid(player): return
	var hz: float={"catch":660.0,"bank":880.0,"warn":145.0,"click":420.0,"down":110.0}.get(kind,420.0)
	var duration: float=0.35 if kind=="warn" else 0.18
	var count: int=int(22050*duration)
	var samples=PackedByteArray()
	samples.resize(count*2)
	for i in range(count):
		var t: float=float(i)/22050.0
		var envelope: float=sin(PI*float(i)/count)*exp(-t*8)
		var sample: int=int(sin(TAU*hz*t)*envelope*14000)
		samples.encode_s16(i*2,sample)
	var stream=AudioStreamWAV.new()
	stream.format=AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate=22050
	stream.data=samples
	player.stream=stream
	player.play()
