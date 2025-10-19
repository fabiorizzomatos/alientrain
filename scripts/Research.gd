extends Panel

signal research_selected(research_type: String)

func _ready():
	$VBoxContainer/BackButton.connect("pressed", Callable(self, "queue_free"))
	$VBoxContainer/SpeedResearch.connect("pressed", Callable(self, "_on_speed_research"))

func _on_speed_research():
	emit_signal("research_selected", "speed")
	# Aqui pode adicionar lógica para custo, etc.