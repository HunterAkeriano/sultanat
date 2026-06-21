extends Control
## EventModal — модальный «Imperial Decree» (§21.4.7). Перекрывает всё с
## затемнением, требует выбора (нельзя закрыть без решения). Тугра, миниатюра
## в поляроид-рамке, заголовок, курсивный текст, восковые кнопки-выборы.

var _card_box: VBoxContainer
var _stat_labels := {}          # ключ стата -> Label (статистика снизу, live)
var _state_cap: Label           # подпись «Ваше положение» / «Возможный исход»
var _preview_ch = null          # вариант, который сейчас зажат (предпросмотр)
var _press_start: int = 0       # время нажатия (для отличия тапа от удержания)

const HIGHER_GOOD := {
	"hazna": true, "stability": true, "army": true,
	"loyalty": true, "food": true, "opposition": false,
}

func build() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP   # перехватываем клики под модалкой
	visible = false

	# Затемнение фона (имитация backdrop brightness 0.4)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.62)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	# Центрирование карточки со скроллом (на случай длинного текста)
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)

	var center := MarginContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for s in ["left", "right"]:
		center.add_theme_constant_override("margin_" + s, Palette.SAFE_AREA)
	for s in ["top", "bottom"]:
		center.add_theme_constant_override("margin_" + s, 32)
	scroll.add_child(center)

	# Парчовая карточка-декрет
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var sb := Palette.box(Palette.PARCHMENT, 12, 3, Palette.PRIMARY, 18)
	sb.border_color = Palette.PRIMARY
	sb.shadow_color = Color(0, 0, 0, 0.5)
	sb.shadow_size = 16
	card.add_theme_stylebox_override("panel", sb)
	center.add_child(card)

	_card_box = VBoxContainer.new()
	_card_box.add_theme_constant_override("separation", 12)
	card.add_child(_card_box)

func show_current() -> void:
	var ev = GameState.active_event
	if ev == null:
		visible = false
		return
	_populate(ev)
	move_to_front()   # поверх заставки и прочих оверлеев
	visible = true
	scale = Vector2(0.96, 0.96)
	modulate.a = 0.0
	pivot_offset = size / 2.0
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "modulate:a", 1.0, 0.18)
	tw.tween_property(self, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _populate(ev: Dictionary) -> void:
	for c in _card_box.get_children():
		c.queue_free()

	# Тугра сверху
	var tughra := Palette.label("\u262A", 30, Palette.CRIMSON_DEEP, true)
	tughra.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_card_box.add_child(tughra)

	# Иллюстрация-миниатюра в «поляроидной» белой рамке
	var poly := PanelContainer.new()
	poly.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var poly_sb := Palette.box(Color.WHITE, 4, 1, Palette.OUTLINE, 8)
	poly_sb.content_margin_bottom = 22
	poly_sb.shadow_color = Color(0, 0, 0, 0.25)
	poly_sb.shadow_size = 4
	poly.add_theme_stylebox_override("panel", poly_sb)
	_card_box.add_child(poly)
	var pv := VBoxContainer.new()
	pv.add_theme_constant_override("separation", 6)
	poly.add_child(pv)
	var img := TextureRect.new()
	img.texture = _safe_load("res://assets/art/%s.png" % ev.get("image", "event_cauldron"))
	img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	img.custom_minimum_size = Vector2(180, 130)
	pv.add_child(img)
	var caption := Palette.label_caps(GameData.loc(ev, "title"), Palette.FS_LABEL, Palette.ON_PARCHMENT.lightened(0.2))
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pv.add_child(caption)

	# Заголовок по центру
	var title := Palette.label(GameData.loc(ev, "title"), Palette.FS_TITLE, Palette.CRIMSON_DEEP, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_card_box.add_child(title)

	var divider := ColorRect.new()
	divider.color = Palette.PRIMARY.darkened(0.1)
	divider.custom_minimum_size = Vector2(0, 1)
	_card_box.add_child(divider)

	# Текст-цитата (курсив через Source Serif italic недоступен — даём serif)
	var body := Palette.label(GameData.loc(ev, "body"), Palette.FS_BODY_LG, Palette.ON_PARCHMENT)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_card_box.add_child(body)

	# Варианты (с показом возможного исхода прямо под каждым)
	_stat_labels.clear()
	_preview_ch = null
	var choices: Array = GameState.resolved_choices(ev)
	for i in range(choices.size()):
		_card_box.add_child(_build_choice(choices[i], i))

	# Статистика снизу: наше текущее положение (обновляется в реальном времени)
	_card_box.add_child(_build_stats_bar())
	_refresh_stats()

func _build_stats_bar() -> PanelContainer:
	var bar := PanelContainer.new()
	bar.add_theme_stylebox_override("panel", Palette.box(Palette.SURFACE_CONTAINER, 8, 1, Palette.OUTLINE_VARIANT, 10))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	bar.add_child(v)
	_state_cap = Palette.label_caps(Loc.t("ev.your_state"), Palette.FS_LABEL, Palette.ON_SURFACE_VARIANT)
	_state_cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_state_cap)
	var flow := HFlowContainer.new()
	flow.alignment = FlowContainer.ALIGNMENT_CENTER
	v.add_child(flow)
	_add_stat_chip(flow, "hazna", "\u269C")
	_add_stat_chip(flow, "stability", "\u2696")
	_add_stat_chip(flow, "army", "\u2694")
	_add_stat_chip(flow, "loyalty", "\u2665")
	_add_stat_chip(flow, "food", "\u2698")
	_add_stat_chip(flow, "opposition", "\u2620")
	return bar

func _add_stat_chip(flow: HFlowContainer, key: String, icon: String) -> void:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 3)
	var ml := MarginContainer.new()
	ml.add_theme_constant_override("margin_left", 6)
	ml.add_theme_constant_override("margin_right", 6)
	ml.add_child(h)
	h.add_child(Palette.label(icon, 13, Palette.ON_SURFACE_VARIANT))
	var val := Palette.label("0", Palette.FS_LABEL, Palette.ON_SURFACE, true)
	h.add_child(val)
	_stat_labels[key] = val
	flow.add_child(ml)

