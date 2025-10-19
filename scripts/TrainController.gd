extends Node

@export var speed: float = 100.0 # px/s
@export var spacing: float = 36.0 # distância entre engates
@export var lookahead: float = 1800.0 # quanto de trilho manter à frente (px)
@export var fuel_max: float = 100.0
@export var fuel_per_px: float = 0.01 # 1 combustível = 100px a 0 de velocidade
@export var max_speed: float = 600.0
@export var fuel_speed_factor: float = 1.0 # quanto mais rápido, mais consome

var L: float = 1.0
var path: Path2D
var loco: PathFollow2D
var cars: Array[PathFollow2D] = []
var fuel: float
var out_of_fuel: bool = false
var enemy_level: float = 0.0
var spawn_timer: Timer
var menu_canvas: CanvasLayer
var research_panel: Control
var shoot_sound: AudioStreamPlayer2D

func _ready() -> void:
	var track := get_node("../Track")
	path = track.get_node("Path2D") as Path2D
	loco = path.get_node("Locomotive") as PathFollow2D
	cars = []
	for n in path.get_children():
		if n is PathFollow2D and n.name.begins_with("Car"):
			cars.append(n)
	fuel = fuel_max
	_ensure_visuals()
	L = max(1.0, path.curve.get_baked_length())
	if track.has_signal("curve_updated"):
		track.connect("curve_updated", Callable(self, "_on_curve_updated"))
	set_physics_process(true)
	set_process(true)
	spawn_timer = Timer.new()
	add_child(spawn_timer)
	spawn_timer.wait_time = 3.0
	spawn_timer.connect("timeout", Callable(self, "_spawn_enemy"))
	spawn_timer.start()
	# Ajusta tamanho da janela inicial (pedido: 1600x900)
	get_window().size = Vector2i(1600, 900)
	# Cursor do mouse (crosshair discreto)
	var img = Image.create(32, 32, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for i in range(32):
		img.set_pixel(i, 15, Color.BLACK)
		img.set_pixel(i, 16, Color.BLACK)
		img.set_pixel(15, i, Color.BLACK)
		img.set_pixel(16, i, Color.BLACK)
	var tex = ImageTexture.create_from_image(img)
	Input.set_custom_mouse_cursor(tex)
	# Redimensionamento responsivo
	if not get_window().size_changed.is_connected(_on_window_resized):
		get_window().size_changed.connect(_on_window_resized)
	# Configurar som de tiro
	shoot_sound = AudioStreamPlayer2D.new()
	add_child(shoot_sound)
	# Tenta carregar som de tiro
	var shoot_audio = load("res://sounds/shoot.wav")
	if shoot_audio:
		shoot_sound.stream = shoot_audio
	# Conecta reinício do HUD
	var hud := get_node_or_null("../HUD")
	if hud and hud.has_signal("restart_pressed"):
		hud.connect("restart_pressed", Callable(self, "_on_restart"))
	if not InputMap.has_action("restart_ride"):
		InputMap.add_action("restart_ride")
		var ev := InputEventKey.new(); ev.keycode = KEY_R; InputMap.action_add_event("restart_ride", ev)
	# Mapear ação de tiro
	if not InputMap.has_action("shoot"):
		InputMap.add_action("shoot")
		var mb := InputEventMouseButton.new()
		mb.button_index = MOUSE_BUTTON_LEFT
		mb.pressed = true
		InputMap.action_add_event("shoot", mb)
		var sp := InputEventKey.new()
		sp.keycode = KEY_SPACE
		InputMap.action_add_event("shoot", sp)

func _physics_process(delta: float) -> void:
	if L <= 1.0:
		return
	# Aceleração por input
	var accel: float = 0.0
	if Input.is_action_pressed("ui_right"):
		accel += 1.0
	if Input.is_action_pressed("ui_left"):
		accel -= 1.0
	speed = clamp(speed + accel * 200.0 * delta, 0.0, max_speed)

	# Consumo de combustível proporcional à velocidade
	var step: float = speed * delta
	if fuel > 0.0 and step > 0.0:
		var speed_ratio := speed / max_speed
		var mult := 1.0 + fuel_speed_factor * speed_ratio * speed_ratio
		var needed := step * fuel_per_px * mult
		if needed > fuel:
			step = fuel / (fuel_per_px * mult)
			needed = fuel
		fuel -= needed
	else:
		step = 0.0
		speed = max(0.0, speed - 60.0 * delta)
		if fuel <= 0.0 and not out_of_fuel:
			out_of_fuel = true
			var hud_end := get_node_or_null("../HUD")
			if hud_end and hud_end.has_method("show_end_dialog"):
				hud_end.show_end_dialog()

	# Estender trilho à frente
	var track_node := get_node("../Track")
	if track_node and track_node.has_method("ensure_length"):
		var predict: float = loco.progress + step + lookahead
		track_node.ensure_length(predict)

	# Avançar
	loco.loop = false
	L = max(L, path.curve.get_baked_length())
	loco.progress = min(loco.progress + step, L - 1.0)

	# Posicionar vagões
	var p: float = loco.progress
	for i in cars.size():
		p = max(0.0, p - spacing)
		cars[i].progress = p

	# HUD
	var hud := get_node_or_null("../HUD")
	if hud and hud.has_method("set_values"):
		hud.call_deferred("set_values", speed, fuel, fuel_max)

	# Câmera segue
	var cam := get_node_or_null("../Camera2D")
	if cam and cam is Camera2D:
		(cam as Camera2D).global_position = loco.global_position

	# Reiniciar com R quando sem combustível
	if out_of_fuel and Input.is_action_just_pressed("restart_ride"):
		reset_run()

func _on_curve_updated(total_length: float) -> void:
	L = max(1.0, total_length)

func _on_restart() -> void:
	reset_run()

func reset_run() -> void:
	var track_node := get_node("../Track")
	if track_node and track_node.has_method("reset_world"):
		track_node.reset_world()
	if track_node and track_node.has_method("ensure_length"):
		track_node.ensure_length(lookahead + 1000.0)
	L = max(1.0, path.curve.get_baked_length())
	loco.progress = 0.0
	var p := 0.0
	for i in cars.size():
		p = max(0.0, p - spacing)
		cars[i].progress = p
	fuel = fuel_max
	speed = 0.0
	out_of_fuel = false
	enemy_level = 0.0  # Reset level
	var hud := get_node_or_null("../HUD")
	if hud and hud.has_method("hide_end_dialog"):
		hud.hide_end_dialog()

func _ensure_visuals() -> void:
	# Locomotive body + smoke
	_ensure_box(loco, Color(0.25, 0.6, 1.0), Vector2(28, 14))
	_ensure_collision(loco, Vector2(28, 14))
	if not loco.has_node("Smoke"):
		var smoke := GPUParticles2D.new()
		smoke.name = "Smoke"
		smoke.position = Vector2(-10, -18)
		smoke.amount = 64
		smoke.lifetime = 1.2
		smoke.one_shot = false
		var mat := ParticleProcessMaterial.new()
		mat.direction = Vector3(0, -1, 0)
		mat.spread = 15.0
		mat.initial_velocity_min = 15.0
		mat.initial_velocity_max = 30.0
		mat.gravity = Vector3(0, -50, 0)
		mat.scale_min = 0.5
		mat.scale_max = 1.1
		smoke.process_material = mat
		smoke.emitting = true
		loco.add_child(smoke)
	# Cars - Apenas o vagão do canhão (verde)
	if cars.size() > 0:
		var cannon_car = cars[0]
		_ensure_box(cannon_car, Color(0.0, 0.8, 0.0), Vector2(26, 12))  # Verde
		_ensure_collision(cannon_car, Vector2(26, 12))
		# Adicionar canhão em cima
		if not cannon_car.has_node("Cannon"):
			var cannon := Node2D.new()
			cannon.name = "Cannon"
			cannon_car.add_child(cannon)
			# Base do canhão
			var base := Polygon2D.new()
			base.name = "Base"
			base.polygon = PackedVector2Array([Vector2(-5, -8), Vector2(5, -8), Vector2(5, -6), Vector2(-5, -6)])
			base.color = Color(0.5, 0.5, 0.5)  # Cinza
			cannon.add_child(base)
			# Cano do canhão
			var barrel := Polygon2D.new()
			barrel.name = "Barrel"
			barrel.polygon = PackedVector2Array([Vector2(-6, -2), Vector2(-6, 2), Vector2(4, 2), Vector2(4, -2)])
			barrel.color = Color(0.3, 0.3, 0.3)  # Cinza escuro
			cannon.add_child(barrel)
			# Ponta vermelha
			var tip := Polygon2D.new()
			tip.name = "Tip"
			tip.polygon = PackedVector2Array([Vector2(3, -1), Vector2(3, 1), Vector2(5, 1), Vector2(5, -1)])
			tip.color = Color.RED
			barrel.add_child(tip)

	# HUD (se existir)
	var hud := get_node_or_null("../HUD")
	if hud and hud.has_method("set_values"):
		hud.set_values(speed, fuel, fuel_max)

func _ensure_box(follow: PathFollow2D, color: Color, size: Vector2) -> void:
	var body: Node2D = follow.get_node_or_null("Body")
	if body == null:
		body = Node2D.new()
		body.name = "Body"
		follow.add_child(body)
	var poly := body.get_node_or_null("Box")
	if poly == null:
		var box := Polygon2D.new()
		box.name = "Box"
		var w := size.x * 0.5
		var h := size.y * 0.5
		box.polygon = PackedVector2Array([Vector2(-w,-h), Vector2(w,-h), Vector2(w,h), Vector2(-w,h)])
		box.color = color
		body.add_child(box)

func _ensure_collision(follow: PathFollow2D, size: Vector2) -> void:
	var area = follow.get_node_or_null("CollisionArea")
	if area == null:
		area = Area2D.new()
		area.name = "CollisionArea"
		follow.add_child(area)
		var collision_shape = CollisionShape2D.new()
		var rect_shape = RectangleShape2D.new()
		rect_shape.size = size
		collision_shape.shape = rect_shape
		area.add_child(collision_shape)
		area.collision_layer = 1  # Trem
		area.collision_mask = 2	# Inimigos

func _process(_delta: float) -> void:
	# Mirar canhão no cursor e disparar
	if cars.size() > 0 and cars[0].has_node("Cannon"):
		var cannon: Node2D = cars[0].get_node("Cannon")
		var barrel: Node2D = cannon.get_node_or_null("Barrel")
		if barrel:
			var mouse_world: Vector2 = cannon.get_global_mouse_position()
			barrel.global_rotation = (mouse_world - cannon.global_position).angle()
		if Input.is_action_just_pressed("shoot"):
			_shoot()

func _spawn_enemy() -> void:
	var enemy_scene = load("res://scenes/Enemy.tscn")  # Assumindo que a cena existe
	if enemy_scene:
		var enemy = enemy_scene.instantiate()
		enemy.type = "a"
		enemy.level = enemy_level
		enemy.progress = loco.progress + 500.0  # Spawn 500px à frente
		enemy.apply_level()  # Aplicar upgrades
		enemy.connect("enemy_collided", Callable(self, "_on_enemy_collided"))
		get_parent().add_child(enemy)  # Adicionar ao root

func _create_main_menu() -> void:
	menu_canvas = CanvasLayer.new()
	add_child(menu_canvas)
	# Dim de fundo
	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.color = Color(0, 0, 0, 0.35)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	menu_canvas.add_child(dim)
	# Centro
	var center := CenterContainer.new(); center.name = "Center"
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	menu_canvas.add_child(center)
	# Painel responsivo
	var panel := PanelContainer.new(); panel.name = "Panel"
	center.add_child(panel)
	var pad := MarginContainer.new(); pad.name = "Pad"
	panel.add_child(pad)
	var ui := VBoxContainer.new(); ui.name = "VBox"
	ui.alignment = BoxContainer.ALIGNMENT_CENTER
	pad.add_child(ui)
	# Título e botões
	var title := Label.new(); title.name = "Title"
	title.text = "Alien Train"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ui.add_child(title)
	var start_button := Button.new(); start_button.name = "Start"
	start_button.text = "Start Ride"
	start_button.connect("pressed", Callable(self, "_start_ride"))
	ui.add_child(start_button)
	var research_button := Button.new(); research_button.name = "Research"
	research_button.text = "Research"
	research_button.connect("pressed", Callable(self, "_show_research"))
	ui.add_child(research_button)
	start_button.grab_focus()
	_update_menu_layout()

func _on_window_resized() -> void:
	_update_menu_layout()

func _update_menu_layout() -> void:
	if menu_canvas == null:
		return
	var center: CenterContainer = menu_canvas.get_node_or_null("Center") as CenterContainer
	var panel: PanelContainer = null
	if center:
		panel = center.get_node_or_null("Panel") as PanelContainer
	var pad: MarginContainer = null
	if panel:
		pad = panel.get_node_or_null("Pad") as MarginContainer
	var ui: VBoxContainer = null
	if pad:
		ui = pad.get_node_or_null("VBox") as VBoxContainer
	var title: Label = null
	var start_b: Button = null
	var research_b: Button = null
	if ui:
		title = ui.get_node_or_null("Title") as Label
		start_b = ui.get_node_or_null("Start") as Button
		research_b = ui.get_node_or_null("Research") as Button
	var view_size: Vector2 = get_viewport().size
	var h: float = view_size.y
	var scale: float = clamp(h / 270.0, 1.0, 3.0)
	# Painel estilizado
	if panel:
		var sb: StyleBoxFlat = StyleBoxFlat.new()
		sb.bg_color = Color(0.06, 0.08, 0.12, 0.9)
		sb.corner_radius_top_left = int(10 * scale)
		sb.corner_radius_top_right = int(10 * scale)
		sb.corner_radius_bottom_left = int(10 * scale)
		sb.corner_radius_bottom_right = int(10 * scale)
		panel.add_theme_stylebox_override("panel", sb)
	# Padding
	if pad:
		var m: int = int(12 * scale)
		pad.add_theme_constant_override("margin_left", m)
		pad.add_theme_constant_override("margin_top", m)
		pad.add_theme_constant_override("margin_right", m)
		pad.add_theme_constant_override("margin_bottom", m)
	# Fontes
	var title_size: int = int(24 * scale)
	var btn_size: int = int(14 * scale)
	if title: title.add_theme_font_size_override("font_size", title_size)
	if start_b: start_b.add_theme_font_size_override("font_size", btn_size)
	if research_b: research_b.add_theme_font_size_override("font_size", btn_size)

func _start_ride() -> void:
	if menu_canvas:
		menu_canvas.queue_free()
	set_physics_process(true)
	set_process(true)
	spawn_timer.start()

func _show_research() -> void:
	if research_panel == null:
		var research_scene = load("res://scenes/Research.tscn")
		if research_scene:
			research_panel = research_scene.instantiate()
			if menu_canvas:
				menu_canvas.add_child(research_panel)
			if research_panel.has_signal("research_selected"):
				research_panel.connect("research_selected", Callable(self, "_on_research_selected"))

func _on_research_selected(research_type: String):
	if research_type == "speed":
		_research_speed()

func _research_speed() -> void:
	max_speed += 100.0
	print("Velocidade máxima aumentada para ", max_speed)

func _on_enemy_collided() -> void:
	fuel = max(0.0, fuel - 10.0)
	if fuel <= 0.0 and not out_of_fuel:
		out_of_fuel = true
		var hud := get_node_or_null("../HUD")
		if hud and hud.has_method("show_end_dialog"):
			hud.show_end_dialog()

func _shoot() -> void:
	if cars.size() > 0 and cars[0].has_node("Cannon"):
		var cannon = cars[0].get_node("Cannon")
		var barrel = cannon.get_node_or_null("Barrel")
		if barrel:
			var direction = Vector2.RIGHT.rotated(barrel.global_rotation)
			var bullet_scene = load("res://scenes/Bullet.tscn")
			if bullet_scene:
				var bullet = bullet_scene.instantiate()
				bullet.direction = direction
				bullet.position = cannon.global_position + direction * 20
				get_parent().add_child(bullet)
				# Toca som de tiro (cria nova instância para evitar sobreposição)
				if shoot_sound and shoot_sound.stream:
					var sound_instance = AudioStreamPlayer2D.new()
					sound_instance.stream = shoot_sound.stream
					sound_instance.position = cannon.global_position
					get_parent().add_child(sound_instance)
					sound_instance.play()
					sound_instance.finished.connect(sound_instance.queue_free)
