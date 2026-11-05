class_name GameScene
extends BaseScene
## One night: the survivor game itself. Numbers and behaviour follow the Mac version.

const NIGHT_LENGTH := 300.0
const VIEW_H := 600.0           # how much of the world fits top to bottom on a phone
const CELL := 72.0
const GRID_N := 72

enum State { PLAYING, LEVEL_UP, PAUSED, ENDED }


class Enemy:
	var kind := 0
	var uid := 0
	var pos := Vector2.ZERO
	var kb := Vector2.ZERO
	var hp := 1.0
	var max_hp := 1.0
	var r := 10.0
	var speed := 50.0
	var dmg := 5.0
	var xp := 1
	var alive := true
	var is_boss := false
	var elite := false
	var flash := 0.0
	var timer := 0.0
	var fuse := -1.0
	var phase := 0.0
	var moth_tick := 0.0
	var patch_tick := 0.0
	var sc := 1.0
	var eye_off := Vector2.ZERO
	var eye_col := Color.WHITE
	var tex: Texture2D


class Bullet:
	var pos := Vector2.ZERO
	var vel := Vector2.ZERO
	var dmg := 1.0
	var r := 6.0
	var pierce := 1
	var life := 1.0
	var homing := false
	var hit := {}
	var size := 24.0
	var color := Color.WHITE


class EnemyBullet:
	var pos := Vector2.ZERO
	var vel := Vector2.ZERO
	var dmg := 5.0
	var life := 6.0


enum { EMBER_SMALL, EMBER_BIG, EMBER_HEART, EMBER_DUST }


class Ember:
	var pos := Vector2.ZERO
	var vel := Vector2.ZERO
	var kind := 0
	var value := 1
	var pulled := false
	var age := 0.0
	var size := 24.0
	var color := Color.WHITE
	var rot := 0.0


class Nova:
	var pos := Vector2.ZERO
	var radius := 0.0
	var max_radius := 200.0
	var dmg := 1.0
	var hit := {}
	var color := Color.WHITE


class Patch:
	var pos := Vector2.ZERO
	var life := 1.0
	var max_life := 1.0
	var r := 26.0
	var dmg := 2.0


class Star:
	var target := Vector2.ZERO
	var t := 0.0
	var dmg := 1.0
	var r := 60.0
	var rot := 0.0


class Fx:
	var tex: Texture2D
	var pos := Vector2.ZERO
	var vel := Vector2.ZERO
	var life := 0.0
	var max_life := 1.0
	var s0 := 1.0
	var s1 := 0.0
	var drag := 0.0
	var rot := 0.0
	var ratio := 1.0
	var color := Color.WHITE


class FloatText:
	var s := ""
	var pos := Vector2.ZERO
	var life := 0.0
	var vy := 0.0
	var size := 18
	var color := Color.WHITE


## A world layer that repaints its contents every frame.
class Layer extends Node2D:
	var painter: Callable
	func _draw() -> void:
		painter.call(self)


const EVENTS := [
	[35.0, "swarm", Data.BAT, 22, "Bats incoming!"],
	[70.0, "ring", Data.SHADE, 30, "They're surrounding you!"],
	[105.0, "swarm", Data.BLOB, 8, "Something heavy is coming…"],
	[125.0, "boss", Data.BOSS1, 0, ""],
	[165.0, "swarm", Data.BAT, 42, "A storm of bats!"],
	[195.0, "ring", Data.SHADE, 54, "They're surrounding you!"],
	[220.0, "swarm", Data.BOMBER, 16, "Run! Fire shadows!"],
	[240.0, "boss", Data.BOSS2, 0, ""],
	[272.0, "ring", Data.MINI, 80, "One last push before dawn!"],
]

var mode := "normal"
var modifier: Dictionary = Data.NO_MODIFIER
var flame_def: Dictionary
var headless := false
var state := State.PLAYING

# World
var world: Node2D
var cam: Camera2D
var layers: Array[Layer] = []
var darkness: ColorRect
var dark_mat: ShaderMaterial
var hurt_rect: ColorRect
var hurt_mat: ShaderMaterial
var hurt_alpha := 0.0
var dawn_glow: ColorRect
var warmth: Sprite2D
var player_root: Node2D
var player_body: Sprite2D
var player_face: Sprite2D
var player_glow: Sprite2D
var dark_strength := 0.965
var dark_override_radius := -1.0
var cam_pos := Vector2.ZERO
var view_w := 1333.0

# Player
var p := Vector2.ZERO
var move_dir := Vector2.ZERO
var facing := Vector2.RIGHT
var light := 100.0
var i_frames := 0.0
var blink_timer := 2.0
var light_radius := 300.0
var max_light := 100.0
var radius_mul := 1.0
var speed_stat := 200.0
var magnet_stat := 125.0
var cooldown_mul := 1.0
var damage_mul := 1.0
var area := 1.0
var xp_mul := 1.0
var crit := 0.07
var luck := 1.0
var revives := 0

# Progress
var t := 0.0
var level := 1
var xp := 0.0
var xp_needed := 5.0
var pending_levels := 0
var kills := 0
var picked_stardust := 0
var weapons := {}
var weapon_order: Array = []
var passives := {}
var weapon_timers := {}
var rerolls := 0
var card_count := 3
var won := false
var finished := false
var bosses_killed := 0

# Things in the world
var enemies: Array = []
var bullets: Array = []
var enemy_bullets: Array = []
var embers: Array = []
var novas: Array = []
var patches: Array = []
var stars: Array = []
var fx: Array = []
var texts: Array = []
var moth_count := 0
var moth_angle := 0.0
var moth_pos: Array = []
var trail_dist := 0.0
var boss: Enemy
var _uid := 0

# Finding nearby enemies quickly
var grid: Array = []
var touched: PackedInt32Array = PackedInt32Array()
var grid_origin := Vector2.ZERO
var _q: Array = []

# Director
var spawn_budget := 0.0
var next_event := 0
var event_times: Array[float] = []

# Finger
var joy_id := -1
var joy_origin := Vector2.ZERO
var joy_pos := Vector2.ZERO
var joy_node: Layer

# Feel
var ember_combo := 0
var ember_combo_timer := 0.0
var number_budget := 0.0
var shake := 0.0
var hit_stop := 0.0
var end_timer := -1.0

# Keeps cheap phones smooth by trimming decoration when frames run slow.
var fx_cap := 420
var enemy_cap := 460
var slow_time := 0.0
var low_quality := false

# Screen furniture
var hud: Node2D
var light_back: Box
var light_bar: Box
var xp_back: Box
var xp_bar: Box
var boss_back: Box
var boss_bar: Box
var level_label: Txt
var time_label: Txt
var time_sub: Txt
var kill_label: Txt
var kill_icon: Sprite2D
var boss_name: Txt
var banner: Txt
var low_label: Txt
var build_row: Node2D
var pause_button: GButton
var overlay: Node2D
var current_options: Array = []
var _banner_tween: Tween
var _last_time_shown := -1
var _margin := {"left": 40.0, "right": 40.0, "top": 10.0, "bottom": 10.0}

# Automated runs drive the flame with this.
var autopilot := false

# Pictures used every frame
var tx_soft: Texture2D
var tx_ember: Texture2D
var tx_star: Texture2D
var tx_ring: Texture2D
var tx_beam: Texture2D
var tx_eyes: Texture2D
var tx_orb: Texture2D
var tx_moth: Texture2D
var tx_ground: Texture2D
var font: Font


func _init(game_mode := "normal", is_headless := false, flame_id := "") -> void:
	super._init()
	mode = game_mode
	headless = is_headless
	modifier = Data.today() if mode == "daily" else Data.NO_MODIFIER
	flame_def = Data.flame(flame_id if flame_id != "" else str(Save.d.selected))
	autopilot = headless
	grid.resize(GRID_N * GRID_N)
	for i in grid.size():
		grid[i] = []
	_setup_stats()
	if not headless:
		_setup_world()
		_setup_hud()
	grant_weapon(flame_def.start)


func _ready() -> void:
	super._ready()
	if headless: return
	Sound.start_music(0.5)
	show_banner("Tonight: %s" % modifier.name if mode == "daily" else "Survive until dawn")


func _setup_stats() -> void:
	max_light = flame_def.light + Save.shop_level("flame") * 8.0
	speed_stat = 200.0 * flame_def.speed * (1.0 + Save.shop_level("feet") * 0.04)
	radius_mul = flame_def.radius * modifier.radius
	damage_mul = 1.0 + Save.shop_level("power") * 0.06
	xp_mul = (1.0 + Save.shop_level("wisdom") * 0.08) * modifier.xp
	rerolls = Save.shop_level("reroll")
	card_count = 3 + Save.shop_level("choice")
	light = max_light
	xp_needed = _xp_for(1)
	# Every night shifts its events a little, so the timetable can't be memorised. Order never changes.
	var last := 0.0
	for ev in EVENTS:
		last = maxf(last + 5.0, float(ev[0]) + randf_range(-12.0, 12.0))
		event_times.append(minf(last, NIGHT_LENGTH - 20.0))


func _xp_for(l: int) -> float:
	return 3.0 + l * 2.5 + pow(l, 1.5)


func _layer(painter: Callable, additive := false, mat: Material = null) -> Layer:
	var l := Layer.new()
	l.painter = painter
	if additive: l.material = Art.additive()
	if mat: l.material = mat
	world.add_child(l)
	layers.append(l)
	return l


func _dark_rect(tint: Color, strength: float) -> Array:
	var rect := ColorRect.new()
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/darkness.gdshader")
	mat.set_shader_parameter("tint", Vector3(tint.r, tint.g, tint.b))
	mat.set_shader_parameter("strength", strength)
	rect.material = mat
	return [rect, mat]