func _refresh_stats() -> void:
	if _stat_labels.is_empty():
		return
	var preview := _preview_ch != null
	if _state_cap != null:
		_state_cap.text = Loc.t("ev.result") if preview else Loc.t("ev.your_state")
		_state_cap.add_theme_color_override("font_color",
			Palette.CRIMSON_DEEP if preview else Palette.ON_SURFACE_VARIANT)
	for key in _stat_labels:
		var cur: float = _stat_current(key)
		var lbl: Label = _stat_labels[key]
		if preview:
			var proj: float = _projected(key)
			lbl.text = _fmt_stat(key, proj)
			var diff: float = proj - cur
			var col := Palette.ON_SURFACE
			if absf(diff) >= 0.5:
				var good: bool = (diff > 0.0) == HIGHER_GOOD[key]
				col = Color(0.0, 0.45, 0.25) if good else Palette.CRIMSON_DEEP
			lbl.add_theme_color_override("font_color", col)
		else:
			lbl.text = _fmt_stat(key, cur)
			var c := Palette.ON_SURFACE
			if key == "food" and GameState.food < 30.0:
				c = Palette.CRIMSON_DEEP
			elif key == "opposition" and GameState.opposition >= 60.0:
				c = Palette.CRIMSON_DEEP
			lbl.add_theme_color_override("font_color", c)

func _stat_current(key: String) -> float:
	return float(GameState.get(key))

func _fmt_stat(key: String, v: float) -> String:
	if key == "hazna":
		return Palette.fmt(v)
	if key == "army":
		return "%d" % int(round(v))
	return "%d%%" % int(round(v))

func _projected(key: String) -> float:
	# Что станет со статом, если выбрать зажатый вариант (с учётом цены и
	# авто-сдвига оппозиции — как в GameState.choose_event).
	var eff: Dictionary = _preview_ch.get("effects", {})
	var base: float = _stat_current(key)
	var d: float = float(eff.get(key, 0.0))
	if key == "hazna" and _preview_ch.has("cost"):
		d -= float(_preview_ch.cost)
	if key == "opposition" and not eff.has("opposition"):
		var sd: float = float(eff.get("stability", 0.0))
		var ld: float = float(eff.get("loyalty", 0.0))
		var auto: float = -(sd + ld) * 0.35
		if absf(auto) < 0.5:
			auto = 1.5
		d += auto
	var v: float = base + d
	if key == "hazna":
		return maxf(v, 0.0)
	return clampf(v, 0.0, 100.0)

