extends Control
## Main — корневой контроллер игрового экрана (§5.1, §21.4). Собирает фон, HUD,
## область из 5 вкладок, нижнюю навигацию с золотой «пилюлей», оверлеи
## (модалка события, тосты, настройки). Тик: обновляет HUD и активную вкладку.

const TABS := [
	{"key": "throne",       "icon": "\u265B", "script": "res://scripts/ui/ThroneView.gd"},        # ♛
	{"key": "provinces",    "icon": "\u2691", "script": "res://scripts/ui/ProvincesView.gd"}, # 
	{"key": "institutions", "icon": "\u265C", "script": "res://scripts/ui/InstitutionsView.gd"}, # 
	{"key": "events",       "icon": "\u2605", "script": "res://scripts/ui/EventsView.gd"},    # 
	{"key": "dynasty",      "icon": "\u265A", "script": "res://scripts/ui/DynastyView.gd"},   # 
]

var _layout: VBoxContainer
var _content: Control
var _hud
var _nav_tabs := {}
var _views := {}
var _active := "throne"

# Интерактивное листание страниц пальцем
var _drag_pointer := ""          # "touch" / "mouse" — кто ведёт жест
var _drag_pending := false       # касание началось, ещё не решили — листание это или прокрутка
var _drag_active := false        # листание захвачено
var _drag_start := Vector2.ZERO
var _drag_from: Control = null   # текущая страница
var _drag_to: Control = null     # соседняя страница (появляется со стороны)
var _drag_to_key := ""
var _drag_dir := 0               # +1 следующая (палец влево), -1 предыдущая (палец вправо)
var _drag_w := 0.0
var _slide_tween: Tween

# Кинетическая (инерционная) прокрутка + защита от случайных нажатий
var _fling_sc: ScrollContainer = null   # контейнер, который сейчас докручивается по инерции
var _fling_v := 0.0                     # скорость пальца, px/с (сглаженная)
var _fling_pos := 0.0                   # накопленная позиция (float — для плавности)
var _scroll_acc := 0.0                  # остаток субпиксельного сдвига при ведении пальцем
var _scroll_dist := 0.0                 # накопленный путь жеста (для порога захвата)
var _scroll_captured := false           # жест признан прокруткой — нажатия кнопок отменены
var _last_drag_ms := 0                  # время прошлого drag-события (для скорости)

const FLING_START_V := 150.0            # мин. скорость отпускания для инерции, px/с
const FLING_FRICTION := 4.0             # коэффициент трения (чем больше — тем быстрее гаснет)
const FLING_STOP_V := 30.0              # ниже этой скорости инерция останавливается
const SCROLL_CAPTURE_DIST := 8.0        # после этого пути жест считается прокруткой
var _ui_tick := 0.0                     # троттлинг обновления текстов UI (20 Гц)