func _setup_world() -> void:
	font = Art.font()
	tx_soft = Art.tex("soft_dot")
	tx_ember = Art.tex("ember")
	tx_star = Art.tex("star")
	tx_ring = Art.tex("ring")
	tx_beam = Art.tex("beam")
	tx_eyes = Art.tex("eyes")
	tx_orb = Art.tex("orb")
	tx_moth = Art.tex("moth")
	tx_ground = Art.tex("ground")

	world = Node2D.new()
	add_child(world)
	cam = Camera2D.new()
	add_child(cam)

	_layer(_paint_ground)
	_layer(_paint_patches, true)

	warmth = Sprite2D.new()
	warmth.texture = tx_soft
	warmth.material = Art.additive()
	warmth.modulate = Color(flame_def.outer, 0.16)
	world.add_child(warmth)

	var enemy_mat := ShaderMaterial.new()
	enemy_mat.shader = load("res://shaders/enemy.gdshader")
	_layer(_paint_enemies, false, enemy_mat)

	var d := _dark_rect(Color(0.012, 0.012, 0.055), dark_strength)
	darkness = d[0]
	dark_mat = d[1]
	world.add_child(darkness)

	_layer(_paint_eyes)

	player_root = Node2D.new()
	world.add_child(player_root)
	player_glow = Sprite2D.new()
	player_glow.texture = tx_soft
	player_glow.material = Art.additive()
	player_glow.scale = Vector2.ONE * 110.0 / 128.0
	player_glow.modulate = Color(flame_def.outer, 0.7)
	player_root.add_child(player_glow)
	player_body = Sprite2D.new()
	player_body.texture = Art.tex("flame_" + flame_def.id)
	player_root.add_child(player_body)
	player_face = Sprite2D.new()
	player_face.texture = Art.tex("flame_face")
	player_root.add_child(player_face)

	_layer(_paint_embers, true)
	_layer(_paint_novas, true)
	_layer(_paint_bullets, true)
	_layer(_paint_enemy_bullets)
	_layer(_paint_moths)
	_layer(_paint_fx, true)
	_layer(_paint_stars, true)
	_layer(_paint_texts)

	dawn_glow = ColorRect.new()
	dawn_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dawn_glow.material = Art.additive()
	dawn_glow.color = Color(1, 0.72, 0.42, 0)
	dawn_glow.size = Vector2(4000, 4000)
	world.add_child(dawn_glow)

	var h := _dark_rect(Color(0.8, 0.05, 0.1), 0.0)
	hurt_rect = h[0]
	hurt_mat = h[1]
	hurt_rect.size = Vector2(4000, 4000)
	hurt_mat.set_shader_parameter("sheet", 4000.0)
	hurt_mat.set_shader_parameter("radius", 620.0)
	world.add_child(hurt_rect)


func _setup_hud() -> void:
	hud = Node2D.new()
	ui.add_child(hud)
	light_back = _bar(Color(0, 0, 0, 0.6))
	xp_back = _bar(Color(0, 0, 0, 0.6))
	boss_back = _bar(Color(0, 0, 0, 0.6))
	light_bar = _bar(Palette.GOLD)
	xp_bar = _bar(Palette.GOLD)
	boss_bar = _bar(Color(0.9, 0.2, 0.4))
	level_label = Txt.make("LV 1", 20, Palette.GOLD, -1)
	time_label = Txt.make("5:00", 34, Palette.CREAM)
	time_sub = Txt.make("until dawn", 15, Palette.MUTED)
	kill_label = Txt.make("0", 22, Palette.CREAM, 1)
	kill_icon = BaseScene.icon_node("skull", 22)
	boss_name = Txt.make("", 16, Palette.CREAM)
	banner = Txt.make("", 30, Palette.GOLD)
	banner.fit_width = 860.0
	low_label = Txt.make("Your light is fading — grab embers!", 19, Color(1, 0.5, 0.4))
	build_row = Node2D.new()
	for n in [level_label, time_label, time_sub, kill_label, kill_icon, boss_name, banner, low_label, build_row]:
		hud.add_child(n)
	boss_back.visible = false
	boss_bar.visible = false
	boss_name.visible = false
	banner.modulate.a = 0.0
	low_label.modulate.a = 0.0

	pause_button = GButton.make("", 58, 58, 20, pause)
	pause_button.radius = 16
	hud.add_child(pause_button)
	for x in [-7.0, 7.0]:
		var bar := Box.new()
		bar.size = Vector2(7, 24)
		bar.color = Palette.CREAM
		bar.position = Vector2(x - 3.5, 0)
		pause_button.add_child(bar)

	joy_node = Layer.new()
	joy_node.painter = _paint_joystick
	ui.add_child(joy_node)
	set_buttons([pause_button])


func _bar(c: Color) -> Box:
	var b := Box.new()
	b.color = c
	hud.add_child(b)
	return b


func layout_ui() -> void:
	if headless or hud == null: return
	var w := W()
	var h := H()
	_margin = safe_margins()
	view_w = VIEW_H * w / h
	cam.zoom = Vector2.ONE * h / VIEW_H
	var left: float = -w / 2.0 + _margin.left
	var right: float = w / 2.0 - _margin.right
	var top: float = -h / 2.0 + _margin.top
	var bottom: float = h / 2.0 - _margin.bottom
	xp_back.position = Vector2(-w / 2.0, -h / 2.0 + 5)
	xp_back.size = Vector2(w, 10)
	xp_bar.position = xp_back.position
	light_back.position = Vector2(left, top + 34)
	light_bar.position = light_back.position
	level_label.position = Vector2(left, top + 60)
	time_label.position = Vector2(0, top + 38)
	time_sub.position = Vector2(0, top + 66)
	pause_button.position = Vector2(right - 29, top + 48)
	kill_label.position = Vector2(right - 72, top + 36)
	kill_icon.position = Vector2(right - 140, top + 36)
	var bw := minf(420.0, w * 0.5)
	boss_back.position = Vector2(-bw / 2.0, top + 94)
	boss_back.size = Vector2(bw, 12)
	boss_bar.position = boss_back.position
	boss_name.position = Vector2(0, top + 114)
	banner.position = Vector2(0, -110)
	banner.fit_width = w - 60.0
	low_label.position = Vector2(0, bottom - 20)
	build_row.position = Vector2(left + 16, bottom - 24)


# MARK: Main loop

func _process(delta: float) -> void:
	var dt := minf(delta, 1.0 / 20.0)
	_watch_speed(delta)
	if end_timer > 0.0:
		end_timer -= dt
		if end_timer <= 0.0: show_end_screen()
	if state == State.PLAYING:
		if hit_stop > 0.0:
			hit_stop -= dt
		else:
			step(dt)
	if state == State.LEVEL_UP and autopilot:
		choose_option(current_options.pick_random())
	if state != State.PLAYING:
		_update_fx(dt)
	_update_camera(dt)
	_update_hud()
	for l in layers:
		l.queue_redraw()
	joy_node.queue_redraw()


func _watch_speed(delta: float) -> void:
	if low_quality or state != State.PLAYING: return
	slow_time = maxf(0.0, slow_time + (delta - 0.024 if delta > 0.024 else -0.002))
	if slow_time > 0.5:
		low_quality = true
		fx_cap = 140
		enemy_cap = 340


## Advances the whole game by one slice of time.
func step(dt: float) -> void:
	t += dt
	_update_player(dt)
	_run_director(dt)
	_rebuild_grid()
	_update_enemies(dt)
	_update_weapons(dt)
	_update_projectiles(dt)
	_update_enemy_bullets(dt)
	_update_embers(dt)
	if not headless: _update_fx(dt)
	_update_light(dt)
	_compact()
	if pending_levels > 0 and state == State.PLAYING: open_level_up()
	if t >= NIGHT_LENGTH and not finished: _reach_dawn()


# MARK: Player

func _input_direction() -> Vector2:
	if autopilot: return _autopilot_direction()
	if joy_id >= 0:
		var delta := joy_pos - joy_origin
		var l := delta.length()
		if l > 8.0:
			return delta / l * minf(1.0, l / 60.0)
	return Vector2.ZERO


func _update_player(dt: float) -> void:
	move_dir = _input_direction()
	if move_dir != Vector2.ZERO: facing = move_dir.normalized()
	var before := p
	p += move_dir * (speed_stat * dt)
	trail_dist += p.distance_to(before)
	i_frames = maxf(0.0, i_frames - dt)
	if headless: return

	# A flame that squashes, leans and blinks has far more personality than a static sprite.
	var wave := sin(t * 11.0)
	var moving := move_dir != Vector2.ZERO
	player_root.position = p
	player_body.scale = Vector2((34.0 / 128.0) * (1.0 + wave * 0.05 - (0.05 if moving else 0.0)), (42.0 / 160.0) * (1.0 - wave * 0.05 + (0.07 if moving else 0.0)))
	player_body.rotation = move_dir.x * 0.22 if moving else sin(t * 3.0) * 0.05
	player_face.position = Vector2(facing.x * 3.0, 6.0 + facing.y * 2.0)
	player_face.rotation = player_body.rotation * 0.5
	blink_timer -= dt
	if blink_timer < 0.0: blink_timer = randf_range(1.8, 4.5)
	player_face.scale = Vector2(18.0 / 64.0, (9.0 / 32.0) * (0.1 if blink_timer < 0.09 else 1.0))
	player_root.modulate.a = 0.5 if i_frames > 0.0 and int(t * 24.0) % 2 == 0 else 1.0

	if moving and randf() < dt * 26.0:
		spawn_fx(tx_soft, p + Vector2(randf_range(-7, 7), 8), Vector2(-move_dir.x * 40.0, -randf_range(10, 45)),
				randf_range(0.25, 0.55), randf_range(10, 18), 1.0, flame_def.outer)


