extends Control
## FamilyTree — генеалогическое древо текущего правления.
## Макет: правитель (по центру) ── его жена/жёны (сбоку справа, связаны брачной линией).
## От пары вниз по центру идёт «кровная линия» к сыну-наследнику, у которого тоже есть
## ячейка под будущую жену — так показана продолжающаяся династическая цепочка.
## Портреты: султан — переданный sultan_tex (взрослое фото поколения); жёны —
## assets/art/wives/<portrait>_<возраст>.webp; наследник — assets/art/dynasty/heir_<gen+1>_teen.webp.
## Если арта нет — карточка с инициалом (фолбэк).

var sultan_label: String = ""
var wives: Array = []             # [{id, name, alive, married_year}]
var children: Array = []          # [{name, alive, gender, born, mother}] — один наследник
var sultan_tex: Texture2D = null
var cur_year: int = 1690
var ancestors: Array = []         # ушедшие правители: [{sultan, generation, wife_name, wife_id, end_year}]
var _anc_tex: Array = []          # предзагруженные портреты предков: [{s: Texture2D, w: Texture2D}]
var _last_sig := ""               # подпись данных: пропускаем пересборку без изменений
var _wife_tex_cache: Texture2D = null    # портрет живой жены, загружается заранее (не в _draw)
var _heir_tex_cache: Texture2D = null    # подростковый портрет наследника, заранее

signal seek_wife_requested        # клик по пустой ячейке жены с «+» (платный поиск)
var _seek_btn: Button

const ADULT_AGE := 14
# Размеры карточек (крупнее + больше зазор между султаном и женой)
const SW := 120.0   # султан
const SH := 152.0
const WW := 84.0    # жена
const WH := 106.0
const HW := 104.0   # наследник
const HH := 132.0
const FW := 76.0    # ячейка будущей жены наследника
const FH := 96.0
const AW := 88.0    # предок-султан (компактнее действующего)
const AH := 112.0
const AWW := 66.0   # супруга предка
const AWH := 84.0
const A_STEP := AH + 66.0   # шаг поколения: карточка + подписи + кровная линия
const TOP := 8.0
const WIFE_STEP := 92.0
const GAP_COUPLE := 26.0

func _ready() -> void:
	custom_minimum_size.y = 320.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE   # не мешаем прокрутке; клики ловит кнопка «+»
	_seek_btn = Button.new()
	_seek_btn.flat = true
	_seek_btn.focus_mode = Control.FOCUS_NONE
	_seek_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	_seek_btn.visible = false
	_seek_btn.pressed.connect(func(): seek_wife_requested.emit())
	add_child(_seek_btn)

func set_data(sultan_l: String, wv: Array, kids: Array, portrait: Texture2D = null, year: int = 1690, anc: Array = []) -> void:
	# set_data зовётся каждый тик обновления UI: без этой проверки древо
	# перерисовывалось бы постоянно, что заметно дёргает телефон.
	var sig := "%s|%d|%s|%s|%d|%s" % [sultan_l, year, str(wv), str(kids), anc.size(), str(portrait)]
	if sig == _last_sig:
		return
	_last_sig = sig
	sultan_label = sultan_l
	wives = wv
	children = kids
	sultan_tex = portrait
	cur_year = year
	ancestors = anc
	# Портреты предков — заранее (не в _draw) и в СЕРОМ: прошлые ветки выцветают.
	# Кэш пересобираем только когда добавилось поколение (set_data зовётся каждый кадр).
	if _anc_tex.size() != ancestors.size():
		_anc_tex.clear()
		for an in ancestors:
			_anc_tex.append({
				"s": _gray_tex(_ancestor_sultan_tex(int(an.get("pidx", 0)))),
				"w": _gray_tex(_wife_tex({"id": an.get("wife_id", "")})),
			})
	# Портреты грузим ЗАРАНЕЕ (здесь, а не в _draw) — иначе текстура может быть ещё не
	# готова к отрисовке и карточка выходит белой.
	_wife_tex_cache = null
	for wf in wives:
		if bool(wf.get("alive", true)):
			_wife_tex_cache = _wife_tex(wf)
			break
	# Портрет наследника по возрасту: младенец (укутанный) → молодой → взрослый.
	# Имена файлов: son_baby_N / son_N / son_adult_N (+ запасные варианты).
	_heir_tex_cache = null
	var h := {}
	for c in children:
		if bool(c.get("alive", true)):
			h = c
			break
	if not h.is_empty():
		var age := cur_year - int(h.get("born", cur_year))
		# Портрет наследника: младенец до 2 лет, дальше — подросток (son_N).
		# «Взрослая» версия (heir_N_adult) появляется ТОЛЬКО когда сын
		# восходит на трон: жив отец — сын на карточке остаётся подростком,
		# сколько бы лет ему ни было. Это визуально: право наследовать
		# всё равно открывается в 14 (см. HEIR_ADULT_AGE в GameState).
		var n := int(h.get("pidx", (GameState.generation % 6) + 1))
		if age <= 2:
			_heir_tex_cache = _first_tex(["son_baby_%d" % n, "son_baby_1"])
		else:
			_heir_tex_cache = _first_tex(["son_%d" % n, "son_1"])
	custom_minimum_size.y = _content_height()
	queue_redraw()

