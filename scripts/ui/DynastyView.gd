extends Control
## DynastyView — страница «The Sublime State» строго по референсу __7_:
## портрет-ниша (тезхип-рамка 3:4, фото целиком), круговой гейдж престижа
## с восковой печатью, карточка Имперского престижа, Legacy Decrees.

const RingGaugeScript := preload("res://scripts/ui/RingGauge.gd")
const FamilyTreeScript := preload("res://scripts/ui/FamilyTree.gd")

## Узорная золотая рамка поверх бумажной карточки древа:
## двойная линия, ромбы по углам, точки на серединах, завитки внутри.
class PaperFrame extends Control:
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)
	func _draw() -> void:
		if size.x < 30.0 or size.y < 30.0:
			return
		var g := Color(0.831, 0.686, 0.216, 0.95)
		var soft := Color(0.831, 0.686, 0.216, 0.4)
		var o := Rect2(Vector2(2.0, 2.0), size - Vector2(4, 4))
		var inr := Rect2(Vector2(12, 12), size - Vector2(24, 24))
		# Линия лежит на самом краю и сама накрывает кромку бумаги — маска не нужна
		_outline(o, g, 6.0)            # основная золотая обводка (широкая)
		_outline(inr, soft, 1.2)       # тонкая параллельная линия
		# углы: ромб + два малых ромбика вдоль сторон
		var corners := [o.position, o.position + Vector2(o.size.x, 0), o.position + o.size, o.position + Vector2(0, o.size.y)]
		var dirs := [Vector2(1, 1), Vector2(-1, 1), Vector2(-1, -1), Vector2(1, -1)]
		for k in range(4):
			var pc: Vector2 = corners[k]
			var d: Vector2 = dirs[k]
			_dia(pc, 5.5, g)
			_dia(pc + Vector2(d.x * 16.0, 0), 2.6, g)
			_dia(pc + Vector2(0, d.y * 16.0), 2.6, g)
		# ромбики на серединах сторон
		_dia(o.position + Vector2(o.size.x / 2.0, 0), 3.6, g)
		_dia(o.position + Vector2(o.size.x / 2.0, o.size.y), 3.6, g)
		_dia(o.position + Vector2(0, o.size.y / 2.0), 3.6, g)
		_dia(o.position + Vector2(o.size.x, o.size.y / 2.0), 3.6, g)
		# завитки-дуги между линиями в углах
		var rr := 9.0
		draw_arc(inr.position + Vector2(rr, rr), rr, PI, 1.5 * PI, 10, soft, 1.0, true)
		draw_arc(inr.position + Vector2(inr.size.x - rr, rr), rr, 1.5 * PI, TAU, 10, soft, 1.0, true)
		draw_arc(inr.position + Vector2(inr.size.x - rr, inr.size.y - rr), rr, 0.0, 0.5 * PI, 10, soft, 1.0, true)
		draw_arc(inr.position + Vector2(rr, inr.size.y - rr), rr, 0.5 * PI, PI, 10, soft, 1.0, true)
	func _outline(r: Rect2, col: Color, t: float) -> void:
		draw_line(r.position, r.position + Vector2(r.size.x, 0), col, t)
		draw_line(r.position, r.position + Vector2(0, r.size.y), col, t)
		draw_line(r.position + Vector2(r.size.x, 0), r.position + r.size, col, t)
		draw_line(r.position + Vector2(0, r.size.y), r.position + r.size, col, t)
	func _dia(c: Vector2, s: float, col: Color) -> void:
		draw_colored_polygon(PackedVector2Array([
			c + Vector2(0, -s), c + Vector2(s, 0), c + Vector2(0, s), c + Vector2(-s, 0),
		]), col)

var _family_tree
var _family_overlay: Control = null
var _family_card: Control = null
var _ring                       # RingGauge (круговой гейдж)
var _rank_lbl: Label
var _prestige_lbl: Label
var _next_lbl: Label
var _next_bar: ProgressBar
var _gain_lbl: Label
var _name_lbl: Label
var _reign_btn: Button
var _reign_hint: Label
var _seek_popup: Control
var _seek_pay_btn: Button
var _seek_body_lbl: Label
var decree_rows := []