func _update_camera(dt: float) -> void:
	var target := p + move_dir * 26.0
	cam_pos += (target - cam_pos) * minf(1.0, dt * 7.0)
	var c := cam_pos
	if shake > 0.0:
		c += Vector2(randf_range(-shake, shake), randf_range(-shake, shake))
		shake = maxf(0.0, shake - dt * 42.0)
	cam.position = c
	dawn_glow.position = c - dawn_glow.size / 2.0
	hurt_rect.position = c - hurt_rect.size / 2.0
	if hurt_alpha > 0.0 or finished:
		hurt_alpha = maxf(0.0, hurt_alpha - dt * 1.8)
		hurt_mat.set_shader_parameter("strength", hurt_alpha)
	# The sheet always reaches past the corners of the screen.
	var sheet := (view_w + VIEW_H) * 2.0
	var radius := dark_override_radius if dark_override_radius > 0.0 else light_radius
	darkness.size = Vector2(sheet, sheet)
	darkness.position = p - darkness.size / 2.0
	dark_mat.set_shader_parameter("radius", radius)
	dark_mat.set_shader_parameter("sheet", sheet)
	dark_mat.set_shader_parameter("strength", dark_strength)
	warmth.position = p
	warmth.scale = Vector2.ONE * radius * 2.6 / 128.0


func _update_light(dt: float) -> void:
	# Light slowly burns away, so standing still is never safe.
	var drain: float = (0.56 + t * 0.0026) * modifier.drain
	if not finished: light -= drain * dt
	light = minf(light, max_light)
	var frac := clampf(light / max_light, 0.0, 1.0)
	var flicker := 1.0 + sin(t * 9.0) * 0.012 + sin(t * 23.0) * 0.008
	var target := (140.0 + 290.0 * frac) * radius_mul * flicker
	light_radius += (target - light_radius) * minf(1.0, dt * 6.0)

	if not headless and not finished:
		# The last 40 seconds, the night slowly lifts.
		var lift := clampf((t - (NIGHT_LENGTH - 15.0)) / 15.0, 0.0, 1.0)
		dark_strength = 0.965 - lift * 0.42
		dawn_glow.color.a = lift * 0.13

	if light <= 0.0 and not finished:
		if revives > 0:
			revives -= 1
			light = max_light * 0.6
			i_frames = 2.5
			Sound.play("revive", 1.0, 0.0)
			show_banner("Second wind!")
			# Blast everything back so the revive actually feels like a rescue.
			for e: Enemy in enemies:
				if e.alive and not e.is_boss:
					var d := e.pos - p
					if d.length() < 500.0: e.kb += d.normalized() * 700.0
			add_nova(500.0, 25.0)
		else:
			_die()


func hurt(amount: float) -> void:
	if i_frames > 0.0 or finished: return
	light -= amount
	i_frames = 0.4
	shake = maxf(shake, 7.0)
	Sound.play("hurt", 1.0, 0.1)
	if not headless:
		hurt_alpha = 0.32
		hurt_mat.set_shader_parameter("strength", hurt_alpha)


# MARK: Director

func _run_director(dt: float) -> void:
	if finished: return
	while next_event < EVENTS.size() and t >= event_times[next_event]:
		_fire_event(EVENTS[next_event])
		next_event += 1
	var base := 2.0 + t * 0.055 + pow(t / 100.0, 2.0) * 1.2
	spawn_budget += base * 1.35 * modifier.spawn * dt
	while spawn_budget >= 1.0:
		spawn_budget -= 1.0
		if enemies.size() >= enemy_cap:
			spawn_budget = 0.0
			break
		spawn(_pick_kind(), _offscreen_point())


func _pick_kind() -> int:
	if modifier.bat > 0.0 and randf() < modifier.bat: return Data.BAT
	var total := 10.0
	if t > 20.0: total += 4.0
	if t > 55.0: total += 1.6
	if t > 90.0: total += 1.7
	if t > 145.0: total += 1.5
	var roll := randf() * total - 10.0
	if roll <= 0.0: return Data.SHADE
	roll -= 4.0
	if roll <= 0.0: return Data.BAT
	roll -= 1.6
	if roll <= 0.0: return Data.BLOB
	roll -= 1.7
	if roll <= 0.0: return Data.SPITTER
	return Data.BOMBER


func _view_radius() -> float:
	return sqrt(view_w * view_w + VIEW_H * VIEW_H) / 2.0


func _offscreen_point() -> Vector2:
	return p + Vector2.from_angle(randf() * TAU) * (_view_radius() + 50.0)


func _fire_event(ev: Array) -> void:
	var kind: int = ev[2]
	var count: int = ev[3]
	match ev[1]:
		"swarm":
			show_banner(ev[4])
			Sound.play("warn", 1.0, 0.0)
			var c := p + Vector2.from_angle(randf() * TAU) * (_view_radius() + 90.0)
			for i in count:
				spawn(kind, c + Vector2(randf_range(-110, 110), randf_range(-110, 110)))
		"ring":
			show_banner(ev[4])
			Sound.play("warn", 1.0, 0.0)
			var radius := _view_radius() + 40.0
			for i in count:
				spawn(kind, p + Vector2.from_angle(float(i) / count * TAU) * radius)
		"boss":
			boss = spawn(kind, _offscreen_point())
			show_banner("The Old Shade wakes" if kind == Data.BOSS1 else "The Night Mother arrives")
			Sound.play("boss", 1.0, 0.0)
			shake = 8.0


func spawn(kind: int, pos: Vector2, forced_elite := false) -> Enemy:
	var e := Enemy.new()
	var d: Array = Data.ENEMY[kind]
	var hp_scale: float = (1.0 + t / 55.0 + pow(t / 110.0, 2.0)) * modifier.hp
	_uid += 1
	e.uid = _uid
	e.kind = kind
	e.is_boss = kind == Data.BOSS1 or kind == Data.BOSS2
	e.pos = pos
	e.timer = randf_range(0.5, 2.2)
	e.phase = randf_range(0.0, 6.28)
	e.r = d[0]
	e.speed = d[2] * modifier.espeed * (1.12 + t / 450.0)
	e.dmg = d[3] * (1.25 + t / 280.0)
	e.xp = d[4]
	# Bosses grow with the player, so an over-levelled flame still gets a real fight.
	e.hp = d[1] * modifier.hp * (1.0 + 0.04 * maxi(0, level - 10)) if e.is_boss else d[1] * hp_scale
	e.elite = forced_elite or (not e.is_boss and t > 50.0 and randf() < 0.04 * luck)
	if e.elite:
		e.hp *= 6.0
		e.r *= 1.4
		e.dmg *= 1.3
		e.xp *= 5
	e.max_hp = e.hp
	if not headless:
		e.tex = Art.tex("enemy_" + Data.ENEMY_TEX[kind])
		if kind == Data.BOMBER: e.eye_col = Color(1, 0.45, 0.3)
		elif e.is_boss: e.eye_col = Color(1, 0.3, 0.3)
		else: e.eye_col = Palette.GOLD if e.elite else Color(1, 0.96, 0.82)
	enemies.append(e)
	return e


# MARK: Enemies

func _rebuild_grid() -> void:
	for i in touched:
		grid[i].clear()
	touched.clear()
	grid_origin = Vector2(p.x - GRID_N * CELL / 2.0, p.y - GRID_N * CELL / 2.0)
	for e: Enemy in enemies:
		if not e.alive: continue
		var cx := int((e.pos.x - grid_origin.x) / CELL)
		var cy := int((e.pos.y - grid_origin.y) / CELL)
		if cx < 0 or cy < 0 or cx >= GRID_N or cy >= GRID_N: continue
		var i := cy * GRID_N + cx
		var cell: Array = grid[i]
		if cell.is_empty(): touched.append(i)
		cell.append(e)


## The enemies near a point. The list is reused, so use it before asking again.
func query(pos: Vector2, radius: float) -> Array:
	_q.clear()
	var x0 := maxi(0, int((pos.x - radius - grid_origin.x) / CELL) - 1)
	var x1 := mini(GRID_N - 1, int((pos.x + radius - grid_origin.x) / CELL) + 1)
	var y0 := maxi(0, int((pos.y - radius - grid_origin.y) / CELL) - 1)
	var y1 := mini(GRID_N - 1, int((pos.y + radius - grid_origin.y) / CELL) + 1)
	for y in range(y0, y1 + 1):
		var row := y * GRID_N
		for x in range(x0, x1 + 1):
			var cell: Array = grid[row + x]
			if not cell.is_empty(): _q.append_array(cell)
	return _q


func nearest_enemy(pos: Vector2, within: float, excluding := {}) -> Enemy:
	var best: Enemy = null
	var best_d := within * within
	for e: Enemy in query(pos, within):
		if not e.alive or excluding.has(e.uid): continue
		var dd := pos.distance_squared_to(e.pos)
		if dd < best_d:
			best_d = dd
			best = e
	return best


