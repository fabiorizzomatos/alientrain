extends CanvasLayer

var speed_label: Label
var speed_value: Label
var speed_bar: ProgressBar
var fuel_text: Label
var fuel_bar: ProgressBar
var message: Label
var end_panel: PanelContainer
var restart_btn: Button

const SPEED_MAX = 600.0

func _ready() -> void:
	# Resolve nodes (novo HUD compacto)
	speed_label = _get_one([
		"Box/UIMargin/UI/SpeedRow/SpeedLabel",
		"MarginContainer/VBox/Speed"
	])
	speed_value = _get_one([
		"Box/UIMargin/UI/SpeedRow/SpeedValue"
	])
	speed_bar = _get_one([
		"Box/UIMargin/UI/SpeedBar",
		"MarginContainer/VBox/SpeedBar"
	])
	fuel_text = _get_one([
		"Box/UIMargin/UI/FuelRow/FuelLabel",
		"MarginContainer/VBox/FuelText"
	])
	fuel_bar = _get_one([
		"Box/UIMargin/UI/Fuel",
		"MarginContainer/VBox/Fuel"
	])
	message = _get_one(["Message"])
	end_panel = _get_one(["EndPanel"])
	restart_btn = _get_one(["EndPanel/EndMargin/EndVBox/RestartButton"])
	if is_instance_valid(restart_btn):
		restart_btn.pressed.connect(_on_restart_pressed)
	# Estilo simples tipo barra azul/verde
	if is_instance_valid(speed_bar):
		speed_bar.max_value = SPEED_MAX
		speed_bar.show_percentage = false
		speed_bar.custom_minimum_size = Vector2(120, 6)
		var bg: StyleBoxFlat = StyleBoxFlat.new(); bg.bg_color = Color(0.1,0.12,0.25,0.6); bg.corner_radius_top_left = 4; bg.corner_radius_top_right = 4; bg.corner_radius_bottom_left = 4; bg.corner_radius_bottom_right = 4
		var fill: StyleBoxFlat = StyleBoxFlat.new(); fill.bg_color = Color(0.44,0.62,1.0,0.7); fill.corner_radius_top_left = 4; fill.corner_radius_top_right = 4; fill.corner_radius_bottom_left = 4; fill.corner_radius_bottom_right = 4
		speed_bar.add_theme_stylebox_override("background", bg)
		speed_bar.add_theme_stylebox_override("fill", fill)
	if is_instance_valid(fuel_bar):
		fuel_bar.max_value = 100.0
		fuel_bar.show_percentage = false
		fuel_bar.custom_minimum_size = Vector2(120, 6)
		var bg2: StyleBoxFlat = StyleBoxFlat.new(); bg2.bg_color = Color(0.07,0.18,0.07,0.6); bg2.corner_radius_top_left = 4; bg2.corner_radius_top_right = 4; bg2.corner_radius_bottom_left = 4; bg2.corner_radius_bottom_right = 4
		var fill2: StyleBoxFlat = StyleBoxFlat.new(); fill2.bg_color = Color(0.45,0.95,0.45,0.7); fill2.corner_radius_top_left = 4; fill2.corner_radius_top_right = 4; fill2.corner_radius_bottom_left = 4; fill2.corner_radius_bottom_right = 4
		fuel_bar.add_theme_stylebox_override("background", bg2)
		fuel_bar.add_theme_stylebox_override("fill", fill2)
	# Compacta fontes
	if is_instance_valid(speed_label): speed_label.add_theme_font_size_override("font_size", 12)
	if is_instance_valid(speed_value): speed_value.add_theme_font_size_override("font_size", 12)

func set_values(speed: float, fuel: float, fuel_max: float) -> void:
	# Texto de velocidade com setas de direção
	if is_instance_valid(speed_label) or is_instance_valid(speed_value):
		var left: bool = Input.is_action_pressed("ui_left")
		var right: bool = Input.is_action_pressed("ui_right")
		var chev: String = ""
		if right:
			chev = "▶▶"
		elif left:
			chev = "◀◀"
		if is_instance_valid(speed_label):
			speed_label.text = "speed"
		if is_instance_valid(speed_value):
			speed_value.text = "%d %s" % [int(speed), chev]
	if is_instance_valid(speed_bar):
		speed_bar.value = clamp(speed, 0.0, SPEED_MAX)
	# Fuel
	if is_instance_valid(fuel_text):
		fuel_text.text = "fuel"
	if is_instance_valid(fuel_bar):
		fuel_bar.max_value = fuel_max
		fuel_bar.value = clamp(fuel, 0.0, fuel_max)

func show_message(text: String, duration: float = 1.2) -> void:
	if not is_instance_valid(message):
		return
	message.text = text
	message.show()
	message.modulate.a = 1.0
	var tw: Tween = create_tween()
	tw.tween_property(message, "modulate:a", 0.0, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_callback(Callable(message, "hide"))

signal restart_pressed

func show_end_dialog() -> void:
	if is_instance_valid(end_panel):
		end_panel.show()
		show_message("Out of fuel!", 1.0)

func hide_end_dialog() -> void:
	if is_instance_valid(end_panel):
		end_panel.hide()

func _on_restart_pressed() -> void:
	emit_signal("restart_pressed")

func _get_one(paths: Array) -> Node:
	for p in paths:
		var n: Node = get_node_or_null(p)
		if n != null:
			return n
	return null