func build() -> void:
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	# Прячем полосу прокрутки (скролл пальцем/перетаскиванием остаётся).
	var vsb := scroll.get_v_scroll_bar()
	if vsb != null:
		vsb.self_modulate = Color(1, 1, 1, 0)
		vsb.custom_minimum_size.x = 0

	var mc := MarginContainer.new()
	mc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for s in ["left", "right"]:
		mc.add_theme_constant_override("margin_" + s, Palette.SAFE_AREA)
	mc.add_theme_constant_override("margin_top", 12)
	mc.add_theme_constant_override("margin_bottom", 24)
	scroll.add_child(mc)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 26)   # gap-8 ≈ 26-32
	mc.add_child(col)

	# Фото, имя и черточка — вместе, с маленьким зазором.
	var pn := VBoxContainer.new()
	pn.add_theme_constant_override("separation", 4)
	pn.add_child(_build_portrait())
	pn.add_child(_build_name())
	pn.add_child(_build_tree_divider())
	col.add_child(pn)
	col.add_child(_build_family_button())
	col.add_child(_build_prestige_card())
	col.add_child(_build_decrees_header())
	for def in GameData.DECREES:
		col.add_child(_build_decree(def))
	col.add_child(_build_reign_card())

	_seek_popup = _build_seek_popup()
	add_child(_seek_popup)

# ── 1. Портрет в тезхип-рамке (192×256, фото целиком, без обрезки) ──
func _build_portrait() -> Control:
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var wrap := Control.new()
	wrap.custom_minimum_size = Vector2(192, 256)
	center.add_child(wrap)

	var frame := PanelContainer.new()
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Palette.SURFACE_LOW
	sb.set_corner_radius_all(8)
	sb.set_border_width_all(2)
	sb.border_color = Palette.PRIMARY
	sb.shadow_color = Color(Palette.PRIMARY.r, Palette.PRIMARY.g, Palette.PRIMARY.b, 0.18)
	sb.shadow_size = 10
	frame.add_theme_stylebox_override("panel", sb)
	frame.clip_contents = true
	wrap.add_child(frame)

	var tex := TextureRect.new()
	tex.texture = _sultan_texture()
	# Фото целиком: соотношение 240×322 ≈ 3:4, помещается без обрезки лица.
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.add_child(tex)

	# Ромбики-тезхип в двух углах
	_diamond(wrap, false)
	_diamond(wrap, true)
	return center

func _diamond(parent: Control, at_br: bool) -> void:
	var d := ColorRect.new()
	d.color = Palette.PRIMARY
	d.custom_minimum_size = Vector2(12, 12)
	if at_br:
		d.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		d.anchor_left = 1.0; d.anchor_top = 1.0; d.anchor_right = 1.0; d.anchor_bottom = 1.0
	else:
		d.anchor_left = 0.0; d.anchor_top = 0.0; d.anchor_right = 0.0; d.anchor_bottom = 0.0
	d.offset_left = -6; d.offset_top = -6; d.offset_right = 6; d.offset_bottom = 6
	d.pivot_offset = Vector2(6, 6)
	d.rotation_degrees = 45
	parent.add_child(d)

# ── Имя правителя красивым шрифтом под портретом ──
func _build_name() -> Control:
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_lbl = Palette.label(GameState.current_sultan(), 24, Palette.PRIMARY, true)
	_name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_lbl.add_theme_constant_override("outline_size", 1)
	_name_lbl.add_theme_color_override("font_outline_color", Palette.CRIMSON_DEEP.darkened(0.2))
	center.add_child(_name_lbl)
	return center

