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
	spawn_timer = Timer.new()
	add_child(spawn_timer)
	spawn_timer.wait_time = 3.0  # Spawn a cada 3 segundos
	spawn_timer.connect("timeout", Callable(self, "_spawn_enemy"))
	spawn_timer.start()
	# Spawn inicial rápido
	call_deferred("_spawn_enemy")

func _physics_process(delta: float) -> void:
	if L <= 1.0:
		return
	var accel: float = 0.0
	if Input.is_action_pressed("ui_right"):
		accel += 1.0
	if Input.is_action_pressed("ui_left"):
		accel -= 1.0
	speed = clamp(speed + accel * 200.0 * delta, 0.0, max_speed)
	enemy_level = min(1.0, loco.progress / 5000.0)  # Upgrade level baseado na distância

	# Consumir combustível por distância real percorrida
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
		# sem combustível: desacelera até parar
		step = 0.0
		speed = max(0.0, speed - 60.0 * delta)
		if fuel <= 0.0 and not out_of_fuel:
			out_of_fuel = true
			var hud := get_node_or_null("../HUD")
			if hud and hud.has_method("show_end_dialog"):
				hud.show_end_dialog()

	# Pedir mais trilhos à frente (com previsão)
	var track_node := get_node("../Track")
	if track_node and track_node.has_method("ensure_length"):
		var predict: float = loco.progress + step + lookahead
		track_node.ensure_length(predict)
	# Avançar no trilho (sem loop)
	loco.loop = false
	L = max(L, path.curve.get_baked_length())
	loco.progress = min(loco.progress + step, L - 1.0)

	var p: float = loco.progress
	for i in cars.size():
		p = max(0.0, p - spacing)
		cars[i].progress = p

		# Atualiza HUD se existir
		var hud := get_node_or_null("../HUD")
		if hud and hud.has_method("set_values"):
			hud.call_deferred("set_values", speed, fuel, fuel_max)

	# Camera follow simples
	var cam := get_node_or_null("../Camera2D")
	if cam and cam is Camera2D:
		(cam as Camera2D).global_position = loco.global_position
	# Tecla R para reiniciar quando sem combustível
	if out_of_fuel and Input.is_action_just_pressed("restart_ride"):
		reset_run()
	# Tecla E para spawnar inimigo na hora (teste)
	if Input.is_action_just_pressed("spawn_enemy"):
		_spawn_enemy()

func _notification(what):
	if what == NOTIFICATION_READY:
		# Conecta reinício do HUD
		var hud := get_node_or_null("../HUD")
		if hud and hud.has_signal("restart_pressed"):
			hud.connect("restart_pressed", Callable(self, "_on_restart"))
		# Mapeia tecla R caso não exista
		if not InputMap.has_action("restart_ride"):
			InputMap.add_action("restart_ride")
			var ev := InputEventKey.new(); ev.keycode = KEY_R; InputMap.action_add_event("restart_ride", ev)
		# Tecla E para spawn de teste
		if not InputMap.has_action("spawn_enemy"):
			InputMap.add_action("spawn_enemy")
			var ev2 := InputEventKey.new(); ev2.keycode = KEY_E; InputMap.action_add_event("spawn_enemy", ev2)

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
	var p: float = 0.0
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
            barrel.polygon = PackedVector2Array([Vector2(-2, -6), Vector2(2, -6), Vector2(2, 4), Vector2(-2, 4)])
            barrel.color = Color(0.3, 0.3, 0.3)  # Cinza escuro
            cannon.add_child(barrel)

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

func _spawn_enemy() -> void:
	var enemy_scene = load("res://scenes/Enemy.tscn")  # Assumindo que a cena existe
	if enemy_scene:
		var enemy = enemy_scene.instantiate()
		enemy.type = "a"
		enemy.level = enemy_level
		enemy.progress = loco.progress + 500.0  # Spawn 500px à frente
		enemy.apply_level()  # Aplicar upgrades
		get_parent().add_child(enemy)  # Adicionar ao root