func _living_wife() -> Dictionary:
	for wf in wives:
		if bool(wf.get("alive", true)):
			return wf
	return {}

func _son_center_y() -> float:
	# От позиции султана (она учитывает цепочку предков), а не от верха полотна
	return _sultan_center_y() + SH / 2.0 + 40.0 + HH / 2.0

func _sultan_center_y() -> float:
	return TOP + float(ancestors.size()) * A_STEP + SH / 2.0

func one_gen_height() -> float:
	# Высота окна под ОДНО поколение (султан + наследник) — окно древа
	# больше не растёт с новыми ветками, они уходят вниз под прокрутку.
	return TOP + SH + 40.0 + HH + 44.0

func _content_height() -> float:
	return _son_center_y() + HH / 2.0 + 44.0

func _is_adult(c: Dictionary) -> bool:
	return (cur_year - int(c.get("born", cur_year))) >= ADULT_AGE

func _safe_load(path: String) -> Texture2D:
	return load(path) if ResourceLoader.exists(path) else null

func _first_tex(names: Array) -> Texture2D:
	for nm in names:
		for ext in [".png", ".jpg", ".webp"]:
			var p := "res://assets/art/dynasty/%s%s" % [str(nm), ext]
			if ResourceLoader.exists(p):
				return load(p)
	return null

func _gray_tex(tex: Texture2D) -> Texture2D:
	# Чёрно-белая копия портрета: прошлое поколение «выцветает» на древе.
	if tex == null:
		return null
	var img := tex.get_image()
	if img == null:
		return tex
	if img.is_compressed():
		img.decompress()
	img.adjust_bcs(1.0, 1.0, 0.0)   # saturation 0 → оттенки серого
	return ImageTexture.create_from_image(img)

func _ancestor_sultan_tex(pidx: int) -> Texture2D:
	# Внешность предка: его личный heir_N_adult; 0 — базовый первый султан
	if pidx >= 1:
		var t := _safe_load("res://assets/art/dynasty/heir_%d_adult.png" % pidx)
		if t != null:
			return t
	var pp := _safe_load("res://assets/art/sultan_portrait.png")
	return pp if pp != null else _safe_load("res://assets/art/sultan.png")

func _wife_tex(w: Dictionary) -> Texture2D:
	var d := GameData.wife_def(str(w.get("id", "")))
	var base := str(d.get("portrait", ""))
	if base == "":
		return null
	return _safe_load("res://assets/art/wives/%s.png" % base)

func _heir_tex() -> Texture2D:
	return _safe_load("res://assets/art/dynasty/heir_%d_teen.png" % (GameState.generation + 1))

