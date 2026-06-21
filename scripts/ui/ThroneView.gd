extends Control
## ThroneView — главный дашборд: эпиграф, Печать султана (idle-тап), активная реформа.

var _seal_frame: PanelContainer
var _seal_area: Control
var _seal_center: Control
var _click_lbl: Label
var _taps_lbl: Label
var _reform_bar: ProgressBar
var _reform_pct: Label

func build() -> void:
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 0)
	add_child(root)

	var mc := MarginContainer.new()
	mc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for s in ["left", "right", "top", "bottom"]:
		mc.add_theme_constant_override("margin_" + s, Palette.SAFE_AREA)
	root.add_child(mc)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	mc.add_child(col)

	# Эпиграф эпохи (§21.4.1)
	var epi := Palette.label(Loc.t("throne.epigraph"), Palette.FS_BODY_LG, Palette.ON_SURFACE_VARIANT)
	epi.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	epi.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	epi.add_theme_font_override("font", Palette.font_serif) if Palette.font_serif else null
	col.add_child(epi)

	# Центр — Печать султана
	var center := CenterContainer.new()
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(center)

	_seal_center = center

	_seal_area = Control.new()
	_seal_area.custom_minimum_size = Vector2(220, 220)
	center.add_child(_seal_area)

	# Золотая тезхип-рамка
	_seal_frame = PanelContainer.new()
	_seal_frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var frame_sb := Palette.box(Palette.PRIMARY_CONTAINER, 16, 5, Palette.PRIMARY, 10)
	frame_sb.shadow_color = Color(Palette.PRIMARY.r, Palette.PRIMARY.g, Palette.PRIMARY.b, 0.35)
	frame_sb.shadow_size = 18
	_seal_frame.add_theme_stylebox_override("panel", frame_sb)
	_seal_area.add_child(_seal_frame)

	var tex := TextureRect.new()
	tex.texture = _safe_load("res://assets/art/seal.png")
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	tex.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_seal_frame.add_child(tex)

	# Прозрачная кнопка-перехватчик клика
	var btn := Button.new()
	btn.flat = true
	btn.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	btn.focus_mode = Control.FOCUS_NONE
	btn.pressed.connect(_on_tap)
	_seal_area.add_child(btn)

	# Подсказка «коснись» + ценность касания
	_click_lbl = Palette.label(Loc.t("throne.tap"), Palette.FS_BODY, Palette.ON_SURFACE_VARIANT)
	_click_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_click_lbl)

	# Счётчик касаний (число наших кликов)
	_taps_lbl = Palette.label_caps(Loc.t("throne.taps") + ": 0", Palette.FS_LABEL, Palette.PRIMARY)
	_taps_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_taps_lbl)

	# Нижняя панель активной реформы (§21.4.1)
	var reform_pc := PanelContainer.new()
	reform_pc.add_theme_stylebox_override("panel", Palette.box(Palette.SURFACE_CONTAINER, 10, 1, Palette.OUTLINE_VARIANT, 14))
	col.add_child(reform_pc)
	var rv := VBoxContainer.new()
	rv.add_theme_constant_override("separation", 6)
	reform_pc.add_child(rv)
	var rrow := HBoxContainer.new()
	rv.add_child(rrow)
	var rtitle := Palette.label_caps(Loc.t("throne.reform"), Palette.FS_LABEL, Palette.PRIMARY)
	rtitle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rrow.add_child(rtitle)
	_reform_pct = Palette.label_caps("42%", Palette.FS_LABEL, Palette.ON_SURFACE_VARIANT)
	rrow.add_child(_reform_pct)
	_reform_bar = ProgressBar.new()
	_reform_bar.show_percentage = false
	_reform_bar.max_value = 100
	_reform_bar.custom_minimum_size = Vector2(0, 10)
	_reform_bar.add_theme_stylebox_override("background", Palette.box(Palette.SURFACE_LOWEST, 6, 0))
	_reform_bar.add_theme_stylebox_override("fill", Palette.box(Palette.PRIMARY, 6, 0))
	rv.add_child(_reform_bar)

	_seal_center.resized.connect(_fit_seal)
	call_deferred("_fit_seal")

func _fit_seal() -> void:
	# Печать занимает доступный квадрат, но в разумных пределах — адаптив под экран.
	if not is_instance_valid(_seal_center):
		return
	var avail := _seal_center.size
	var s := clampf(minf(avail.x, avail.y) - 8.0, 140.0, 320.0)
	_seal_area.custom_minimum_size = Vector2(s, s)
	_center_pivot()

func _center_pivot() -> void:
	_seal_frame.pivot_offset = _seal_frame.size / 2.0

func _on_tap() -> void:
	var v := GameState.click_value()
	GameState.tap_seal()
	# «Впечатано»: scale(0.94) → 1.0 (§21.5)
	_seal_frame.pivot_offset = _seal_frame.size / 2.0
	var tw := create_tween()
	tw.tween_property(_seal_frame, "scale", Vector2(0.94, 0.94), 0.05)
	tw.tween_property(_seal_frame, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_spawn_floater("+" + Palette.fmt(v))

func _spawn_floater(text: String) -> void:
	var f := Palette.label(text, 22, Palette.PRIMARY_FIXED, true)
	f.z_index = 10
	add_child(f)
	var c := _seal_area.global_position + _seal_area.size / 2.0 - global_position
	f.position = c + Vector2(randf_range(-30, 30), -40)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(f, "position:y", f.position.y - 80, 0.8)
	tw.tween_property(f, "modulate:a", 0.0, 0.8)
	tw.chain().tween_callback(f.queue_free)

func update_view() -> void:
	_click_lbl.text = "+%s %s" % [Palette.fmt(GameState.click_value()), Loc.t("throne.per_click")]
	_taps_lbl.text = "%s: %s" % [Loc.t("throne.taps"), Palette.fmt_int(GameState.tap_count)]
	_reform_bar.value = GameState.reform_progress
	if GameState.reform_done:
		_reform_pct.text = "100% \u2713"
	else:
		_reform_pct.text = "%d%%" % int(GameState.reform_progress)

func _safe_load(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path)
	return null
