extends Node2D

signal enemy_collided

@export var type: String = "a"
@export var level: float = 0.0
@export var speed: float = 50.0
@export var progress: float = 0.0
@export var track_path: NodePath = NodePath("../Track/Path2D")
@export var target_height: float = 24.0 # altura desejada do inimigo em unidades do mundo

var _path: Path2D
var _curve: Curve2D
var _sprite: Sprite2D
var _area: Area2D
var health: float
var _hp_node: Node2D
var _hp_bg: Polygon2D
var _hp_fill: Polygon2D
var lateral_offset: float = 0.0  # Offset lateral ao trilho
var _shadow: Polygon2D
var _hit_tween: Tween
var _knock_vel: Vector2 = Vector2.ZERO
var _shake_t: float = 0.0
var _sprite_base_pos: Vector2 = Vector2.ZERO

func _ready() -> void:
	_path = get_node_or_null(track_path) as Path2D
	if _path:
		_curve = _path.curve
	_sprite = get_node_or_null("Sprite2D")
	lateral_offset = randf_range(-80.0, 80.0)  # Offset lateral aleatório
	_ensure_placeholder_texture()
	_fit_sprite_to_height()
	_sprite_base_pos = _sprite.position if _sprite else Vector2.ZERO
	_build_shadow()
	_setup_collision()
	apply_level()
	_setup_health()

func apply_level() -> void:
	# Cresce conforme o nível (eixo uniforme)
	var s: float = 0.7 + level * 0.25
	scale = Vector2.ONE * clamp(s, 0.4, 2.5)
	if _sprite:
		_sprite.modulate = Color(1, 1, 1, 1) # usa as cores reais do sprite

func _physics_process(delta: float) -> void:
	if _curve == null:
		return
	progress += speed * delta
	var L: float = _curve.get_baked_length()
	if progress > L:
		progress = L
	var pos: Vector2 = _curve.sample_baked(progress)
	# Calcular offset perpendicular ao trilho
	var tangent: Vector2 = _curve.sample_baked(min(progress + 5.0, L)) - pos
	tangent = tangent.normalized()
	var perpendicular: Vector2 = Vector2(-tangent.y, tangent.x) * lateral_offset
	global_position = pos + perpendicular
	# Rotaciona pela tangente
	rotation = tangent.angle()
	# Aplica knockback
	if _knock_vel.length() > 0.01:
		global_position += _knock_vel * delta
		_knock_vel = _knock_vel.move_toward(Vector2.ZERO, 120.0 * delta)

	# Se ficar muito para trás do trem, remove
	var loco: PathFollow2D = _path.get_node_or_null("Locomotive") as PathFollow2D
	if loco and progress < loco.progress - 800.0:
		queue_free()
	# Atualiza barra de vida posicionada acima da cabeça, horizontal
	if _hp_node:
		var offset_y: float = target_height * 0.7 + 8.0
		_hp_node.global_position = global_position + Vector2(0, -offset_y)
		_hp_node.global_rotation = 0.0
	# Atualiza sombra no chão (horizontal, levemente abaixo)
	if _shadow:
		_shadow.global_position = global_position + Vector2(0, 4)
		_shadow.global_rotation = 0.0
	# Shake leve quando recebe dano
	if _sprite:
		if _shake_t > 0.0:
			_shake_t -= delta
			var mag: float = 1.5
			_sprite.position = _sprite_base_pos + Vector2(randf_range(-mag, mag), randf_range(-mag, mag))
		elif _sprite.position != _sprite_base_pos:
			_sprite.position = _sprite_base_pos

func _ensure_placeholder_texture() -> void:
	if _sprite == null:
		return
	if _sprite.texture != null:
		return
	# Tenta carregar textura do projeto
	var tex = load("res://images/sprite_20251018_212424.png")
	if tex:
		_sprite.texture = tex
		_sprite.centered = true
		return
	# Fallback: cria uma textura 16x16 em tempo de execução
	var img: Image = Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.85, 0.2, 0.2, 1.0))
	# desenho de borda
	for x in range(16):
		img.set_pixel(x, 0, Color.BLACK)
		img.set_pixel(x, 15, Color.BLACK)
	for y in range(16):
		img.set_pixel(0, y, Color.BLACK)
		img.set_pixel(15, y, Color.BLACK)
	var fallback_tex: ImageTexture = ImageTexture.create_from_image(img)
	_sprite.texture = fallback_tex
	_sprite.centered = true

func _fit_sprite_to_height() -> void:
	if _sprite == null:
		return
	var tex: Texture2D = _sprite.texture
	if tex == null:
		return
	var sz: Vector2 = tex.get_size()
	if sz.y <= 0.0:
		return
	var s: float = clamp(target_height / sz.y, 0.02, 4.0)
	_sprite.scale = Vector2(s, s)

