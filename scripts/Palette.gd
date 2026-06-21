extends Node
## Palette — единый источник дизайн-токенов «Sunset of the Crescent» (ТЗ §21.2).
## Цвета взяты из утверждённой Material-схемы макетов (DESIGN.md / §21.2.1).

# ── Цвета (§21.2.1) ───────────────────────────────────────────────
const SURFACE             := Color("#131313")  # Угольный «войд» империи
const SURFACE_LOWEST      := Color("#0e0e0e")
const SURFACE_LOW         := Color("#1b1c1c")
const SURFACE_CONTAINER   := Color("#1f2020")
const SURFACE_HIGH        := Color("#2a2a2a")
const SURFACE_HIGHEST     := Color("#353535")
const ON_SURFACE          := Color("#e4e2e1")  # Основной текст
const ON_SURFACE_VARIANT  := Color("#d0c5af")  # Вторичный (тёплый пергамент)
const OUTLINE             := Color("#99907c")
const OUTLINE_VARIANT     := Color("#4d4635")

const PRIMARY             := Color("#f2ca50")  # Imperial Gold
const PRIMARY_CONTAINER   := Color("#d4af37")
const ON_PRIMARY          := Color("#3c2f00")
const PRIMARY_FIXED       := Color("#ffe088")  # светлое золото (блики печати)

const SECONDARY           := Color("#70db9d")  # Ottoman Emerald — стабильность/рост
const SECONDARY_CONTAINER := Color("#008650")
const ON_SECONDARY        := Color("#00391f")

const TERTIARY            := Color("#ff968f")  # Sultan's Crimson — военное/тревога
const ON_TERTIARY         := Color("#68000a")
const CRIMSON_DEEP        := Color("#a31d1d")
const CRIMSON_WAX         := Color("#68000a")

const ERROR               := Color("#ffb4ab")
const ERROR_CONTAINER     := Color("#93000a")  # бейдж HIGH RISK

const PARCHMENT           := Color("#f4ecd8")  # поверхность модалок/Летописи
const PARCHMENT_DIM       := Color("#e9e0c9")
const ON_PARCHMENT        := Color("#3a2f1a")

# ── Spacing (§21.2.4) ─────────────────────────────────────────────
const SAFE_AREA   := 20
const GUTTER      := 14
const NAV_HEIGHT  := 78

# ── Типографика — размеры (§21.2.2). Шрифты-семейства подменяются ──
# Bricolage Grotesque / Source Serif 4 / Metrophobic, если положены в assets/fonts.
const FS_HEADLINE   := 28
const FS_TITLE      := 22
const FS_BODY_LG    := 18
const FS_BODY       := 16
const FS_LABEL      := 12

var theme: Theme

# Опциональные шрифты (если пользователь положил TTF в assets/fonts)
var font_display: Font   # Bricolage Grotesque
var font_serif: Font     # Source Serif 4
var font_label: Font     # Metrophobic

func _ready() -> void:
	_load_fonts()
	theme = Theme.new()
	theme.default_font_size = FS_BODY
	if font_serif:
		theme.default_font = font_serif

func _load_fonts() -> void:
	# Подхватываем шрифты, если они есть; иначе остаётся дефолтный шрифт Godot.
	font_display = _try_font("res://assets/fonts/BricolageGrotesque.ttf")
	font_serif   = _try_font("res://assets/fonts/SourceSerif4.ttf")
	font_label   = _try_font("res://assets/fonts/Metrophobic.ttf")

func _try_font(path: String) -> Font:
	if ResourceLoader.exists(path):
		var f = load(path)
		if f is Font:
			return f
	return null

# ── Форматирование чисел (k / M / B / T) ──────────────────────────
func fmt(v: float) -> String:
	var neg := v < 0.0
	var n := absf(v)
	var s := ""
	if n < 1000.0:
		s = str(int(round(n)))
	elif n < 1_000_000.0:
		s = _trim(n / 1000.0) + "k"
	elif n < 1_000_000_000.0:
		s = _trim(n / 1_000_000.0) + "M"
	elif n < 1_000_000_000_000.0:
		s = _trim(n / 1_000_000_000.0) + "B"
	else:
		s = _trim(n / 1_000_000_000_000.0) + "T"
	return ("-" if neg else "") + s

