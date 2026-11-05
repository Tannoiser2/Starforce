class_name UI
extends RefCounted
## Helper grafici condivisi. Tema "SPI 1974": il nero-bruno dello Stellar Display con la griglia e gli
## anelli rosa, i sistemi magenta (sotto il piano) e bianchi (sopra), le tabelle rosa e bianche, il
## giallo del logo StarForce sulla copertina.
## Caratteri liberi (OFL): Audiowide per i titoli (il lettering largo e arrotondato del logo),
## Orbitron per le intestazioni, Exo 2 per i testi, Share Tech Mono per coordinate e numeri.

const SPACE := Color("#0b0605")
const MAP := Color("#1c110d")
const MAP_L := Color("#2b1a14")
const PANEL := Color("#120b09")
const PINK := Color("#ea8bb0")
const PINK_D := Color("#8c3d5c")
const PINK_L := Color("#f6c3d6")
const MAGENTA := Color("#d8195f")
const YELLOW := Color("#f6d01e")
const YELLOW_L := Color("#fff0a0")
const OLIVE := Color("#7c7a55")
const PAPER := Color("#f3ecef")
const TEXT := Color("#efe6e2")
const MUTED := Color("#a69690")
const CYAN := Color("#7fd3f0")
const RED := Color("#ff4a3d")
const GREEN := Color("#8ee07a")
const ORANGE := Color("#ff9d3d")

static var font_title: Font
static var font_head: Font
static var font_body: Font
static var font_bold: Font
static var font_mono: Font
static var _tex := {}


static func init_fonts() -> void:
	if font_title != null:
		return
	font_title = load("res://assets/fonts/Audiowide-Regular.ttf")
	var orb: FontFile = load("res://assets/fonts/Orbitron.ttf")
	var fh := FontVariation.new()
	fh.base_font = orb
	fh.variation_opentype = {"wght": 700}
	font_head = fh
	var exo: FontFile = load("res://assets/fonts/Exo2.ttf")
	var fb := FontVariation.new()
	fb.base_font = exo
	fb.variation_opentype = {"wght": 420}
	font_body = fb
	var fbb := FontVariation.new()
	fbb.base_font = exo
	fbb.variation_opentype = {"wght": 700}
	font_bold = fbb
	font_mono = load("res://assets/fonts/ShareTechMono-Regular.ttf")


static func tex(path: String) -> Texture2D:
	if not _tex.has(path):
		_tex[path] = load(path) if ResourceLoader.exists(path) else null
	return _tex[path]


## colore del lato (serie di pedine)
static func side_color(set_name: String) -> Color:
	match set_name:
		"blu":
			return Color("#2aa3e0")
		"verde":
			return Color("#6fae4e")
		"grigio":
			return Color("#9aa39a")
		"ocra":
			return Color("#e0b23a")
	return Color.WHITE


static func counter_tex(set_name: String, label: String, gate: bool) -> Texture2D:
	var p := "res://assets/counters/%s_%s%s.png" % [set_name, "g" if gate else "", label]
	return tex(p)


static func make_theme() -> Theme:
	init_fonts()
	var t := Theme.new()
	t.default_font = font_body
	t.default_font_size = 20
	t.set_color("font_color", "Label", TEXT)
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", YELLOW_L)
	t.set_color("font_pressed_color", "Button", YELLOW)
	t.set_color("font_disabled_color", "Button", Color(0.5, 0.45, 0.43))
	t.set_stylebox("normal", "Button", box(Color("#2a1712"), PINK_D, 2, 6))
	t.set_stylebox("hover", "Button", box(Color("#3d2018"), PINK, 2, 6))
	t.set_stylebox("pressed", "Button", box(Color("#5a2236"), YELLOW, 2, 6))
	t.set_stylebox("disabled", "Button", box(Color("#1b100d"), Color("#3a2a26"), 1, 6))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_stylebox("panel", "PanelContainer", box(Color(PANEL, 0.94), PINK_D, 2, 8))
	t.set_stylebox("normal", "LineEdit", box(Color("#0c0706"), PINK_D, 2, 6))
	t.set_stylebox("focus", "LineEdit", box(Color("#0c0706"), PINK, 2, 6))
	t.set_color("font_color", "LineEdit", TEXT)
	t.set_stylebox("panel", "PopupMenu", box(Color("#160d0a"), PINK_D, 2, 6))
	t.set_stylebox("normal", "OptionButton", box(Color("#2a1712"), PINK_D, 2, 6))
	t.set_stylebox("hover", "OptionButton", box(Color("#3d2018"), PINK, 2, 6))
	t.set_stylebox("pressed", "OptionButton", box(Color("#5a2236"), YELLOW, 2, 6))
	t.set_stylebox("focus", "OptionButton", StyleBoxEmpty.new())
	t.set_stylebox("scroll", "VScrollBar", box(Color("#140c0a"), Color("#140c0a"), 0, 4))
	t.set_stylebox("grabber", "VScrollBar", box(PINK_D, PINK_D, 0, 4))
	t.set_stylebox("grabber_highlight", "VScrollBar", box(PINK, PINK, 0, 4))
	t.set_stylebox("grabber_pressed", "VScrollBar", box(YELLOW, YELLOW, 0, 4))
	t.set_stylebox("panel", "TooltipPanel", box(Color("#160d0a"), PINK, 2, 6))
	t.set_color("font_color", "TooltipLabel", TEXT)
	t.set_font_size("font_size", "TooltipLabel", 18)
	t.set_color("font_color", "CheckBox", TEXT)
	t.set_color("font_color", "RichTextLabel", TEXT)
	return t


