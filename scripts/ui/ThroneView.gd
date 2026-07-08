extends Control
## ThroneView — главный дашборд: эпиграф, Печать султана (idle-тап), активная реформа.

var _seal_frame: PanelContainer
var _seal_area: Control
var _seal_center: Control
var _click_lbl: Label
var _taps_lbl: Label
var _diplomacy_btn: Button
var _diplo_overlay: Control
var _diplo_card: PanelContainer
var _diplo_rows: Dictionary = {}    # id страны -> {pct: Label, bar: ProgressBar, up: Button, down: Button}
var _diplo_tariff: Label

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
	btn.set_meta("no_sfx", true)   # у Печати свой ритм — без общего клика
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

	# Кнопка «Дипломатия» (вместо панели реформы). Пока заглушка: окно отношений
	# с соседями (цены на хлеб, приграничные стычки) появится позже.
	_diplomacy_btn = Button.new()
	_diplomacy_btn.custom_minimum_size = Vector2(0, 56)
	Palette.style_glass_button(_diplomacy_btn, true)
	_diplomacy_btn.text = "\u2696  " + Loc.t("throne.diplomacy")
	_diplomacy_btn.pressed.connect(_on_diplomacy)
	col.add_child(_diplomacy_btn)

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

var _seal_tw: Tween
var _tilt_right := false

func _on_tap() -> void:
	GameState.tap_seal()
	var v := GameState.click_value()
	_seal_frame.pivot_offset = _seal_frame.size / 2.0
	# При быстрой серии касаний твины наслаиваются — гасим предыдущий
	if _seal_tw != null and _seal_tw.is_valid():
		_seal_tw.kill()
	_seal_tw = create_tween()
	if GameState.frenzy_active():
		# РАЖ: Печать раздувается и качается — каждое касание в другую сторону
		var sx := get_node_or_null("/root/Sfx")
		if sx != null:
			sx.frenzy_whoosh()   # тихий свист на каждом касании в раже
		_tilt_right = not _tilt_right
		var ang := deg_to_rad(7.0) * (1.0 if _tilt_right else -1.0)
		_seal_tw.set_parallel(true)
		_seal_tw.tween_property(_seal_frame, "scale", Vector2(1.14, 1.14), 0.06)
		_seal_tw.tween_property(_seal_frame, "rotation", ang, 0.06)
		_seal_tw.chain().tween_property(_seal_frame, "scale", Vector2.ONE, 0.14) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_seal_tw.parallel().tween_property(_seal_frame, "rotation", 0.0, 0.14)
		_spawn_floater("+%s \u00D7%d" % [Palette.fmt(v), int(GameState.FRENZY_MULT)])
	else:
		# Обычное «впечатано»: scale(0.94) → 1.0 (§21.5)
		_seal_tw.tween_property(_seal_frame, "scale", Vector2(0.94, 0.94), 0.05)
		_seal_tw.tween_property(_seal_frame, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_seal_tw.parallel().tween_property(_seal_frame, "rotation", 0.0, 0.12)
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
	if GameState.frenzy_active():
		var left := int(ceil(GameState.frenzy_until - Time.get_unix_time_from_system()))
		_click_lbl.text = "+%s %s · \u00D7%d (%d)" % [Palette.fmt(GameState.click_value()), Loc.t("throne.per_click"), int(GameState.FRENZY_MULT), left]
		_click_lbl.add_theme_color_override("font_color", Palette.PRIMARY)
	else:
		var txt := "+%s %s" % [Palette.fmt(GameState.click_value()), Loc.t("throne.per_click")]
		var cd := GameState.frenzy_cd_left()
		if cd > 0.0:
			txt += " · " + Loc.t("throne.frenzy_cd") % [int(GameState.FRENZY_MULT), int(ceil(cd))]
		_click_lbl.text = txt
		_click_lbl.add_theme_color_override("font_color", Palette.ON_SURFACE_VARIANT)
	_taps_lbl.text = "%s: %s" % [Loc.t("throne.taps"), Palette.fmt_int(GameState.tap_count)]
	if _diplo_overlay != null and _diplo_overlay.visible:
		_refresh_diplo()   # проценты тают в реальном времени — обновляем окно


func _exit_tree() -> void:
	# Оверлей живёт в viewport (вне вью) — прибираем при пересборке UI,
	# иначе после смены языка останется висеть осиротевшая копия.
	if _diplo_overlay != null and is_instance_valid(_diplo_overlay):
		_diplo_overlay.queue_free()
		_diplo_overlay = null

func _on_diplomacy() -> void:
	if _diplo_overlay == null:
		_diplo_overlay = _build_diplo_overlay()
		# Поверх всего экрана (вне клипа области контента), как семейное древо
		get_viewport().add_child(_diplo_overlay)
	_refresh_diplo()
	_diplo_overlay.visible = true
	# Плавное открытие: фейд + лёгкий «наезд» карточки
	_diplo_overlay.modulate.a = 0.0
	_diplo_card.scale = Vector2(0.92, 0.92)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_diplo_overlay, "modulate:a", 1.0, 0.22)
	tw.tween_property(_diplo_card, "scale", Vector2.ONE, 0.28) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _close_diplo() -> void:
	if _diplo_overlay == null or not _diplo_overlay.visible:
		return
	var tw := create_tween()
	tw.tween_property(_diplo_overlay, "modulate:a", 0.0, 0.16)
	tw.tween_callback(func(): _diplo_overlay.visible = false)

