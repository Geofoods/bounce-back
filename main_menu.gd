extends Control

## Main menu for Balls of Duty.
## Play looks for res://game.tscn so the menu can be wired up before the game
## scene exists.

const GAME_SCENE := "res://game.tscn"

@onready var play_button: Button = %PlayButton
@onready var how_to_play_button: Button = %HowToPlayButton
@onready var quit_button: Button = %QuitButton
@onready var back_button: Button = %BackButton
@onready var how_to_play: Control = %HowToPlay
@onready var status_label: Label = %StatusLabel
@onready var dim: ColorRect = %Dim

var _balls: Array[Control] = []
var _status_tween: Tween


func _ready() -> void:
	get_tree().paused = false

	_balls = [%Ball1, %Ball2, %Ball3, %Ball4]
	_animate_balls()
	_wire_buttons()

	how_to_play.hide()
	status_label.modulate.a = 0.0
	play_button.grab_focus()


func _wire_buttons() -> void:
	play_button.pressed.connect(_on_play_pressed)
	how_to_play_button.pressed.connect(_open_how_to_play)
	quit_button.pressed.connect(_on_quit_pressed)
	back_button.pressed.connect(_close_how_to_play)
	dim.gui_input.connect(_on_dim_gui_input)

	for button: Button in [play_button, how_to_play_button, quit_button, back_button]:
		button.mouse_entered.connect(_on_button_hover.bind(button, true))
		button.mouse_exited.connect(_on_button_hover.bind(button, false))
		button.resized.connect(_center_pivot.bind(button))
		_center_pivot(button)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and how_to_play.visible:
		_close_how_to_play()
		get_viewport().set_input_as_handled()


func _center_pivot(button: Button) -> void:
	button.pivot_offset = button.size * 0.5


func _on_button_hover(button: Button, hovered: bool) -> void:
	var tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(button, "scale", Vector2.ONE * (1.04 if hovered else 1.0), 0.18)
	if hovered:
		button.grab_focus()


func _animate_balls() -> void:
	for i in _balls.size():
		var ball := _balls[i]
		var float_distance := 12.0 + i * 5.0
		var duration := 2.6 + i * 0.45
		var base_y := ball.position.y

		var drift := create_tween().set_loops()
		drift.tween_property(ball, "position:y", base_y - float_distance, duration) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		drift.tween_property(ball, "position:y", base_y, duration) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

		var pulse := create_tween().set_loops()
		pulse.tween_property(ball, "scale", Vector2.ONE * 1.06, duration * 0.65) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		pulse.tween_property(ball, "scale", Vector2.ONE, duration * 0.65) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _on_play_pressed() -> void:
	if ResourceLoader.exists(GAME_SCENE):
		get_tree().change_scene_to_file(GAME_SCENE)
	else:
		_flash_status("No game scene yet - add res://game.tscn to start playing.")


func _open_how_to_play() -> void:
	how_to_play.show()
	how_to_play.modulate.a = 0.0
	create_tween().tween_property(how_to_play, "modulate:a", 1.0, 0.15)
	back_button.grab_focus()


func _close_how_to_play() -> void:
	how_to_play.hide()
	how_to_play_button.grab_focus()


func _on_dim_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_close_how_to_play()


func _on_quit_pressed() -> void:
	get_tree().quit()


func _flash_status(message: String) -> void:
	status_label.text = message
	if _status_tween and _status_tween.is_valid():
		_status_tween.kill()

	_status_tween = create_tween()
	_status_tween.tween_property(status_label, "modulate:a", 1.0, 0.2)
	_status_tween.tween_interval(2.8)
	_status_tween.tween_property(status_label, "modulate:a", 0.0, 0.4)