# ── Окошко подтверждения: платный поиск невесты ──
func _build_seek_popup() -> Control:
	var wrap := Control.new()
	wrap.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	wrap.visible = false
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(func(e): if e is InputEventMouseButton and e.pressed: _close_seek_popup())
	wrap.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	wrap.add_child(center)

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(312, 0)
	card.add_theme_stylebox_override("panel", Palette.tezhip(Palette.SURFACE_LOWEST, 12, 20))
	center.add_child(card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	card.add_child(v)

	var title := Palette.label(Loc.t("dyn.seek_title"), Palette.FS_TITLE, Palette.PRIMARY, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	_seek_body_lbl = Palette.label(Loc.t("dyn.seek_body"), Palette.FS_BODY, Palette.ON_SURFACE_VARIANT)
	_seek_body_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_seek_body_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_seek_body_lbl)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	v.add_child(row)
	var cancel := Button.new()
	cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	Palette.style_button(cancel, false)
	cancel.text = Loc.t("dyn.seek_cancel")
	cancel.pressed.connect(_close_seek_popup)
	row.add_child(cancel)
	_seek_pay_btn = Button.new()
	_seek_pay_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	Palette.style_button(_seek_pay_btn, true)
	_seek_pay_btn.pressed.connect(_on_seek_pay)
	row.add_child(_seek_pay_btn)
	return wrap

func _open_seek_popup() -> void:
	if _seek_popup == null:
		return
	# Древо теперь в полноэкранном оверлее — попап должен жить там же, поверх
	if _family_overlay != null and _seek_popup.get_parent() != _family_overlay:
		_seek_popup.get_parent().remove_child(_seek_popup)
		_family_overlay.add_child(_seek_popup)
	if _seek_popup.get_parent() != null:
		_seek_popup.get_parent().move_child(_seek_popup, _seek_popup.get_parent().get_child_count() - 1)
	var afford: bool = GameState.hazna >= GameState.wife_search_cost()
	_seek_pay_btn.text = "%s (%s \u269C)" % [Loc.t("dyn.seek_pay"), Palette.fmt_int(GameState.wife_search_cost())]
	_seek_pay_btn.disabled = not afford
	_seek_pay_btn.modulate.a = 1.0 if afford else 0.5
	_seek_body_lbl.text = Loc.t("dyn.seek_body") if afford else Loc.t("dyn.seek_poor")
	_seek_popup.visible = true

func _close_seek_popup() -> void:
	if _seek_popup != null:
		_seek_popup.visible = false

func _on_seek_pay() -> void:
	if GameState.pay_to_seek_wife():
		_close_seek_popup()
		update_view()

# ── Декоративный «семейный узел» под портретом ──
func _build_tree_divider() -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	var l1 := ColorRect.new()
	l1.color = Palette.OUTLINE_VARIANT
	l1.custom_minimum_size = Vector2(32, 1)
	l1.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(l1)
	row.add_child(Palette.label("\u26AC", 14, Palette.PRIMARY_CONTAINER, true))  # узел
	var l2 := ColorRect.new()
	l2.color = Palette.OUTLINE_VARIANT
	l2.custom_minimum_size = Vector2(32, 1)
	l2.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(l2)
	return row

# ── 2. Круговой гейдж престижа ──
func _build_gauge() -> Control:
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var area := Control.new()
	area.custom_minimum_size = Vector2(212, 212)
	center.add_child(area)

	_ring = RingGaugeScript.new()
	_ring.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	area.add_child(_ring)

	var gc := CenterContainer.new()
	gc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	area.add_child(gc)

	var gv := VBoxContainer.new()
	gv.alignment = BoxContainer.ALIGNMENT_CENTER
	gv.add_theme_constant_override("separation", 4)
	gc.add_child(gv)

	# Восковая печать с гербовым знаком
	var seal_center := CenterContainer.new()
	gv.add_child(seal_center)
	var seal := PanelContainer.new()
	seal.custom_minimum_size = Vector2(64, 64)
	var seal_sb := StyleBoxFlat.new()
	seal_sb.bg_color = Palette.CRIMSON_DEEP
	seal_sb.set_corner_radius_all(999)
	seal_sb.set_border_width_all(2)
	seal_sb.border_color = Palette.TERTIARY
	seal_sb.shadow_color = Color(0, 0, 0, 0.5)
	seal_sb.shadow_size = 4
	seal_sb.shadow_offset = Vector2(1, 2)
	seal.add_theme_stylebox_override("panel", seal_sb)
	var sc := CenterContainer.new()
	sc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	seal.add_child(sc)
	sc.add_child(Palette.label("\u265A", 26, Color.WHITE, true))   # ♚ герб Дома
	seal_center.add_child(seal)

	_rank_lbl = Palette.label("", Palette.FS_TITLE, Palette.PRIMARY, true)
	_rank_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gv.add_child(_rank_lbl)
	return center

# ── 3. Карточка Имперского престижа (тезхип + ромбики) ──
## Кнопка «Семейное древо» в стиле меню — открывает древо поверх экрана.
func _build_family_button() -> Control:
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, 56)
	Palette.style_glass_button(b, true)
	b.text = "\u263D  " + Loc.t("dyn.family")
	b.pressed.connect(_open_family_overlay)
	return b

func _open_family_overlay() -> void:
	if _family_overlay == null:
		_family_overlay = _build_family_overlay()
		# Поверх всего экрана (вне клипа области контента) — кнопки всегда доступны
		get_viewport().add_child(_family_overlay)
	update_view()
	_family_overlay.visible = true
	# Плавное открытие: фейд + лёгкий «наезд» карточки
	_family_overlay.modulate.a = 0.0
	_family_card.scale = Vector2(0.92, 0.92)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_family_overlay, "modulate:a", 1.0, 0.22)
	tw.tween_property(_family_card, "scale", Vector2.ONE, 0.28) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _close_family_overlay() -> void:
	if _family_overlay == null or not _family_overlay.visible:
		return
	var tw := create_tween()
	tw.tween_property(_family_overlay, "modulate:a", 0.0, 0.16)
	tw.tween_callback(func(): _family_overlay.visible = false)

