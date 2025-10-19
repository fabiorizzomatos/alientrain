extends Node2D

var direction: Vector2
var speed: float = 300.0

@onready var _area: Area2D = $Area2D

func _ready():
	_area.connect("area_entered", Callable(self, "_on_hit"))

func _physics_process(delta):
	position += direction * speed * delta
	# Remove se sair da tela (limites maiores para mundo infinito)
	if position.x > 10000 or position.x < -2000 or position.y > 2000 or position.y < -2000:
		queue_free()

func _on_hit(area):
	# Verifica se acertou um inimigo
	if area.get_parent() is Node2D and area.get_parent().name.begins_with("Enemy"):
		area.get_parent().queue_free()
	queue_free()