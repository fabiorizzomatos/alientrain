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
var lateral_offset: float = 0.0  # Offset lateral ao trilho

func _ready() -> void:
	_path = get_node_or_null(track_path) as Path2D
	if _path:
		_curve = _path.curve
	_sprite = get_node_or_null("Sprite2D")
	lateral_offset = randf_range(-80.0, 80.0)  # Offset lateral aleatório
	_ensure_placeholder_texture()
	_fit_sprite_to_height()
	_setup_collision()
	apply_level()

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

	# Se ficar muito para trás do trem, remove
	var loco: PathFollow2D = _path.get_node_or_null("Locomotive") as PathFollow2D
	if loco and progress < loco.progress - 800.0:
		queue_free()

func _ensure_placeholder_texture() -> void:
	if _sprite == null:
		return
	if _sprite.texture != null:
		return
	# Cria uma textura 16x16 em tempo de execução (sem PNG externo)
	var img: Image = Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.85, 0.2, 0.2, 1.0))
	# desenho de borda
	for x in range(16):
		img.set_pixel(x, 0, Color.BLACK)
		img.set_pixel(x, 15, Color.BLACK)
	for y in range(16):
		img.set_pixel(0, y, Color.BLACK)
		img.set_pixel(15, y, Color.BLACK)
	var tex: ImageTexture = ImageTexture.create_from_image(img)
	_sprite.texture = tex
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

func _on_area_entered(area: Area2D) -> void:
	# Verifica se colidiu com o trem
	if area.collision_layer == 1:  # Trem
		emit_signal("enemy_collided")
		queue_free()  # Remove o inimigo após colisão
	elif area.collision_layer == 4:  # Bala
		queue_free()  # Remove o inimigo se acertado por bala