var _modal
var _event_intro
var _coup_screen
var _settings
var _menu
var _wheel_screen
var _donate_screen
var _overlay_layer: CanvasLayer
var _toast_box: VBoxContainer

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Фон — угольный «войд» империи (§21.1)
	var bg := ColorRect.new()
	bg.color = Palette.SURFACE
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Художественный фон: дворец под звёздным небом (заполняет экран по высоте).
	# _bg_tex() пробует .png (старое имя), затем .webp (после оптимизации).
	var bg_tex := _bg_tex()
	if bg_tex != null:
		var bg_img := TextureRect.new()
		bg_img.texture = bg_tex
		bg_img.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		bg_img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bg_img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		bg_img.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(bg_img)

	_build_ui()

	# Оверлеи живут в отдельном CanvasLayer — он всегда поверх игрового слоя
	# (layer 0), независимо от порядка детей и пересборок _rebuild_all.
	_overlay_layer = CanvasLayer.new()
	_overlay_layer.layer = 10
	add_child(_overlay_layer)

	_modal = load("res://scripts/ui/EventModal.gd").new()
	_overlay_layer.add_child(_modal)
	_modal.build()

	# Заставка с гонцом — открывается перед самим событием
	_event_intro = load("res://scripts/ui/EventIntro.gd").new()
	_overlay_layer.add_child(_event_intro)
	_event_intro.build()
	_event_intro.on_open = func():
		var sx := get_node_or_null("/root/Sfx")
		if sx != null:
			sx.open_letter()
		_event_intro.hide_intro()   # прячем заставку
		_modal.show_current()       # и показываем окно события поверх всего

	# Экран конца игры (переворот)
	_coup_screen = load("res://scripts/ui/CoupScreen.gd").new()
	_overlay_layer.add_child(_coup_screen)
	_coup_screen.build()
	_coup_screen.on_restart = func():
		var sx := get_node_or_null("/root/Sfx")
		if sx != null:
			sx.restart()             # звук меча
		var vo := get_node_or_null("/root/Voice")
		if vo != null:
			vo.stop()                # оборвать озвучку «Вас свергли»
		GameState.start_over()
		_coup_screen.hide_over()

	_settings = load("res://scripts/ui/SettingsPanel.gd").new()
	_overlay_layer.add_child(_settings)
	_settings.build()
	_settings.language_toggled.connect(_rebuild_all)
	_settings.language_toggled.connect(func():
		if _menu != null and _menu.visible:
			_menu.open_menu())

	# ── Главное меню + экраны колеса удачи и доната ──
	_menu = load("res://scripts/ui/MenuScreen.gd").new()
	_overlay_layer.add_child(_menu)
	_menu.build()
	_wheel_screen = load("res://scripts/ui/WheelScreen.gd").new()
	_overlay_layer.add_child(_wheel_screen)
	_wheel_screen.build()
	_donate_screen = load("res://scripts/ui/DonateScreen.gd").new()
	_overlay_layer.add_child(_donate_screen)
	_donate_screen.build()
	# Настройки создаются раньше меню и оказывались ПОД ним — поднимаем наверх,
	# чтобы панель открывалась и поверх главного меню.
	_overlay_layer.move_child(_settings, _overlay_layer.get_child_count() - 1)
	_menu.play_pressed.connect(func(): _menu.close_menu())
	_menu.wheel_pressed.connect(func():
		_menu.visible = false
		_wheel_screen.open_screen())
	_menu.settings_pressed.connect(func(): _settings.open())
	_menu.donate_pressed.connect(func():
		_menu.visible = false
		_donate_screen.open_screen())
	_wheel_screen.back_pressed.connect(func():
		_wheel_screen.visible = false
		_menu.open_menu(true))
	_donate_screen.back_pressed.connect(func():
		_donate_screen.visible = false
		_menu.open_menu(true))
	_menu.open_menu(true)   # при запуске игрок попадает в меню (мгновенно, без мигания игры)
	# Заставка загрузки: слайдшоу + случайная цитата. Показывается ПОВЕРХ
	# меню, пока крутится. Скрывается сама и удаляется по завершении.
	var LoadingScreenScript := load("res://scripts/ui/LoadingScreen.gd")
	if LoadingScreenScript != null:
		var loading: Node = LoadingScreenScript.new()
		_overlay_layer.add_child(loading)
		# Меню на первом кадре может «мигнуть» до заставки — заставка перекрывает.
		# Настройки/донат заранее прячем на всякий случай, пока крутится заставка.
	GameState.claim_daily()   # ежедневная награда за вход
	GameState.energy_depleted.connect(func():
		if not _menu.visible:
			_menu.open_menu())

	_toast_box = VBoxContainer.new()
	_toast_box.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_toast_box.offset_bottom = -(Palette.NAV_HEIGHT + 12)
	_toast_box.offset_top = -240
	_toast_box.alignment = BoxContainer.ALIGNMENT_END
	_toast_box.add_theme_constant_override("separation", 6)
	_toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay_layer.add_child(_toast_box)

	# Сигналы симуляции
	GameState.notify.connect(_on_notify)
	GameState.event_started.connect(_on_event_started)
	GameState.event_resolved.connect(func(): _event_intro.hide_intro())
	GameState.reign_changed.connect(_rebuild_all)
	GameState.coup_triggered.connect(func():
		_event_intro.hide_intro()   # переворот закрывает гонца и письмо —
		_modal.visible = false      # поверх «Вас свергли» ничего не открывается
		_coup_screen.show_over())

	# Если есть отложенное событие при запуске
	if GameState.active_event != null:
		_present_event()

	# Попап офлайн-дохода (§26)
	if GameState.pending_offline > 1.0:
		_settings.show_offline(GameState.pending_offline)
		GameState.pending_offline = 0.0