# ════════════════════════════════════════════════════════════════
func _draw() -> void:
	var w := size.x
	if w <= 1.0:
		return
	var cx := w / 2.0
	var gold: Color = Palette.PRIMARY
	var branch := Color(0.45, 0.31, 0.10)   # бронзовые линии-«чернила» на бумаге

	var sy := _sultan_center_y()
	var sultan_center := Vector2(cx, sy)
	var sultan_right := cx + SW / 2.0

	# ── Предки: династия продолжается — ушедшие правители остаются на древе ──
	var ay := TOP + AH / 2.0
	for i in range(ancestors.size()):
		var an: Dictionary = ancestors[i]
		var tp: Dictionary = _anc_tex[i] if i < _anc_tex.size() else {}
		var acx := Vector2(cx, ay)
		# Прошлая ветка выцветает: ч/б портреты, пепельные рамки и подписи
		var ash := Color(0.56, 0.54, 0.49)
		var ash_cap := Color(0.52, 0.50, 0.45)
		var wnm := GameData.person_name_loc(str(an.get("wife_name", "")))
		if wnm != "":
			var awx := cx + AW / 2.0 + GAP_COUPLE + AWW / 2.0
			_line(Vector2(cx + AW / 2.0, ay), Vector2(awx - AWW / 2.0, ay), ash.darkened(0.15))
			_photo_card(Vector2(awx, ay), AWW, AWH, tp.get("w", null), wnm, ash, 2.0, 1.45)
			_cap(Vector2(awx, ay + AWH / 2.0 + 19.0), wnm, ash_cap, 11)
		_photo_card(acx, AW, AH, tp.get("s", null), str(an.get("sultan", "")), ash, 2.5)
		_cap(Vector2(cx, ay + AH / 2.0 + 20.0), str(an.get("sultan", "")), ash_cap, 12)
		_cap(Vector2(cx, ay + AH / 2.0 + 35.0),
			"%s %d" % [Loc.t("dyn.reigned_until"), int(an.get("end_year", 0))],
			ash_cap.darkened(0.1), 10)
		# кровная линия вниз к следующему поколению (обходит подписи)
		var next_top := (ay + A_STEP - AH / 2.0) if i < ancestors.size() - 1 else (sy - SH / 2.0)
		_line(Vector2(cx, ay + AH / 2.0 + 40.0), Vector2(cx, next_top), branch)
		ay += A_STEP

	# ── Жена (одна за раз): живая жена справа от султана, связана брачной линией.
	#    Усопших не показываем. Пустая ячейка: «+» (клик → платный поиск), либо
	#    «Поиск невесты…», если поиск уже объявлен. ──
	var wife_cx := cx + SW / 2.0 + GAP_COUPLE + WW / 2.0
	_line(Vector2(sultan_right, sy), Vector2(wife_cx - WW / 2.0, sy), branch)
	var lw := _living_wife()
	var wcenter := Vector2(wife_cx, sy)
	var show_seek_btn := false
	if not lw.is_empty():
		_photo_card(wcenter, WW, WH, _wife_tex_cache, GameData.wife_display_name(lw), gold, 2.0, 1.45)
		_cap(Vector2(wife_cx, sy + WH / 2.0 + 21.0), GameData.wife_display_name(lw), Color(0.95, 0.79, 0.31), 13)
	elif GameState.seeking_wife:
		_empty_card(wcenter, WW, WH, "\u2026")   # …
		_cap(Vector2(wife_cx, sy + WH / 2.0 + 21.0), Loc.t("dyn.seeking"), Color(0.85, 0.70, 0.30), 12)
	elif GameState.can_seek_wife():
		_empty_card(wcenter, WW, WH, "+", Palette.PRIMARY_CONTAINER.darkened(0.45))
		_cap(Vector2(wife_cx, sy + WH / 2.0 + 21.0), Loc.t("dyn.seek_cta"), Color(0.98, 0.82, 0.35), 12)
		show_seek_btn = true
	else:
		_empty_card(wcenter, WW, WH, "\u2014")   # — нет доступных невест
		_cap(Vector2(wife_cx, sy + WH / 2.0 + 21.0), Loc.t("dyn.no_wife"), Color(0.78, 0.62, 0.28), 12)

	# Прозрачная кнопка поверх ячейки «+» — ловит клик (древо само mouse-ignore)
	if _seek_btn != null:
		_seek_btn.visible = show_seek_btn
		if show_seek_btn:
			_seek_btn.position = Vector2(wife_cx - WW / 2.0, sy - WH / 2.0)
			_seek_btn.size = Vector2(WW, WH)

	# ── Султан (корень кровной линии, по центру) ──
	_photo_card(sultan_center, SW, SH, sultan_tex, sultan_label, gold, 3.0)
	_cap(Vector2(cx, sy + SH / 2.0 + 23.0), Loc.t("dyn.you"), Color(0.95, 0.79, 0.31), 14)

	# ── Кровная линия вниз по центру к сыну ──
	var son_y := _son_center_y()
	_line(Vector2(cx, sy + SH / 2.0), Vector2(cx, son_y - HH / 2.0), branch)

	# ── Наследник (по центру) + ячейка его будущей жены справа ──
	var son_center := Vector2(cx, son_y)
	var fwife_cx := cx + HW / 2.0 + GAP_COUPLE + FW / 2.0
	# брачная линия сына к ячейке жены
	_line(Vector2(cx + HW / 2.0, son_y), Vector2(fwife_cx - FW / 2.0, son_y), branch.darkened(0.1))
	_empty_card(Vector2(fwife_cx, son_y), FW, FH, "+")
	_cap(Vector2(fwife_cx, son_y + FH / 2.0 + 20.0), Loc.t("dyn.future_wife"), Color(0.78, 0.62, 0.28), 11)

	if children.size() > 0:
		var c: Dictionary = children[0]
		if bool(c.get("alive", true)):
			var adult := _is_adult(c)
			_photo_card(son_center, HW, HH, _heir_tex_cache, GameData.person_name_loc(str(c.get("name", ""))), gold, 2.5, 1.45)
			_cap(Vector2(cx, son_y + HH / 2.0 + 22.0), GameData.person_name_loc(str(c.get("name", ""))), Color(0.95, 0.79, 0.31), 14)
			_cap(Vector2(cx, son_y + HH / 2.0 + 38.0),
				(Loc.t("dyn.heir_ready") if adult else Loc.t("dyn.heir")),
				(Color(0.95, 0.79, 0.31) if adult else Color(0.78, 0.62, 0.28)), 12)
		else:
			_dead_card(son_center, HW, HH, GameData.person_name_loc(str(c.get("name", ""))))
			_cap(Vector2(cx, son_y + HH / 2.0 + 22.0),
				"%s (%s)" % [GameData.person_name_loc(str(c.get("name", ""))), Loc.t("dyn.deceased")],
				Color(0.78, 0.62, 0.28), 13)
	else:
		_empty_card(son_center, HW, HH, "?")
		_cap(Vector2(cx, son_y + HH / 2.0 + 22.0), Loc.t("dyn.empty_heir"), Color(0.78, 0.62, 0.28), 12)

