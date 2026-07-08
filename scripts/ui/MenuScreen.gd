extends Control
## MenuScreen — главное меню по дизайну Stitch (токены из DESIGN.md архива):
## стеклянные панели, филигранные уголки, изумрудная пульсация «Колеса удачи».
## Рендер нативный (шрифты + векторные рамки) — резко на любом экране.

signal play_pressed
signal wheel_pressed
signal settings_pressed
signal donate_pressed

# Токены Stitch (DESIGN.md)
const GOLD := Color("#f2ca50")
const GOLD_DEEP := Color("#d4af37")
const TEAL := Color("#75d9b1")
const MUTED := Color("#d0c5af")
const GLASS := Color(0.031, 0.039, 0.059, 0.4)   # rgba(8,10,15,0.4)
const BAR_BG := Color("#32353c")

var _play_cell: Control
var _play_btn: Button
var _wheel_glow: Control
var _wheel_hint: Label
var _energy_bar: ProgressBar
var _energy_val: Label
var _energy_timer: Label
var _energy_ad_btn: Button
var _title: Label
var _title_logo: TextureRect
var _title_logo_wrap: MarginContainer
var _tick := 0.0
var _fade: Tween

## Пульсирующая градиентная обводка: изумруд (доступно) / красный (кулдаун).
class GlowBorder extends Control:
	var ok := true
	var _ph := 0.0
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)
	func _process(delta: float) -> void:
		if not is_visible_in_tree():
			return
		_ph += delta
		queue_redraw()
	func _draw() -> void:
		if size.x < 8.0 or size.y < 8.0:
			return
		var pulse := 0.5 - 0.5 * cos(TAU * _ph / 2.5)   # период 2.5с, как в Stitch
		var r := 13.0
		var pts := PackedVector2Array()
		var corners := [
			[Vector2(r, r), PI, 1.5 * PI],
			[Vector2(size.x - r, r), 1.5 * PI, TAU],
			[Vector2(size.x - r, size.y - r), 0.0, 0.5 * PI],
			[Vector2(r, size.y - r), 0.5 * PI, PI],
		]
		for c in corners:
			for k in range(9):
				var a := lerpf(float(c[1]), float(c[2]), float(k) / 8.0)
				pts.append(Vector2(c[0]) + Vector2(cos(a), sin(a)) * r)
		pts.append(pts[0])
		var c1 := Color("#75d9b1") if ok else Color("#ff5c5c")
		var c2 := Color("#0a8a63") if ok else Color("#7a1616")
		var n := pts.size()
		var cols := PackedColorArray()
		var glow := PackedColorArray()
		var la := lerpf(0.55, 1.0, pulse)
		var ga := lerpf(0.12, 0.45, pulse)
		for i in range(n):
			var t := float(i) / float(n - 1)
			var g := 0.5 - 0.5 * cos(t * TAU * 2.0)
			var col := c1.lerp(c2, g)
			cols.append(Color(col.r, col.g, col.b, la))
			glow.append(Color(col.r, col.g, col.b, ga))
		draw_polyline_colors(pts, glow, lerpf(5.0, 8.0, pulse), true)
		draw_polyline_colors(pts, cols, 2.0, true)

## Филигранные уголки панели (тонкие золотые дуги, как в макете).
class Filigree extends Control:
	# PanelContainer вжимает детей внутрь отступов панели, поэтому уголки
	# рисуем с выносом наружу (inset) — по краям самой панели, а не поверх
	# контента. Иначе скобочки налазят на текст и полоску бара.
	var inset := 0.0
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)
	func _draw() -> void:
		if size.x < 20.0 or size.y < 20.0:
			return
		var g := Color(0.831, 0.686, 0.216, 0.6)   # #d4af37, 60%
		var rr := 9.0
		var m := 3.0
		var x0 := -inset + m + rr
		var x1 := size.x + inset - m - rr
		var y0 := -inset + m + rr
		var y1 := size.y + inset - m - rr
		draw_arc(Vector2(x0, y0), rr, PI, 1.5 * PI, 10, g, 1.0, true)
		draw_arc(Vector2(x1, y0), rr, 1.5 * PI, TAU, 10, g, 1.0, true)
		draw_arc(Vector2(x1, y1), rr, 0.0, 0.5 * PI, 10, g, 1.0, true)
		draw_arc(Vector2(x0, y1), rr, 0.5 * PI, PI, 10, g, 1.0, true)

