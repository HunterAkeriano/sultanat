extends Control
## InstitutionsView — фракции как развиваемые институты (§21.4.3, §21.0).

var rows := []
var _reform_bar: ProgressBar
var _reform_pct: Label
var _accel_btn: Button

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

	col.add_child(Palette.label(Loc.t("inst.title"), Palette.FS_HEADLINE, Palette.PRIMARY, true))
	var epi := Palette.label(Loc.t("inst.epigraph"), Palette.FS_BODY, Palette.ON_SURFACE_VARIANT)
	epi.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(epi)

	for def in GameData.INSTITUTIONS:
		col.add_child(_build_card(def))

	col.add_child(_build_reform_card())

func _build_card(def: Dictionary) -> PanelContainer:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", Palette.tezhip(Palette.SURFACE_CONTAINER, 10, 14))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	card.add_child(v)

	# Шапка: иконка-печать + имя/ранг + (HIGH RISK)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	v.add_child(top)
	var seal := PanelContainer.new()
	seal.add_theme_stylebox_override("panel", Palette.box(Palette.CRIMSON_DEEP if not def.wax_gold else Palette.PRIMARY_CONTAINER, 8, 0, Color.TRANSPARENT, 8))
	var ico := Palette.label(def.icon, 18, Palette.ON_SURFACE if not def.wax_gold else Palette.ON_PRIMARY)
	seal.add_child(ico)
	top.add_child(seal)

	var nb := VBoxContainer.new()
	nb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nb.add_theme_constant_override("separation", 0)
	top.add_child(nb)
	var name_lbl := Palette.label(GameData.loc(def, "name"), Palette.FS_BODY_LG, Palette.ON_SURFACE, true)
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nb.add_child(name_lbl)
	var rank_lbl := Palette.label("", Palette.FS_BODY, Palette.ON_SURFACE_VARIANT)
	rank_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nb.add_child(rank_lbl)

	if def.high_risk:
		var badge := PanelContainer.new()
		badge.add_theme_stylebox_override("panel", Palette.box(Palette.ERROR_CONTAINER, 4, 0, Color.TRANSPARENT, 6))
		badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var bl := Palette.label_caps(Loc.t("inst.high_risk"), Palette.FS_LABEL, Color.WHITE)
		badge.add_child(bl)
		top.add_child(badge)

	# Эффект
	var eff := Palette.label("", Palette.FS_BODY, Palette.SECONDARY)
	eff.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(eff)

	# Кнопка апгрейда (золотая, цена в Hazna)
	var up := Button.new()
	up.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	Palette.style_button(up, true)
	up.pressed.connect(func(): GameState.upgrade_institution(def))
	v.add_child(up)

	rows.append({"def": def, "rank": rank_lbl, "eff": eff, "up": up})
	return card

func _build_reform_card() -> PanelContainer:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", Palette.box(Palette.SURFACE_HIGH, 10, 1, Palette.OUTLINE_VARIANT, 16))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	card.add_child(v)
	v.add_child(Palette.label("Nizam-i Cedid", Palette.FS_TITLE, Palette.PRIMARY, true))
	var reform_desc := Palette.label(
		"Western-style military reform progress" if Loc.lang == "en" else "Прогресс военной реформы по западному образцу",
		Palette.FS_BODY, Palette.ON_SURFACE_VARIANT)
	reform_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(reform_desc)
	_reform_bar = ProgressBar.new()
	_reform_bar.show_percentage = false
	_reform_bar.max_value = 100
	_reform_bar.custom_minimum_size = Vector2(0, 10)
	_reform_bar.add_theme_stylebox_override("background", Palette.box(Palette.SURFACE_LOWEST, 6, 0))
	_reform_bar.add_theme_stylebox_override("fill", Palette.box(Palette.PRIMARY, 6, 0))
	v.add_child(_reform_bar)
	var row := HBoxContainer.new()
	v.add_child(row)
	_reform_pct = Palette.label("42% " + Loc.t("inst.progress"), Palette.FS_BODY, Palette.SECONDARY)
	_reform_pct.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_reform_pct)
	_accel_btn = Button.new()
	Palette.style_button(_accel_btn, true)
	_accel_btn.pressed.connect(func(): GameState.accelerate_reform())
	row.add_child(_accel_btn)
	return card

func update_view() -> void:
	for r in rows:
		var def: Dictionary = r.def
		var lvl: int = GameState.institutions.get(def.id, 0)
		r.rank.text = "%s %d · %s: %s" % [Loc.t("inst.level"), lvl, Loc.t("inst.rank"), GameData.loc(def, "rank")]
		r.eff.text = GameData.loc(def, "effect") % int(def.per_level * lvl)
		r.eff.add_theme_color_override("font_color", Palette.SECONDARY)
		var cost := GameState.institution_cost(def)
		r.up.text = "%s · %s \u269C" % [Loc.t("inst.upgrade"), Palette.fmt(cost)]
		r.up.disabled = not GameState.can_upgrade(def)

	_reform_bar.value = GameState.reform_progress
	if GameState.reform_done:
		_reform_pct.text = Loc.t("inst.reform_done") + " \u2713"
		_accel_btn.disabled = true
		_accel_btn.text = "\u2713"
	else:
		_reform_pct.text = "%d%% %s" % [int(GameState.reform_progress), Loc.t("inst.progress")]
		_accel_btn.text = Loc.t("inst.accelerate") + " · 600"
		_accel_btn.disabled = GameState.hazna < 600.0