# ── примитивы ─────────────────────────────────────────────────────
func _line(a: Vector2, b: Vector2, col: Color) -> void:
	draw_line(a, b, col, 3.0, true)

func _node(c: Vector2, col: Color) -> void:
	draw_circle(c, 4.0, col)

func _photo_card(center: Vector2, cw: float, ch: float, tex: Texture2D, nm: String, ring: Color, b: float, zoom: float = 1.0) -> void:
	var inner := Rect2(center.x - cw / 2.0, center.y - ch / 2.0, cw, ch)
	var outer := Rect2(inner.position - Vector2(b, b), inner.size + Vector2(b * 2.0, b * 2.0))
	draw_rect(Rect2(outer.position + Vector2(1.5, 2.5), outer.size), Color(0, 0, 0, 0.30))
	draw_rect(outer, ring)
	if tex != null:
		# Кроп «обложкой» под формат ячейки + приближение (zoom) со сдвигом к верху —
		# единый паттерн: в ячейке видно лицо/плечи крупно, а не вся картина целиком.
		var tw := float(tex.get_width())
		var th := float(tex.get_height())
		var card_aspect := cw / ch
		var src_w := tw
		var src_h := th
		if tw / th > card_aspect:
			src_w = th * card_aspect
		else:
			src_h = tw / card_aspect
		src_w /= zoom
		src_h /= zoom
		var src_x := (tw - src_w) * 0.5         # по центру по горизонтали
		var src_y := (th - src_h) * 0.12        # ближе к верху — фокус на лице
		draw_texture_rect_region(tex, inner, Rect2(src_x, src_y, src_w, src_h))
	else:
		draw_rect(inner, Palette.PRIMARY_CONTAINER)
		_crescent(Vector2(center.x, center.y - ch * 0.14), ch * 0.15, Palette.CRIMSON_DEEP)
		_letter(Vector2(center.x, center.y + ch * 0.20), cw * 0.5, _initial(nm), Palette.CRIMSON_DEEP)
	_ornate_frame(outer, ring)