func _build_ui() -> void:
	_layout = VBoxContainer.new()
	_layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_layout.add_theme_constant_override("separation", 0)
	add_child(_layout)

	# ── HUD (фиксированная высота сверху) ──
	_hud = load("res://scripts/ui/Hud.gd").new()
	_hud.custom_minimum_size = Vector2(0, 150)
	_hud.menu_pressed = func(): _menu.open_menu()
	_layout.add_child(_hud)
	_hud.build()

	# ── Область вкладок (растягивается) ──
	_content = Control.new()
	_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content.clip_contents = true
	_layout.add_child(_content)

	for tab in TABS:
		var view = load(tab.script).new()
		view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		view.visible = (tab.key == _active)
		_content.add_child(view)
		view.build()
		_views[tab.key] = view

	# Прячем полосы прокрутки во всех экранах (скролл пальцем/перетаскиванием остаётся).
	for v in _views.values():
		_hide_scrollbars(v)

	# Край контента «растворяется» у рамки: полоска поверх кромки рисует ТОТ ЖЕ фон
	# (та же COVER-раскладка) с альфа-градиентом — контент тает, разницы цветов нет.
	var etex_bg := _bg_tex()
	if etex_bg != null:
		var edge := TextureRect.new()
		var etex: Texture2D = etex_bg
		edge.texture = etex
		edge.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		edge.stretch_mode = TextureRect.STRETCH_SCALE
		var esh := Shader.new()
		esh.code = """
shader_type canvas_item;
uniform vec2 view_size;
uniform vec2 tex_size;
varying vec2 world;
void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}
void fragment() {
	float s = max(view_size.x / tex_size.x, view_size.y / tex_size.y);
	vec2 draw = tex_size * s;
	vec2 off = (view_size - draw) * 0.5;
	vec2 uv = (world - off) / draw;
	vec4 c = texture(TEXTURE, clamp(uv, vec2(0.0), vec2(1.0)));
	c.a = pow(clamp(1.0 - UV.y, 0.0, 1.0), 1.35);
	COLOR = c;
}
"""
		var em := ShaderMaterial.new()
		em.shader = esh
		em.set_shader_parameter("view_size", get_viewport_rect().size)
		em.set_shader_parameter("tex_size", Vector2(etex.get_width(), etex.get_height()))
		edge.material = em
		edge.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
		edge.offset_bottom = 48
		edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_content.add_child(edge)

	# ── Нижняя навигация ──
	_layout.add_child(_build_nav())
	_highlight_nav()

func _vscroll(dy: float) -> bool:
	# Вертикальная прокрутка активного экрана пальцем (работает над любым контентом).
	if _overlay_open():
		return false
	var sc := _active_scroll()
	if sc == null:
		return false
	# Защита от случайных нажатий: как только палец прошёл порог — жест
	# считается прокруткой, и всем кнопкам отправляется отмена нажатия.
	_scroll_dist += absf(dy)
	if not _scroll_captured and _scroll_dist > SCROLL_CAPTURE_DIST:
		_scroll_captured = true
		if is_instance_valid(_layout):
			_layout.propagate_notification(Control.NOTIFICATION_SCROLL_BEGIN)
	# Замер скорости пальца (сглаженный) — для инерции после отпускания.
	var now := Time.get_ticks_msec()
	var dt := clampf(float(now - _last_drag_ms) / 1000.0, 0.001, 0.1)
	_last_drag_ms = now
	_fling_v = lerpf(_fling_v, dy / dt, 0.4)
	# Сдвиг с накоплением дробной части (иначе мелкие движения теряются).
	_scroll_acc += dy
	var step := int(_scroll_acc)
	if step != 0:
		sc.scroll_vertical -= step
		_scroll_acc -= float(step)
	return true

func _active_scroll() -> ScrollContainer:
	var view = _views.get(_active, null)
	if view == null:
		return null
	return _find_scroll(view)

func _find_scroll(node: Node) -> ScrollContainer:
	if node is ScrollContainer:
		return node
	for c in node.get_children():
		var r := _find_scroll(c)
		if r != null:
			return r
	return null

func _hide_scrollbars(node: Node) -> void:
	if node is ScrollContainer:
		for bar in [node.get_v_scroll_bar(), node.get_h_scroll_bar()]:
			if bar != null:
				for sname in ["scroll", "scroll_focus", "grabber", "grabber_highlight", "grabber_pressed"]:
					bar.add_theme_stylebox_override(sname, StyleBoxEmpty.new())
				bar.custom_minimum_size = Vector2.ZERO
	for child in node.get_children():
		_hide_scrollbars(child)