func _build_shadow() -> void:
	_shadow = Polygon2D.new()
	_shadow.name = "Shadow"
	_shadow.color = Color(0,0,0,0.22)
	_shadow.antialiased = true
	var w: float = max(target_height * 0.9, 14.0)
	var h: float = max(target_height * 0.35, 5.0)
	_shadow.polygon = _ellipse_points(w*0.5, h*0.5, 16)
	add_child(_shadow)

func _ellipse_points(rx: float, ry: float, steps: int) -> PackedVector2Array:
	var pts: PackedVector2Array = PackedVector2Array()
	for i in range(steps):
		var t: float = TAU * float(i) / float(steps)
		pts.append(Vector2(cos(t)*rx, sin(t)*ry))
	return pts

func _setup_collision() -> void:
	_area = Area2D.new()
	add_child(_area)
	var collision_shape = CollisionShape2D.new()
	var rect_shape = RectangleShape2D.new()
	rect_shape.size = Vector2(target_height, target_height)  # Ajuste conforme necessário
	collision_shape.shape = rect_shape
	_area.add_child(collision_shape)
	_area.collision_layer = 2  # Camada para inimigos
	_area.collision_mask = 1 | 4   # Colidir com trem e balas
	_area.connect("area_entered", Callable(self, "_on_area_entered"))

func _setup_health() -> void:
	health = 1.0 + level
	_hp_node = Node2D.new(); _hp_node.name = "HpBar"; add_child(_hp_node)
	var w: float = max(target_height * 1.4, 18.0)
	var h: float = 3.0
	_hp_bg = Polygon2D.new(); _hp_bg.color = Color(0,0,0,0.7)
	_hp_bg.polygon = PackedVector2Array([Vector2(-w*0.5,-h*0.5), Vector2(w*0.5,-h*0.5), Vector2(w*0.5,h*0.5), Vector2(-w*0.5,h*0.5)])
	_hp_node.add_child(_hp_bg)
	_hp_fill = Polygon2D.new(); _hp_fill.color = Color(0.35,0.95,0.35,0.95)
	_hp_node.add_child(_hp_fill)
	_update_hp_bar()

func _on_area_entered(area: Area2D) -> void:
	# Verifica colisões
	if area.collision_layer == 1:  # Trem
		emit_signal("enemy_collided")
		take_damage(health, global_position)
	elif area.collision_layer == 4:  # Bala
		var from: Vector2 = area.global_position
		take_damage(1.0, from)

func _update_hp_bar() -> void:
	if not is_instance_valid(_hp_fill) or not is_instance_valid(_hp_bg):
		return
	var w: float = (_hp_bg.polygon[1].x - _hp_bg.polygon[0].x)
	var h: float = (_hp_bg.polygon[2].y - _hp_bg.polygon[1].y)
	var ratio: float = clamp(health / max(0.001, (1.0 + level)), 0.0, 1.0)
	_hp_fill.polygon = PackedVector2Array([
		Vector2(-w*0.5, -h*0.5),
		Vector2(-w*0.5 + w*ratio, -h*0.5),
		Vector2(-w*0.5 + w*ratio, h*0.5),
		Vector2(-w*0.5, h*0.5)
	])

func take_damage(amount: float, from_pos: Vector2 = Vector2.ZERO) -> void:
	health = max(0.0, health - amount)
	_update_hp_bar()
	_flash_hit()
	if from_pos != Vector2.ZERO:
		var dir := (global_position - from_pos).normalized()
		_knock_vel += dir * (80.0 + 40.0 * amount)
	_shake_t = 0.12
	if health <= 0.0:
		_explode_and_die()

func _explode_and_die() -> void:
	var p := GPUParticles2D.new()
	var mat := ParticleProcessMaterial.new()
	p.lifetime = 0.6
	mat.direction = Vector3(0, -1, 0)
	mat.gravity = Vector3(0, 120, 0)
	mat.initial_velocity_min = 80
	mat.initial_velocity_max = 160
	mat.spread = 180
	mat.scale_min = 0.5
	mat.scale_max = 1.3
	p.process_material = mat
	p.one_shot = true
	p.amount = 70
	p.emitting = true
	add_child(p)
	queue_free()

func _flash_hit() -> void:
	if _sprite == null:
		return
	if _hit_tween and _hit_tween.is_running():
		_hit_tween.kill()
	_sprite.modulate = Color(1.0, 0.6, 0.6, 1.0)
	_hit_tween = create_tween()
	_hit_tween.tween_property(_sprite, "modulate", Color(1,1,1,1), 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