func _update_enemies(dt: float) -> void:
	const CONTACT := 13.0
	for e: Enemy in enemies:
		if not e.alive: continue
		var to := p - e.pos
		var dist := to.length()
		var dir := to / dist if dist > 0.001 else Vector2.ZERO
		var move := dir
		e.phase += dt
		e.moth_tick = maxf(0.0, e.moth_tick - dt)
		e.patch_tick = maxf(0.0, e.patch_tick - dt)

		match e.kind:
			Data.BAT:
				move = (dir + Vector2(-dir.y, dir.x) * (sin(e.phase * 6.0) * 0.9)).normalized()
			Data.SPITTER:
				if dist < 230.0: move = dir * -0.8
				elif dist < 290.0: move = Vector2.ZERO
				e.timer -= dt
				if e.timer <= 0.0 and dist < 520.0:
					e.timer = randf_range(1.2, 1.8)
					# Aim a little ahead of a moving flame, so running in a straight line no longer dodges.
					var lead := p + move_dir * speed_stat * (dist / 215.0) * 0.6
					_shoot_enemy_bullet(e.pos, (lead - e.pos).normalized(), 215.0, e.dmg)
					Sound.play("spit", 0.6)
			Data.BOMBER:
				if e.fuse >= 0.0:
					move = Vector2.ZERO
					e.fuse -= dt
					e.sc = 1.0 + (1.0 - e.fuse / 0.42) * 0.55
					e.flash = 0.9 if int(e.fuse * 16.0) % 2 == 0 else 0.1
					if e.fuse <= 0.0:
						e.alive = false
						_explode(e.pos, 92.0, 15.0 + t / 28.0)
						continue
				elif dist < 90.0:
					e.fuse = 0.42
			Data.BOSS1, Data.BOSS2:
				e.timer -= dt
				if e.timer <= 0.0:
					var first := e.kind == Data.BOSS1
					e.timer = 2.0 if first else 1.4
					var count := 12 if first else 18
					var off := randf()
					for i in count:
						_shoot_enemy_bullet(e.pos, Vector2.from_angle(float(i) / count * TAU + off), 150.0 if first else 175.0, e.dmg * 0.55)
					Sound.play("spit", 1.0, 0.0)
					for i in (4 if first else 7):
						spawn(Data.BAT, e.pos + Vector2(randf_range(-60, 60), randf_range(-60, 60)))

		e.pos += move * (e.speed * dt) + e.kb * dt
		e.kb *= maxf(0.0, 1.0 - dt * 7.5)
		to = p - e.pos
		dist = to.length()

		# Shadows that fall too far behind reappear ahead of you, so running away never empties the screen.
		if dist > 1250.0 and not e.is_boss: e.pos = _offscreen_point()
		if dist < e.r + CONTACT and e.dmg > 0.0 and e.fuse < 0.0: hurt(e.dmg)
		if not headless:
			e.flash = maxf(0.0, e.flash - dt * 7.0)
			e.eye_off = Vector2(dir.x * e.r * 0.32, -e.r * 0.16 + dir.y * e.r * 0.2)

	# Gently push overlapping enemies apart so crowds read as crowds, not a single blob.
	for ci in touched:
		var list: Array = grid[ci]
		var n := mini(list.size(), 12)
		if n < 2: continue
		for i in n:
			var a: Enemy = list[i]
			for j in range(i + 1, n):
				var b: Enemy = list[j]
				var d := a.pos - b.pos
				var min_d := (a.r + b.r) * 0.82
				var dd := d.length_squared()
				if dd < min_d * min_d and dd > 0.01:
					var l := sqrt(dd)
					var m := d * ((min_d - l) * 0.5 * minf(1.0, dt * 12.0) / l)
					if not a.is_boss: a.pos += m
					if not b.is_boss: b.pos -= m

	if boss != null and not boss.alive: boss = null


func _explode(pos: Vector2, radius: float, dmg: float) -> void:
	Sound.play("bomb", 1.0, 0.06)
	shake = maxf(shake, 6.0)
	if pos.distance_to(p) < radius: hurt(dmg)
	if headless: return
	spawn_fx(tx_ring, pos, Vector2.ZERO, 0.35, 30.0, radius * 2.4, Color(1, 0.4, 0.2))
	for i in 14:
		spawn_fx(tx_soft, pos, Vector2.from_angle(randf() * TAU) * randf_range(60, 280), randf_range(0.3, 0.6), randf_range(16, 30), 2.0,
				Color(1, randf_range(0.3, 0.7), 0.15), 3.0)


func _shoot_enemy_bullet(pos: Vector2, dir: Vector2, speed: float, dmg: float) -> void:
	var b := EnemyBullet.new()
	b.pos = pos
	b.vel = dir * speed
	b.dmg = dmg
	enemy_bullets.append(b)


func _update_enemy_bullets(dt: float) -> void:
	for b: EnemyBullet in enemy_bullets:
		b.pos += b.vel * dt
		b.life -= dt
		if b.pos.distance_squared_to(p) < 361.0:
			hurt(b.dmg)
			b.life = 0.0


# MARK: Damage

func damage(e: Enemy, amount: float, from := Vector2.INF, knock := 60.0) -> void:
	if not e.alive: return
	var d := amount * damage_mul
	var is_crit := randf() < crit
	if is_crit: d *= 2.0
	e.hp -= d
	e.flash = 0.75
	if from != Vector2.INF and knock > 0.0 and not e.is_boss:
		e.kb += (e.pos - from).normalized() * knock * (0.4 if e.elite else 1.0)
	Sound.play("hit", 0.7, 0.05)
	if not headless: _show_number(d, e.pos, is_crit)
	if e.hp <= 0.0: _kill(e)


func _kill(e: Enemy) -> void:
	e.alive = false
	kills += 1
	Sound.play("kill", 1.0 if e.is_boss else 0.8, 0.035)
	if not headless:
		var col := Color(0.56, 0.46, 0.92)
		var bits := 60 if e.is_boss else (16 if e.elite else 6)
		if low_quality: bits /= 2
		for i in bits:
			spawn_fx(tx_soft, e.pos, Vector2.from_angle(randf() * TAU) * randf_range(40, 200) * (2.0 if e.is_boss else 1.0),
					randf_range(0.2, 0.5), randf_range(8, 18), 1.0, col, 4.0)

	# Drops. Big drops come in clusters so that collecting them plays the rising ember melody.
	if e.is_boss:
		bosses_killed += 1
		picked_stardust += 60
		hit_stop = 0.14
		shake = 16.0
		Sound.play("bossdie", 1.0, 0.0)
		show_banner("The Old Shade is gone!" if e.kind == Data.BOSS1 else "The Night Mother falls!")
		for i in 26: drop_ember(EMBER_BIG, 5, e.pos + Vector2(randf_range(-70, 70), randf_range(-70, 70)))
		for i in 3: drop_ember(EMBER_HEART, 1, e.pos + Vector2(randf_range(-60, 60), randf_range(-60, 60)))
		for i in 5: drop_ember(EMBER_DUST, 3, e.pos + Vector2(randf_range(-60, 60), randf_range(-60, 60)))
		return
	if e.kind == Data.BLOB:
		for i in 2: spawn(Data.MINI, e.pos + Vector2(randf_range(-14, 14), randf_range(-14, 14)))
	if e.elite:
		drop_ember(EMBER_DUST, 12, e.pos)
		drop_ember(EMBER_BIG, 5, e.pos + Vector2(randf_range(-14, 14), randf_range(-14, 14)))
		drop_ember(EMBER_HEART, 1, e.pos + Vector2(randf_range(-14, 14), randf_range(-14, 14)))
		return
	if randf() < 0.012 * luck:
		drop_ember(EMBER_HEART, 1, e.pos)
	elif embers.size() > 260 or e.xp >= 3 or randf() < 0.05 * luck:
		drop_ember(EMBER_BIG, maxi(e.xp, 3), e.pos)
	else:
		drop_ember(EMBER_SMALL, e.xp, e.pos)


# MARK: Embers

func drop_ember(kind: int, value: int, pos: Vector2) -> void:
	var m := Ember.new()
	m.kind = kind
	m.value = value
	m.pos = pos
	m.vel = Vector2.from_angle(randf() * TAU) * randf_range(20, 90)
	match kind:
		EMBER_SMALL:
			m.color = Color(1, 0.62, 0.20)
			m.size = 24.0
		EMBER_BIG:
			m.color = Color(0.45, 0.85, 1)
			m.size = 36.0
		EMBER_HEART:
			m.color = Color(1, 0.92, 0.55)
			m.size = 62.0
		EMBER_DUST:
			m.color = Palette.VIOLET
			m.size = 28.0
	embers.append(m)


func _update_embers(dt: float) -> void:
	ember_combo_timer -= dt
	if ember_combo_timer < 0.0: ember_combo = 0
	var magnet := magnet_stat * (1.0 + int(passives.get("magnet", 0)) * 0.4)
	var keep := maxf(0.0, 1.0 - dt * 5.0)
	var slow := maxf(0.0, 1.0 - dt * 6.0)
	for m: Ember in embers:
		m.age += dt
		var to := p - m.pos
		var d := to.length()
		# Embers left behind eventually come to you, so a kill far away in the dark is never wasted.
		if not m.pulled and (m.age > 9.0 or d < (magnet * 1.5 if m.kind == EMBER_HEART else magnet)): m.pulled = true
		if m.pulled:
			m.vel = m.vel * keep + (to / maxf(d, 0.001)) * (1400.0 * dt)
		else:
			m.vel *= slow
		m.pos += m.vel * dt
		if m.kind == EMBER_DUST: m.rot += dt * 2.0
		if d < 20.0:
			_collect(m)
			m.value = 0


func _collect(m: Ember) -> void:
	match m.kind:
		EMBER_SMALL, EMBER_BIG:
			_add_xp(m.value * xp_mul)
			light = minf(max_light, light + 0.34 * m.value)
			ember_combo_timer = 0.7
			Sound.play("ember%d" % mini(ember_combo, 7), 0.8, 0.03)
			ember_combo += 1
		EMBER_HEART:
			light = minf(max_light, light + 22.0)
			Sound.play("revive", 0.6, 0.1)
			if not headless: float_text("+ light", p + Vector2(0, -34), Palette.GOLD, 22)
		EMBER_DUST:
			picked_stardust += m.value
			Sound.play("buy", 0.7, 0.05)
			if not headless: float_text("+%d ✦" % m.value, p + Vector2(0, -34), Palette.VIOLET, 22)


func _add_xp(amount: float) -> void:
	xp += amount
	while xp >= xp_needed:
		xp -= xp_needed
		level += 1
		xp_needed = _xp_for(level)
		pending_levels += 1


