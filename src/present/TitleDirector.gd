## TitleDirector.gd — atmospheric title screen.
##
## Shows the game title, prompts to start, and transitions to the gameplay scene.
## Owned by the vision-capable frontend agent. The non-vision frontend agent can
## replace this with a full MainMenu later; this provides the visual foundation.
extends Control

const GAME_VIEW_PATH := "res://scenes/GameView.tscn"

@export var title_color: Color = Color("#c01028")
@export var subtitle_color: Color = Color("#a0a0b0")
@export var prompt_color: Color = Color("#e8e8f0")

@onready var title_label: Label = $TitleLabel
@onready var subtitle_label: Label = $SubtitleLabel
@onready var prompt_label: Label = $PromptLabel
@onready var atmosphere: ColorRect = $Atmosphere

var _pulse_t: float = 0.0
var _starting: bool = false

func _ready() -> void:
	# Apply the UI theme from UIManager if available.
	if UIManager != null and UIManager.theme != null:
		theme = UIManager.theme
	_update_prompt_visibility()

func _process(delta: float) -> void:
	_pulse_t += delta
	if prompt_label != null and not _starting:
		var alpha := 0.5 + 0.5 * sin(_pulse_t * 3.0)
		prompt_label.modulate.a = alpha

func _input(event: InputEvent) -> void:
	if _starting:
		return
	if event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton:
		if event.is_pressed() and not event.is_echo():
			_start_game()
			get_viewport().set_input_as_handled()

func _update_prompt_visibility() -> void:
	if prompt_label != null:
		prompt_label.visible = not _starting

func _start_game() -> void:
	_starting = true
	if prompt_label != null:
		prompt_label.text = "Loading..."
	# Fade out then change scene.
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.6)
	tween.tween_callback(_change_scene)

func _change_scene() -> void:
	get_tree().change_scene_to_file(GAME_VIEW_PATH)