## Узорная рамка портрета: внешняя линия, ромбы по углам, точки на серединах,
## тонкие завитки-дуги — в золоте кольца.
func _ornate_frame(r: Rect2, col: Color) -> void:
	var g := Color(col.r, col.g, col.b, 0.95)
	var soft := Color(col.r, col.g, col.b, 0.55)
	var o := Rect2(r.position - Vector2(4, 4), r.size + Vector2(8, 8))
	# внешняя тонкая линия
	draw_line(o.position, o.position + Vector2(o.size.x, 0), soft, 1.0)
	draw_line(o.position, o.position + Vector2(0, o.size.y), soft, 1.0)
	draw_line(o.position + Vector2(o.size.x, 0), o.position + o.size, soft, 1.0)
	draw_line(o.position + Vector2(0, o.size.y), o.position + o.size, soft, 1.0)
	# угловые ромбики
	for pcorn in [o.position, o.position + Vector2(o.size.x, 0), o.position + o.size, o.position + Vector2(0, o.size.y)]:
		_frame_diamond(pcorn, 4.5, g)
	# точки на серединах сторон
	draw_circle(o.position + Vector2(o.size.x / 2.0, 0), 2.2, g)
	draw_circle(o.position + Vector2(o.size.x / 2.0, o.size.y), 2.2, g)
	draw_circle(o.position + Vector2(0, o.size.y / 2.0), 2.2, g)
	draw_circle(o.position + Vector2(o.size.x, o.size.y / 2.0), 2.2, g)
	# завитки-дуги в углах (снаружи)
	var rr := 7.0
	draw_arc(o.position + Vector2(rr, rr), rr, PI, 1.5 * PI, 8, soft, 1.0, true)
	draw_arc(o.position + Vector2(o.size.x - rr, rr), rr, 1.5 * PI, TAU, 8, soft, 1.0, true)
	draw_arc(o.position + Vector2(o.size.x - rr, o.size.y - rr), rr, 0.0, 0.5 * PI, 8, soft, 1.0, true)
	draw_arc(o.position + Vector2(rr, o.size.y - rr), rr, 0.5 * PI, PI, 8, soft, 1.0, true)

func _frame_diamond(c: Vector2, s: float, col: Color) -> void:
	draw_colored_polygon(PackedVector2Array([
		c + Vector2(0, -s), c + Vector2(s, 0), c + Vector2(0, s), c + Vector2(-s, 0),
	]), col)

func _dead_card(center: Vector2, cw: float, ch: float, nm: String) -> void:
	var b := 2.0
	var inner := Rect2(center.x - cw / 2.0, center.y - ch / 2.0, cw, ch)
	var outer := Rect2(inner.position - Vector2(b, b), inner.size + Vector2(b * 2.0, b * 2.0))
	draw_rect(outer, Palette.OUTLINE)
	draw_rect(inner, Palette.SURFACE_HIGH)
	_letter(Vector2(center.x, center.y - ch * 0.04), cw * 0.5, _initial(nm), Palette.ON_SURFACE_VARIANT)
	_cross(center, cw * 0.28, Palette.CRIMSON_DEEP)

func _empty_card(center: Vector2, cw: float, ch: float, glyph: String, fill: Color = Palette.SURFACE_HIGHEST) -> void:
	var inner := Rect2(center.x - cw / 2.0, center.y - ch / 2.0, cw, ch)
	draw_rect(inner, fill)
	_rect_outline(inner, Palette.OUTLINE_VARIANT, 2.0)
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(center.x - cw / 2.0, center.y + ch * 0.18), glyph,
		HORIZONTAL_ALIGNMENT_CENTER, cw, int(ch * 0.5), Palette.ON_SURFACE_VARIANT)

func _rect_outline(r: Rect2, col: Color, t: float) -> void:
	draw_line(r.position, r.position + Vector2(r.size.x, 0), col, t)
	draw_line(r.position, r.position + Vector2(0, r.size.y), col, t)
	draw_line(r.position + Vector2(r.size.x, 0), r.position + r.size, col, t)
	draw_line(r.position + Vector2(0, r.size.y), r.position + r.size, col, t)

func _crescent(c: Vector2, r: float, col: Color) -> void:
	draw_circle(c, r, col)
	draw_circle(c + Vector2(r * 0.42, -r * 0.12), r * 0.92, Palette.PRIMARY_CONTAINER)

func _cross(c: Vector2, s: float, col: Color) -> void:
	draw_line(c + Vector2(-s, -s), c + Vector2(s, s), col, 4.0, true)
	draw_line(c + Vector2(s, -s), c + Vector2(-s, s), col, 4.0, true)

func _letter(c: Vector2, r: float, ch: String, col: Color) -> void:
	var font := ThemeDB.fallback_font
	var fs := int(r * 0.95)
	draw_string(font, Vector2(c.x - r, c.y + fs * 0.34), ch,
		HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, fs, col)

func _cap(pos: Vector2, text: String, col: Color, fs: int) -> void:
	var font := ThemeDB.fallback_font
	# тёмная тень — золото читается на бумаге
	draw_string(font, Vector2(pos.x - 100.0 + 1.0, pos.y + 1.5), text,
		HORIZONTAL_ALIGNMENT_CENTER, 200.0, fs, Color(0.16, 0.10, 0.02, 0.55))
	draw_string(font, Vector2(pos.x - 100.0, pos.y), text,
		HORIZONTAL_ALIGNMENT_CENTER, 200.0, fs, col)

func _initial(nm: String) -> String:
	return nm.substr(0, 1).to_upper() if nm.length() > 0 else "?"