# MARK: Weapons

func grant_weapon(w: String) -> void:
	if not weapons.has(w): weapon_order.append(w)
	weapons[w] = int(weapons.get(w, 0)) + 1
	if not weapon_timers.has(w): weapon_timers[w] = 0.2
	if w == "moths":
		moth_count = weapons[w] + 1
		moth_pos.resize(moth_count)
		moth_pos.fill(p)
	_refresh_build_row()


func apply_passive(id: String) -> void:
	passives[id] = int(passives.get(id, 0)) + 1
	match id:
		"soul":
			max_light += 15.0
			light = minf(max_light, light + 15.0)
		"glow": radius_mul *= 1.15
		"feet": speed_stat *= 1.09
		"rapid": cooldown_mul *= 0.91
		"sharp": damage_mul *= 1.15
		"big": area *= 1.12
		"wind": revives += 1
		"luck":
			crit += 0.05
			luck *= 1.3
	_refresh_build_row()


func _update_weapons(dt: float) -> void:
	for w: String in weapon_order:
		var l: int = weapons[w]
		match w:
			"moths": _update_moths(dt, l)
			"trail": _update_trail(l)
			_:
				weapon_timers[w] -= dt
				if weapon_timers[w] <= 0.0:
					weapon_timers[w] = _cooldown(w, l) * cooldown_mul if _fire_weapon(w, l) else 0.12
	_update_novas(dt)
	_update_patches(dt)
	_update_stars(dt)


func _cooldown(w: String, l: int) -> float:
	match w:
		"bolt": return 0.62 - l * 0.025
		"nova": return 3.5 - l * 0.28
		"fireflies": return 1.7 - l * 0.11
		"zap": return 2.25 - l * 0.16
		"starfall": return 2.7 - l * 0.2
	return 1.0


func _target_range() -> float:
	return maxf(light_radius * 1.25, 360.0)


## Returns false if there was nothing to shoot at, so weapons never waste a shot on an empty screen.
func _fire_weapon(w: String, l: int) -> bool:
	match w:
		"bolt":
			var target := nearest_enemy(p, _target_range())
			if target == null: return false
			var count := 1 + (1 if l >= 3 else 0) + (1 if l >= 5 else 0)
			var base := (target.pos - p).angle()
			for i in count:
				var spread := (i - (count - 1) / 2.0) * 0.17
				_add_bullet(Vector2.from_angle(base + spread), 560.0, 5.0 + l * 1.9, 7.0 * area, 0.9, 3 if l >= 4 else 1, flame_def.inner, 26.0 * area, false)
			Sound.play("shoot", 0.7, 0.05)
		"fireflies":
			var target := nearest_enemy(p, _target_range() * 1.3)
			if target == null: return false
			var count := (l + 2) / 2
			var base := (target.pos - p).angle()
			for i in count:
				_add_bullet(Vector2.from_angle(base + randf_range(-1.4, 1.4)), 300.0, 7.0 + l * 2.2, 7.0 * area, 2.4, 1, Color(0.72, 1, 0.36), 24.0 * area, true)
			Sound.play("shoot", 0.45, 0.05)
		"nova":
			if nearest_enemy(p, (150.0 + l * 26.0) * area + 40.0) == null: return false
			add_nova((150.0 + l * 26.0) * area, 7.0 + l * 4.5)
			Sound.play("nova", 0.8, 0.1)
		"zap":
			var current := nearest_enemy(p, _target_range())
			if current == null: return false
			var from := p
			var seen := {}
			var jumps := 2 + l
			var dmg := 7.0 + l * 3.4
			while current != null and jumps > 0:
				seen[current.uid] = true
				_draw_beam(from, current.pos)
				from = current.pos
				damage(current, dmg, Vector2.INF, 0.0)
				current = nearest_enemy(from, 200.0 * area, seen)
				jumps -= 1
			Sound.play("zap", 0.8, 0.08)
		"starfall":
			var count := 1 + l / 2
			var fired := false
			var reach := _target_range() * 1.4
			var picks := enemies.filter(func(e): return e.alive and e.pos.distance_to(p) < reach)
			if picks.is_empty(): return false
			for i in count:
				_add_star(picks.pick_random().pos, 16.0 + l * 6.5, 58.0 * area * (1.0 + l * 0.06))
				fired = true
			return fired
		_:
			return false
	return true


func _add_bullet(dir: Vector2, speed: float, dmg: float, r: float, life: float, pierce: int, color: Color, size: float, homing: bool) -> void:
	var b := Bullet.new()
	b.pos = p
	b.vel = dir * speed
	b.dmg = dmg
	b.r = r
	b.pierce = pierce
	b.life = life
	b.homing = homing
	b.color = color
	b.size = size
	bullets.append(b)


func _update_projectiles(dt: float) -> void:
	for b: Bullet in bullets:
		b.life -= dt
		if b.homing:
			var target := nearest_enemy(b.pos, 420.0)
			if target != null:
				var want := (target.pos - b.pos).normalized() * 460.0
				b.vel += (want - b.vel) * minf(1.0, dt * 5.0)
		b.pos += b.vel * dt
		for e: Enemy in query(b.pos, b.r + 30.0):
			if b.pierce <= 0: break
			if not e.alive or b.hit.has(e.uid): continue
			var reach := e.r + b.r
			if b.pos.distance_squared_to(e.pos) < reach * reach:
				b.hit[e.uid] = true
				b.pierce -= 1
				damage(e, b.dmg, b.pos, 70.0)
		if not headless and (b.pierce <= 0 or b.life <= 0.0):
			spawn_fx(tx_soft, b.pos, Vector2.ZERO, 0.14, 26.0, 3.0, b.color)


func _update_moths(dt: float, l: int) -> void:
	moth_angle += dt * 3.1
	var radius := (82.0 + l * 5.0) * area
	var dmg := 4.0 + l * 1.8
	var hit_r := 18.0 * area
	for i in moth_count:
		var pos := p + Vector2.from_angle(moth_angle + float(i) / moth_count * TAU) * radius
		moth_pos[i] = pos
		for e: Enemy in query(pos, hit_r + 30.0):
			if not e.alive or e.moth_tick > 0.0: continue
			var reach := e.r + hit_r
			if pos.distance_squared_to(e.pos) < reach * reach:
				e.moth_tick = 0.32
				damage(e, dmg, p, 90.0)


func add_nova(radius: float, dmg: float) -> void:
	var n := Nova.new()
	n.pos = p
	n.radius = 10.0
	n.max_radius = radius
	n.dmg = dmg
	n.color = flame_def.outer
	novas.append(n)
	shake = maxf(shake, 2.5)


func _update_novas(dt: float) -> void:
	var i := 0
	while i < novas.size():
		var n: Nova = novas[i]
		n.radius += dt * n.max_radius * 3.6
		for e: Enemy in query(n.pos, n.radius + 10.0):
			if not e.alive or n.hit.has(e.uid): continue
			if n.pos.distance_to(e.pos) < n.radius + e.r:
				n.hit[e.uid] = true
				damage(e, n.dmg, n.pos, 280.0)
		if n.radius >= n.max_radius:
			novas[i] = novas[-1]
			novas.pop_back()
		else:
			i += 1


func _update_trail(l: int) -> void:
	if trail_dist <= 30.0: return
	trail_dist = 0.0
	var q := Patch.new()
	q.pos = p
	q.max_life = 1.7 + l * 0.3
	q.life = q.max_life
	q.r = (28.0 + l * 2.5) * area
	q.dmg = 3.0 + l * 1.5
	patches.append(q)


func _update_patches(dt: float) -> void:
	var i := 0
	while i < patches.size():
		var q: Patch = patches[i]
		q.life -= dt
		for e: Enemy in query(q.pos, q.r + 30.0):
			if not e.alive or e.patch_tick > 0.0: continue
			var reach := e.r + q.r * 0.8
			if q.pos.distance_squared_to(e.pos) < reach * reach:
				e.patch_tick = 0.38
				damage(e, q.dmg, Vector2.INF, 0.0)
		if q.life <= 0.0:
			patches[i] = patches[-1]
			patches.pop_back()
		else:
			i += 1


func _draw_beam(a: Vector2, b: Vector2) -> void:
	if headless: return
	# Two jagged segments look much more like lightning than a straight line.
	var mid := (a + b) * 0.5 + Vector2(randf_range(-18, 18), randf_range(-18, 18))
	for seg in [[a, mid], [mid, b]]:
		var d: Vector2 = seg[1] - seg[0]
		spawn_fx(tx_beam, (seg[0] + seg[1]) * 0.5, Vector2.ZERO, 0.16, 12.0, 3.0, Color(0.62, 0.82, 1), 0.0, d.angle(), maxf(1.0, d.length() / 12.0))


func _add_star(target: Vector2, dmg: float, r: float) -> void:
	var s := Star.new()
	s.target = target
	s.dmg = dmg
	s.r = r
	stars.append(s)


func _update_stars(dt: float) -> void:
	var i := 0
	while i < stars.size():
		var s: Star = stars[i]
		s.t += dt / 0.42
		s.rot += dt * 9.0
		if s.t >= 1.0:
			for e: Enemy in query(s.target, s.r + 30.0):
				if e.alive and s.target.distance_to(e.pos) < s.r + e.r:
					damage(e, s.dmg, s.target, 180.0)
			Sound.play("star", 0.9, 0.06)
			shake = maxf(shake, 3.0)
			var col := Color(1, 0.9, 0.55)
			spawn_fx(tx_ring, s.target, Vector2.ZERO, 0.3, 20.0, s.r * 2.3, col)
			spawn_fx(tx_soft, s.target, Vector2.ZERO, 0.22, s.r * 2.0, 8.0, col)
			stars[i] = stars[-1]
			stars.pop_back()
		else:
			i += 1


