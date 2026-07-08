extends Control
## EventsView — Летопись: хроника решений партии (§21.4.6).
## Лента парчовых карточек по годам на вертикальной «шёлковой нити»
## с узловыми бейджами. Эффекты решений — цветными плашками.

var _list: VBoxContainer
var _empty_lbl: Label
var _last_count: int = -1

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
	col.add_theme_constant_override("separation", 12)
	mc.add_child(col)

	# Заголовок «Летопись / The Imperial Record» + эпиграф
	var title := Palette.label(Loc.t("ev.subtitle"), Palette.FS_HEADLINE, Palette.PRIMARY, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	var epi := Palette.label(Loc.t("ev.epigraph"), Palette.FS_BODY, Palette.ON_SURFACE_VARIANT)
	epi.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	epi.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(epi)

	var sep := ColorRect.new()
	sep.color = Palette.OUTLINE_VARIANT
	sep.custom_minimum_size = Vector2(0, 1)
	col.add_child(sep)

	_empty_lbl = Palette.label(Loc.t("ev.empty"), Palette.FS_BODY, Palette.OUTLINE)
	_empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_empty_lbl)

	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 14)
	col.add_child(_list)

	_rebuild_list()

func _rebuild_list() -> void:
	for c in _list.get_children():
		c.queue_free()
	var entries: Array = GameState.chronicle
	_empty_lbl.visible = entries.is_empty()
	for i in range(entries.size()):
		_list.add_child(_build_entry(entries[i], i == entries.size() - 1))
	_last_count = entries.size()

func _build_entry(entry: Dictionary, _is_last: bool) -> Control:
	# Горизонталь: [шёлковая нить + узел] [парчовая карточка]
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)

	# Левая колонка — нить с узлом-бейджем (контейнерная раскладка)
	var thread := VBoxContainer.new()
	thread.custom_minimum_size = Vector2(26, 0)
	thread.size_flags_vertical = Control.SIZE_FILL
	thread.add_theme_constant_override("separation", 0)
	row.add_child(thread)

	# Узловой бейдж: «!» (важное) или книга.
	# Плашки собираются здесь, в момент отрисовки, на ТЕКУЩЕМ языке.
	var chips: Array = _entry_chips(entry)
	var alarming := false
	for ch in chips:
		if ch.size() >= 2 and not ch[1]:
			alarming = true
	var badge := PanelContainer.new()
	badge.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var badge_sb := Palette.box(Palette.ERROR_CONTAINER if alarming else Palette.PRIMARY_CONTAINER, 999, 0, Color.TRANSPARENT, 5)
	badge.add_theme_stylebox_override("panel", badge_sb)
	var bico := Palette.label("!" if alarming else "\u2666", 12, Palette.PARCHMENT if alarming else Palette.ON_PARCHMENT)
	badge.add_child(bico)
	thread.add_child(badge)

	# Нить вниз от узла
	var line := ColorRect.new()
	line.color = Palette.OUTLINE_VARIANT
	line.custom_minimum_size = Vector2(2, 0)
	line.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	line.size_flags_vertical = Control.SIZE_EXPAND_FILL
	thread.add_child(line)

	# Парчовая карточка решения
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var card_sb := Palette.box(Palette.PARCHMENT, 8, 2, Palette.PRIMARY.darkened(0.1), 14)
	card_sb.shadow_color = Color(0, 0, 0, 0.3)
	card_sb.shadow_size = 4
	card_sb.shadow_offset = Vector2(0, 2)
	card.add_theme_stylebox_override("panel", card_sb)
	row.add_child(card)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	card.add_child(v)

	# Шапка: заголовок (кримсон) + капсула года
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	v.add_child(head)
	var t := Palette.label(_entry_title(entry), Palette.FS_BODY_LG, Palette.CRIMSON_DEEP, true)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	head.add_child(t)
	var year_cap := PanelContainer.new()
	year_cap.add_theme_stylebox_override("panel", Palette.box(Palette.PARCHMENT_DIM, 6, 1, Palette.OUTLINE, 6))
	year_cap.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var yl := Palette.label_caps(str(int(entry.get("year", 0))), Palette.FS_LABEL, Palette.ON_PARCHMENT)
	year_cap.add_child(yl)
	head.add_child(year_cap)

	# Текст-резюме (если есть)
	var summary := _entry_summary(entry)
	if summary != "":
		var body := Palette.label(summary, Palette.FS_BODY, Palette.ON_PARCHMENT)
		body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(body)

	# Плашки эффектов
	if not chips.is_empty():
		var chip_flow := HFlowContainer.new()
		chip_flow.add_theme_constant_override("h_separation", 6)
		chip_flow.add_theme_constant_override("v_separation", 6)
		v.add_child(chip_flow)
		for ch in chips:
			if ch.size() >= 2:
				chip_flow.add_child(_chip(ch[0], ch[1]))

	return row

