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

var _modal
var _event_intro
var _coup_screen
var _settings
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
	if ResourceLoader.exists("res://assets/art/bg_palace.png"):
		var bg_img := TextureRect.new()
		bg_img.texture = load("res://assets/art/bg_palace.png")
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
		_event_intro.hide_intro()   # прячем заставку
		_modal.show_current()       # и показываем окно события поверх всего

	# Экран конца игры (переворот)
	_coup_screen = load("res://scripts/ui/CoupScreen.gd").new()
	_overlay_layer.add_child(_coup_screen)
	_coup_screen.build()
	_coup_screen.on_restart = func():
		GameState.start_over()
		_coup_screen.hide_over()

	_settings = load("res://scripts/ui/SettingsPanel.gd").new()
	_overlay_layer.add_child(_settings)
	_settings.build()
	_settings.language_toggled.connect(_rebuild_all)

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
	GameState.coup_triggered.connect(func(): _coup_screen.show_over())

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
	_hud.gear_pressed = func(): _settings.open()
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

	# ── Нижняя навигация ──
	_layout.add_child(_build_nav())
	_highlight_nav()

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
	var cap := Palette.label_caps(Loc.t("nav." + tab.key), Palette.FS_LABEL, Palette.ON_SURFACE_VARIANT)
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
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

func _switch_tab(key: String) -> void:
	if key == _active:
		return
	_views[_active].visible = false
	_active = key
	_views[_active].visible = true
	_views[_active].update_view()
	_highlight_nav()

func _highlight_nav() -> void:
	for key in _nav_tabs:
		var t: Dictionary = _nav_tabs[key]
		if key == _active:
			var pill_sb := Palette.box(Palette.PRIMARY_CONTAINER, 14, 0, Color.TRANSPARENT, 4)
			t.pill.add_theme_stylebox_override("panel", pill_sb)
			t.icon.add_theme_color_override("font_color", Palette.ON_PRIMARY)
			t.cap.add_theme_color_override("font_color", Palette.ON_PRIMARY)
		else:
			t.pill.add_theme_stylebox_override("panel", Palette.box(Color.TRANSPARENT, 14, 0))
			t.icon.add_theme_color_override("font_color", Palette.ON_SURFACE_VARIANT)
			t.cap.add_theme_color_override("font_color", Palette.ON_SURFACE_VARIANT)

func _rebuild_all() -> void:
	# Полная пересборка интерфейса при смене языка/правления.
	_layout.queue_free()
	_views.clear()
	_nav_tabs.clear()
	await get_tree().process_frame
	_build_ui()

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
	var bg := Palette.SECONDARY_CONTAINER if good else Palette.CRIMSON_DEEP
	toast.add_theme_stylebox_override("panel", Palette.box(bg, 8, 0, Color.TRANSPARENT, 12))
	toast.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var l := Palette.label(text, Palette.FS_BODY, Palette.PARCHMENT)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
	if _hud:
		_hud.update_view()
	if _views.has(_active):
		_views[_active].update_view()
	# Появилось событие во время игры — показать заставку с гонцом
	if GameState.active_event != null and not _modal.visible and not _event_intro.visible:
		_present_event()

func _notification(what: int) -> void:
	# Жест «назад»/сворачивание (Android) — сохраняемся (§5.2, §26.1)
	if what == NOTIFICATION_WM_GO_BACK_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		GameState.save_game()
	elif what == NOTIFICATION_WM_CLOSE_REQUEST:
		GameState.save_game()