func build() -> void:
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var bg := TextureRect.new()
	bg.texture = _safe_load("res://assets/art/bg_menu.jpg")
	if bg.texture == null:
		bg.texture = _safe_load("res://assets/art/bg_palace.png")
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Вертикальный градиент читаемости: сверху лёгкое затемнение, снизу плотное.
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
	grad.colors = PackedColorArray([
		Color(0.063, 0.075, 0.102, 0.40),
		Color(0.063, 0.075, 0.102, 0.0),
		Color(0.063, 0.075, 0.102, 0.92),
	])
	var gtex := GradientTexture2D.new()
	gtex.gradient = grad
	gtex.fill_from = Vector2(0, 0)
	gtex.fill_to = Vector2(0, 1)
	var dim := TextureRect.new()
	dim.texture = gtex
	dim.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	dim.stretch_mode = TextureRect.STRETCH_SCALE
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	# ── Панель энергии сверху (стекло + филигрань) ──
	var top := MarginContainer.new()
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.add_theme_constant_override("margin_top", 16)
	top.add_theme_constant_override("margin_left", 20)
	top.add_theme_constant_override("margin_right", 20)
	add_child(top)
	var ecenter := CenterContainer.new()
	top.add_child(ecenter)
	var epanel := PanelContainer.new()
	epanel.custom_minimum_size = Vector2(240, 0)
	epanel.add_theme_stylebox_override("panel",
		Palette.box(GLASS, 12, 1, Color(GOLD_DEEP.r, GOLD_DEEP.g, GOLD_DEEP.b, 0.3), 12))
	ecenter.add_child(epanel)
	var fil := Filigree.new()
	fil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fil.inset = 12.0   # компенсируем отступ контента панели — уголки по краям панели
	epanel.add_child(fil)
	var ecol := VBoxContainer.new()
	ecol.add_theme_constant_override("separation", 6)
	epanel.add_child(ecol)
	var erow := HBoxContainer.new()
	erow.add_theme_constant_override("separation", 8)
	ecol.add_child(erow)
	erow.add_child(Palette.label("\u26A1", 15, GOLD))
	var etitle := Palette.label_caps(Loc.t("energy.title"), Palette.FS_LABEL, MUTED)
	etitle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	erow.add_child(etitle)
	_energy_val = Palette.label("30/30", Palette.FS_LABEL, GOLD, true)
	erow.add_child(_energy_val)
	_energy_bar = ProgressBar.new()
	_energy_bar.min_value = 0.0
	_energy_bar.max_value = 1.0
	_energy_bar.show_percentage = false
	_energy_bar.custom_minimum_size = Vector2(0, 5)
	_energy_bar.add_theme_stylebox_override("background", Palette.box(BAR_BG, 3))
	var fill_sb := Palette.box(GOLD, 3)
	fill_sb.shadow_color = Color(GOLD.r, GOLD.g, GOLD.b, 0.6)
	fill_sb.shadow_size = 4
	_energy_bar.add_theme_stylebox_override("fill", fill_sb)
	ecol.add_child(_energy_bar)
	_energy_timer = Palette.label_caps(" ", 10, MUTED)
	_energy_timer.self_modulate = Color(1, 1, 1, 0.6)
	_energy_timer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ecol.add_child(_energy_timer)
	# Реклама за энергию: видна, когда энергии меньше половины
	_energy_ad_btn = Button.new()
	_energy_ad_btn.custom_minimum_size = Vector2(0, 40)
	Palette.style_glass_button(_energy_ad_btn, true)
	_energy_ad_btn.pressed.connect(_on_energy_ad)
	ecol.add_child(_energy_ad_btn)

	# ── Заголовок + тонкая золотая линия ──
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	center.add_child(col)

	_title = Palette.label("", 30, GOLD, true)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	_title.add_theme_constant_override("shadow_offset_x", 0)
	_title.add_theme_constant_override("shadow_offset_y", 4)
	_title.add_theme_constant_override("shadow_outline_size", 8)
	col.add_child(_title)
	# Каллиграфический логотип вместо текста (текст — запасной вариант).
	# Своя картинка на каждый язык; при переключении языка меняется в _refresh_texts.
	_title_logo_wrap = MarginContainer.new()
	_title_logo_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title_logo = TextureRect.new()
	_title_logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_title_logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_title_logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title_logo_wrap.add_child(_title_logo)
	col.add_child(_title_logo_wrap)
	col.move_child(_title_logo_wrap, _title.get_index())
	_apply_title_logo()

	var dgrad := Gradient.new()
	dgrad.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	dgrad.colors = PackedColorArray([
		Color(GOLD_DEEP.r, GOLD_DEEP.g, GOLD_DEEP.b, 0.0),
		Color(GOLD_DEEP.r, GOLD_DEEP.g, GOLD_DEEP.b, 0.5),
		Color(GOLD_DEEP.r, GOLD_DEEP.g, GOLD_DEEP.b, 0.0),
	])
	var dtex := GradientTexture2D.new()
	dtex.gradient = dgrad
	var divider := TextureRect.new()
	divider.texture = dtex
	divider.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	divider.stretch_mode = TextureRect.STRETCH_SCALE
	divider.custom_minimum_size = Vector2(110, 1)
	divider.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(divider)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 12)
	col.add_child(spacer)

	# ── Кнопки — PNG из архива Stitch (готовые, с надписями) ──
	var play := _make_img_btn(col, "btn_play", func(): play_pressed.emit())
	_play_cell = play[0]
	_play_btn = play[1]
	var wheel := _make_img_btn(col, "btn_wheel", func(): wheel_pressed.emit())
	_wheel_glow = GlowBorder.new()
	_wheel_glow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Внутренние поля PNG-кнопки (~2px на экране) — обводка ложится точно на её рамку.
	_wheel_glow.offset_left = 2.0
	_wheel_glow.offset_top = 2.0
	_wheel_glow.offset_right = -2.0
	_wheel_glow.offset_bottom = -2.0
	wheel[0].add_child(_wheel_glow)
	_wheel_hint = Palette.label_caps(" ", 10, MUTED)
	_wheel_hint.self_modulate = Color(1, 1, 1, 0.7)
	_wheel_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_wheel_hint)
	_make_img_btn(col, "btn_settings", func(): settings_pressed.emit())
	_make_img_btn(col, "btn_donate", func(): donate_pressed.emit())

