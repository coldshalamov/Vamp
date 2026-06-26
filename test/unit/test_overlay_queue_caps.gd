## Regression guard for UI overlay caps. CaptionOverlay/NotificationPanel used to trim overflow with
## `while get_child_count() >= cap: queue_free(oldest)`, but queue_free is deferred, so child_count
## never dropped inside the same call and the main thread could spin forever once a capped overlay
## received one more caption/toast/banner.
extends GutTest

const CaptionScene := preload("res://scenes/ui/CaptionOverlay.tscn")
const NotificationScene := preload("res://scenes/ui/NotificationPanel.tscn")
const UIThemeScript := preload("res://src/ui/UITheme.gd")

var _caption: CaptionOverlay = null
var _panel: NotificationPanel = null


func before_each() -> void:
	if UIManager != null and UIManager.theme_resource == null:
		UIManager.theme_resource = UIThemeScript.new()
	_caption = CaptionScene.instantiate()
	add_child_autoqfree(_caption)
	_panel = NotificationScene.instantiate()
	add_child_autoqfree(_panel)


func test_caption_overlay_stays_bounded_when_pushing_past_cap() -> void:
	for i in range(6):
		_caption.push_caption("caption %d" % i, "left")
		assert_lte(_caption._box.get_child_count(), 4, "caption overlay must stay at the 4-line cap")
	var texts: Array[String] = []
	for child in _caption._box.get_children():
		texts.append(String((child as Label).text))
	assert_eq(texts.size(), 4, "caption overlay kept the newest 4 captions")
	assert_true(texts[0].find("caption 2") != -1, "oldest visible caption should be the third push")
	assert_true(texts[3].find("caption 5") != -1, "newest caption should remain visible")


func test_notification_panel_caps_toasts_and_banners_without_hanging() -> void:
	for i in range(7):
		_panel.push_notification("toast %d" % i)
		assert_lte(_panel._toast_box().get_child_count(), 4, "toast queue must stay at the 4-item cap")
	for i in range(4):
		_panel.push_banner("title %d" % i, "body %d" % i)
		assert_lte(_panel._banner_box().get_child_count(), 2, "banner queue must stay at the 2-item cap")
	assert_eq(_panel._toast_box().get_child_count(), 4, "toast queue kept the newest 4 toasts")
	assert_eq(_panel._banner_box().get_child_count(), 2, "banner queue kept the newest 2 banners")
	var first_banner := _panel._banner_box().get_child(0)
	var title_label := first_banner.get_child(0).get_child(0) as Label
	assert_true(String(title_label.text).find("title 2") != -1, "oldest visible banner should be the third push")
