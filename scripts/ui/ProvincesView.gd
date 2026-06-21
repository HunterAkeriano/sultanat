extends Control
## ProvincesView — карта-свиток + управление эялетами (§21.4.2). Invest/Suppress (§11.4).

var _revenue_lbl: Label
var _trend_lbl: Label
var _food_bar: ProgressBar
var _food_lbl: Label
var _buy_food_btn: Button
var _granary_btn: Button
var cards := []   # массив словарей с ref на узлы каждой провинции

func build() -> void:
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)

	var mc := MarginContainer.new()
	mc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for s in ["left", "right", "top", "bottom"]:
		mc.add_theme_constant_override("margin_" + s, Palette.SAFE_AREA)
	scroll.add_child(mc)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	mc.add_child(col)

	# ── Баннер дохода ──
	var rev := VBoxContainer.new()
	rev.add_theme_constant_override("separation", 2)
	col.add_child(rev)
	rev.add_child(Palette.label_caps(Loc.t("prov.revenue"), Palette.FS_LABEL, Palette.ON_SURFACE_VARIANT))
	var rrow := HBoxContainer.new()
	rrow.add_theme_constant_override("separation", 8)
	rev.add_child(rrow)
	_revenue_lbl = Palette.label("+0", Palette.FS_HEADLINE, Palette.PRIMARY, true)
	rrow.add_child(_revenue_lbl)
	rrow.add_child(Palette.label_caps(Loc.t("prov.per_tap"), Palette.FS_LABEL, Color(0.45, 0.40, 0.30)))
	_trend_lbl = Palette.label("\u2197 " + Loc.t("prov.rising"), Palette.FS_BODY, Palette.SECONDARY)
	_trend_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rrow.add_child(_trend_lbl)

	# ── Снабжение: купить еду + улучшить амбары ──
	col.add_child(_build_provisions())

	# ── Карта-свиток (показываем целиком, без обрезки) ──
	var map := TextureRect.new()
	map.texture = _safe_load("res://assets/art/map_scroll.png")
	Palette.lock_texture_aspect(map, 1334.0 / 714.0)
	var map_panel := PanelContainer.new()
	map_panel.add_theme_stylebox_override("panel", Palette.box(Palette.SURFACE_LOWEST, 8, 2, Palette.OUTLINE_VARIANT, 4))
	map_panel.add_child(map)
	col.add_child(map_panel)

	# ── Заголовок списка ──
	col.add_child(Palette.label(Loc.t("prov.governed"), Palette.FS_TITLE, Palette.ON_SURFACE, true))

	# ── Карточки провинций ──
	for p in GameState.provinces:
		col.add_child(_build_card(p))

func _build_provisions() -> PanelContainer:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", Palette.box(Palette.SURFACE_CONTAINER, 10, 1, Palette.OUTLINE_VARIANT, 14))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	card.add_child(v)

	var head := HBoxContainer.new()
	v.add_child(head)
	var t := Palette.label_caps("\u2698 " + Loc.t("prov.provisions"), Palette.FS_LABEL, Palette.PRIMARY)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	_food_lbl = Palette.label_caps("0%", Palette.FS_LABEL, Palette.SECONDARY)
	head.add_child(_food_lbl)

	_food_bar = ProgressBar.new()
	_food_bar.show_percentage = false
	_food_bar.max_value = 100
	_food_bar.custom_minimum_size = Vector2(0, 8)
	_food_bar.add_theme_stylebox_override("background", Palette.box(Palette.SURFACE_LOWEST, 4, 0))
	_food_bar.add_theme_stylebox_override("fill", Palette.box(Palette.SECONDARY, 4, 0))
	v.add_child(_food_bar)

	var btns := HBoxContainer.new()
	btns.add_theme_constant_override("separation", 8)
	v.add_child(btns)
	_buy_food_btn = Button.new()
	_buy_food_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	Palette.style_button(_buy_food_btn, true)
	_buy_food_btn.clip_text = true
	_buy_food_btn.pressed.connect(func(): GameState.buy_food())
	btns.add_child(_buy_food_btn)
	_granary_btn = Button.new()
	_granary_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	Palette.style_button(_granary_btn, false)
	_granary_btn.clip_text = true
	_granary_btn.pressed.connect(func(): GameState.upgrade_food_tool())
	btns.add_child(_granary_btn)
	return card

