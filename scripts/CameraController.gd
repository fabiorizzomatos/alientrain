extends Camera2D

@export var min_zoom: float = 0.4
@export var max_zoom: float = 2.0
@export var zoom_step: float = 0.1
@export var zoom_smooth: float = 8.0

var _target_zoom: float = 1.0

func _ready() -> void:
    _ensure_actions()
    _target_zoom = 1.0
    zoom = Vector2.ONE

func _process(delta: float) -> void:
    # Suaviza até o zoom alvo
    var cur := zoom.x
    cur = lerp(cur, _target_zoom, clamp(zoom_smooth * delta, 0.0, 1.0))
    zoom = Vector2(cur, cur)

func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed("zoom_in"):
        _target_zoom = clamp(_target_zoom - zoom_step, min_zoom, max_zoom)
        _notify_zoom()
    elif event.is_action_pressed("zoom_out"):
        _target_zoom = clamp(_target_zoom + zoom_step, min_zoom, max_zoom)
        _notify_zoom()
    elif event.is_action_pressed("zoom_reset"):
        _target_zoom = 1.0
        _notify_zoom()

func _input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.pressed:
        var mb := event as InputEventMouseButton
        if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
            _target_zoom = clamp(_target_zoom - zoom_step, min_zoom, max_zoom)
            _notify_zoom()
        elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
            _target_zoom = clamp(_target_zoom + zoom_step, min_zoom, max_zoom)
            _notify_zoom()

func _notify_zoom() -> void:
    var hud := get_node_or_null("../HUD")
    if hud and hud.has_method("show_message"):
        var pct := int(round(100.0 / _target_zoom))
        hud.show_message("Zoom: %d%%" % pct)

func _ensure_actions() -> void:
    if not InputMap.has_action("zoom_in"):
        InputMap.add_action("zoom_in")
        var ev1 := InputEventKey.new(); ev1.keycode = KEY_EQUAL; InputMap.action_add_event("zoom_in", ev1)
        var ev2 := InputEventKey.new(); ev2.keycode = KEY_KP_ADD; InputMap.action_add_event("zoom_in", ev2)
    if not InputMap.has_action("zoom_out"):
        InputMap.add_action("zoom_out")
        var ev3 := InputEventKey.new(); ev3.keycode = KEY_MINUS; InputMap.action_add_event("zoom_out", ev3)
        var ev4 := InputEventKey.new(); ev4.keycode = KEY_KP_SUBTRACT; InputMap.action_add_event("zoom_out", ev4)
    if not InputMap.has_action("zoom_reset"):
        InputMap.add_action("zoom_reset")
        var ev5 := InputEventKey.new(); ev5.keycode = KEY_0; InputMap.action_add_event("zoom_reset", ev5)
