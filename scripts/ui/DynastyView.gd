extends Control
## DynastyView — страница «The Sublime State» строго по референсу __7_:
## портрет-ниша (тезхип-рамка 3:4, фото целиком), круговой гейдж престижа
## с восковой печатью, карточка Имперского престижа, Legacy Decrees.

const RingGaugeScript := preload("res://scripts/ui/RingGauge.gd")

var _ring                       # RingGauge (круговой гейдж)
var _level_lbl: Label
var _rank_lbl: Label
var _prestige_lbl: Label
var _next_lbl: Label
var _next_bar: ProgressBar
var _gain_lbl: Label
var decree_rows := []

func build() -> void:
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)

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

	col.add_child(_build_portrait())
	col.add_child(_build_tree_divider())
	col.add_child(_build_gauge())
	col.add_child(_build_prestige_card())
	col.add_child(_build_decrees_header())
	for def in GameData.DECREES:
		col.add_child(_build_decree(def))
	col.add_child(_build_reign_card())

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

	_level_lbl = Palette.label_caps("Level 1", Palette.FS_LABEL, Palette.ON_SURFACE_VARIANT)
	_level_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gv.add_child(_level_lbl)
	_rank_lbl = Palette.label("", Palette.FS_TITLE, Palette.PRIMARY, true)
	_rank_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gv.add_child(_rank_lbl)
	return center

# ── 3. Карточка Имперского престижа (тезхип + ромбики) ──
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
	prow.add_child(Palette.label("\u262A", 28, Palette.PRIMARY, true))
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
	var hint := Palette.label(Loc.t("dyn.new_reign_hint"), Palette.FS_BODY, Palette.ON_SURFACE_VARIANT)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(hint)
	_gain_lbl = Palette.label("", Palette.FS_BODY, Palette.SECONDARY)
	v.add_child(_gain_lbl)
	var btn := Button.new()
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	Palette.style_button(btn, true)
	btn.text = "\u262A " + Loc.t("dyn.new_reign")
	btn.pressed.connect(_on_new_reign)
	v.add_child(btn)
	return card

func _on_new_reign() -> void:
	GameState.begin_new_reign()

func update_view() -> void:
	var info := GameData.dynasty_rank(GameState.imperial_prestige)
	var cur: Dictionary = info.current
	var nxt = info.next
	_level_lbl.text = "%s %d" % [Loc.t("inst.level"), cur.lvl]
	_rank_lbl.text = (cur.en if Loc.lang == "en" else cur.ru)
	_prestige_lbl.text = Palette.fmt_int(GameState.imperial_prestige)

	if nxt != null:
		var span: float = float(nxt.min - cur.min)
		var into: float = float(GameState.imperial_prestige - cur.min)
		var frac: float = clampf(into / maxf(span, 1.0), 0.0, 1.0)
		_ring.progress = frac
		_next_bar.value = frac * 100.0
		_next_bar.visible = true
		_next_lbl.text = "%s: %s (%s)" % [Loc.t("dyn.next_rank"),
			(nxt.en if Loc.lang == "en" else nxt.ru), Palette.fmt_int(nxt.min)]
	else:
		_ring.progress = 1.0
		_next_bar.visible = false
		_next_lbl.text = "\u2014"

	_gain_lbl.text = "+%s %s" % [Palette.fmt_int(GameState.prestige_gain_preview()), Loc.t("dyn.gain")]

	for r in decree_rows:
		var def: Dictionary = r.def
		var owned: bool = GameState.decrees_owned.has(def.id)
		if owned:
			r.cost.text = Loc.t("dyn.bought")
			r.btn.text = "\u2713"
			r.btn.disabled = true
		else:
			r.cost.text = "%s \u262A" % Palette.fmt_int(def.cost)
			r.btn.text = Loc.t("dyn.buy")
			r.btn.disabled = GameState.imperial_prestige < def.cost

func _sultan_texture() -> Texture2D:
	# Полный портрет в оригинальном цвете (не меняется при смене правления).
	return _safe_load("res://assets/art/sultan.png")

func _safe_load(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path)
	return null
