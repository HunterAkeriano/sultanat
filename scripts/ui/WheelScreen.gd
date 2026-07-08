extends Control
## WheelScreen — «локация» колеса удачи: рисованное колесо с 8 секторами,
## вращение с анимацией, выигрыш применяется к игре (GameState).

signal back_pressed

var _wheel: Control
var _spin_btn: Button
var _back_btn: Button
var _result: Label
var _respin_btn: Button
var _double_btn: Button
var _last_idx := -1
var _cooldown: Label
var _title: Label
var _spinning := false
var _tick := 0.0

class Wheel extends Control:
	const COLORS := [
		Color("#7d2a2d"), Color("#1f3a5f"), Color("#3f6b4f"), Color("#8a6d1f"),
		Color("#5a2d63"), Color("#2d5f5a"), Color("#6b3f1f"), Color("#33425f"),
		Color("#4f2d3f"),
	]
	func _ready() -> void:
		resized.connect(func(): pivot_offset = size / 2.0; queue_redraw())
	func _draw() -> void:
		var n: int = GameData.WHEEL_PRIZES.size()
		if n == 0:
			return
		var c := size / 2.0
		var r := minf(c.x, c.y) - 6.0
		var seg := TAU / float(n)
		var f := get_theme_default_font()
		var gold: Color = Palette.PRIMARY
		# Сектора: объём за счёт двух тонов (тёмный клин + светлая сердцевина)
		for i in range(n):
			var a0 := seg * float(i)
			var base: Color = COLORS[i % COLORS.size()]
			var pts := PackedVector2Array([c])
			for k in range(21):
				var a := a0 + seg * float(k) / 20.0
				pts.append(c + Vector2(cos(a), sin(a)) * r)
			draw_colored_polygon(pts, base.darkened(0.22))
			var inner := PackedVector2Array([c])
			for k in range(21):
				var a := a0 + seg * float(k) / 20.0
				inner.append(c + Vector2(cos(a), sin(a)) * r * 0.86)
			draw_colored_polygon(inner, base.lightened(0.06))
		# Мягкий блик сверху (луна освещает колесо)
		draw_circle(c, r * 0.86, Color(1.0, 0.97, 0.85, 0.05))
		# Подписи призов с тенью — читаются на любом цвете
		for i in range(n):
			var mid := seg * (float(i) + 0.5)
			var prize: Dictionary = GameData.WHEEL_PRIZES[i]
			var label := Loc.t(str(prize.get("label_key", ""))) if prize.has("label_key") else (Loc.t(str(prize.get("label_key", ""))) if prize.has("label_key") else str(prize.get("label", "")))
			draw_set_transform(c, mid, Vector2.ONE)
			draw_string(f, Vector2(r * 0.24, 6.0), label,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0, 0, 0, 0.55))
			draw_string(f, Vector2(r * 0.24, 4.5), label,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.97, 0.93, 0.84))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		# Золотые спицы вместо чёрных
		for i in range(n):
			var a := seg * float(i)
			var dir := Vector2(cos(a), sin(a))
			draw_line(c + dir * 16.0, c + dir * r, Color(gold.r, gold.g, gold.b, 0.55), 2.0, true)
		# Обод: двойное золотое кольцо + «жемчужины» на стыках секторов
		draw_arc(c, r, 0.0, TAU, 128, gold.darkened(0.35), 9.0, true)
		draw_arc(c, r, 0.0, TAU, 128, gold, 4.0, true)
		draw_arc(c, r * 0.86, 0.0, TAU, 128, Color(gold.r, gold.g, gold.b, 0.5), 1.5, true)
		for i in range(n):
			var a := seg * float(i)
			var p := c + Vector2(cos(a), sin(a)) * r
			draw_circle(p, 4.5, gold)
			draw_circle(p, 2.0, Color("#7d1f2d"))
		# Ступица: золотой медальон с полумесяцем
		draw_circle(c, 22.0, gold.darkened(0.35))
		draw_circle(c, 19.0, gold)
		draw_circle(c, 14.0, Color("#7d1f2d"))
		draw_circle(c, 9.0, gold)
		draw_circle(c + Vector2(3.2, -1.2), 7.6, Color("#7d1f2d"))   # вырез → полумесяц

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
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	center.add_child(col)

	_title = Palette.label("", 26, Palette.PRIMARY, true)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_title)

	# указатель над колесом
	var pointer := Palette.label("\u25BC", 26, Palette.PRIMARY, true)
	pointer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(pointer)

	_wheel = Wheel.new()
	_wheel.custom_minimum_size = Vector2(310, 310)
	col.add_child(_wheel)

	_result = Palette.label(" ", Palette.FS_TITLE, Palette.SECONDARY, true)
	_result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_result)
	# Монетизация: респин и удвоение приза за ролик
	_respin_btn = Button.new()
	_respin_btn.custom_minimum_size = Vector2(280, 46)
	Palette.style_glass_button(_respin_btn, true)
	_respin_btn.visible = false
	_respin_btn.pressed.connect(_on_respin)
	col.add_child(_respin_btn)
	_double_btn = Button.new()
	_double_btn.custom_minimum_size = Vector2(280, 46)
	Palette.style_glass_button(_double_btn, true)
	_double_btn.visible = false
	_double_btn.pressed.connect(_on_double)
	col.add_child(_double_btn)

	_cooldown = Palette.label(" ", Palette.FS_LABEL, Palette.ON_SURFACE_VARIANT)
	_cooldown.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_cooldown)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	col.add_child(row)
	_spin_btn = Button.new()
	_spin_btn.custom_minimum_size = Vector2(190, 50)
	Palette.style_glass_button(_spin_btn, true)
	_spin_btn.pressed.connect(_on_spin)
	row.add_child(_spin_btn)
	_back_btn = Button.new()
	_back_btn.custom_minimum_size = Vector2(120, 50)
	Palette.style_glass_button(_back_btn, false)
	_back_btn.pressed.connect(func(): if not _spinning: back_pressed.emit())
	row.add_child(_back_btn)