func _build_family_overlay() -> Control:
	var wrap := Control.new()
	wrap.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	wrap.visible = false
	wrap.add_to_group("fullscreen_modal")
	# Блюр фона (мип-размытие экрана) + затемнение; тап по фону закрывает
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
	blur.gui_input.connect(_family_dim_input)
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
	_family_card = _build_family()
	_family_card.resized.connect(func(): _family_card.pivot_offset = _family_card.size / 2.0)
	v.add_child(_family_card)
	var close := Button.new()
	close.custom_minimum_size = Vector2(0, 48)
	Palette.style_glass_button(close, false)
	close.text = Loc.t("wheel.back")
	close.pressed.connect(_close_family_overlay)
	v.add_child(close)
	return wrap

func _family_dim_input(e: InputEvent) -> void:
	# тап по затемнению — закрыть древо
	if e is InputEventMouseButton and e.pressed:
		_close_family_overlay()

func _build_family() -> Control:
	var card := PanelContainer.new()
	var framed := false
	# Фон — старая мятая бумага; подписи в древе — «чернильные» тёмные.
	var paper_tex := _safe_load("res://assets/art/paper_bg.jpg")
	if paper_tex != null:
		var sbt := StyleBoxTexture.new()
		sbt.texture = paper_tex
		sbt.content_margin_left = 16
		sbt.content_margin_right = 16
		sbt.content_margin_top = 16
		sbt.content_margin_bottom = 16
		card.add_theme_stylebox_override("panel", sbt)
		framed = true
	else:
		card.add_theme_stylebox_override("panel",
			Palette.box(Palette.SURFACE_CONTAINER, 14, 1, Palette.OUTLINE_VARIANT, 16))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	card.add_child(v)
	# Заголовок: по центру, крупнее, золотом (обычный шрифт, без курсива)
	var head := Palette.label(Loc.t("dyn.family"), 19, Color(0.95, 0.79, 0.31), true)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_theme_color_override("font_shadow_color", Color(0.14, 0.09, 0.02, 0.6))
	head.add_theme_constant_override("shadow_offset_y", 2)
	v.add_child(head)
	# Древо — в прокрутке, но окно НЕ растянуто впустую: его высота равна
	# содержимому и растёт с каждым новым поколением. Упёршись в край
	# экрана, рост останавливается и включается прокрутка веток.
	var tree_scroll := ScrollContainer.new()
	tree_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(tree_scroll)
	_family_tree = FamilyTreeScript.new()
	_family_tree.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_family_tree.seek_wife_requested.connect(_open_seek_popup)
	tree_scroll.add_child(_family_tree)
	# Окно фиксировано под одно поколение: новые ветки НЕ растягивают его,
	# а уходят вниз — их видно прокруткой.
	var fit := func():
		var cap := maxf(get_viewport_rect().size.y - 240.0, 280.0)
		tree_scroll.custom_minimum_size.y = minf(_family_tree.one_gen_height(), cap)
	_family_tree.minimum_size_changed.connect(fit)
	fit.call()
	if not framed:
		return card
	# Обёртка: рамка-оверлей лежит ПОВЕРХ карточки по её реальному краю
	# (детей PanelContainer он укладывает внутрь отступов — туда рамке нельзя).
	var wrap := MarginContainer.new()
	wrap.add_child(card)
	var fr := PaperFrame.new()
	wrap.add_child(fr)
	return wrap

