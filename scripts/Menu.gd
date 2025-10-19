extends Control

func _ready():
	$CenterContainer/VBoxContainer/StartButton.connect("pressed", Callable(self, "_on_start_pressed"))
	$CenterContainer/VBoxContainer/ResearchButton.connect("pressed", Callable(self, "_on_research_pressed"))

func _on_start_pressed():
	get_tree().change_scene_to_file("res://scenes/Main.tscn")

func _on_research_pressed():
	var research_scene = load("res://scenes/Research.tscn")
	var research = research_scene.instantiate()
	add_child(research)
	research.connect("research_selected", Callable(self, "_on_research_selected"))

func _on_research_selected(research_type: String):
	if research_type == "speed":
		# Aplicar globalmente ou salvar
		print("Pesquisa de velocidade aplicada")