# MARK: Effects

func spawn_fx(tex: Texture2D, pos: Vector2, vel: Vector2, life: float, s0: float, s1: float, color: Color, drag := 0.0, rot := 0.0, stretch := 1.0) -> void:
	if headless or fx.size() >= fx_cap: return
	var f := Fx.new()
	f.tex = tex
	f.pos = pos
	f.vel = vel
	f.life = life
	f.max_life = life
	f.s0 = s0
	f.s1 = s1
	f.drag = drag
	f.rot = rot
	f.ratio = stretch
	f.color = color
	fx.append(f)


func _update_fx(dt: float) -> void:
	var i := 0
	while i < fx.size():
		var f: Fx = fx[i]
		f.life -= dt
		if f.life <= 0.0:
			fx[i] = fx[-1]
			fx.pop_back()
			continue
		if f.drag > 0.0: f.vel *= maxf(0.0, 1.0 - f.drag * dt)
		f.pos += f.vel * dt
		i += 1
	var j := 0
	while j < texts.size():
		var x: FloatText = texts[j]
		x.life -= dt
		if x.life <= 0.0:
			texts[j] = texts[-1]
			texts.pop_back()
			continue
		x.pos.y += x.vy * dt
		x.vy *= maxf(0.0, 1.0 - dt * 3.0)
		j += 1
	number_budget = minf(16.0, number_budget + dt * 16.0)


func _show_number(d: float, pos: Vector2, is_crit: bool) -> void:
	if number_budget < 1.0: return
	number_budget -= 1.0
	float_text(str(int(maxf(1.0, round(d)))), pos + Vector2(randf_range(-8, 8), -16), Palette.GOLD if is_crit else Color.WHITE, 25 if is_crit else 18)


func float_text(s: String, pos: Vector2, color: Color, size: int) -> void:
	if texts.size() >= 40: return
	var x := FloatText.new()
	x.s = s
	x.pos = pos
	x.color = color
	x.size = size
	x.life = 0.6
	x.vy = -70.0
	texts.append(x)


func show_banner(s: String) -> void:
	if headless: return
	banner.text = s
	if _banner_tween: _banner_tween.kill()
	banner.modulate.a = 0.0
	banner.scale = Vector2.ONE * 0.8
	_banner_tween = create_tween()
	_banner_tween.tween_property(banner, "modulate:a", 1.0, 0.15)
	_banner_tween.parallel().tween_property(banner, "scale", Vector2.ONE, 0.15)
	_banner_tween.tween_interval(1.8)
	_banner_tween.tween_property(banner, "modulate:a", 0.0, 0.4)


func _compact() -> void:
	_compact_enemies()
	var i := 0
	while i < bullets.size():
		var b: Bullet = bullets[i]
		if b.life <= 0.0 or b.pierce <= 0:
			bullets[i] = bullets[-1]
			bullets.pop_back()
		else:
			i += 1
	i = 0
	while i < enemy_bullets.size():
		if enemy_bullets[i].life <= 0.0:
			enemy_bullets[i] = enemy_bullets[-1]
			enemy_bullets.pop_back()
		else:
			i += 1
	i = 0
	while i < embers.size():
		if embers[i].value == 0:
			embers[i] = embers[-1]
			embers.pop_back()
		else:
			i += 1


func _compact_enemies() -> void:
	var i := 0
	while i < enemies.size():
		if not enemies[i].alive:
			enemies[i] = enemies[-1]
			enemies.pop_back()
		else:
			i += 1


# MARK: Painting

func _visible(pos: Vector2, margin: float) -> bool:
	return absf(pos.x - cam_pos.x) < view_w / 2.0 + margin and absf(pos.y - cam_pos.y) < VIEW_H / 2.0 + margin


func _paint_ground(l: Layer) -> void:
	const S := 1024.0
	var gx: float = roundf(cam_pos.x / S) * S
	var gy: float = roundf(cam_pos.y / S) * S
	for ix in range(-2, 3):
		for iy in range(-1, 2):
			var x: float = gx + ix * S
			var y: float = gy + iy * S
			if absf(x - cam_pos.x) < view_w / 2.0 + S / 2.0 + 30.0 and absf(y - cam_pos.y) < VIEW_H / 2.0 + S / 2.0 + 30.0:
				l.draw_texture_rect(tx_ground, Rect2(x - S / 2.0, y - S / 2.0, S + 1.0, S + 1.0), false)


func _paint_patches(l: Layer) -> void:
	for q: Patch in patches:
		var a := minf(1.0, q.life / q.max_life * 2.0) * 0.8
		var s := q.r * 3.0
		l.draw_texture_rect(tx_soft, Rect2(q.pos.x - s / 2.0, q.pos.y - s / 2.0, s, s), false, Color(1, 0.45, 0.1, a))


func _paint_enemies(l: Layer) -> void:
	for e: Enemy in enemies:
		if not e.alive or not _visible(e.pos, e.r * 2.0): continue
		var drawn := e.r * 3.1 * e.sc
		var bob := sin(e.phase * (16.0 if e.kind == Data.BAT else 5.0))
		var w := drawn * (1.0 + bob * 0.05)
		var h := drawn * (1.0 - bob * 0.05)
		var c := Color(1, 1, 1, e.flash)
		if e.flash <= 0.0 and e.elite: c = Color(Palette.GOLD, 0.32)
		l.draw_texture_rect(e.tex, Rect2(e.pos.x - w / 2.0, e.pos.y - h / 2.0, w, h), false, c)


func _paint_eyes(l: Layer) -> void:
	# Eyes draw above the darkness, so you can always see what's coming.
	for e: Enemy in enemies:
		if not e.alive or not _visible(e.pos, e.r * 2.0): continue
		var w := e.r * (1.0 if e.is_boss else 1.25) * e.sc
		var c := e.pos + e.eye_off * e.sc
		l.draw_texture_rect(tx_eyes, Rect2(c.x - w / 2.0, c.y - w / 4.0, w, w / 2.0), false, e.eye_col)


func _paint_embers(l: Layer) -> void:
	for m: Ember in embers:
		if not _visible(m.pos, m.size): continue
		var s := m.size
		if m.kind == EMBER_DUST:
			l.draw_set_transform(m.pos, m.rot)
			l.draw_texture_rect(tx_star, Rect2(-s / 2.0, -s / 2.0, s, s), false, m.color)
			l.draw_set_transform(Vector2.ZERO)
		else:
			l.draw_texture_rect(tx_ember, Rect2(m.pos.x - s / 2.0, m.pos.y - s / 2.0, s, s), false, m.color)


func _paint_novas(l: Layer) -> void:
	for n: Nova in novas:
		var s := n.radius * 2.0 / 0.9
		var a := maxf(0.0, 1.0 - n.radius / n.max_radius) * 0.9 + 0.1
		l.draw_texture_rect(tx_ring, Rect2(n.pos.x - s / 2.0, n.pos.y - s / 2.0, s, s), false, Color(n.color, a))


func _paint_bullets(l: Layer) -> void:
	for b: Bullet in bullets:
		if b.life <= 0.0: continue
		l.draw_texture_rect(tx_soft, Rect2(b.pos.x - b.size / 2.0, b.pos.y - b.size / 2.0, b.size, b.size), false, b.color)


func _paint_enemy_bullets(l: Layer) -> void:
	for b: EnemyBullet in enemy_bullets:
		l.draw_texture_rect(tx_orb, Rect2(b.pos.x - 12.0, b.pos.y - 12.0, 24.0, 24.0), false)


func _paint_moths(l: Layer) -> void:
	for i in moth_count:
		var a := moth_angle + float(i) / moth_count * TAU
		var w := 30.0 * (0.75 + absf(sin(t * 18.0 + i)) * 0.35)
		l.draw_set_transform(moth_pos[i], a)
		l.draw_texture_rect(tx_moth, Rect2(-w / 2.0, -15.0, w, 30.0), false)
	l.draw_set_transform(Vector2.ZERO)


func _paint_fx(l: Layer) -> void:
	for f: Fx in fx:
		if not _visible(f.pos, f.s0 * f.ratio): continue
		var u := f.life / f.max_life
		var s := f.s1 + (f.s0 - f.s1) * u
		var w := s * f.ratio
		var c := Color(f.color, u)
		if f.rot != 0.0:
			l.draw_set_transform(f.pos, f.rot)
			l.draw_texture_rect(f.tex, Rect2(-w / 2.0, -s / 2.0, w, s), false, c)
			l.draw_set_transform(Vector2.ZERO)
		else:
			l.draw_texture_rect(f.tex, Rect2(f.pos.x - w / 2.0, f.pos.y - s / 2.0, w, s), false, c)


func _paint_stars(l: Layer) -> void:
	var col := Color(1, 0.9, 0.55)
	for s: Star in stars:
		var u := minf(1.0, s.t)
		l.draw_set_transform(s.target + Vector2(200.0 * (1.0 - u), -460.0 * (1.0 - u)), s.rot)
		l.draw_texture_rect(tx_star, Rect2(-21.0, -21.0, 42.0, 42.0), false, col)
	l.draw_set_transform(Vector2.ZERO)


func _paint_texts(l: Layer) -> void:
	for x: FloatText in texts:
		var c := Color(x.color, minf(1.0, x.life * 3.0))
		l.draw_string(font, x.pos - Vector2(x.size * 0.28 * x.s.length(), 0), x.s, HORIZONTAL_ALIGNMENT_LEFT, -1, x.size, c)


