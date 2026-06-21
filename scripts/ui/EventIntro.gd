extends Control
## EventIntro — заставка перед событием: к трону прибыл гонец с письмом.
## Показывает портрет гонца и крупную кнопку «Открыть письмо», по нажатию
## которой поверх открывается окно самого события (EventModal).

var on_open: Callable = func(): pass
var _img: TextureRect

func build() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.66)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)

	var center := MarginContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for s in ["left", "right"]:
		center.add_theme_constant_override("margin_" + s, Palette.SAFE_AREA)
	for s in ["top", "bottom"]:
		center.add_theme_constant_override("margin_" + s, 36)
	scroll.add_child(center)

	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var sb := Palette.box(Palette.PARCHMENT, 14, 3, Palette.PRIMARY, 18)
	sb.border_color = Palette.PRIMARY
	sb.shadow_color = Color(0, 0, 0, 0.55)
	sb.shadow_size = 18
	card.add_theme_stylebox_override("panel", sb)
	center.add_child(card)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_child(v)

	# Тугра + заголовок
	var tughra := Palette.label("\u262A", 28, Palette.CRIMSON_DEEP, true)
	tughra.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(tughra)
	var title := Palette.label(Loc.t("ev.envoy_title"), Palette.FS_TITLE, Palette.CRIMSON_DEEP, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(title)

	# Портрет гонца в «поляроидной» рамке
	var poly := PanelContainer.new()
	poly.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var poly_sb := Palette.box(Color.WHITE, 5, 1, Palette.OUTLINE, 8)
	poly_sb.content_margin_bottom = 16
	poly_sb.shadow_color = Color(0, 0, 0, 0.3)
	poly_sb.shadow_size = 5
	poly.add_theme_stylebox_override("panel", poly_sb)
	v.add_child(poly)
	_img = TextureRect.new()
	_img.texture = _safe_load("res://assets/art/envoy.jpg")
	_img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_img.custom_minimum_size = Vector2(280, 360)
	poly.add_child(_img)

	# Подпись-флавор
	var sub := Palette.label(Loc.t("ev.envoy_sub"), Palette.FS_BODY, Palette.ON_PARCHMENT.lightened(0.05))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(sub)

	# ── Красивая кнопка «Открыть письмо» (восковая печать) ──
	var btn := Button.new()
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.focus_mode = Control.FOCUS_NONE
	btn.text = "\u262A  " + Loc.t("ev.open_letter")
	btn.add_theme_font_size_override("font_size", Palette.FS_BODY_LG)
	var nsb := StyleBoxFlat.new()
	nsb.bg_color = Palette.PRIMARY
	nsb.set_corner_radius_all(999)
	nsb.set_border_width_all(2)
	nsb.border_color = Palette.PRIMARY_CONTAINER.darkened(0.1)
	nsb.content_margin_top = 14
	nsb.content_margin_bottom = 14
	nsb.content_margin_left = 22
	nsb.content_margin_right = 22
	nsb.shadow_color = Color(0, 0, 0, 0.35)
	nsb.shadow_size = 6
	nsb.shadow_offset = Vector2(0, 3)
	var hsb := nsb.duplicate()
	hsb.bg_color = Palette.PRIMARY.lightened(0.08)
	var psb := nsb.duplicate()
	psb.bg_color = Palette.PRIMARY.darkened(0.12)
	psb.shadow_size = 2
	btn.add_theme_stylebox_override("normal", nsb)
	btn.add_theme_stylebox_override("hover", hsb)
	btn.add_theme_stylebox_override("pressed", psb)
	btn.add_theme_stylebox_override("focus", nsb)
	btn.add_theme_color_override("font_color", Palette.ON_PRIMARY)
	btn.add_theme_color_override("font_hover_color", Palette.ON_PRIMARY)
	btn.add_theme_color_override("font_pressed_color", Palette.ON_PRIMARY)
	btn.pressed.connect(func(): on_open.call())
	v.add_child(btn)

func show_intro() -> void:
	if visible:
		return
	# обновим портрет на случай, если ассет появился позже
	if _img != null and _img.texture == null:
		_img.texture = _safe_load("res://assets/art/envoy.jpg")
	visible = true
	scale = Vector2(0.96, 0.96)
	modulate.a = 0.0
	pivot_offset = size / 2.0
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "modulate:a", 1.0, 0.18)
	tw.tween_property(self, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func hide_intro() -> void:
	if not visible:
		return
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.14)
	tw.tween_callback(func(): visible = false)

func _safe_load(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path)
	return null