func _build_diplo_overlay() -> Control:
	var wrap := Control.new()
	wrap.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	wrap.visible = false
	wrap.add_to_group("fullscreen_modal")   # Main блокирует свой скролл/свайпы
	# Блюр фона + затемнение; тап по фону закрывает (как у древа)
	var blur := ColorRect.new()
	var bsh := Shader.new()
	bsh.code = """
shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float lod : hint_range(0.0, 5.0) = 2.4;
uniform float darken : hint_range(0.0, 1.0) = 0.38;
void fragment() {
	vec4 c = textureLod(screen_tex, SCREEN_UV, lod);
	COLOR = vec4(c.rgb * (1.0 - darken), 1.0);
}
"""
	var bm := ShaderMaterial.new()
	bm.shader = bsh
	blur.material = bm
	blur.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	blur.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed:
			_close_diplo())
	wrap.add_child(blur)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", Palette.SAFE_AREA)
	margin.add_theme_constant_override("margin_right", Palette.SAFE_AREA)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.add_child(margin)
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 10)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(v)

	# Карточка-пергамент, как у семейного древа
	_diplo_card = PanelContainer.new()
	_diplo_card.add_theme_stylebox_override("panel",
		Palette.box(Palette.SURFACE_CONTAINER, 14, 1, Palette.OUTLINE_VARIANT, 14))
	_diplo_card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_diplo_card.resized.connect(func(): _diplo_card.pivot_offset = _diplo_card.size / 2.0)
	v.add_child(_diplo_card)

	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", 8)
	_diplo_card.add_child(cv)

	# Карта — верхняя часть карточки
	var map := TextureRect.new()
	map.texture = _safe_load("res://assets/art/diplomacy_map.jpg")
	map.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	# Показываем карту ЦЕЛИКОМ, без подрезки (вписываем в отведённую область)
	map.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	map.size_flags_vertical = Control.SIZE_EXPAND_FILL
	map.size_flags_stretch_ratio = 1.7
	map.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cv.add_child(map)
	# Плавный градиентный переход: низ и верх карты растворяются в фоне
	# окна вместо резкого среза (как у артов событий).
	var pc: Color = Palette.SURFACE_CONTAINER
	for side in [true, false]:   # true = низ, false = верх
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 1.0])
		g.colors = PackedColorArray([Color(pc.r, pc.g, pc.b, 0.0), Color(pc.r, pc.g, pc.b, 1.0)])
		var gt := GradientTexture2D.new()
		gt.gradient = g
		gt.fill_from = Vector2(0.0, 0.0 if side else 1.0)
		gt.fill_to = Vector2(0.0, 1.0 if side else 0.0)
		var fade := TextureRect.new()
		fade.texture = gt
		fade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if side:
			fade.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
			fade.offset_top = -64.0
		else:
			fade.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
			fade.offset_bottom = 40.0
		map.add_child(fade)

	# Пошлины на хлеб
	_diplo_tariff = Palette.label("", Palette.FS_LABEL, Palette.ON_SURFACE_VARIANT)
	_diplo_tariff.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_diplo_tariff.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cv.add_child(_diplo_tariff)

	# Список стран
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	# Список компактнее (~3 страны на экране, остальное скроллом) — карта крупнее
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.size_flags_stretch_ratio = 0.9
	cv.add_child(sc)
	var rows := VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", 10)
	sc.add_child(rows)
	_diplo_rows.clear()
	for id in GameState.DIPLO_COUNTRIES:
		rows.add_child(_diplo_row(str(id)))

	var close := Button.new()
	close.custom_minimum_size = Vector2(0, 48)
	Palette.style_glass_button(close, false)
	close.text = Loc.t("wheel.back")
	close.pressed.connect(_close_diplo)
	v.add_child(close)
	return wrap