func _paint_joystick(l: Layer) -> void:
	if joy_id < 0 or state != State.PLAYING: return
	var o := joy_origin - ui.position
	var q := joy_pos - ui.position
	l.draw_texture_rect(tx_ring, Rect2(o.x - 76.0, o.y - 76.0, 152.0, 152.0), false, Color(1, 1, 1, 0.3))
	var k := o + (q - o).limit_length(60.0)
	l.draw_texture_rect(Art.tex("dot"), Rect2(k.x - 22.0, k.y - 22.0, 44.0, 44.0), false, Color(1, 1, 1, 0.34))


# MARK: Touch

func on_touch(event: InputEvent) -> void:
	if state != State.PLAYING:
		joy_id = -1
		button_touch(event)
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			if pause_button.hit(event.position):
				button_touch(event)
			elif joy_id < 0:
				joy_id = event.index
				joy_origin = event.position
				joy_pos = event.position
		else:
			if event.index == joy_id: joy_id = -1
			button_touch(event)
	elif event is InputEventScreenDrag:
		# A thumb still down when the cards close carries on steering without lifting.
		if joy_id < 0:
			joy_id = event.index
			joy_origin = event.position
		if event.index == joy_id:
			joy_pos = event.position
			# The stick follows the thumb, so changing direction never needs a long swipe back.
			var d: Vector2 = joy_pos - joy_origin
			if d.length() > 80.0: joy_origin = joy_pos - d.limit_length(80.0)


func on_back() -> void:
	match state:
		State.PLAYING: pause()
		State.PAUSED: resume()
		State.LEVEL_UP:
			# You have to pick a card; a nudge shows Back was heard.
			if overlay:
				var tw := overlay.create_tween()
				tw.tween_property(overlay, "position:x", 14.0, 0.05)
				tw.tween_property(overlay, "position:x", -10.0, 0.05)
				tw.tween_property(overlay, "position:x", 0.0, 0.05)
		State.ENDED:
			if end_timer <= 0.0 and overlay: Main.I.go_to(TitleScene.new())


func auto_pause() -> void:
	joy_id = -1
	if state == State.PLAYING and not autopilot: pause()


# MARK: Ending

func _die() -> void:
	finished = true
	light = 0.0
	Sound.play("die", 1.0, 0.0)
	Sound.set_music_volume(0.15)
	state = State.ENDED
	shake = 12.0
	if not headless:
		for i in 40:
			spawn_fx(tx_soft, p, Vector2.from_angle(randf() * TAU) * randf_range(30, 240), randf_range(0.4, 1.0), randf_range(10, 22), 1.0, flame_def.outer, 3.0)
		var tw := create_tween()
		tw.tween_property(player_root, "modulate:a", 0.0, 0.4)
		dark_override_radius = light_radius
		var td := create_tween()
		td.tween_property(self, "dark_override_radius", 200.0, 0.8)
		td.parallel().tween_property(self, "dark_strength", 1.0, 0.8)
	end_timer = 1.1
	_record_run()


func _reach_dawn() -> void:
	finished = true
	won = true
	if not headless and not autopilot and not Main.test_mode: Save.d.dawns = int(Save.d.dawns) + 1
	Sound.play("dawn", 1.0, 0.0)
	Sound.set_music_volume(0.2)
	state = State.ENDED
	# Sunrise burns every shadow away.
	for e: Enemy in enemies:
		if e.alive and not headless:
			for i in 3:
				spawn_fx(tx_soft, e.pos, Vector2(randf_range(-20, 20), -randf_range(40, 160)), randf_range(0.4, 0.9), randf_range(10, 22), 1.0, Palette.GOLD)
		e.alive = false
	for b: EnemyBullet in enemy_bullets:
		b.life = 0.0
	_compact()
	if not headless:
		var tw := create_tween()
		tw.tween_property(self, "dark_strength", 0.0, 1.6)
		tw.parallel().tween_property(dawn_glow, "color:a", 0.3, 1.6)
		show_banner("Dawn!")
	end_timer = 2.4
	_record_run()


func score() -> int:
	return kills * 10 + int(t) * 5 + level * 50 + bosses_killed * 1000 + (5000 if won else 0)


func earned_stardust() -> int:
	var base := kills / 30.0 + t / 6.0 + picked_stardust + (60.0 if won else 0.0)
	return int(base * modifier.dust)


func _record_run() -> void:
	if headless or autopilot: return
	var d: Dictionary = Save.d
	d.runs = int(d.runs) + 1
	d.totalKills = int(d.totalKills) + kills
	d.stardust = int(d.stardust) + earned_stardust()
	d.bestTime = maxf(float(d.bestTime), t)
	var best_before := int(d.bestScore)
	_was_best = score() >= best_before and score() > 0
	d.bestScore = maxi(best_before, score())
	if mode == "daily":
		var today := Data.day_number()
		if int(d.dailyDay) != today:
			d.dailyDay = today
			d.dailyBest = 0
		d.dailyBest = maxi(int(d.dailyBest), score())
	Save.write()


var _was_best := false


# MARK: Automated runs

func _autopilot_direction() -> Vector2:
	var force := Vector2.ZERO
	for e: Enemy in query(p, 240.0):
		if not e.alive: continue
		var d := p - e.pos
		var l := maxf(d.length(), 1.0)
		var weight := (240.0 - l) / 240.0
		force += d / l * (weight * weight * 3.2)
	for b: EnemyBullet in enemy_bullets:
		var d := p - b.pos
		var l := maxf(d.length(), 1.0)
		if l < 130.0: force += d / l * 1.6
	var best: Ember = null
	var best_d := 400.0
	for m: Ember in embers:
		var l := m.pos.distance_to(p)
		var weighted := l * 0.4 if m.kind == EMBER_HEART else l
		if weighted < best_d:
			best_d = weighted
			best = m
	if best != null: force += (best.pos - p).normalized() * 0.9
	if force.length() < 0.1: return Vector2.from_angle(t * 0.6) * 0.6
	return force.normalized()


# MARK: HUD

func _update_hud() -> void:
	var frac := clampf(light / max_light, 0.0, 1.0)
	var bar_w := minf(240.0 + (max_light - 100.0) * 0.8, W() * 0.3)
	light_back.size = Vector2(bar_w, 18)
	light_bar.size = Vector2(bar_w * frac, 18)
	light_bar.color = Color(1, 0.72, 0.2) if frac > 0.5 else (Color(1, 0.5, 0.16) if frac > 0.25 else Color(1, 0.22, 0.2))
	xp_bar.size = Vector2(W() * clampf(xp / xp_needed, 0.0, 1.0), 10)
	low_label.modulate.a = 0.6 + 0.4 * sin(t * 7.0) if frac < 0.25 and not finished else 0.0
	var remaining := ceili(maxf(0.0, NIGHT_LENGTH - t))
	if remaining != _last_time_shown:
		_last_time_shown = remaining
		time_label.text = Data.time_string(remaining)
	level_label.text = "LV %d" % level
	kill_label.text = str(kills)
	var has_boss := boss != null and boss.alive and state == State.PLAYING
	# Full-screen panels use the middle of the screen, so the timer steps aside for them.
	time_label.visible = state == State.PLAYING
	time_sub.visible = state == State.PLAYING
	boss_back.visible = has_boss
	boss_bar.visible = has_boss
	boss_name.visible = has_boss
	if has_boss:
		boss_name.text = "The Old Shade" if boss.kind == Data.BOSS1 else "The Night Mother"
		boss_bar.size = Vector2(boss_back.size.x * clampf(boss.hp / boss.max_hp, 0.0, 1.0), 12)


func _refresh_build_row() -> void:
	if headless: return
	for c in build_row.get_children():
		c.queue_free()
	var x := 0.0
	for w: String in weapon_order:
		build_row.add_child(_build_icon(w, weapons[w], x))
		x += 44.0
	x += 12.0
	for pid: String in Data.PASSIVES:
		if passives.has(pid):
			build_row.add_child(_build_icon(pid, passives[pid], x))
			x += 40.0


func _build_icon(icon: String, l: int, x: float) -> Node2D:
	var n := Node2D.new()
	n.position = Vector2(x, 0)
	n.add_child(BaseScene.icon_node(icon, 28))
	var lv := Txt.make(str(l), 15, Palette.GOLD)
	lv.position = Vector2(15, 13)
	n.add_child(lv)
	return n


# MARK: Upgrade cards

func available_options() -> Array:
	var out := []
	var full_hands := weapon_order.size() >= 5
	for w: String in Data.WEAPONS:
		var l := int(weapons.get(w, 0))
		if l >= 5 or (l == 0 and full_hands): continue
		out.append("w." + w)
	for id: String in Data.PASSIVES:
		if int(passives.get(id, 0)) < Data.passive_max(id):
			out.append("p." + id)
	return out


func _option_weight(o: String) -> float:
	if o.begins_with("w."):
		# New weapons are the most exciting pick, and upgrading what you own keeps a build focused.
		if not weapons.has(o.substr(2)):
			return 3.2 if weapon_order.size() < 3 else 1.6
		return 2.2
	return 0.7 if o == "p.wind" else 1.0


func _roll_options() -> Array:
	var pool := available_options()
	var picks := []
	while picks.size() < card_count and not pool.is_empty():
		var total := 0.0
		for o: String in pool:
			total += _option_weight(o)
		var roll := randf() * total
		var index := 0
		for i in pool.size():
			roll -= _option_weight(pool[i])
			if roll <= 0.0:
				index = i
				break
		picks.append(pool[index])
		pool.remove_at(index)
	# When light is low, always give a way out of the death spiral.
	if light / max_light < 0.25 and not picks.is_empty(): picks[-1] = "warm"
	if picks.is_empty(): picks = ["warm"]
	return picks


func open_level_up() -> void:
	pending_levels -= 1
	current_options = _roll_options()
	state = State.LEVEL_UP
	if headless: return
	joy_id = -1
	Sound.play("levelup", 1.0, 0.0)
	input_lock_until = now() + 0.35
	_show_cards()