func _build_prestige_card() -> Control:
	var wrap := MarginContainer.new()
	wrap.add_theme_constant_override("margin_left", 6)
	wrap.add_theme_constant_override("margin_right", 6)

	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", Palette.tezhip(Palette.SURFACE_LOWEST, 12, 20))
	wrap.add_child(card)

	var pv := VBoxContainer.new()
	pv.alignment = BoxContainer.ALIGNMENT_CENTER
	pv.add_theme_constant_override("separation", 6)
	card.add_child(pv)

	var cap := Palette.label_caps(Loc.t("dyn.prestige"), Palette.FS_LABEL, Palette.ON_SURFACE_VARIANT)
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pv.add_child(cap)

	var prow := HBoxContainer.new()
	prow.alignment = BoxContainer.ALIGNMENT_CENTER
	prow.add_theme_constant_override("separation", 8)
	pv.add_child(prow)
	prow.add_child(Palette.label("\u2726", 28, Palette.PRIMARY, true))
	_prestige_lbl = Palette.label("0", Palette.FS_HEADLINE, Palette.PRIMARY, true)
	prow.add_child(_prestige_lbl)

	_next_bar = ProgressBar.new()
	_next_bar.show_percentage = false
	_next_bar.max_value = 100
	_next_bar.custom_minimum_size = Vector2(0, 6)
	_next_bar.add_theme_stylebox_override("background", Palette.box(Palette.SURFACE_CONTAINER, 4, 0))
	_next_bar.add_theme_stylebox_override("fill", Palette.box(Palette.PRIMARY, 4, 0))
	pv.add_child(_next_bar)

	_next_lbl = Palette.label("", Palette.FS_LABEL, Palette.OUTLINE)
	_next_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pv.add_child(_next_lbl)

	return wrap

# ── 4. Legacy Decrees ──
func _build_decrees_header() -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	h.add_child(Palette.label("\u2727", Palette.FS_TITLE, Palette.PRIMARY, true))
	h.add_child(Palette.label(Loc.t("dyn.decrees"), Palette.FS_TITLE, Palette.PRIMARY, true))
	v.add_child(h)
	var line := ColorRect.new()
	line.color = Palette.OUTLINE_VARIANT
	line.custom_minimum_size = Vector2(0, 1)
	v.add_child(line)
	return v

func _build_decree(def: Dictionary) -> PanelContainer:
	var card := PanelContainer.new()
	var owned: bool = GameState.decrees_owned.has(def.id)
	card.add_theme_stylebox_override("panel", _decree_sb(owned))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	card.add_child(row)

	# Круглая иконка
	var icon := PanelContainer.new()
	icon.custom_minimum_size = Vector2(48, 48)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var ic_sb := StyleBoxFlat.new()
	ic_sb.bg_color = Palette.PRIMARY_CONTAINER if owned else Palette.SURFACE_LOWEST
	ic_sb.set_corner_radius_all(999)
	icon.add_theme_stylebox_override("panel", ic_sb)
	var icc := CenterContainer.new()
	icc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon.add_child(icc)
	icc.add_child(Palette.label(def.icon, 20, Palette.ON_PRIMARY if owned else Palette.ON_SURFACE_VARIANT))
	row.add_child(icon)

	# Текст
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	info.add_theme_constant_override("separation", 2)
	row.add_child(info)
	info.add_child(Palette.label(GameData.loc(def, "name"), Palette.FS_BODY_LG, Palette.ON_SURFACE, true))
	var desc_col: Color = Palette.SECONDARY if def.kind == "income" else Palette.ON_SURFACE_VARIANT
	var desc := Palette.label_caps(GameData.loc(def, "desc"), Palette.FS_LABEL, desc_col)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(desc)

	# Справа: цена + Buy, либо UPGRADED + галочка
	var right := VBoxContainer.new()
	right.alignment = BoxContainer.ALIGNMENT_CENTER
	right.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	right.add_theme_constant_override("separation", 4)
	row.add_child(right)

	var cost_lbl := Palette.label("", Palette.FS_LABEL, Palette.PRIMARY)
	cost_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.add_child(cost_lbl)
	var btn := Button.new()
	Palette.style_button(btn, true)
	btn.add_theme_font_size_override("font_size", Palette.FS_LABEL)
	btn.pressed.connect(func(): GameState.buy_decree(def))
	right.add_child(btn)

	decree_rows.append({"def": def, "btn": btn, "cost": cost_lbl, "card": card})
	return card

func _decree_sb(owned: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Palette.SURFACE_HIGH
	sb.set_corner_radius_all(8)
	sb.border_width_left = 4
	sb.border_color = Palette.PRIMARY if owned else Palette.OUTLINE_VARIANT
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 14
	sb.content_margin_bottom = 14
	return sb

# ── 5. Передача Печати наследнику ──
func _build_reign_card() -> Control:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", Palette.box(Palette.SURFACE_CONTAINER, 10, 1, Palette.PRIMARY.darkened(0.2), 16))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	card.add_child(v)
	_reign_hint = Palette.label(Loc.t("dyn.new_reign_hint"), Palette.FS_BODY, Palette.ON_SURFACE_VARIANT)
	_reign_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_reign_hint)
	_gain_lbl = Palette.label("", Palette.FS_BODY, Palette.SECONDARY)
	v.add_child(_gain_lbl)
	_reign_btn = Button.new()
	_reign_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	Palette.style_button(_reign_btn, true)
	_reign_btn.text = "\u2726 " + Loc.t("dyn.new_reign")
	_reign_btn.pressed.connect(_on_new_reign)
	v.add_child(_reign_btn)
	return card