func _build_nav() -> PanelContainer:
	var bar := PanelContainer.new()
	bar.custom_minimum_size = Vector2(0, Palette.NAV_HEIGHT)
	var sb := Palette.box(Palette.SURFACE_LOWEST, 0, 0, Color.TRANSPARENT, 6)
	sb.border_width_top = 1
	sb.border_color = Palette.OUTLINE_VARIANT
	bar.add_theme_stylebox_override("panel", sb)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	bar.add_child(row)
	_nav_tabs.clear()
	for tab in TABS:
		row.add_child(_make_tab(tab))
	return bar

func _make_tab(tab: Dictionary) -> Control:
	var holder := Control.new()
	holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	holder.custom_minimum_size = Vector2(0, Palette.NAV_HEIGHT - 12)
	holder.clip_contents = false  # подписи вкладок не обрезаем; длинные (Institutions) должны уместиться шрифтом

	var pill := PanelContainer.new()
	pill.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.add_child(pill)

	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 2)
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill.add_child(v)

	var ico := Palette.label(tab.icon, 18, Palette.ON_SURFACE_VARIANT)
	ico.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ico.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(ico)
	# Мелкий шрифт: длинные «Institutions» / «Институты» помещаются в слот
	var cap := Palette.label_caps(Loc.t("nav." + tab.key), 10, Palette.ON_SURFACE_VARIANT)
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cap.autowrap_mode = TextServer.AUTOWRAP_OFF
	cap.clip_text = false
	cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(cap)

	var btn := Button.new()
	btn.flat = true
	btn.focus_mode = Control.FOCUS_NONE
	btn.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	btn.pressed.connect(func(): _switch_tab(tab.key))
	holder.add_child(btn)

	_nav_tabs[tab.key] = {"pill": pill, "icon": ico, "cap": cap}
	return holder

func _switch_tab(key: String, dir: int = 0) -> void:
	if key == _active or not _views.has(key):
		return
	var sx := get_node_or_null("/root/Sfx")
	if sx != null:
		sx.page_flip()
	var old_view: Control = _views[_active]
	var new_view: Control = _views[key]
	if dir == 0:
		dir = 1 if _tab_index(key) > _tab_index(_active) else -1
	_active = key
	new_view.update_view()
	_highlight_nav()
	_animate_slide(old_view, new_view, dir)

func _tab_index(key: String) -> int:
	for i in TABS.size():
		if TABS[i].key == key:
			return i
	return 0

func _set_view_full(v: Control) -> void:
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _set_view_free(v: Control, x: float) -> void:
	v.set_anchors_preset(Control.PRESET_TOP_LEFT)
	v.size = _content.size
	v.position = Vector2(x, 0)

func _animate_slide(old_view: Control, new_view: Control, dir: int) -> void:
	var w := _content.size.x
	if w <= 1.0:
		old_view.visible = false
		new_view.visible = true
		return
	if _slide_tween != null and _slide_tween.is_valid():
		_slide_tween.kill()
	for k in _views:
		if _views[k] != old_view and _views[k] != new_view:
			_views[k].visible = false
			_set_view_full(_views[k])
	_set_view_free(old_view, 0.0)
	_set_view_free(new_view, dir * w)   # новая приходит со стороны свайпа
	new_view.visible = true
	_slide_tween = create_tween()
	_slide_tween.set_parallel(true)
	_slide_tween.set_trans(Tween.TRANS_CUBIC)
	_slide_tween.set_ease(Tween.EASE_OUT)
	_slide_tween.tween_property(new_view, "position:x", 0.0, 0.24)
	_slide_tween.tween_property(old_view, "position:x", -dir * w, 0.24)
	_slide_tween.chain().tween_callback(_finish_slide.bind(old_view, new_view))