func _dim(c: Color, alpha: float) -> Box:
	var d := Box.new()
	d.size = Vector2(5000, 3000)
	d.position = Vector2(-2500, 0)
	d.color = Color(c, alpha)
	return d


func _show_cards() -> void:
	close_overlay()
	overlay = Node2D.new()
	ui.add_child(overlay)
	overlay.add_child(_dim(Palette.DIM, 0.66))
	var title := Txt.make("Your light grows", 32, Palette.GOLD)
	title.position = Vector2(0, -236)
	overlay.add_child(title)
	var sub := Txt.make("Level %d — pick one" % level, 18, Palette.MUTED)
	sub.position = Vector2(0, -202)
	overlay.add_child(sub)

	var n := current_options.size()
	var gap := 16.0
	var card_w := minf(270.0, (W() - 32.0 - gap * (n - 1)) / n)
	var total_w := n * card_w + (n - 1) * gap
	var list := []
	for i in n:
		var card := _make_card(current_options[i], card_w, 350.0)
		card.position = Vector2(-total_w / 2.0 + card_w / 2.0 + i * (card_w + gap), 0)
		overlay.add_child(card)
		list.append(card)
		card.scale = Vector2.ONE * 0.85
		card.modulate.a = 0.0
		var tw := card.create_tween()
		tw.tween_interval(i * 0.05)
		tw.tween_property(card, "modulate:a", 1.0, 0.12)
		tw.parallel().tween_property(card, "scale", Vector2.ONE, 0.14)
	if rerolls > 0:
		var r := GButton.make("Reroll (%d)" % rerolls, 220, 54, 19, reroll_cards)
		r.position = Vector2(0, 228)
		var ic := BaseScene.icon_node("reroll", 26)
		ic.position = Vector2(-80, 0)
		r.add_child(ic)
		overlay.add_child(r)
		list.append(r)
	set_buttons(list)


func reroll_cards() -> void:
	if rerolls <= 0: return
	rerolls -= 1
	current_options = _roll_options()
	_show_cards()


func _make_card(o: String, w: float, h: float) -> GButton:
	var card := GButton.make("", w, h, 20, func(): choose_option(o))
	card.radius = 20
	var icon := "warm"
	var name := "Warm Up"
	var desc := "Instantly restore 22 light."
	var lvl := 0
	var max_level := 0
	var tag := "RESCUE"
	var tag_color := Color(1, 0.62, 0.4)
	if o.begins_with("w."):
		var wid := o.substr(2)
		var current := int(weapons.get(wid, 0))
		icon = wid
		name = Data.WEAPON_NAME[wid]
		lvl = current + 1
		max_level = 5
		desc = Data.weapon_blurb(wid, lvl)
		tag = "NEW WEAPON" if current == 0 else "WEAPON"
		tag_color = Palette.GOLD if current == 0 else Color(0.62, 0.82, 1)
	elif o.begins_with("p."):
		var pid := o.substr(2)
		icon = pid
		name = Data.PASSIVE_NAME[pid]
		lvl = int(passives.get(pid, 0)) + 1
		max_level = Data.passive_max(pid)
		desc = Data.PASSIVE_BLURB[pid]
		tag = "PASSIVE"
		tag_color = Palette.VIOLET
	var badge := Txt.make(tag, 15, tag_color)
	badge.position = Vector2(0, -h / 2.0 + 26)
	card.add_child(badge)
	var e := BaseScene.icon_node(icon, 76)
	e.position = Vector2(0, -74)
	card.add_child(e)
	var n := Txt.make(name, 26, Palette.CREAM)
	n.fit_width = w - 24.0
	n.position = Vector2(0, 2)
	card.add_child(n)
	var d := Txt.make(desc, 19, Palette.MUTED)
	d.wrap_width = w - 30.0
	d.position = Vector2(0, 26)
	card.add_child(d)
	if max_level > 1:
		var pip_w := 22.0
		var start := -(max_level - 1) * pip_w / 2.0
		for i in max_level:
			var pip := Sprite2D.new()
			pip.texture = Art.tex("dot")
			pip.scale = Vector2.ONE * 13.0 / 64.0
			pip.modulate = Palette.GOLD if i < lvl else Color(1, 1, 1, 0.18)
			pip.position = Vector2(start + i * pip_w, h / 2.0 - 28)
			card.add_child(pip)
	return card


func choose_option(o: String) -> void:
	if o.begins_with("w."): grant_weapon(o.substr(2))
	elif o.begins_with("p."): apply_passive(o.substr(2))
	else: light = minf(max_light, light + 22.0)
	if headless:
		state = State.PLAYING
		return
	close_overlay()
	set_buttons([pause_button])
	if pending_levels > 0:
		open_level_up()
	else:
		state = State.PLAYING
		i_frames = maxf(i_frames, 0.4)   # a small grace period after the world un-freezes


func close_overlay() -> void:
	if overlay:
		overlay.queue_free()
		overlay = null


# MARK: Pause

func pause() -> void:
	if state != State.PLAYING: return
	state = State.PAUSED
	joy_id = -1
	Sound.set_music_volume(0.2)
	overlay = Node2D.new()
	ui.add_child(overlay)
	overlay.add_child(_dim(Palette.DIM, 0.72))
	var title := Txt.make("Paused", 42, Palette.CREAM)
	title.position = Vector2(0, -206)
	overlay.add_child(title)
	var hint := Txt.make("Touch and drag anywhere to move. Your flame shoots by itself.", 17, Palette.MUTED)
	hint.fit_width = W() - 40.0
	hint.position = Vector2(0, -162)
	overlay.add_child(hint)
	var resume_b := GButton.make("Keep going", 300, 60, 23, resume)
	resume_b.position = Vector2(0, -100)
	var sound_b := GButton.make("Sound: off" if Save.d.muted else "Sound: on", 300, 60, 23, Callable())
	sound_b.action = func():
		Sound.toggle_mute()
		sound_b.title.text = "Sound: off" if Save.d.muted else "Sound: on"
	sound_b.position = Vector2(0, -28)
	var restart := GButton.make("Restart night", 300, 60, 23, func(): Main.I.go_to(GameScene.new(mode)))
	restart.position = Vector2(0, 44)
	var quit := GButton.make("Back to title", 300, 60, 23, func(): Main.I.go_to(TitleScene.new()))
	quit.position = Vector2(0, 116)
	var list := [resume_b, sound_b, restart, quit]
	for b in list:
		overlay.add_child(b)
	set_buttons(list)


func resume() -> void:
	close_overlay()
	set_buttons([pause_button])
	state = State.PLAYING
	Sound.set_music_volume(0.5)


# MARK: End of run

func show_end_screen() -> void:
	overlay = Node2D.new()
	ui.add_child(overlay)
	var dim := _dim(Color(0.26, 0.11, 0.10) if won else Palette.DIM, 0.0)
	overlay.add_child(dim)
	var target: Color = dim.color
	target.a = 0.78 if won else 0.8
	dim.create_tween().tween_property(dim, "color", target, 0.3)

	var title := Txt.make("You made it to dawn!" if won else "Your light went out", 40, Palette.GOLD if won else Palette.CREAM)
	title.position = Vector2(0, -226)
	overlay.add_child(title)
	var survived := Data.time_string(minf(t, NIGHT_LENGTH))
	var sub := Txt.make("The shadows melt away. Your little flame lives another day." if won
			else "You lasted %s of the night. One more go?" % survived, 18, Palette.MUTED)
	sub.fit_width = W() - 40.0
	sub.position = Vector2(0, -186)
	overlay.add_child(sub)
	var rows := [["Survived", survived], ["Shadows burned", str(kills)], ["Level reached", str(level)],
			["Score", str(score()) + ("  ★ best" if _was_best else "")]]
	for i in rows.size():
		var y := -146.0 + i * 31.0
		var a := Txt.make(rows[i][0], 20, Palette.MUTED, 1)
		a.position = Vector2(-14, y)
		var b := Txt.make(rows[i][1], 22, Palette.CREAM, -1)
		b.position = Vector2(14, y)
		overlay.add_child(a)
		overlay.add_child(b)
	var dust := Txt.make("+%d ✦ stardust" % earned_stardust(), 28, Palette.VIOLET)
	dust.position = Vector2(0, -8)
	dust.scale = Vector2.ONE * 0.6
	var tw := dust.create_tween()
	tw.tween_interval(0.25)
	tw.tween_property(dust, "scale", Vector2.ONE, 0.2)
	overlay.add_child(dust)
	var hint := Txt.make(_unlock_hint(), 17, Palette.GOLD)
	hint.fit_width = W() - 40.0
	hint.position = Vector2(0, 28)
	overlay.add_child(hint)
	var again := GButton.make("Another night" if won else "Try again", 320, 70, 26, func(): Main.I.go_to(GameScene.new(mode)))
	again.position = Vector2(0, 92)
	var back := GButton.make("Title and upgrades", 320, 60, 21, func(): Main.I.go_to(TitleScene.new()))
	back.position = Vector2(0, 168)
	overlay.add_child(again)
	overlay.add_child(back)
	input_lock_until = now() + 0.45
	set_buttons([again, back])


## Tells the player how close they are to something new, which is what makes "one more run" hard to resist.
func _unlock_hint() -> String:
	var dust := int(Save.d.stardust)
	for f in Data.FLAMES:
		if not Save.d.unlocked.has(f.id):
			if dust >= f.cost: return "You can unlock the %s flame on the title screen!" % f.name
			return "%d ✦ more to unlock the %s flame" % [f.cost - dust, f.name]
	for item in Data.SHOP:
		var l := Save.shop_level(item.id)
		if l < item.max and dust >= item.cost * (l + 1): return "You can afford %s in the upgrades screen!" % item.name
	return "You have %d ✦ stardust" % dust