## Кнопка-картинка из архива: срез + невидимый кликер (нажатие притемняет).
func _make_img_btn(col: VBoxContainer, tex_name: String, cb: Callable) -> Array:
	var cell := Control.new()
	cell.custom_minimum_size = Vector2(254, 55)
	cell.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(cell)
	var tr := TextureRect.new()
	tr.texture = _safe_load("res://assets/art/menu/%s.png" % tex_name)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.add_child(tr)
	# Подпись кнопки — Label поверх картинки; ключ живёт в meta,
	# переключение языка в _refresh_texts подставит нужный перевод.
	var key := "menu." + tex_name.substr(4)   # btn_play → menu.play
	var lbl := Palette.label_caps(Loc.t(key), 18, Palette.PRIMARY)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.75))
	lbl.add_theme_constant_override("shadow_offset_x", 0)
	lbl.add_theme_constant_override("shadow_offset_y", 2)
	lbl.add_theme_constant_override("shadow_outline_size", 6)
	lbl.set_meta("loc_key", key)
	cell.add_child(lbl)
	var b := Button.new()
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	for st in ["normal", "hover", "pressed", "disabled", "focus"]:
		b.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	b.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	b.button_down.connect(func(): cell.modulate = Color(0.8, 0.8, 0.8, cell.modulate.a))
	b.button_up.connect(func(): cell.modulate = Color(1, 1, 1, cell.modulate.a))
	b.pressed.connect(cb)
	cell.add_child(b)
	return [cell, b]

func _on_energy_ad() -> void:
	GameState.request_rewarded("energy", _grant_energy)

func _grant_energy() -> void:
	GameState.energy = GameState.ENERGY_MAX
	_update_energy()

