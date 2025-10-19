class_name TrackGen
extends Object

# Helper configurável para geração de trilhos

enum Mode { STRAIGHT, CURVE }

var segment_length: float = 240.0
var max_turn_deg: float = 18.0
var handle_factor: float = 0.5

# Blocos de geração
var straight_block_min: int = 1
var straight_block_max: int = 2
var curve_block_min: int = 2
var curve_block_max: int = 4
var alternate_blocks: bool = true

# Razões (quando não alternar)
var ratio_straight: float = 0.4
var ratio_curve: float = 0.6

# Ruído para curvas "meandro"
var use_noise_curves: bool = true
var noise_frequency: float = 0.35
var noise_amplitude_deg: float = 12.0
var noise_octaves: int = 3
var noise_gain: float = 0.5
var noise_lacunarity: float = 2.0

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _mode: int = Mode.STRAIGHT
var _block_left: int = 0
var _noise_t: float = 0.0
var _noise_phase: PackedFloat32Array = []

func configure(cfg: Dictionary) -> void:
	# Permite passar um dicionário parcial para configurar
	for k in cfg.keys():
		if _has_prop(k):
			set(k, cfg[k])

func _has_prop(prop_name: String) -> bool:
	var list := get_property_list()
	for p in list:
		if typeof(p) == TYPE_DICTIONARY and p.has("name") and String(p["name"]) == prop_name:
			return true
	return false

func reset(_seed: int, start_straight: bool = true) -> void:
	if _seed != 0:
		_rng.seed = _seed
	else:
		_rng.randomize()
	_mode = Mode.STRAIGHT if start_straight else Mode.CURVE
	_block_left = 0
	_noise_t = 0.0
	_init_noise()

func _init_noise() -> void:
	_noise_phase = PackedFloat32Array()
	for i in range(max(1, noise_octaves)):
		_noise_phase.append(_rng.randf_range(0.0, TAU))

func _fbm_1d(t: float) -> float:
	var v: float = 0.0
	var amp: float = 1.0
	var freq: float = 1.0
	var sum_amp: float = 0.0
	for i in range(max(1, noise_octaves)):
		var phase: float = _noise_phase[i]
		v += amp * sin(t * freq + phase)
		sum_amp += amp
		amp *= noise_gain
		freq *= noise_lacunarity
	if sum_amp > 0.0:
		v /= sum_amp
	return clamp(v, -1.0, 1.0)

func _start_new_block() -> void:
	if alternate_blocks:
		_mode = Mode.CURVE if _mode == Mode.STRAIGHT else Mode.STRAIGHT
	else:
		# escolhe por probabilidade
		var r := _rng.randf()
		_mode = Mode.STRAIGHT if r < ratio_straight else Mode.CURVE
	if _mode == Mode.STRAIGHT:
		_block_left = _rng.randi_range(straight_block_min, straight_block_max)
	else:
		_block_left = _rng.randi_range(curve_block_min, curve_block_max)

func _sample_turn(_last_angle: float) -> float:
	if _mode == Mode.STRAIGHT:
		return 0.0
	if use_noise_curves:
		var curv: float = deg_to_rad(noise_amplitude_deg) * _fbm_1d(_noise_t)
		_noise_t += noise_frequency
		var turn: float = clamp(curv, deg_to_rad(-max_turn_deg), deg_to_rad(max_turn_deg))
		return turn
	else:
		return deg_to_rad(_rng.randf_range(-max_turn_deg, max_turn_deg))

func next_segment(last_pos: Vector2, last_angle: float) -> Dictionary:
	if _block_left <= 0:
		_start_new_block()
	var turn: float = _sample_turn(last_angle)
	var new_angle: float = last_angle + turn
	var new_pos: Vector2 = last_pos + Vector2(segment_length, 0).rotated(new_angle)
	var in_tan: Vector2 = Vector2(-segment_length * handle_factor, 0).rotated(new_angle)
	var out_tan: Vector2 = Vector2(segment_length * handle_factor, 0).rotated(new_angle)
	_block_left -= 1
	return {
		"new_pos": new_pos,
		"new_angle": new_angle,
		"in_tan": in_tan,
		"out_tan": out_tan
	}
