extends Control
## DonateScreen — поддержка игры: просмотр рекламы (пока заглушка до подключения
## AdMob) и пожертвование на разработку (открывает ссылку DONATE_URL).

signal back_pressed

const DONATE_URL := "https://example.com/donate"   # ← замени на свою страницу доната

var _title: Label
var _body: Label
var _ad_btn: Button
var _debt_btn: Button
var _ad_hint: Label
var _support_btn: Button
var _back_btn: Button

func build() -> void:
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var bg := TextureRect.new()
	bg.texture = _safe_load("res://assets/art/bg_menu.jpg")
	if bg.texture == null:
		bg.texture = _safe_load("res://assets/art/bg_palace.png")
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	center.add_child(col)

	_title = Palette.label("", 26, Palette.PRIMARY, true)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_title)

	_body = Palette.label("", Palette.FS_BODY, Palette.ON_SURFACE_VARIANT)
	_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.custom_minimum_size = Vector2(300, 0)
	col.add_child(_body)

	_ad_btn = Button.new()
	_ad_btn.custom_minimum_size = Vector2(280, 52)
	Palette.style_glass_button(_ad_btn, true)
	_ad_btn.pressed.connect(_on_ad)      # заглушка: награда сразу; TODO ADMOB — реальный ролик
	col.add_child(_ad_btn)

	_ad_hint = Palette.label("", Palette.FS_LABEL, Palette.ON_SURFACE_VARIANT)
	_ad_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_ad_hint)

	_support_btn = Button.new()
	_support_btn.custom_minimum_size = Vector2(280, 52)
	Palette.style_glass_button(_support_btn, false)
	_support_btn.pressed.connect(func(): OS.shell_open(DONATE_URL))
	col.add_child(_support_btn)

	# Сжечь долг за ролик (видна только в минусе)
	_debt_btn = Button.new()
	_debt_btn.custom_minimum_size = Vector2(280, 46)
	Palette.style_glass_button(_debt_btn, true)
	_debt_btn.pressed.connect(_on_burn_debt)
	col.add_child(_debt_btn)

	# ── Покупки (заглушки до Google Play Billing) ──
	var iap_title := Palette.label_caps(" ", Palette.FS_LABEL, Palette.ON_SURFACE_VARIANT)
	iap_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	iap_title.name = "IapTitle"
	col.add_child(iap_title)
	for sku in ["noads", "starter", "hazna1", "hazna2", "hazna3", "firman"]:
		var b := Button.new()
		b.custom_minimum_size = Vector2(280, 42)
		Palette.style_glass_button(b, false)
		b.name = "Iap_" + sku
		b.pressed.connect(GameState.request_purchase.bind(sku))
		col.add_child(b)

	_back_btn = Button.new()
	_back_btn.custom_minimum_size = Vector2(280, 48)
	Palette.style_glass_button(_back_btn, false)
	_back_btn.pressed.connect(func(): back_pressed.emit())
	col.add_child(_back_btn)


func _animate_open() -> void:
	# Плавное открытие: фейд + лёгкий «наезд» (как у древа и дипломатии)
	pivot_offset = size / 2.0
	modulate.a = 0.0
	scale = Vector2(0.94, 0.94)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "modulate:a", 1.0, 0.2)
	tw.tween_property(self, "scale", Vector2.ONE, 0.26) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func open_screen() -> void:
	_title.text = Loc.t("donate.title")
	_body.text = Loc.t("donate.body")
	_ad_btn.text = Loc.t("donate.ad")
	_ad_hint.text = Loc.t("donate.ad_soon")
	_support_btn.text = Loc.t("donate.support")
	_back_btn.text = Loc.t("wheel.back")
	_debt_btn.text = "\u2696 " + Loc.t("donate.burn_debt")
	_debt_btn.visible = GameState.hazna < 0.0
	var it := find_child("IapTitle", true, false)
	if it != null:
		it.text = Loc.t("iap.title")
	for sku in ["noads", "starter", "hazna1", "hazna2", "hazna3", "firman"]:
		var b := find_child("Iap_" + sku, true, false)
		if b != null:
			b.text = Loc.t("iap." + sku)
	var was := visible
	visible = true
	if not was:
		_animate_open()

func _on_ad() -> void:
	GameState.request_rewarded("donate_hazna", _grant_ad)

func _grant_ad() -> void:
	GameState.hazna += 1000.0
	GameState.save_game()

func _on_burn_debt() -> void:
	if GameState.hazna >= 0.0:
		return
	GameState.request_rewarded("burn_debt", _grant_burn_debt)

func _grant_burn_debt() -> void:
	if GameState.hazna < 0.0:
		GameState.hazna = 0.0
	GameState.notify.emit(Loc.t("debt.forgiven"), true)
	GameState.save_game()
	_debt_btn.visible = false

func _safe_load(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path)
	var alt := path.get_basename() + ".webp"
	if ResourceLoader.exists(alt):
		return load(alt)
	return null
