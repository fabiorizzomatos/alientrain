extends Panel

signal research_selected(research_type: String)

var research_nodes = {}
var current_research = "start"
var camera_offset = Vector2.ZERO
var zoom_level = 1.0
var is_dragging = false
var drag_start = Vector2.ZERO

var research_data = {
	"start": {
		"name": "Início",
		"cost": 0,
		"unlocked": true,
		"position": Vector2(400, 300),
		"connections": []
	},
	"speed_basic": {
		"name": "Velocidade Básica",
		"cost": 50,
		"unlocked": true,
		"position": Vector2(250, 200),
		"connections": ["speed_advanced"],
		"effect": "speed_basic"
	},
	"damage_basic": {
		"name": "Dano Básico",
		"cost": 50,
		"unlocked": true,
		"position": Vector2(550, 200),
		"connections": ["damage_advanced"],
		"effect": "damage_basic"
	},
	"speed_advanced": {
		"name": "Velocidade Avançada",
		"cost": 150,
		"unlocked": false,
		"position": Vector2(150, 100),
		"connections": ["speed_master"],
		"effect": "speed_advanced"
	},
	"damage_advanced": {
		"name": "Dano Avançado",
		"cost": 150,
		"unlocked": false,
		"position": Vector2(650, 100),
		"connections": ["damage_master"],
		"effect": "damage_advanced"
	},
	"speed_master": {
		"name": "Velocidade Mestre",
		"cost": 300,
		"unlocked": false,
		"position": Vector2(50, 50),
		"connections": [],
		"effect": "speed_master"
	},
	"damage_master": {
		"name": "Dano Mestre",
		"cost": 300,
		"unlocked": false,
		"position": Vector2(750, 50),
		"connections": [],
		"effect": "damage_master"
	}
}

func _ready():
	# Fundo escuro
	var bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.1, 0.1, 0.1, 0.95)
	add_child(bg)
	
	# Botão voltar
	var back_button = Button.new()
	back_button.text = "Voltar"
	back_button.position = Vector2(20, 20)
	back_button.connect("pressed", Callable(self, "_on_back_pressed"))
	add_child(back_button)
	
	# Título
	var title = Label.new()
	title.text = "Árvore de Pesquisas"
	title.position = Vector2(350, 20)
	title.add_theme_font_size_override("font_size", 24)
	add_child(title)
	
	# Criar container para a árvore
	var tree_container = Control.new()
	tree_container.name = "TreeContainer"
	tree_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(tree_container)
	
	# Criar nós de pesquisa
	_create_research_tree()
	
	# Desenhar conexões
	_draw_connections()
	
	# Configurar input para pan e zoom
	set_process_input(true)

func _create_research_tree():
	for id in research_data:
		var data = research_data[id]
		var node = _create_research_node(id, data)
		if node:  # Só adicionar se o nó deve ser mostrado
			research_nodes[id] = node
			$TreeContainer.add_child(node)

func _create_research_node(id: String, data: Dictionary) -> Control:
	# Verificar se o nó deve ser mostrado
	if not _should_show_node(id):
		return null
	
	var container = Control.new()
	container.position = data.position
	container.size = Vector2(120, 80)
	
	# Fundo do nó
	var bg = ColorRect.new()
	bg.size = Vector2(120, 80)
	bg.position = Vector2(0, 0)
	
	if data.unlocked:
		bg.color = Color(0.2, 0.8, 0.2, 0.8)  # Verde
	elif id == "start":
		bg.color = Color(0.8, 0.8, 0.2, 0.8)  # Amarelo
	else:
		bg.color = Color(0.5, 0.5, 0.5, 0.8)  # Cinza
	
	container.add_child(bg)
	
	# Nome da pesquisa
	var name_label = Label.new()
	name_label.text = data.name
	name_label.position = Vector2(10, 10)
	name_label.size = Vector2(100, 30)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 12)
	container.add_child(name_label)
	
	# Custo
	if id != "start":
		var cost_label = Label.new()
		cost_label.text = "Custo: " + str(data.cost)
		cost_label.position = Vector2(10, 40)
		cost_label.size = Vector2(100, 20)
		cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cost_label.add_theme_font_size_override("font_size", 10)
		container.add_child(cost_label)
	
	# Botão de compra (se não for start e não estiver desbloqueado)
	if id != "start" and not data.unlocked:
		var buy_button = Button.new()
		buy_button.text = "Comprar"
		buy_button.position = Vector2(35, 60)
		buy_button.size = Vector2(50, 15)
		buy_button.connect("pressed", Callable(self, "_buy_research").bind(id))
		container.add_child(buy_button)
	
	# Aplicar transformação de câmera
	_apply_camera_transform(container)
	
	return container