static func box(bg: Color, border: Color, bw := 2, radius := 6, pad := 10) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(radius)
	s.content_margin_left = pad + 2
	s.content_margin_right = pad + 2
	s.content_margin_top = pad - 2
	s.content_margin_bottom = pad - 2
	return s


static func panel_style(alpha := 0.92) -> StyleBoxFlat:
	return box(Color(PANEL, alpha), PINK_D, 2, 8, 14)


static func label(t: String, size := 20, col := TEXT, font: Font = null) -> Label:
	init_fonts()
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	if font != null:
		l.add_theme_font_override("font", font)
	return l


static func wrap(l: Label, w: float) -> Label:
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = w
	return l


static func title(t: String, size := 48, col := YELLOW) -> Label:
	init_fonts()
	var l := label(t, size, col, font_title)
	l.add_theme_color_override("font_outline_color", Color(0.05, 0.02, 0.02))
	l.add_theme_constant_override("outline_size", maxi(4, size / 9))
	return l


static func head(t: String, size := 22, col := PINK_L) -> Label:
	init_fonts()
	return label(t, size, col, font_head)


static func mono(t: String, size := 18, col := TEXT) -> Label:
	init_fonts()
	return label(t, size, col, font_mono)


static func button(t: String, w := 0, h := 48, size := 20) -> Button:
	var b := Button.new()
	b.text = t
	b.custom_minimum_size = Vector2(w, h)
	b.add_theme_font_size_override("font_size", size)
	b.focus_mode = Control.FOCUS_NONE
	return b


static func primary(b: Button) -> Button:
	b.add_theme_stylebox_override("normal", box(Color("#6a1c3b"), YELLOW, 2, 6))
	b.add_theme_stylebox_override("hover", box(Color("#8a2550"), YELLOW_L, 2, 6))
	b.add_theme_color_override("font_color", YELLOW_L)
	return b


static func rich(size := 18) -> RichTextLabel:
	init_fonts()
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.add_theme_font_override("normal_font", font_body)
	r.add_theme_font_override("bold_font", font_bold)
	r.add_theme_font_override("mono_font", font_mono)
	r.add_theme_font_size_override("normal_font_size", size)
	r.add_theme_font_size_override("bold_font_size", size)
	r.add_theme_font_size_override("mono_font_size", size)
	r.add_theme_color_override("default_color", TEXT)
	return r


static func hsep(col := PINK_D) -> ColorRect:
	var c := ColorRect.new()
	c.color = col
	c.custom_minimum_size = Vector2(0, 2)
	return c


## Sfondo stellato animato per i menu (disegnato, nessun carattere speciale)
class Starfield extends Control:
	var stars: Array = []
	var t := 0.0

	func _ready() -> void:
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var g := RandomNumberGenerator.new()
		g.seed = 1974
		for i in 260:
			stars.append([Vector2(g.randf(), g.randf()), g.randf_range(0.6, 2.4), g.randf_range(0.2, 1.0), g.randf() * 6.28])

	func _process(dt: float) -> void:
		t += dt
		queue_redraw()

	func _draw() -> void:
		var s := size
		draw_rect(Rect2(Vector2.ZERO, s), Color("#070304"))
		for st in stars:
			var p: Vector2 = st[0] * s
			var a: float = st[2] * (0.65 + 0.35 * sin(t * 0.8 + st[3]))
			draw_circle(p, st[1], Color(1, 0.92, 0.95, a))