func _build_card(p: Dictionary) -> PanelContainer:
	var card := PanelContainer.new()
	var sb := Palette.box(Palette.PARCHMENT, 10, 2, Palette.PRIMARY, 14)
	card.add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	card.add_child(v)

	# Заголовок: имя + подзаголовок | +доход
	var top := HBoxContainer.new()
	v.add_child(top)
	var titles := VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.add_theme_constant_override("separation", 0)
	top.add_child(titles)
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 6)
	titles.add_child(name_row)
	var warn := Palette.label("\u26A0", Palette.FS_BODY, Palette.CRIMSON_DEEP)  # ⚠
	name_row.add_child(warn)
	var name_lbl := Palette.label(GameData.loc(p, "name"), Palette.FS_BODY_LG, Palette.ON_PARCHMENT, true)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_row.add_child(name_lbl)
	var sub := Palette.label(GameData.loc(p, "sub"), Palette.FS_BODY, Color(0.36, 0.30, 0.18))
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	titles.add_child(sub)

	var inc_box := VBoxContainer.new()
	inc_box.alignment = BoxContainer.ALIGNMENT_END
	var inc_lbl := Palette.label("+0", Palette.FS_BODY_LG, Color(0.0, 0.45, 0.25), true)
	inc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	inc_box.add_child(inc_lbl)
	var inc_unit := Palette.label_caps(Loc.t("prov.per_tap"), Palette.FS_LABEL, Color(0.45, 0.40, 0.30))
	inc_box.add_child(inc_unit)
	top.add_child(inc_box)

	# Статы: Souls | Лояльность + Трещина
	var stats := HBoxContainer.new()
	stats.add_theme_constant_override("separation", 8)
	v.add_child(stats)

	var souls := PanelContainer.new()
	souls.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	souls.add_theme_stylebox_override("panel", Palette.box(Color(0.85, 0.80, 0.66), 6, 0, Color.TRANSPARENT, 8))
	var sv := VBoxContainer.new()
	sv.add_theme_constant_override("separation", 0)
	souls.add_child(sv)
	sv.add_child(Palette.label("%s %s" % [p.souls, Loc.t("prov.souls")], Palette.FS_BODY, Palette.ON_PARCHMENT))
	stats.add_child(souls)

	var bars := PanelContainer.new()
	bars.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bars.add_theme_stylebox_override("panel", Palette.box(Color(0.85, 0.80, 0.66), 6, 0, Color.TRANSPARENT, 8))
	var bv := VBoxContainer.new()
	bv.add_theme_constant_override("separation", 4)
	bars.add_child(bv)
	var loy_bar := ProgressBar.new()
	loy_bar.show_percentage = false
	loy_bar.max_value = 100
	loy_bar.custom_minimum_size = Vector2(0, 8)
	loy_bar.add_theme_stylebox_override("background", Palette.box(Color(0.7, 0.66, 0.55), 4, 0))
	loy_bar.add_theme_stylebox_override("fill", Palette.box(Palette.SECONDARY_CONTAINER, 4, 0))
	bv.add_child(loy_bar)
	var fr_lbl := Palette.label_caps("%s 0%%" % Loc.t("prov.fracture"), Palette.FS_LABEL, Palette.CRIMSON_DEEP)
	bv.add_child(fr_lbl)
	stats.add_child(bars)

	# Кнопки Invest / Suppress
	var btns := HBoxContainer.new()
	btns.add_theme_constant_override("separation", 8)
	v.add_child(btns)
	var invest := Button.new()
	invest.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	Palette.style_button(invest, true)
	invest.pressed.connect(func(): GameState.invest(p))
	btns.add_child(invest)
	var suppress := Button.new()
	suppress.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	Palette.style_button(suppress, false)
	suppress.pressed.connect(func(): GameState.suppress(p))
	btns.add_child(suppress)

	cards.append({
		"p": p, "card": card, "warn": warn, "inc": inc_lbl,
		"loy": loy_bar, "fr": fr_lbl, "invest": invest, "suppress": suppress,
	})
	return card

func update_view() -> void:
	var tap_total := GameState.provinces_yield() * GameState.click_mult()
	_revenue_lbl.text = "+%s" % Palette.fmt(tap_total)
	var rising := GameState.stability >= 50.0 and not _any_lost()
	_trend_lbl.text = ("\u2197 " + Loc.t("prov.rising")) if rising else ("\u2198 " + Loc.t("prov.declining"))
	_trend_lbl.add_theme_color_override("font_color", Palette.SECONDARY if rising else Palette.TERTIARY)

	# Снабжение
	_food_bar.value = GameState.food
	var fc := Palette.SECONDARY
	if GameState.food < 25.0:
		fc = Palette.TERTIARY
	elif GameState.food < 45.0:
		fc = Palette.PRIMARY
	_food_bar.add_theme_stylebox_override("fill", Palette.box(fc, 4, 0))
	_food_lbl.text = "%d%%" % int(round(GameState.food))
	_food_lbl.add_theme_color_override("font_color", fc)
	_buy_food_btn.text = "%s +%d \u00B7 %s \u269C" % [Loc.t("prov.buy_food"),
		int(GameState.FOOD_BUY_AMOUNT), Palette.fmt(GameState.food_buy_cost())]
	_buy_food_btn.disabled = not GameState.can_buy_food()
	_granary_btn.text = "%s %d \u00B7 %s \u269C" % [Loc.t("prov.upgrade_granaries"),
		GameState.food_tool_level + 1, Palette.fmt(GameState.food_tool_cost())]
	_granary_btn.disabled = not GameState.can_upgrade_food_tool()

	for c in cards:
		var p: Dictionary = c.p
		c.warn.visible = (not p.lost) and p.fracture >= 50.0
		c.loy.value = p.loyalty
		var fill := Palette.box(Palette.SECONDARY_CONTAINER if p.loyalty >= 40 else Palette.CRIMSON_DEEP, 4, 0)
		c.loy.add_theme_stylebox_override("fill", fill)
		c.fr.text = "%s %d%%" % [Loc.t("prov.fracture"), int(p.fracture)]
		# доход провинции
		if p.lost:
			c.inc.text = Loc.t("prov.lost")
			c.inc.add_theme_color_override("font_color", Palette.CRIMSON_DEEP)
			c.card.modulate = Color(1, 1, 1, 0.45)
			c.invest.disabled = true
			c.suppress.disabled = true
			c.invest.text = "—"
			c.suppress.text = "—"
		else:
			var inc: float = GameState.province_yield(p) * GameState.click_mult()
			c.inc.text = "+%s" % Palette.fmt(inc)
			c.invest.disabled = not GameState.can_invest(p)
			c.suppress.disabled = not GameState.can_suppress(p)
			c.invest.text = "\u2191 %s · %s" % [Loc.t("prov.invest"), Palette.fmt(GameState.invest_cost(p))]
			c.suppress.text = "\u2299 %s · %s" % [Loc.t("prov.suppress"), Palette.fmt(GameState.suppress_cost(p))]

func _any_lost() -> bool:
	for p in GameState.provinces:
		if p.lost:
			return true
	return false

func _safe_load(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path)
	return null