func _process(_delta: float) -> void:
	if visible and not _stat_labels.is_empty():
		_refresh_stats()

func _build_choice(ch: Dictionary, index: int) -> PanelContainer:
	var gold: bool = not (ch.has("req") and ch.get("req", {}).has("army"))
	# Кримсон — для жёстких/военных (с требованием армии), золото — иначе
	var available := _choice_available(ch)

	var card := PanelContainer.new()
	var bg := Palette.PARCHMENT_DIM
	card.add_theme_stylebox_override("panel", Palette.box(bg, 8, 1, (Palette.PRIMARY if gold else Palette.CRIMSON_DEEP).darkened(0.05), 12))
	var btn := Button.new()
	btn.flat = true
	btn.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	btn.focus_mode = Control.FOCUS_NONE
	# Зажатие = предпросмотр исхода внизу; короткий тап = выбор.
	btn.modulate.a = 1.0 if available else 0.5
	btn.button_down.connect(func(): _on_choice_down(ch))
	btn.button_up.connect(func(): _on_choice_up(index, available))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(row)

	# Восковая иконка-печать слева
	var seal := PanelContainer.new()
	seal.add_theme_stylebox_override("panel", Palette.box(Palette.PRIMARY_CONTAINER if gold else Palette.CRIMSON_DEEP, 999, 0, Color.TRANSPARENT, 8))
	seal.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	seal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sym := "\u269C" if gold else "\u2694"   #  / ⚔
	if ch.has("req"):
		sym = "\u2694"   # щит для условных
	var sl := Palette.label(sym, 16, Palette.ON_PRIMARY if gold else Palette.PARCHMENT)
	sl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	seal.add_child(sl)
	row.add_child(seal)

	# Текст варианта + цена/требование + возможный исход
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 3)
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(info)
	var lbl := Palette.label(GameData.loc(ch, "label"), Palette.FS_BODY_LG, Palette.ON_PARCHMENT, true)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.add_child(lbl)

	if ch.has("req"):
		var req_txt := Loc.t("ev.requirement") + ": "
		var parts: Array = []
		for stat in ch.req:
			parts.append("%s > %d" % [Loc.t("res." + stat), int(ch.req[stat])])
		req_txt += ", ".join(parts)
		var rl := Palette.label(req_txt, Palette.FS_LABEL, Palette.ON_PARCHMENT.lightened(0.15))
		rl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		info.add_child(rl)

	# Галочка/крест доступности
	if ch.has("req") or ch.has("cost"):
		var check := Palette.label("\u2713" if available else "\u2715", 18,
			Palette.SECONDARY_CONTAINER if available else Palette.CRIMSON_DEEP, true)
		check.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		check.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(check)

	card.add_child(btn)
	return card

func _on_choice_down(ch: Dictionary) -> void:
	_press_start = Time.get_ticks_msec()
	_preview_ch = ch
	_refresh_stats()

func _on_choice_up(index: int, available: bool) -> void:
	var held := Time.get_ticks_msec() - _press_start
	_preview_ch = null
	_refresh_stats()
	# Короткий тап = выбрать (если доступно). Долгое удержание = только предпросмотр.
	if held < 350 and available:
		_choose(index)

func _choice_available(ch: Dictionary) -> bool:
	if ch.has("req"):
		for stat in ch.req:
			if GameState.get(stat) < ch.req[stat]:
				return false
	if ch.has("cost") and GameState.hazna < ch.cost:
		return false
	return true

func _choose(index: int) -> void:
	GameState.choose_event(index)
	if GameState.active_event == null:
		_close()

func _close() -> void:
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.14)
	tw.tween_callback(func(): visible = false)

func _safe_load(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path)
	return null