func _diplo_row(id: String) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var top := HBoxContainer.new()
	box.add_child(top)
	var nm := Palette.label_caps(Loc.t("diplo." + id), Palette.FS_LABEL, Palette.PRIMARY)
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(nm)
	var pct := Palette.label_caps("55%", Palette.FS_LABEL, Palette.ON_SURFACE_VARIANT)
	top.add_child(pct)
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.max_value = 100
	bar.custom_minimum_size = Vector2(0, 8)
	bar.add_theme_stylebox_override("background", Palette.box(Palette.SURFACE_LOWEST, 5, 0))
	bar.add_theme_stylebox_override("fill", Palette.box(Palette.PRIMARY, 5, 0))
	box.add_child(bar)
	var up: Button = null
	var eff: Label = null
	if GameState.is_vassal(id):
		var badge := Palette.label_caps("\u2726 " + Loc.t("diplo.vassal"), Palette.FS_LABEL, Palette.ON_SURFACE_VARIANT)
		box.add_child(badge)
	else:
		# Кнопка «Улучшить» + под ней — текущий эффект отношений (баф или дебаф).
		# Кнопки «Ухудшить» больше нет: игрок не должен намеренно портить связи,
		# они и так тают со временем.
		up = Button.new()
		up.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		up.custom_minimum_size = Vector2(0, 40)
		Palette.style_glass_button(up, true)
		up.pressed.connect(func():
			var sx := get_node_or_null("/root/Sfx")
			if sx != null and GameState.can_improve_relation(id):
				sx.buy_food()   # тот же звук, что и при закупке зерна в Снабжении
			GameState.improve_relation(id)
			_refresh_diplo())
		box.add_child(up)
		eff = Palette.label("", Palette.FS_LABEL, Palette.ON_SURFACE_VARIANT)
		eff.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		eff.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(eff)
	_diplo_rows[id] = {"pct": pct, "bar": bar, "up": up, "eff": eff}
	return box

func _refresh_diplo() -> void:
	if _diplo_overlay == null:
		return
	var cost := GameState.improve_relation_cost()
	for id in _diplo_rows:
		var r: Dictionary = _diplo_rows[id]
		var v := GameState.relation(str(id))
		(r.pct as Label).text = "%d%%" % int(roundf(v))
		(r.bar as ProgressBar).value = v
		if r.up != null:
			(r.up as Button).text = "%s (%s)" % [Loc.t("diplo.improve"), Palette.fmt(cost)]
			(r.up as Button).disabled = not GameState.can_improve_relation(str(id))
		if r.eff != null:
			var text := GameState.relation_effect_text(str(id))
			(r.eff as Label).text = text
			# Цвет: тревожно-красный при плохих отношениях, тёплый при хороших
			var c := Palette.ON_SURFACE_VARIANT
			if v < 30.0:
				c = Palette.TERTIARY
			elif v < 60.0:
				c = Palette.PRIMARY
			else:
				c = Palette.SECONDARY
			(r.eff as Label).add_theme_color_override("font_color", c)
	var extra := int(roundf((GameState.chumak_tariff_mult() - 1.0) * 100.0))
	if extra > 0:
		_diplo_tariff.text = Loc.t("diplo.tariff") % extra
	else:
		_diplo_tariff.text = Loc.t("diplo.tariff_none")

func _safe_load(path: String) -> Texture2D:
	# Сперва пробуем оригинальный путь, затем — .webp-вариант (мы пожали
	# крупные PNG/JPG в webp ради размера APK).
	if ResourceLoader.exists(path):
		return load(path)
	var alt := path.get_basename() + ".webp"
	if ResourceLoader.exists(alt):
		return load(alt)
	return null