func _on_new_reign() -> void:
	GameState.begin_new_reign()

func update_view() -> void:
	if _name_lbl != null:
		_name_lbl.text = GameState.current_sultan()
	if _family_tree != null:
		_family_tree.set_data(GameState.current_sultan(), GameState.wives, GameState.children, _sultan_tree_texture(), GameState.year, GameState.ancestors)
	var info := GameData.dynasty_rank(GameState.imperial_prestige)
	var cur: Dictionary = info.current
	var nxt = info.next
	if _rank_lbl != null:
		_rank_lbl.text = (cur.en if Loc.lang == "en" else cur.ru)
	_prestige_lbl.text = Palette.fmt_int(GameState.imperial_prestige)

	if nxt != null:
		var span: float = float(nxt.min - cur.min)
		var into: float = float(GameState.imperial_prestige - cur.min)
		var frac: float = clampf(into / maxf(span, 1.0), 0.0, 1.0)
		if _ring != null:
			_ring.progress = frac
		_next_bar.value = frac * 100.0
		_next_bar.visible = true
		_next_lbl.text = "%s: %s (%s)" % [Loc.t("dyn.next_rank"),
			(nxt.en if Loc.lang == "en" else nxt.ru), Palette.fmt_int(nxt.min)]
	else:
		if _ring != null:
			_ring.progress = 1.0
		_next_bar.visible = false
		_next_lbl.text = "\u2014"

	_gain_lbl.text = "+%s %s" % [Palette.fmt_int(GameState.prestige_gain_preview()), Loc.t("dyn.gain")]

	# Передача трона сыну: доступна только при живом взрослом наследнике.
	if _reign_btn != null:
		var has_adult: bool = GameState.has_adult_heir()
		var has_son: bool = not GameState.heir().is_empty()
		_reign_btn.disabled = not has_adult
		if not has_son:
			_reign_hint.text = Loc.t("dyn.need_heir")
		elif not has_adult:
			_reign_hint.text = Loc.t("dyn.heir_growing")
		elif GameState.stability < 40.0 or GameState.opposition > 60.0:
			# Кризис — призыв передать Печать, пока сын не взял трон силой.
			_reign_hint.text = Loc.t("dyn.crisis_pass")
		else:
			_reign_hint.text = Loc.t("dyn.new_reign_hint")

	for r in decree_rows:
		var def: Dictionary = r.def
		var owned: bool = GameState.decrees_owned.has(def.id)
		if owned:
			r.cost.text = Loc.t("dyn.bought")
			r.btn.text = "\u2713"
			r.btn.disabled = true
		else:
			r.cost.text = "%s \u269C" % Palette.fmt_int(def.cost)
			r.btn.text = Loc.t("dyn.buy")
			r.btn.disabled = GameState.imperial_prestige < def.cost

func _sultan_texture() -> Texture2D:
	# Портрет текущего правителя: gen 0 — стартовый султан; далее — взрослое фото сына,
	# который взошёл на трон (res://assets/art/dynasty/heir_<gen>_adult.webp).
	if GameState.sultan_pidx >= 1:
		var t := _safe_load("res://assets/art/dynasty/heir_%d_adult.png" % GameState.sultan_pidx)
		if t != null:
			return t
	return _safe_load("res://assets/art/sultan.png")

func _sultan_tree_texture() -> Texture2D:
	# Портрет правителя для карточки в древе (без вшитой подписи).
	if GameState.sultan_pidx >= 1:
		var t := _safe_load("res://assets/art/dynasty/heir_%d_adult.png" % GameState.sultan_pidx)
		if t != null:
			return t
	var pp := _safe_load("res://assets/art/sultan_portrait.png")
	return pp if pp != null else _safe_load("res://assets/art/sultan.png")

func _safe_load(path: String) -> Texture2D:
	# Сперва пробуем оригинальный путь, затем — .webp-вариант (мы пожали
	# крупные PNG/JPG в webp ради размера APK).
	if ResourceLoader.exists(path):
		return load(path)
	var alt := path.get_basename() + ".webp"
	if ResourceLoader.exists(alt):
		return load(alt)
	return null