func _finish_slide(old_view: Control, new_view: Control) -> void:
	old_view.visible = false
	_set_view_full(old_view)
	_set_view_full(new_view)

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			if _drag_pointer == "":
				_drag_pointer = "touch"
				_drag_begin(event.position)
		elif _drag_pointer == "touch":
			_drag_end()
			_drag_pointer = ""
	elif event is InputEventScreenDrag:
		if _drag_pointer == "touch":
			if _drag_move(event.position):
				get_viewport().set_input_as_handled()
			else:
				if _vscroll(event.relative.y):
					get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if _drag_pointer == "":
				_drag_pointer = "mouse"
				_drag_begin(event.position)
		elif _drag_pointer == "mouse":
			_drag_end()
			_drag_pointer = ""
	elif event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT):
		if _drag_pointer == "mouse":
			if _drag_move(event.position):
				get_viewport().set_input_as_handled()
			else:
				if _vscroll(event.relative.y):
					get_viewport().set_input_as_handled()

func _overlay_open() -> bool:
	if _modal.visible or _event_intro.visible or _coup_screen.visible or _settings.visible \
			or _menu.visible or _wheel_screen.visible or _donate_screen.visible:
		return true
	# Полноэкранные модалки вне слоя (например, семейное древо)
	for n in get_tree().get_nodes_in_group("fullscreen_modal"):
		if n.visible:
			return true
	return false

func _drag_begin(pos: Vector2) -> void:
	# Палец коснулся экрана — немедленно останавливаем инерционный докрут.
	_fling_sc = null
	_fling_v = 0.0
	_scroll_acc = 0.0
	_scroll_dist = 0.0
	_scroll_captured = false
	_last_drag_ms = Time.get_ticks_msec()
	if _overlay_open():
		_drag_pending = false
		return
	_drag_pending = true
	_drag_active = false
	_drag_start = pos
	_drag_w = _content.size.x

# Возвращает true, если жест захвачен как листание (тогда событие гасим).
func _drag_move(pos: Vector2) -> bool:
	if not _drag_pending and not _drag_active:
		return false
	var d := pos - _drag_start
	if not _drag_active:
		if absf(d.x) < 12.0 and absf(d.y) < 12.0:
			return false                       # ещё мало двигались — ждём
		if absf(d.x) <= absf(d.y):
			_drag_pending = false              # вертикаль — отдаём прокрутке списков
			return false
		_begin_horizontal_drag(d.x)
	if _drag_active:
		_update_drag(d.x)
		return true
	return false

func _begin_horizontal_drag(dx: float) -> void:
	if _slide_tween != null and _slide_tween.is_valid():
		_slide_tween.kill()
	_drag_active = true
	_drag_pending = false
	# Листание страниц — тоже жест: отменяем начатые нажатия кнопок.
	if not _scroll_captured:
		_scroll_captured = true
		if is_instance_valid(_layout):
			_layout.propagate_notification(Control.NOTIFICATION_SCROLL_BEGIN)
	_drag_from = _views[_active]
	_drag_dir = 1 if dx < 0.0 else -1          # палец влево → следующая
	var ni := _tab_index(_active) + _drag_dir
	if ni < 0 or ni >= TABS.size():
		_drag_to = null
		_drag_to_key = ""
	else:
		_drag_to_key = TABS[ni].key
		_drag_to = _views[_drag_to_key]
		_drag_to.visible = true
		_drag_to.update_view()
	# спрячем прочие страницы
	for k in _views:
		if _views[k] != _drag_from and _views[k] != _drag_to:
			_views[k].visible = false
	_set_view_free(_drag_from, 0.0)
	if _drag_to != null:
		_set_view_free(_drag_to, _drag_dir * _drag_w)

func _update_drag(dx: float) -> void:
	if _drag_to == null:
		dx *= 0.3                              # резинка на краю списка
	_set_view_free(_drag_from, dx)
	if _drag_to != null:
		_set_view_free(_drag_to, dx + _drag_dir * _drag_w)

func _drag_end() -> void:
	_scroll_release()
	if not _drag_active:
		_drag_pending = false
		return
	_drag_active = false
	_drag_pending = false
	var from_v := _drag_from
	var to_v := _drag_to
	var dir := _drag_dir
	var w := _drag_w
	var key := _drag_to_key
	_drag_from = null
	_drag_to = null
	if to_v != null and absf(from_v.position.x) > w * 0.26:
		_commit_drag(from_v, to_v, dir, w, key)   # дотащили — перелистываем
	else:
		_cancel_drag(from_v, to_v, dir, w)        # вернуть назад

