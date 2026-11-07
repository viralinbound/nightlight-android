class_name TitleScene
extends MenuScene
## Title screen. Phones are wide, so the flame sits on the left and the buttons on the right.

var flame_holder := Node2D.new()
var flame_name := Txt.make("", 26, Palette.CREAM)
var flame_blurb := Txt.make("", 18, Palette.MUTED)
var title := Txt.make("Nightlight", 64, Palette.CREAM)
var tagline := Txt.make("Keep your little light alive until dawn.", 18, Palette.MUTED)
var hint := Txt.make("Touch and drag anywhere to move. Your flame shoots by itself.", 16, Palette.MUTED)
var stats := Txt.make("", 15, Palette.MUTED)
var dust := Txt.make("", 24, Palette.VIOLET, 1)
var credit := Txt.make("v1.3.1 · Made with Godot · Fonts and icons: Nunito, Noto", 13, Palette.MUTED)
var left_arrow: GButton
var right_arrow: GButton
var play_button: GButton
var daily_button: GButton
var shop_button: GButton
var sound_button: GButton
var flame_index := 0


func _init() -> void:
	super._init()
	for i in Data.FLAMES.size():
		if Data.FLAMES[i].id == Save.d.selected: flame_index = i
	for n in [title, tagline, flame_holder, flame_name, flame_blurb, hint, stats, dust, credit]:
		ui.add_child(n)
	left_arrow = _arrow("‹", func(): cycle(-1))
	right_arrow = _arrow("›", func(): cycle(1))
	play_button = GButton.make("Play", 300, 78, 30, _play_or_unlock)
	var today: Dictionary = Data.today()
	daily_button = GButton.make("Tonight: %s" % today.name, 300, 62, 20, func(): Main.I.go_to(GameScene.new("daily")))
	shop_button = GButton.make("Upgrades", 146, 62, 19, func(): Main.I.go_to(ShopScene.new()))
	sound_button = GButton.make(_sound_title(), 146, 62, 19, _toggle_sound)
	for b in [play_button, daily_button, shop_button, sound_button]:
		ui.add_child(b)
	set_buttons([left_arrow, right_arrow, play_button, daily_button, shop_button, sound_button])
	_refresh_flame()
	_refresh_stats()


func _ready() -> void:
	super._ready()
	var tw := title.create_tween().set_loops()
	tw.tween_property(title, "modulate:a", 0.86, 1.8)
	tw.tween_property(title, "modulate:a", 1.0, 1.8)


func _arrow(s: String, act: Callable) -> GButton:
	var b := GButton.make("", 90, 130, 20, act)
	b.plain = true
	var t := Txt.make(s, 64, Palette.GOLD)
	t.position = Vector2(0, -6)
	b.add_child(t)
	ui.add_child(b)
	return b


func _resized() -> void:
	# Light pool sits on the flame, in the left column.
	focus = Vector2(-W() * 0.23, -30)
	super._resized()


func layout_ui() -> void:
	var w := W()
	var h := H()
	var lx := -w * 0.23
	var rx := w * 0.25
	var col_w := w * 0.46 - 12.0
	title.position = Vector2(lx, -h / 2.0 + 56)
	title.fit_width = col_w
	tagline.position = Vector2(lx, -h / 2.0 + 102)
	tagline.fit_width = col_w
	flame_holder.position = Vector2(lx, -36)
	left_arrow.position = Vector2(lx - 136, -36)
	right_arrow.position = Vector2(lx + 136, -36)
	flame_name.position = Vector2(lx, 42)
	flame_blurb.wrap_width = minf(col_w, 400.0)
	flame_blurb.position = Vector2(lx, 62)
	hint.wrap_width = minf(col_w, 400.0)
	hint.position = Vector2(lx, h / 2.0 - 70)
	play_button.position = Vector2(rx, -96)
	daily_button.position = Vector2(rx, -14)
	shop_button.position = Vector2(rx - 77, 62)
	sound_button.position = Vector2(rx + 77, 62)
	stats.wrap_width = 300.0
	stats.position = Vector2(rx, 108)
	credit.position = Vector2(rx, h / 2.0 - 22)
	credit.fit_width = col_w
	var m := safe_margins()
	dust.position = Vector2(w / 2.0 - m.right, -h / 2.0 + m.top + 24)
	if quit_box: quit_box.position = Vector2.ZERO