func _trim(x: float) -> String:
	return ("%.1f" % x).trim_suffix(".0")

# Целое с разделителями тысяч (для Имперского престижа: 48,250)
func fmt_int(v: int) -> String:
	var neg := v < 0
	var digits := str(absi(v))
	var out := ""
	var c := 0
	for i in range(digits.length() - 1, -1, -1):
		out = digits[i] + out
		c += 1
		if c % 3 == 0 and i != 0:
			out = "," + out
	return ("-" if neg else "") + out

# ── StyleBox-помощники ────────────────────────────────────────────
func box(bg: Color, radius: int = 8, bw: int = 0, bc: Color = Color.TRANSPARENT, pad: int = 14) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	if bw > 0:
		sb.set_border_width_all(bw)
		sb.border_color = bc
	sb.content_margin_left = pad
	sb.content_margin_right = pad
	sb.content_margin_top = pad
	sb.content_margin_bottom = pad
	return sb

# Тезхип-рамка: тёмная карточка с двойным золотым контуром (§21.3)
func tezhip(bg: Color = SURFACE_CONTAINER, radius: int = 10, pad: int = 16) -> StyleBoxFlat:
	var sb := box(bg, radius, 2, PRIMARY, pad)
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_size = 6
	return sb

# Восковая кнопка-печать (§21.3): золото — мирное, кримсон — военное
func wax_button(gold: bool = true) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	if gold:
		sb.bg_color = PRIMARY_CONTAINER
		sb.border_color = PRIMARY_FIXED
	else:
		sb.bg_color = CRIMSON_DEEP
		sb.border_color = TERTIARY
	sb.set_corner_radius_all(8)
	sb.set_border_width_all(1)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	sb.shadow_color = Color(0, 0, 0, 0.4)
	sb.shadow_size = 4
	sb.shadow_offset = Vector2(0, 2)
	return sb

# Применить wax-стиль к Button во всех состояниях
func style_button(btn: Button, gold: bool = true) -> void:
	var normal := wax_button(gold)
	var hover := wax_button(gold)
	hover.bg_color = normal.bg_color.lightened(0.06)
	var pressed := wax_button(gold)
	pressed.bg_color = normal.bg_color.darkened(0.12)
	pressed.shadow_size = 1
	var disabled := wax_button(gold)
	disabled.bg_color = SURFACE_HIGH
	disabled.border_color = OUTLINE_VARIANT
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("disabled", disabled)
	btn.add_theme_color_override("font_color", ON_PRIMARY if gold else ON_SURFACE)
	btn.add_theme_color_override("font_hover_color", ON_PRIMARY if gold else ON_SURFACE)
	btn.add_theme_color_override("font_pressed_color", ON_PRIMARY if gold else ON_SURFACE)
	btn.add_theme_color_override("font_disabled_color", OUTLINE)
	btn.add_theme_font_size_override("font_size", FS_BODY)
	if font_label:
		btn.add_theme_font_override("font", font_label)

# ── Конструкторы виджетов ─────────────────────────────────────────
func label(text: String, size: int = FS_BODY, color: Color = ON_SURFACE, display := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if display and font_display:
		l.add_theme_font_override("font", font_display)
	elif not display and font_serif:
		l.add_theme_font_override("font", font_serif)
	return l

func label_caps(text: String, size: int = FS_LABEL, color: Color = ON_SURFACE_VARIANT) -> Label:
	var l := label(text.to_upper(), size, color)
	if font_label:
		l.add_theme_font_override("font", font_label)
	l.add_theme_constant_override("line_spacing", 2)
	return l

# ── Замок пропорций для TextureRect: высота = ширина × aspect_hw ───
# Показывает текстуру целиком без обрезки и адаптируется под любую ширину.
func lock_texture_aspect(tr: TextureRect, aspect_hw: float) -> void:
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var apply := func():
		if not is_instance_valid(tr):
			return
		var target: float = tr.size.x * aspect_hw
		if absf(tr.custom_minimum_size.y - target) > 1.0:
			tr.custom_minimum_size.y = target
	tr.resized.connect(apply)
	apply.call_deferred()