# ── Локализация записей Летописи в момент отрисовки ───────────────
# Запись хранит данные (title_ru/en, summary_ru/en или summary_key,
# effects, cost, extra) — текст собираем на текущем Loc.lang.
# Старый формат сейвов ({title, summary, chips} — готовые строки)
# отображаем как есть.

const _CHIP_STATS := {
	"hazna": "res.hazna", "stability": "res.stability", "army": "res.army",
	"loyalty": "res.loyalty", "food": "res.food", "opposition": "res.opposition",
	"legitimacy": "res.legitimacy", "external_pressure": "res.pressure",
}
# Показатели, у которых рост — плохая новость
const _CHIP_BAD_UP := ["opposition", "external_pressure"]

func _entry_title(e: Dictionary) -> String:
	if e.has("title_ru") or e.has("title_en"):
		return GameData.loc(e, "title")
	return str(e.get("title", ""))  # старый формат сейва

func _entry_summary(e: Dictionary) -> String:
	if e.has("summary_key"):
		return Loc.t(str(e.summary_key))
	if e.has("summary_ru") or e.has("summary_en"):
		return GameData.loc(e, "summary")
	return str(e.get("summary", ""))  # старый формат сейва

func _entry_chips(e: Dictionary) -> Array:
	if e.has("chips"):
		return e.get("chips", [])  # старый формат сейва: готовые строки
	var out: Array = []
	# Уплаченная цена решения
	var cost := float(e.get("cost", 0.0))
	if cost > 0.0:
		out.append(["−%s %s" % [Palette.fmt_int(roundi(cost)), Loc.t("res.hazna")], false])
	# Числовые эффекты решения
	var eff: Dictionary = e.get("effects", {})
	for stat in eff:
		var v := float(eff[stat])
		if absf(v) < 0.5:
			continue
		var key := str(stat)
		if key.begins_with("prov."):
			out.append(_prov_chip(key, v))
			continue
		if not _CHIP_STATS.has(key):
			continue  # спец-эффекты (marry, usurp и т.п.) плашками не показываем
		var good := v > 0.0
		if key in _CHIP_BAD_UP:
			good = v < 0.0
		out.append(["%s %s" % [_signed(v), Loc.t(_CHIP_STATS[key])], good])
	# Дополнительные плашки по ключам локализации: [[loc_key, good], ...]
	for ex in e.get("extra", []):
		if ex is Array and ex.size() >= 2:
			out.append([Loc.t(str(ex[0])), bool(ex[1])])
	return out

func _signed(v: float) -> String:
	var n := absf(v)
	var s := Palette.fmt_int(roundi(n)) if n >= 1000.0 else str(roundi(n))
	return ("+" if v > 0.0 else "−") + s

func _prov_chip(key: String, v: float) -> Array:
	# Эффект вида prov.<id>.<stat> → «Румелия: −10 Недовольство»
	var parts := key.split(".")
	var pname := parts[1] if parts.size() > 1 else key
	for p in GameData.PROVINCES:
		if parts.size() > 1 and str(p.id) == parts[1]:
			pname = GameData.loc(p, "name")
			break
	var stat := parts[2] if parts.size() > 2 else ""
	var good := v > 0.0
	if stat == "fracture":
		good = v < 0.0
	return ["%s: %s %s" % [pname, _signed(v), Loc.t("res." + stat)], good]

func _chip(text: String, good: bool) -> PanelContainer:
	var p := PanelContainer.new()
	var bg := Palette.SECONDARY_CONTAINER if good else Palette.CRIMSON_DEEP
	p.add_theme_stylebox_override("panel", Palette.box(bg, 6, 0, Color.TRANSPARENT, 8))
	var l := Palette.label(text, Palette.FS_LABEL, Palette.PARCHMENT)
	p.add_child(l)
	return p

func update_view() -> void:
	# Хроника растёт по ходу партии — перестраиваем список при изменении длины.
	if GameState.chronicle.size() != _last_count:
		_rebuild_list()
