extends Control
## StatCard — карточка статистики с рамкой, нарисованной кодом (всегда целая).
## shape: "arch" (михраб) или "round" (скруглённый прямоугольник).
## Внутри — лёгкое затемнение по форме (не квадрат) + иконка и значение.

var shape: String = "arch"
var fill: Color = Color(0.055, 0.065, 0.095, 0.55)
var border: Color = Palette.PRIMARY
var highlighted: bool = false            # true — золотое свечение вокруг (центральная арка)
var _val: Label
var _ico: Label
var _cap: Label = null

func setup(icon: String, shp: String, value_color: Color, h: float) -> void:
	shape = shp
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	custom_minimum_size = Vector2(0, h)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 2)
	if shape == "arch":
		# Внутри арки контент опущен от острия РАВНОМЕРНО сверху и снизу,
		# иначе VBoxContainer.ALIGNMENT_CENTER сдвигает всё «на глаз» —
		# и цифра «плывёт» относительно иконки и подписи.
		var top_pad := int(h * 0.22)
		box.offset_top = top_pad
		box.offset_bottom = -int(h * 0.06)
	else:
		# Скруглённые плитки: значение сидит близко под иконкой, но не впритык
		# (иначе смайлики и цифра сливаются). Небольшой отрицательный
		# separation стягивает их без наложения.
		box.add_theme_constant_override("separation", 0)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	var isz := int(clamp(h * 0.24, 22.0, 36.0))
	_ico = Palette.label(icon, isz, Palette.ON_SURFACE_VARIANT)
	_ico.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ico.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(_ico)
	var vsz: int = Palette.FS_BODY
	if highlighted:
		vsz = Palette.FS_HEADLINE   # у выделенной центральной арки цифра крупнее
	_val = Palette.label("0", vsz, value_color, true)
	_val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_val.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(_val)
	# Подпись под значением («Стабильность/Хазна/Армия…»)
	_cap = Palette.label_caps("", Palette.FS_LABEL, Palette.ON_SURFACE_VARIANT)
	_cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(_cap)
	resized.connect(queue_redraw)

func set_caption(text: String) -> void:
	if _cap != null:
		_cap.text = text

func set_highlighted(on: bool) -> void:
	highlighted = on
	queue_redraw()

func value_label() -> Label:
	return _val

func _draw() -> void:
	var w := size.x
	var h := size.y
	if w <= 2.0 or h <= 2.0:
		return
	if shape == "round":
		var sb := StyleBoxFlat.new()
		sb.bg_color = fill
		var r := int(min(16.0, h * 0.30))
		sb.set_corner_radius_all(r)
		sb.border_color = border
		sb.set_border_width_all(2)
		draw_style_box(sb, Rect2(Vector2.ZERO, size))
		return
	# ── Михраб (стрельчатая арка) ──
	var sh := h * 0.40                     # плечо арки
	var lcy := sh * 0.12
	var pts := PackedVector2Array()
	pts.append(Vector2(0.0, h))
	pts.append(Vector2(0.0, sh))
	var lcx := w * 0.10
	for i in range(16):
		var t := float(i) / 15.0
		var bx := 2.0 * (1.0 - t) * t * lcx + t * t * (w / 2.0)
		var by := pow(1.0 - t, 2.0) * sh + 2.0 * (1.0 - t) * t * lcy
		pts.append(Vector2(bx, by))
	var rcx := w - w * 0.10
	for i in range(16):
		var t := float(i) / 15.0
		var bx := pow(1.0 - t, 2.0) * (w / 2.0) + 2.0 * (1.0 - t) * t * rcx + t * t * w
		var by := 2.0 * (1.0 - t) * t * lcy + t * t * sh
		pts.append(Vector2(bx, by))
	pts.append(Vector2(w, sh))
	pts.append(Vector2(w, h))
	draw_colored_polygon(pts, fill)
	var outline := pts
	outline.append(pts[0])
	draw_polyline(outline, border, 3.0 if highlighted else 2.0, true)