func _scroll_release() -> void:
	# Палец отпущен: закрываем жест прокрутки и, если скорость достаточная,
	# запускаем плавный инерционный докрут (гаснет в _process).
	if not _scroll_captured:
		return
	if is_instance_valid(_layout):
		_layout.propagate_notification(Control.NOTIFICATION_SCROLL_END)
	_scroll_captured = false
	if absf(_fling_v) > FLING_START_V and not _overlay_open():
		var sc := _active_scroll()
		if sc != null:
			_fling_sc = sc
			_fling_pos = float(sc.scroll_vertical)

func _commit_drag(from_v: Control, to_v: Control, dir: int, w: float, key: String) -> void:
	_active = key
	_highlight_nav()
	var sx := get_node_or_null("/root/Sfx")
	if sx != null:
		sx.page_flip()                            # звук — только при окончательном перелистывании
	if _slide_tween != null and _slide_tween.is_valid():
		_slide_tween.kill()
	_slide_tween = create_tween()
	_slide_tween.set_parallel(true)
	_slide_tween.set_trans(Tween.TRANS_CUBIC)
	_slide_tween.set_ease(Tween.EASE_OUT)
	_slide_tween.tween_property(to_v, "position:x", 0.0, 0.16)
	_slide_tween.tween_property(from_v, "position:x", -dir * w, 0.16)
	_slide_tween.chain().tween_callback(_finish_slide.bind(from_v, to_v))

func _cancel_drag(from_v: Control, to_v: Control, dir: int, w: float) -> void:
	if _slide_tween != null and _slide_tween.is_valid():
		_slide_tween.kill()
	_slide_tween = create_tween()
	_slide_tween.set_parallel(true)
	_slide_tween.set_trans(Tween.TRANS_CUBIC)
	_slide_tween.set_ease(Tween.EASE_OUT)
	_slide_tween.tween_property(from_v, "position:x", 0.0, 0.16)
	if to_v != null:
		_slide_tween.tween_property(to_v, "position:x", dir * w, 0.16)
	_slide_tween.chain().tween_callback(_finish_cancel.bind(from_v, to_v))

func _finish_cancel(from_v: Control, to_v: Control) -> void:
	if to_v != null:
		to_v.visible = false
		_set_view_full(to_v)
	_set_view_full(from_v)

func _highlight_nav() -> void:
	for key in _nav_tabs:
		var t: Dictionary = _nav_tabs[key]
		if key == _active:
			# Отступы как у неактивной (2), иначе пилюля растёт и налезает на соседей.
			var pill_sb := Palette.box(Palette.PRIMARY_CONTAINER, 12, 0, Color.TRANSPARENT, 2)
			t.pill.add_theme_stylebox_override("panel", pill_sb)
			t.icon.add_theme_color_override("font_color", Palette.ON_PRIMARY)
			t.cap.add_theme_color_override("font_color", Palette.ON_PRIMARY)
		else:
			t.pill.add_theme_stylebox_override("panel", Palette.box(Color.TRANSPARENT, 12, 0, Color.TRANSPARENT, 2))
			t.icon.add_theme_color_override("font_color", Palette.ON_SURFACE_VARIANT)
			t.cap.add_theme_color_override("font_color", Palette.ON_SURFACE_VARIANT)

func _rebuild_all() -> void:
	# Полная пересборка интерфейса при смене языка/правления.
	# Тексты оверлеев (EventIntro/EventModal/CoupScreen) «запечены» в их build(),
	# поэтому пересобираем и их тоже; открытые экраны возвращаем уже на новом языке.
	# (MenuScreen/WheelScreen/DonateScreen сами обновляют тексты в open_*().)
	var modal_open: bool = _modal.visible
	var intro_open: bool = _event_intro.visible
	var coup_open: bool = _coup_screen.visible
	_layout.queue_free()
	_views.clear()
	_nav_tabs.clear()
	await get_tree().process_frame
	_build_ui()
	for w in [_modal, _event_intro, _coup_screen]:
		for c in w.get_children():
			c.queue_free()
		w.build()
	if coup_open and GameState.game_over:
		# Возвращаем экран переворота только если игра ВСЁ ЕЩЁ окончена:
		# при «Начать сначала» reign_changed приходит до скрытия экрана,
		# и без проверки табличка «Вас свергли» воскресала после рестарта.
		_coup_screen.show_over()
	if GameState.active_event != null and not GameState.game_over:
		if modal_open:
			_modal.show_current()
		elif intro_open:
			_event_intro.show_intro()