func _refresh_flame() -> void:
	var def: Dictionary = Data.FLAMES[flame_index]
	for c in flame_holder.get_children():
		c.queue_free()
	var node := BaseScene.make_flame_node(def, 100.0)
	var owned: bool = Save.d.unlocked.has(def.id)
	node.modulate.a = 1.0 if owned else 0.4
	flame_holder.add_child(node)
	flame_name.text = def.name
	flame_blurb.text = def.blurb
	if owned:
		Save.d.selected = def.id
		Save.write()
		play_button.title.text = "Play"
		play_button.disabled = false
	else:
		play_button.title.text = "Unlock — %d ✦" % def.cost
		play_button.disabled = int(Save.d.stardust) < def.cost
	daily_button.disabled = not owned


func _refresh_stats() -> void:
	dust.text = "%d ✦" % int(Save.d.stardust)
	if int(Save.d.runs) == 0:
		stats.text = ""
	else:
		var daily_best := int(Save.d.dailyBest) if int(Save.d.dailyDay) == Data.day_number() else 0
		stats.text = "Best %d  ·  Longest %s  ·  Dawns %d  ·  Tonight's best %d" % [int(Save.d.bestScore), Data.time_string(float(Save.d.bestTime)), int(Save.d.dawns), daily_best]


func _play_or_unlock() -> void:
	var def: Dictionary = Data.FLAMES[flame_index]
	if Save.d.unlocked.has(def.id):
		Main.I.go_to(GameScene.new())
	elif int(Save.d.stardust) >= def.cost:
		Save.d.stardust = int(Save.d.stardust) - def.cost
		Save.d.unlocked.append(def.id)
		Save.write()
		Sound.play("buy", 1.0, 0.0)
		_refresh_flame()
		_refresh_stats()


func cycle(delta: int) -> void:
	flame_index = (flame_index + delta + Data.FLAMES.size()) % Data.FLAMES.size()
	Sound.play("hover", 1.0, 0.0)
	_refresh_flame()


func _sound_title() -> String:
	return "Sound: off" if Save.d.muted else "Sound: on"


func _toggle_sound() -> void:
	Sound.toggle_mute()
	sound_button.title.text = _sound_title()


var quit_box: Node2D
var _main_buttons: Array = []


func on_back() -> void:
	if quit_box:
		_close_quit()
		return
	_main_buttons = buttons
	quit_box = Node2D.new()
	ui.add_child(quit_box)
	var dim := Box.new()
	dim.size = Vector2(5000, 3000)
	dim.position = Vector2(-2500, 0)
	dim.color = Color(Palette.DIM, 0.7)
	quit_box.add_child(dim)
	var panel := GButton.make("", 420, 200, 20, Callable())
	panel.radius = 22
	panel.disabled = false
	quit_box.add_child(panel)
	var q := Txt.make("Leave Nightlight?", 30, Palette.CREAM)
	q.position = Vector2(0, -50)
	quit_box.add_child(q)
	var stay := GButton.make("Stay", 170, 60, 22, _close_quit)
	stay.position = Vector2(-95, 40)
	var quit := GButton.make("Quit", 170, 60, 22, func(): get_tree().quit())
	quit.position = Vector2(95, 40)
	quit_box.add_child(stay)
	quit_box.add_child(quit)
	set_buttons([stay, quit])


func _close_quit() -> void:
	if quit_box:
		quit_box.queue_free()
		quit_box = null
	set_buttons(_main_buttons)

