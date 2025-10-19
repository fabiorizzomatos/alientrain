extends Node2D

signal curve_updated(total_length: float)

@onready var path: Path2D = $Path2D
@onready var line: Line2D = $Line2D

# Visual fidelity of the baked curve
@export var bake_interval: float = 6.0

# Procedural parameters
@export var segment_length: float = 240.0
@export var max_turn_deg: float = 18.0
@export var handle_factor: float = 0.5 # 0..1

enum GenMode { STRAIGHT, CURVE }
@export var straight_block_min: int = 1
@export var straight_block_max: int = 2
@export var curve_block_min: int = 2
@export var curve_block_max: int = 4

# "Meandro" via ruído 1D integrado (fBm)
@export var use_noise_curves: bool = true
@export var noise_frequency: float = 0.35
@export var noise_amplitude_deg: float = 12.0
@export var noise_octaves: int = 3
@export var noise_gain: float = 0.5
@export var noise_lacunarity: float = 2.0

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _last_angle: float = 0.0
var _mode: int = GenMode.STRAIGHT
var _block_left: int = 0
var _noise_phase: PackedFloat32Array = []
var _gen: TrackGen
var _curve_bias: float = 0.6 # 0..1 (quanto de curva queremos)

func _ready() -> void:
	if path.curve == null:
		path.curve = Curve2D.new()
	path.curve.bake_interval = bake_interval
	if path.curve.point_count < 2:
		_build_seed_curve()
	_refresh_line()
	line.z_index = -1  # Trilhos embaixo do trem
	emit_signal("curve_updated", path.curve.get_baked_length())
	_ensure_actions()

func _build_seed_curve() -> void:
	var size: Vector2 = get_viewport_rect().size
	var y: float = floor(size.y * 0.6)
	var p0: Vector2 = Vector2(32, y)
	var p1: Vector2 = p0 + Vector2(segment_length, 0)
	var c: Curve2D = path.curve
	c.clear_points()
	c.add_point(p0, Vector2.ZERO, Vector2(segment_length * handle_factor, 0))
	c.add_point(p1, Vector2(-segment_length * handle_factor, 0), Vector2(segment_length * handle_factor, 0))
	_last_angle = 0.0
	_start_new_block() # define o primeiro bloco
	_init_noise()
	# Inicializa helper com os mesmos parâmetros exportados
	_gen = TrackGen.new()
	_gen.configure({
		"segment_length": segment_length,
		"max_turn_deg": max_turn_deg,
		"handle_factor": handle_factor,
		"straight_block_min": straight_block_min,
		"straight_block_max": straight_block_max,
		"curve_block_min": curve_block_min,
		"curve_block_max": curve_block_max,
		"alternate_blocks": false,
		"ratio_straight": 1.0 - _curve_bias,
		"ratio_curve": _curve_bias,
		"use_noise_curves": use_noise_curves,
		"noise_frequency": noise_frequency,
		"noise_amplitude_deg": noise_amplitude_deg,
		"noise_octaves": noise_octaves,
		"noise_gain": noise_gain,
		"noise_lacunarity": noise_lacunarity
	})
	_gen.reset(0, true)

func _init_noise() -> void:
	_rng.randomize()
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
	# alterna o modo; objetivando ~60% retas vs 40% curvas
	_mode = GenMode.CURVE if _mode == GenMode.STRAIGHT else GenMode.STRAIGHT
	if _mode == GenMode.STRAIGHT:
		_block_left = _rng.randi_range(straight_block_min, straight_block_max)
	else:
		_block_left = _rng.randi_range(curve_block_min, curve_block_max)

func ensure_length(target_length: float) -> void:
	var c: Curve2D = path.curve
	while c.get_baked_length() < target_length:
		_append_segment()
	_refresh_line()
	emit_signal("curve_updated", c.get_baked_length())

func _append_segment() -> void:
	var c: Curve2D = path.curve
	var last_idx: int = c.point_count - 1
	var last_pos: Vector2 = c.get_point_position(last_idx)
	# Usa o helper para determinar o próximo segmento
	var seg: Dictionary = _gen.next_segment(last_pos, _last_angle)
	var new_pos: Vector2 = seg["new_pos"]
	var new_angle: float = seg["new_angle"]
	c.set_point_out(last_idx, Vector2(segment_length * handle_factor, 0).rotated(_last_angle))
	c.add_point(new_pos, seg["in_tan"], seg["out_tan"]) 
	_last_angle = new_angle

func _refresh_line() -> void:
	if not is_instance_valid(line):
		return
	line.points = path.curve.get_baked_points()

func reset_world() -> void:
	var c: Curve2D = path.curve
	c.clear_points()
	_build_seed_curve()
	_refresh_line()
	emit_signal("curve_updated", c.get_baked_length())

func _ensure_actions() -> void:
	if not InputMap.has_action("curvy_more"):
		InputMap.add_action("curvy_more")
		var e1 := InputEventKey.new(); e1.keycode = KEY_BRACKETRIGHT; InputMap.action_add_event("curvy_more", e1)
	if not InputMap.has_action("curvy_less"):
		InputMap.add_action("curvy_less")
		var e2 := InputEventKey.new(); e2.keycode = KEY_BRACKETLEFT; InputMap.action_add_event("curvy_less", e2)
	if not InputMap.has_action("meander_toggle"):
		InputMap.add_action("meander_toggle")
		var e3 := InputEventKey.new(); e3.keycode = KEY_M; InputMap.action_add_event("meander_toggle", e3)
	if not InputMap.has_action("regen_seed"):
		InputMap.add_action("regen_seed")
		var e4 := InputEventKey.new(); e4.keycode = KEY_N; InputMap.action_add_event("regen_seed", e4)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("curvy_more"):
		_tune_curviness(0.05)
	elif event.is_action_pressed("curvy_less"):
		_tune_curviness(-0.05)
	elif event.is_action_pressed("meander_toggle"):
		use_noise_curves = not use_noise_curves
		_gen.configure({"use_noise_curves": use_noise_curves})
		_hud_msg("Meandro: %s" % ("ON" if use_noise_curves else "OFF"))
	elif event.is_action_pressed("regen_seed"):
		_gen.reset(0, true)
		_hud_msg("Nova semente gerada")

func _tune_curviness(delta_bias: float) -> void:
	_curve_bias = clamp(_curve_bias + delta_bias, 0.0, 1.0)
	var amp: float = clamp(noise_amplitude_deg + delta_bias * 8.0, 4.0, 28.0)
	var freq: float = clamp(noise_frequency + delta_bias * 0.2, 0.1, 0.8)
	noise_amplitude_deg = amp
	noise_frequency = freq
	_gen.configure({
		"ratio_straight": 1.0 - _curve_bias,
		"ratio_curve": _curve_bias,
		"noise_amplitude_deg": noise_amplitude_deg,
		"noise_frequency": noise_frequency
	})
	_hud_msg("Curvas: %d%%" % int(round(_curve_bias * 100.0)))

func _hud_msg(t: String) -> void:
	var hud := get_node_or_null("../HUD")
	if hud and hud.has_method("show_message"):
		hud.show_message(t)