func _on_event_started() -> void:
	_present_event()

func _present_event() -> void:
	# Сначала заставка с гонцом; окно событий откроется по «Открыть письмо».
	if _modal.visible or _event_intro.visible:
		return
	if GameState.active_event == null:
		return
	_event_intro.show_intro()

func _on_notify(text: String, good: bool) -> void:
	var toast := PanelContainer.new()
	toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Стиль игры: тёмное стекло, золотая рамка, мягкая тень (читается на любом фоне)
	var sb := Palette.box(Color(0.031, 0.039, 0.059, 0.85), 13, 1, Color(0.831, 0.686, 0.216, 0.45), 12)
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_size = 6
	toast.add_theme_stylebox_override("panel", sb)
	toast.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var tc := Color("#78dcb4") if good else Color("#ff8585")
	var l := Palette.label(text, Palette.FS_BODY, tc)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# Короткий текст — компактная «пилюля», длинный — перенос с ограничением по экрану
	var maxw := get_viewport_rect().size.x - Palette.SAFE_AREA * 2.0 - 28.0
	var natural := maxw
	var font := l.get_theme_font("font")
	if font != null:
		natural = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, Palette.FS_BODY).x + 2.0
	l.custom_minimum_size = Vector2(minf(natural, maxw), 0)
	toast.add_child(l)
	_toast_box.add_child(toast)
	toast.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(toast, "modulate:a", 1.0, 0.2)
	tw.tween_interval(2.2)
	tw.tween_property(toast, "modulate:a", 0.0, 0.5)
	tw.tween_callback(toast.queue_free)
	# Не копим слишком много тостов
	while _toast_box.get_child_count() > 4:
		var first := _toast_box.get_child(0)
		_toast_box.remove_child(first)
		first.queue_free()

func _process(_delta: float) -> void:
	# Инерционный докрут после отпускания пальца (плавно гаснет трением).
	if _fling_sc != null:
		if not is_instance_valid(_fling_sc) or _overlay_open():
			_fling_sc = null
		else:
			_fling_v *= exp(-FLING_FRICTION * _delta)
			_fling_pos -= _fling_v * _delta
			var target := int(roundf(_fling_pos))
			_fling_sc.scroll_vertical = target
			# Упёрлись в край списка (значение обрезалось) или скорость угасла — стоп.
			if _fling_sc.scroll_vertical != target or absf(_fling_v) < FLING_STOP_V:
				_fling_sc = null
				_fling_v = 0.0
	# Тексты HUD и активного экрана незачем пересобирать 120 раз в секунду —
	# на телефоне это главный источник рывков. 20 Гц глазу неотличимо.
	_ui_tick += _delta
	if _ui_tick >= 0.05:
		_ui_tick = 0.0
		if _hud:
			_hud.update_view()
		if _views.has(_active):
			_views[_active].update_view()
	# Появилось событие во время игры — показать заставку с гонцом
	if GameState.active_event != null and not _modal.visible and not _event_intro.visible:
		_present_event()

func _notification(what: int) -> void:
	# Жест «назад»/сворачивание (Android/десктоп) — ставим симуляцию на паузу
	# и сохраняемся. Пока игра свёрнута, события/тик стоят, но офлайн-сбор
	# Двора продолжает идти — начисляется при возврате.
	if what == NOTIFICATION_WM_GO_BACK_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED \
			or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		GameState.on_app_paused()
	elif what == NOTIFICATION_APPLICATION_RESUMED or what == NOTIFICATION_APPLICATION_FOCUS_IN:
		GameState.on_app_resumed()
		# Показать попап «пока тебя не было», если что-то накапало
		if GameState.pending_offline > 1.0 and _settings != null:
			_settings.show_offline(GameState.pending_offline)
			GameState.pending_offline = 0.0
	elif what == NOTIFICATION_WM_CLOSE_REQUEST:
		GameState.save_game()

func _bg_tex() -> Texture2D:
	# Фон дворца: после оптимизации размера картинки лежат в .webp, но код
	# ссылается на .png. Пробуем обе версии, чтобы работало и до, и после.
	if ResourceLoader.exists("res://assets/art/bg_palace.png"):
		return load("res://assets/art/bg_palace.png")
	if ResourceLoader.exists("res://assets/art/bg_palace.webp"):
		return load("res://assets/art/bg_palace.webp")
	return null
