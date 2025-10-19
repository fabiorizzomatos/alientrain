extends Control

func _ready():
	get_window().size = Vector2(1600, 900)
	# Configurar cursor do mouse
	var img = Image.create(32, 32, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for i in range(32):
		img.set_pixel(i, 15, Color.WHITE)
		img.set_pixel(i, 16, Color.WHITE)
		img.set_pixel(15, i, Color.WHITE)
		img.set_pixel(16, i, Color.WHITE)
	var tex = ImageTexture.create_from_image(img)
	Input.set_custom_mouse_cursor(tex)
	
	$CenterContainer/VBoxContainer/StartButton.connect("pressed", Callable(self, "_on_start_pressed"))
	$CenterContainer/VBoxContainer/ResearchButton.connect("pressed", Callable(self, "_on_research_pressed"))
	$CenterContainer/VBoxContainer/StartButton.grab_focus()

func _on_start_pressed():
	get_tree().change_scene_to_file("res://scenes/Main.tscn")

func _on_research_pressed():
	var research_scene = load("res://scenes/Research.tscn")
	if research_scene:
		var research = research_scene.instantiate()
		add_child(research)
		if research.has_signal("research_selected"):
			research.connect("research_selected", Callable(self, "_on_research_selected"))
		research.connect("tree_exited", Callable(self, "_on_research_closed"))

func _on_research_selected(research_type: String):
	match research_type:
		"speed_basic":
			print("Velocidade básica desbloqueada!")
		"damage_basic":
			print("Dano básico desbloqueado!")
		"speed_advanced":
			print("Velocidade avançada desbloqueada!")
		"damage_advanced":
			print("Dano avançado desbloqueado!")
		"speed_master":
			print("Velocidade mestre desbloqueada!")
		"damage_master":
			print("Dano mestre desbloqueado!")
		_:
			print("Pesquisa aplicada: ", research_type)

func _on_research_closed():
	$CenterContainer/VBoxContainer/StartButton.grab_focus()