func open_menu(instant: bool = false) -> void:
	if not instant:
		GameState.maybe_interstitial()   # TODO ADMOB: реальный показ внутри
	_refresh_texts()
	_update_energy()
	_update_wheel_hint()
	GameState.sim_paused = true
	if _fade:
		_fade.kill()
	if instant or visible:
		modulate.a = 1.0
		visible = true
		return
	modulate.a = 0.0
	visible = true
	_fade = create_tween()
	_fade.tween_property(self, "modulate:a", 1.0, 0.3)

func close_menu() -> void:
	GameState.sim_paused = false
	if _fade:
		_fade.kill()
	_fade = create_tween()
	_fade.tween_property(self, "modulate:a", 0.0, 0.3)
	_fade.tween_callback(_after_fade_out)

func _after_fade_out() -> void:
	visible = false
	modulate.a = 1.0

func _refresh_texts() -> void:
	_title.text = Loc.t("menu.title")
	_apply_title_logo()
	_refresh_btn_labels(self)

func _refresh_btn_labels(node: Node) -> void:
	if node is Label and node.has_meta("loc_key"):
		node.text = Loc.t(str(node.get_meta("loc_key")))
	for c in node.get_children():
		_refresh_btn_labels(c)

func _apply_title_logo() -> void:
	if _title_logo == null:
		return
	var tex := _safe_load("res://assets/art/logo_title_%s.png" % Loc.lang)
	if tex == null:
		tex = _safe_load("res://assets/art/logo_title_ru.png")
	if tex == null:
		# Ассетов нет — возвращаем текстовый заголовок
		_title_logo_wrap.visible = false
		_title.visible = true
		return
	_title_logo.texture = tex
	# Английскую версию опускаем ниже русской и делаем чуть крупнее
	_title_logo_wrap.add_theme_constant_override("margin_top", 48 if Loc.lang == "en" else 0)
	# Один размер и одно место для обеих версий: ширина фиксированная,
	# высота — по пропорциям текущей картинки
	var lw := 452.0 if Loc.lang == "en" else 428.0
	_title_logo.custom_minimum_size = Vector2(lw, lw * float(tex.get_height()) / float(tex.get_width()))
	_title_logo_wrap.visible = true
	_title.visible = false

func _process(delta: float) -> void:
	if not visible:
		return
	_tick += delta
	if _tick >= 0.5:
		_tick = 0.0
		_update_wheel_hint()
		_update_energy()

func _update_energy() -> void:
	if GameState.energy_unlimited():
		_energy_bar.value = 1.0
		_energy_val.text = "\u221E"
		_energy_timer.text = Loc.t("energy.unlim") % _fmt(GameState.energy_unlim_left_sec())
	else:
		_energy_bar.value = GameState.energy_fraction()
		_energy_val.text = "%d/%d" % [ceili(GameState.energy), int(GameState.ENERGY_MAX)]
		# Таймер «Полная через…» показываем ТОЛЬКО в фазе подзарядки
		# (после полного разряда). Частично севшая батарея стоит без таймера.
		if GameState.energy_recharging and GameState.energy < GameState.ENERGY_MAX - 0.01:
			_energy_timer.text = Loc.t("energy.full_in") % _fmt(GameState.energy_full_in_sec())
		else:
			_energy_timer.text = " "
	var ok := GameState.can_play()
	_play_btn.disabled = not ok
	_play_cell.modulate.a = 1.0 if ok else 0.55
	_energy_ad_btn.text = "\u26A1 " + Loc.t("ads.energy")
	_energy_ad_btn.visible = not GameState.energy_unlimited() \
		and GameState.energy < GameState.ENERGY_MAX * 0.5

func _update_wheel_hint() -> void:
	var avail := GameState.wheel_available()
	if _wheel_glow.ok != avail:
		_wheel_glow.ok = avail
		_wheel_glow.queue_redraw()
	if avail:
		_wheel_hint.text = " "
	else:
		_wheel_hint.text = Loc.t("menu.wheel_in") % _fmt(GameState.wheel_seconds_left())

func _fmt(sec: float) -> String:
	var s := int(sec)
	return "%d:%02d:%02d" % [s / 3600, (s % 3600) / 60, s % 60]

func _safe_load(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path)
	var alt := path.get_basename() + ".webp"
	if ResourceLoader.exists(alt):
		return load(alt)
	return null
