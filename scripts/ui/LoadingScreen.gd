extends Control
## LoadingScreen — заставка на старте: медленный кроссфейд между случайными
## фото из assets/art/loading/, красивая полоса прогресса чуть ниже центра
## экрана, случайные цитаты внизу, меняющиеся синхронно с картинками.
## По окончании стреляет сигналом finished — Main показывает меню.
##
## Как добавлять картинки: .webp/.jpg в assets/art/loading/ — LoadingScreen
## сам их найдёт при старте.
## Как добавлять цитаты: ключи Loc.t("load.q1") ... "load.qN" в Loc.gd.

signal finished

const IMAGES_DIR := "res://assets/art/loading/"
# Общая длительность: комфортно посмотреть 2–3 слайда, но не заскучать
const DURATION := 10.0
# Каждый слайд держится примерно столько (реальное значение подгоняется под DURATION)
const SLIDE_INTERVAL := 3.8
# Плавный переход между слайдами
const CROSSFADE := 1.1

var _images: Array = []
var _quote_keys: Array = []
var _slide_a: TextureRect
var _slide_b: TextureRect
var _bar: ProgressBar
var _bar_label: Label
var _quote: Label
var _elapsed := 0.0
var _next_slide_at := SLIDE_INTERVAL
var _quote_idx := 0
var _finished := false

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP   # блокируем клики под заставкой

	# Тёмный «войд» на случай если картинок нет — экран не будет пустым
	var bg := ColorRect.new()
	bg.color = Color(0.031, 0.039, 0.059, 1.0)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	_load_manifest()
	_collect_quote_keys()

	# Два TextureRect для кроссфейда: пока один виден, второй готовит следующее фото
	_slide_a = _make_slide()
	_slide_b = _make_slide()
	_slide_b.modulate.a = 0.0
	add_child(_slide_a)
	add_child(_slide_b)

	# Читаемость подписи бара и цитаты обеспечивается собственными теневыми
	# обводками у самих лейблов — плоские затемняющие полосы поверх картинки
	# смотрятся неаккуратно, лучше их убрать.

	# ── Прогресс-бар чуть ниже центра экрана ──
	var bar_wrap := VBoxContainer.new()
	bar_wrap.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	bar_wrap.anchor_left = 0.0
	bar_wrap.anchor_right = 1.0
	bar_wrap.anchor_top = 0.72      # ~72% высоты экрана — ниже, чем было
	bar_wrap.offset_left = 56.0
	bar_wrap.offset_right = -56.0
	bar_wrap.offset_top = 0.0
	bar_wrap.add_theme_constant_override("separation", 12)
	add_child(bar_wrap)

	# Тонкая подпись «Загрузка / Loading» над баром
	_bar_label = Palette.label_caps(Loc.t("load.progress"), Palette.FS_LABEL, Palette.PRIMARY_FIXED)
	_bar_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_bar_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	_bar_label.add_theme_constant_override("shadow_offset_x", 0)
	_bar_label.add_theme_constant_override("shadow_offset_y", 2)
	_bar_label.add_theme_constant_override("shadow_outline_size", 5)
	bar_wrap.add_child(_bar_label)

	# Бар в декоративной рамке: тёмное «стекло» с двойной золотой рамкой,
	# лёгкое сияние вокруг заполненной части, «нити-разделители» слева/справа.
	var bar_row := HBoxContainer.new()
	bar_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar_row.add_theme_constant_override("separation", 8)
	bar_wrap.add_child(bar_row)

	var dot_l := Palette.label("\u2726", 14, Palette.PRIMARY_FIXED)   # ✦ — звёздочка-узелок
	dot_l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	dot_l.add_theme_constant_override("shadow_outline_size", 3)
	bar_row.add_child(dot_l)

	# Сам бар: толще (16 px), с двойной обводкой и мягким свечением
	_bar = ProgressBar.new()
	_bar.show_percentage = false
	_bar.max_value = 100.0
	_bar.value = 0.0
	_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bar.custom_minimum_size = Vector2(0, 16)
	# Двухслойный «футляр»: сначала тёмная стеклянная подложка с золотой рамкой,
	# поверх (через тень стилибокса) — второе тонкое кольцо для «двойной рамки».
	var bg_box := Palette.box(Color(0.019, 0.023, 0.035, 0.92), 8, 2, Palette.PRIMARY, 3)
	bg_box.shadow_color = Color(Palette.PRIMARY.r, Palette.PRIMARY.g, Palette.PRIMARY.b, 0.35)
	bg_box.shadow_size = 6
	# Заливка — тёплое золото с мягким тёмным контуром внутри, чтобы «горело»
	var fill_box := Palette.box(Palette.PRIMARY_FIXED, 6, 0, Color(0.6, 0.4, 0.1, 0.6), 2)
	fill_box.shadow_color = Color(Palette.PRIMARY_FIXED.r, Palette.PRIMARY_FIXED.g, Palette.PRIMARY_FIXED.b, 0.5)
	fill_box.shadow_size = 5
	_bar.add_theme_stylebox_override("background", bg_box)
	_bar.add_theme_stylebox_override("fill", fill_box)
	bar_row.add_child(_bar)

	var dot_r := Palette.label("\u2726", 14, Palette.PRIMARY_FIXED)
	dot_r.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	dot_r.add_theme_constant_override("shadow_outline_size", 3)
	bar_row.add_child(dot_r)

	# ── Цитата снизу ──
	_quote = Palette.label("", Palette.FS_BODY, Palette.PRIMARY_FIXED)
	_quote.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_quote.offset_left = 36.0
	_quote.offset_right = -36.0
	_quote.offset_top = -180.0
	_quote.offset_bottom = -60.0
	_quote.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_quote.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_quote.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_quote.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	_quote.add_theme_constant_override("shadow_offset_x", 0)
	_quote.add_theme_constant_override("shadow_offset_y", 2)
	_quote.add_theme_constant_override("shadow_outline_size", 8)
	if Palette.font_serif:
		_quote.add_theme_font_override("font", Palette.font_serif)
	add_child(_quote)

	# Стартовые слайд и цитата
	_show_next_slide()
	_show_next_quote()