func _should_show_node(id: String) -> bool:
	# Sempre mostrar start, básicos e avançados
	if id == "start" or id.ends_with("_basic") or id.ends_with("_advanced"):
		return true
	
	# Mostrar mestres apenas se o avançado correspondente estiver desbloqueado
	if id.ends_with("_master"):
		var base_id = id.replace("_master", "_advanced")
		return research_data.has(base_id) and research_data[base_id].unlocked
	
	return false

func _draw_connections():
	# Desenhar linhas entre os nós conectados
	for id in research_data:
		var data = research_data[id]
		# Verificar se o nó atual está desbloqueado
		if data.unlocked or id == "start":
			for connection_id in data.connections:
				# Verificar se o nó de destino existe
				if research_data.has(connection_id):
					var start_pos = research_data[id].position + Vector2(60, 40)
					var end_pos = research_data[connection_id].position + Vector2(60, 40)
					_draw_line(start_pos, end_pos)

func _draw_line(start: Vector2, end: Vector2):
	var line = Line2D.new()
	var transformed_start = _transform_point(start)
	var transformed_end = _transform_point(end)
	line.points = PackedVector2Array([transformed_start, transformed_end])
	line.width = 2
	line.default_color = Color.WHITE
	$TreeContainer.add_child(line)

func _buy_research(research_id: String):
	var data = research_data[research_id]
	if not data.unlocked and data.cost > 0:
		# Aqui você pode adicionar lógica de recursos/moeda
		# Por enquanto, vamos apenas desbloquear
		data.unlocked = true
		_refresh_tree()
		emit_signal("research_selected", data.effect)
		
		# Verificar se desbloqueia pesquisas mestres
		_check_master_unlocks()

func _check_master_unlocks():
	# Não desbloquear mestres automaticamente - eles aparecem quando o avançado é comprado
	# Mas não ficam disponíveis para compra até serem desbloqueados
	pass

func _input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_MIDDLE:
			if event.pressed:
				is_dragging = true
				drag_start = event.position
			else:
				is_dragging = false
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_in()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_out()
	elif event is InputEventMouseMotion and is_dragging:
		var delta = event.position - drag_start
		camera_offset += delta
		drag_start = event.position
		_refresh_tree()

func _zoom_in():
	zoom_level = min(zoom_level * 1.1, 3.0)
	_refresh_tree()

func _zoom_out():
	zoom_level = max(zoom_level / 1.1, 0.5)
	_refresh_tree()

func _transform_point(point: Vector2) -> Vector2:
	return (point + camera_offset) * zoom_level

func _apply_camera_transform(node: Control):
	node.position = _transform_point(node.position)
	node.scale = Vector2(zoom_level, zoom_level)

func _refresh_tree():
	# Limpar nós existentes
	for node in research_nodes.values():
		node.queue_free()
	research_nodes.clear()
	
	# Limpar container
	if has_node("TreeContainer"):
		var container = $TreeContainer
		for child in container.get_children():
			child.queue_free()
	
	# Recriar árvore
	_create_research_tree()
	_draw_connections()

func _on_back_pressed():
	get_tree().change_scene_to_file("res://scenes/Menu.tscn")