func _animate_open() -> void:
	# Плавное открытие: фейд + лёгкий «наезд» (как у древа и дипломатии)
	pivot_offset = size / 2.0
	modulate.a = 0.0
	scale = Vector2(0.94, 0.94)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "modulate:a", 1.0, 0.2)
	tw.tween_property(self, "scale", Vector2.ONE, 0.26) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func open_screen() -> void:
	_title.text = Loc.t("wheel.title")
	_spin_btn.text = Loc.t("wheel.spin")
	_back_btn.text = Loc.t("wheel.back")
	_result.text = " "
	_last_idx = -1
	_wheel.rotation = 0.0
	_refresh_state()
	var was := visible
	visible = true
	if not was:
		_animate_open()

func _refresh_state() -> void:
	var avail := GameState.wheel_available()
	_spin_btn.disabled = not avail or _spinning
	_spin_btn.modulate.a = 1.0 if avail else 0.55
	if avail:
		_cooldown.text = " "
	else:
		_cooldown.text = Loc.t("wheel.next") % _fmt(GameState.wheel_seconds_left())
	_respin_btn.text = "\u25B6 " + Loc.t("wheel.respin")
	_respin_btn.visible = not avail and not _spinning and not GameState.wheel_respin_used
	_double_btn.text = "\u2716\u0032 " + Loc.t("wheel.double")
	var can_double := _last_idx >= 0 and not GameState.wheel_doubled \
		and str(GameData.WHEEL_PRIZES[_last_idx].get("kind", "")) == "hazna"
	_double_btn.visible = not _spinning and can_double

func _process(delta: float) -> void:
	if not visible or _spinning:
		return
	_tick += delta
	if _tick >= 0.5:
		_tick = 0.0
		_refresh_state()

func _on_spin() -> void:
	if _spinning or not GameState.wheel_available():
		return
	_spinning = true
	_spin_btn.disabled = true
	_result.text = " "
	var idx := GameState.pick_wheel_prize()
	var n: int = GameData.WHEEL_PRIZES.size()
	var seg := TAU / float(n)
	# сектор idx должен остановиться под указателем (сверху, угол -PI/2)
	var target := -PI / 2.0 - (float(idx) + 0.5) * seg
	var final := 5.0 * TAU + wrapf(target, 0.0, TAU)
	_wheel.rotation = 0.0
	var tw := create_tween()
	tw.tween_property(_wheel, "rotation", final, 3.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_callback(_finish_spin.bind(idx))

func _finish_spin(idx: int) -> void:
	_last_idx = idx
	GameState.apply_wheel_prize(idx)
	_result.text = "%s %s" % [Loc.t("wheel.won"), str(GameData.WHEEL_PRIZES[idx].get("label", ""))]
	_spinning = false
	_refresh_state()

func _on_respin() -> void:
	if GameState.wheel_respin_used or GameState.wheel_available():
		return
	GameState.request_rewarded("wheel_respin", _grant_respin)

func _grant_respin() -> void:
	GameState.wheel_respin_used = true
	GameState.wheel_next_ts = 0.0
	GameState.save_game()
	_refresh_state()

func _on_double() -> void:
	if _last_idx < 0 or GameState.wheel_doubled:
		return
	GameState.request_rewarded("wheel_double", _grant_double)

func _grant_double() -> void:
	GameState.wheel_doubled = true
	var p: Dictionary = GameData.WHEEL_PRIZES[_last_idx]
	GameState.hazna += float(p.get("amount", 0.0))
	GameState.notify.emit("%s \u00D72!" % str(p.get("label", "")), true)
	GameState.save_game()
	_refresh_state()

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