func _load_manifest() -> void:
	_images.clear()
	# ── Способ 1: сканирование папки. Работает на компьютере, но в экспортированной
	# сборке (Android APK) DirAccess по res:// часто не видит содержимое, потому
	# что Godot упаковывает только явно связанные ресурсы. Оставляем как основной,
	# но не полагаемся только на него.
	var dir := DirAccess.open(IMAGES_DIR)
	if dir != null:
		dir.list_dir_begin()
		while true:
			var f := dir.get_next()
			if f == "":
				break
			if dir.current_is_dir():
				continue
			var low := f.to_lower()
			if low.ends_with(".webp") or low.ends_with(".jpg") or low.ends_with(".jpeg") or low.ends_with(".png"):
				_images.append(IMAGES_DIR + f)
		dir.list_dir_end()

	# ── Способ 2: явный список. Каждое имя мы прописываем здесь — Godot тогда
	# видит эти пути и УПАКОВЫВАЕТ файлы в .pck при экспорте. Если сканирование
	# в способе 1 ничего не нашло (Android), берём список отсюда. Дублирования
	# нет: мы фильтруем ниже.
	var fallback: Array = [
		"load_01_janissary_sentinel.webp",
		"load_02_janissary_candle_a.webp",
		"load_03_janissary_candle_b.webp",
		"load_04_cossack_dawn.webp",
		"load_05_hetman.webp",
		"load_06_chaikas.webp",
		"load_07_chumak_oxcart.webp",
		"load_08_chumak_camp.webp",
		"load_09_bazaar.webp",
		"load_10_plague_doctor.webp",
		"load_11_mob.webp",
		"load_12_watchtower.webp",
		"load_13_kettles.webp",
	]
	for name in fallback:
		var full: String = IMAGES_DIR + str(name)
		if _images.has(full):
			continue
		if ResourceLoader.exists(full):
			_images.append(full)

	_images.shuffle()

func _collect_quote_keys() -> void:
	# Ищем все ключи load.q1, load.q2, ... пока натыкаемся на существующие
	_quote_keys.clear()
	var i := 1
	while true:
		var k := "load.q%d" % i
		if Loc.t(k) == k:
			break
		_quote_keys.append(k)
		i += 1
	_quote_keys.shuffle()

func _make_slide() -> TextureRect:
	var r := TextureRect.new()
	r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r

func _pick_texture() -> Texture2D:
	if _images.is_empty():
		return null
	var path: String = _images[randi() % _images.size()]
	if not ResourceLoader.exists(path):
		return null
	return load(path)

func _show_next_slide() -> void:
	var t := _pick_texture()
	if t == null:
		return
	if _slide_a.texture == null:
		_slide_a.texture = t
		return
	_slide_b.texture = t
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_slide_a, "modulate:a", 0.0, CROSSFADE)
	tw.tween_property(_slide_b, "modulate:a", 1.0, CROSSFADE)
	tw.chain().tween_callback(_swap_slides)

func _swap_slides() -> void:
	var tmp := _slide_a
	_slide_a = _slide_b
	_slide_b = tmp
	_slide_b.modulate.a = 0.0

func _show_next_quote() -> void:
	if _quote_keys.is_empty():
		return
	var text := Loc.t(str(_quote_keys[_quote_idx % _quote_keys.size()]))
	_quote_idx += 1
	# Плавная смена: фейд-аут, замена текста, фейд-ин
	if _quote.text == "":
		_quote.text = text
		_quote.modulate.a = 0.0
		var tw0 := create_tween()
		tw0.tween_property(_quote, "modulate:a", 1.0, 0.6)
		return
	var tw := create_tween()
	tw.tween_property(_quote, "modulate:a", 0.0, 0.4)
	tw.tween_callback(func(): _quote.text = text)
	tw.tween_property(_quote, "modulate:a", 1.0, 0.4)

func _process(delta: float) -> void:
	if _finished:
		return
	_elapsed += delta
	# Прогресс движется по времени, с ease-out — визуально приятнее ровной полосы
	var p: float = clamp(_elapsed / DURATION, 0.0, 1.0)
	var eased := 1.0 - pow(1.0 - p, 2.2)
	_bar.value = eased * 100.0

	# Смена слайда И цитаты синхронно, если до конца загрузки ещё есть время
	if _elapsed >= _next_slide_at and _next_slide_at + CROSSFADE < DURATION:
		_next_slide_at += SLIDE_INTERVAL
		_show_next_slide()
		_show_next_quote()

	if _elapsed >= DURATION:
		_finished = true
		var tw := create_tween()
		tw.tween_property(self, "modulate:a", 0.0, 0.5)
		tw.tween_callback(func():
			finished.emit()
			queue_free())
