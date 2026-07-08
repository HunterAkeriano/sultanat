extends Control
## RingGauge — круговой индикатор престижа (референс «Dynasty»: круг-гейдж
## #353535 трек + золотая дуга, старт сверху). Рисуется вручную через _draw.

var progress: float = 0.0:
	set(value):
		var v := clampf(value, 0.0, 1.0)
		if absf(v - progress) < 0.0001:
			return
		progress = v
		queue_redraw()

var track_color: Color = Color("#353535")
var fill_color: Color = Color("#f2ca50")
var ring_width: float = 6.0

func _draw() -> void:
	var c := size / 2.0
	var r := minf(size.x, size.y) / 2.0 - ring_width
	if r <= 0.0:
		return
	# Трек (полный круг)
	draw_arc(c, r, 0.0, TAU, 96, track_color, ring_width, true)
	# Заполнение от верхней точки по часовой стрелке
	if progress > 0.0:
		var start := -PI / 2.0
		var end := start + TAU * progress
		draw_arc(c, r, start, end, 96, fill_color, ring_width, true)
