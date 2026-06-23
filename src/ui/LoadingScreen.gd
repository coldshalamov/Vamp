## LoadingScreen.gd — simple loading / transition screen.
##
## Shows a title + animated progress indicator (reduced-motion aware: static when on).
## The game host (Boot.gd) drives progress via set_progress(0..1). Adds itself to the
## `loading_screen` group so UIManager ignores `pause` while it's up.
extends BaseScreen

var _progress: ProgressBar = null
var _title_label: Label = null
var _status_label: Label = null
var _spinner: Label = null


func _ready() -> void:
	super._ready()
	add_to_group("loading_screen")
	title = tr("MENU_LOADING")
	_build()


func _build() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	close_on_cancel = false
	block_gameplay_input = true
	var center := VBoxContainer.new()
	center.set_anchors_preset(PRESET_FULL_RECT)
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(center)

	_title_label = Label.new()
	_title_label.text = tr("MENU_LOADING")
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center.add_child(_title_label)

	_progress = ProgressBar.new()
	_progress.min_value = 0.0
	_progress.max_value = 1.0
	_progress.value = 0.0
	_progress.custom_minimum_size = Vector2(360, 18)
	_progress.show_percentage = false
	center.add_child(_progress)

	_status_label = Label.new()
	_status_label.text = ""
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center.add_child(_status_label)

	_spinner = Label.new()
	_spinner.text = "•"
	_spinner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center.add_child(_spinner)


func set_status(text: String) -> void:
	if _status_label:
		_status_label.text = text


func set_progress(value: float) -> void:
	if _progress:
		_progress.value = clampf(value, 0.0, 1.0)


func _process(_delta: float) -> void:
	# Animated indicator (skipped under reduced motion).
	if _spinner == null or UIManager.is_reduced_motion():
		return
	var t := fposmod(Time.get_ticks_msec() / 1000.0, TAU)
	var glyphs := ["•", "••", "•••", "••"]
	_spinner.text = glyphs[int(t * 3.0) % glyphs.size()]


func default_focus_control() -> Control:
	return null   # no interactive controls while loading
