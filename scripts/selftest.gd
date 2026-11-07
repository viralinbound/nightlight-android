extends Node
## Plays the real screens with made-up finger touches and saves pictures. Never touches the player's progress.

var dir := ""
var fails := 0
var passes := 0


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(dir)
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [dir, name])
	print("SHOT ", name)


func _ok(cond: bool, what: String) -> void:
	if cond:
		passes += 1
		print("PASS ", what)
	else:
		fails += 1
		print("FAIL ", what)


## Real touches arrive in phone pixels and the engine scales them to screen units; made-up ones must do the same.
func _to_window(pos: Vector2) -> Vector2:
	return pos * Vector2(DisplayServer.window_get_size()) / get_viewport().get_visible_rect().size


func _touch(pos: Vector2, down: bool, index := 0) -> void:
	var e := InputEventScreenTouch.new()
	e.device = Main.TEST_DEVICE
	e.index = index
	e.position = _to_window(pos)
	e.pressed = down
	Input.parse_input_event(e)
	Input.flush_buffered_events()


func _drag(pos: Vector2, index := 0) -> void:
	var e := InputEventScreenDrag.new()
	e.device = Main.TEST_DEVICE
	e.index = index
	e.position = _to_window(pos)
	Input.parse_input_event(e)
	Input.flush_buffered_events()


func _tap(pos: Vector2) -> void:
	_touch(pos, true)
	await get_tree().process_frame
	_touch(pos, false)
	await get_tree().process_frame


func _tap_button(b: GButton) -> void:
	await _tap(b.global_position)


func _settle() -> void:
	while Main.I.switching:
		await get_tree().process_frame
	await _wait(0.2)


func start(shot_dir: String, _playthrough := false) -> void:
	dir = shot_dir
	await _wait(0.6)
	var saved_stardust: int = int(Save.d.stardust)
	Save.d.stardust = 0

	# Title screen.
	var title: TitleScene = Main.I.current
	await _wait(1.0)
	await _shot("title")
	var w := get_viewport().get_visible_rect().size
	print("screen units ", w)
	_ok(w.y >= 540.0 and w.x >= 960.0, "screen fits the layout")
	await _tap_button(title.right_arrow)
	_ok(title.flame_index == 1, "right arrow picks the next flame")
	_ok(title.play_button.disabled, "locked flame without stardust can't be bought")
	await _shot("title_locked")
	await _tap_button(title.play_button)
	_ok(Main.I.current == title, "disabled Play does nothing")
	await _tap_button(title.left_arrow)
	_ok(title.flame_index == 0, "left arrow goes back")
	var muted: bool = Save.d.muted
	await _tap_button(title.sound_button)
	_ok(Save.d.muted != muted, "sound button toggles")
	await _tap_button(title.sound_button)

	# The intern's test-build-1 report: Back on the title asks before quitting.
	Main.I._notification(NOTIFICATION_WM_GO_BACK_REQUEST)
	await _wait(0.2)
	_ok(title.quit_box != null, "Back on the title asks before quitting")
	await _shot("quit_ask")
	await _tap_button(title.quit_box.get_child(3))
	_ok(title.quit_box == null and Main.I.current == title, "Stay closes the question")
	# A finger that never lifts (palm on the glass) must not block the next tap.
	_touch(w * Vector2(0.5, 0.95), true, 3)
	await _wait(1.6)
	var fi := title.flame_index
	await _tap_button(title.right_arrow)
	_ok(title.flame_index != fi, "a stuck finger doesn't block taps")
	_touch(w * Vector2(0.5, 0.95), false, 3)
	await get_tree().process_frame
	await _tap_button(title.left_arrow)
	# A sloppy tap that lands just off the button edge still counts.
	fi = title.flame_index
	await _tap(title.right_arrow.global_position + Vector2(title.right_arrow.w / 2.0 + 12.0, 0))
	_ok(title.flame_index != fi, "a tap just off the edge still counts")
	await _tap_button(title.left_arrow)
	var sm := title.safe_margins()
	print("safe margins ", sm, " safe area ", DisplayServer.get_display_safe_area(), " window ", DisplayServer.window_get_size())
	_ok(sm.left >= 40.0 and sm.right >= 40.0, "side margins keep clear of a camera hole")

	# Upgrades.
	Save.d.stardust = 100
	await _tap_button(title.shop_button)
	await _settle()
	var shop: ShopScene = Main.I.current
	_ok(shop is ShopScene, "Upgrades opens")
	await _wait(0.5)
	await _shot("shop")
	var before := Save.shop_level("flame")
	await _tap_button(shop.rows[0][1])
	_ok(Save.shop_level("flame") == before + 1, "tapping a row buys it")
	_ok(int(Save.d.stardust) == 70, "stardust is spent")
	Save.d.shop.erase("flame")
	Save.d.stardust = 0
	Main.I.current.on_back()
	await _settle()
	title = Main.I.current
	_ok(title is TitleScene, "Back returns to the title")

	# Play.
	await _tap_button(title.play_button)
	await _settle()
	var g: GameScene = Main.I.current
	_ok(g is GameScene, "Play starts a night")
	await _wait(0.5)
	await _shot("game_start")

	# The finger moves the flame the way it drags.
	var c := w / 2.0
	var p0 := g.p
	_touch(c + Vector2(-200, 100), true)
	await get_tree().process_frame
	_drag(c + Vector2(-140, 100))
	await _wait(0.6)
	await _shot("game_joystick")
	_ok(g.p.x > p0.x + 40.0 and absf(g.p.y - p0.y) < 25.0, "dragging right moves the flame right (moved %s)" % str(g.p - p0))
	var p1 := g.p
	_drag(c + Vector2(-200, 170))
	await _wait(0.4)
	_ok(g.p.y > p1.y + 20.0, "dragging down moves the flame down")
	_touch(c + Vector2(-200, 170), false)
	await get_tree().process_frame
	var p2 := g.p
	await _wait(0.3)
	_ok(g.p == p2, "lifting the finger stops the flame")

	# Weapons kill things and embers level you up.
	g.light = g.max_light
	for i in 8:
		g.spawn(Data.SHADE, g.p + Vector2.from_angle(i * 0.8) * 150.0)
	await _wait(2.5)
	_ok(g.kills > 0, "the flame shoots by itself (%d kills)" % g.kills)
	await _shot("game_fight")

	# Upgrade cards: a thumb already down must not pick a card.
	g.light = g.max_light
	_touch(c, true)
	g._add_xp(g.xp_needed + 0.1)
	await _wait(0.5)
	_ok(g.state == GameScene.State.LEVEL_UP, "levelling up opens the cards")
	await _shot("cards")
	var cards_count := g.current_options.size()
	_ok(cards_count == 3, "three cards offered")
	g.card_count = 4
	g.rerolls = 2
	g.reroll_cards()
	await _wait(0.4)
	_ok(g.current_options.size() == 4, "the Fourth Card upgrade shows four cards")
	await _shot("cards4")
	g.reroll_cards()
	await _wait(0.3)
	await _shot("cards4_reroll")
	_touch(c, false)
	await get_tree().process_frame
	_ok(g.state == GameScene.State.LEVEL_UP, "a thumb lifting doesn't pick a card")
	var lvl_w := g.weapons.duplicate()
	var lvl_p := g.passives.duplicate()
	await _tap_button(g.buttons[0])
	_ok(g.state == GameScene.State.PLAYING, "tapping a card closes the cards")
	_ok(g.weapons != lvl_w or g.passives != lvl_p or g.current_options[0] == "warm", "the chosen upgrade is applied")

	# Every weapon runs on screen without errors.
	for wid in Data.WEAPONS:
		if not g.weapons.has(wid): g.grant_weapon(wid)
	g.pending_levels = 0
	g.light = g.max_light
	for i in 30:
		g.spawn([Data.SHADE, Data.BAT, Data.BLOB, Data.SPITTER, Data.BOMBER][i % 5], g.p + Vector2.from_angle(i * 0.4) * randf_range(120, 300))
	await _wait(3.0)
	await _shot("game_all_weapons")
	g.light = g.max_light
	g.pending_levels = 0

	# Leaving the app: game pauses, music stops; coming back brings the music back.
	if g.state == GameScene.State.LEVEL_UP: g.choose_option("warm")
	g.pending_levels = 0
	Main.I._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	await get_tree().process_frame
	_ok(g.state == GameScene.State.PAUSED, "leaving the app pauses the game")
	_ok(Sound._music.stream_paused and AudioServer.is_bus_mute(0), "leaving the app silences the music")
	Main.I._notification(NOTIFICATION_APPLICATION_FOCUS_IN)
	await get_tree().process_frame
	_ok(not Sound._music.stream_paused and AudioServer.is_bus_mute(0) == Save.d.muted, "coming back restores the sound")
	_ok(g.state == GameScene.State.PAUSED, "the game stays paused until you tap Keep going")
	g.resume()
	await get_tree().process_frame

	# Pause button and the phone's Back button.
	if g.state == GameScene.State.LEVEL_UP: g.choose_option("warm")
	g.pending_levels = 0
	await _wait(0.1)
	await _tap_button(g.pause_button)
	_ok(g.state == GameScene.State.PAUSED, "pause button pauses")
	await _wait(0.3)
	await _shot("paused")
	var frozen := g.t
	await _wait(0.3)
	_ok(g.t == frozen, "time stops while paused")
	Main.I._notification(NOTIFICATION_WM_GO_BACK_REQUEST)
	_ok(g.state == GameScene.State.PLAYING, "Back resumes")
	Main.I._notification(NOTIFICATION_WM_GO_BACK_REQUEST)
	_ok(g.state == GameScene.State.PAUSED, "Back pauses")
	g.resume()

	# Boss.
	g.t = g.event_times[3] - 0.1   # boss time shifts a little every night
	g.next_event = 3
	g.light = g.max_light
	await _wait(0.4)
	_ok(g.boss != null, "the boss arrives on time")
	if g.boss: g.boss.pos = g.p + Vector2(220, 0)
	g.light = g.max_light
	await _wait(0.5)
	await _shot("game_boss")

	# Low light warning, then death.
	if g.state == GameScene.State.LEVEL_UP: g.choose_option("warm")
	g.pending_levels = 0
	g.revives = 0
	g.light = g.max_light * 0.1
	await _wait(0.3)
	await _shot("game_low_light")
	if g.state == GameScene.State.LEVEL_UP: g.choose_option("warm")
	g.pending_levels = 0
	g.light = -1.0
	await _wait(1.8)
	_ok(g.state == GameScene.State.ENDED and g.finished, "running out of light ends the night")
	await _shot("end_lost")
	Main.I._notification(NOTIFICATION_WM_GO_BACK_REQUEST)
	await _settle()
	_ok(Main.I.current is TitleScene, "Back on the end screen returns to the title")
	await _tap_button(Main.I.current.play_button)
	await _settle()
	g = Main.I.current
	g.light = -1.0
	await _wait(1.8)
	_ok(int(Save.d.runs) >= 1, "the run is counted")
	await _wait(0.5)
	await _tap_button(g.buttons[0])
	await _settle()
	g = Main.I.current
	_ok(g is GameScene and g.t < 2.0, "Try again starts a new night")

	# Dawn.
	g.t = GameScene.NIGHT_LENGTH - 20.0
	g.next_event = GameScene.EVENTS.size()
	g.light = g.max_light
	await _wait(0.5)
	await _shot("game_near_dawn")
	g.t = GameScene.NIGHT_LENGTH - 0.01
	g.light = g.max_light
	await _wait(3.2)
	_ok(g.won, "reaching dawn wins")
	await _shot("end_won")

	_ok(not FileAccess.file_exists("user://save.json"), "test runs never write the player's progress")
	Save.d.stardust = saved_stardust
	print("RESULT passes=%d fails=%d" % [passes, fails])
	get_tree().quit(1 if fails > 0 else 0)


## Lets the automated player run the busiest part of a night and reports the real frame rate.
func perf(g: GameScene, shot_dir: String) -> void:
	dir = shot_dir
	await _wait(1.0)
	var run_seconds := 20.0
	# Busiest stretch of the night, with a late-game build.
	g.t = 225.0
	g.next_event = 6
	for wid in ["bolt", "moths", "nova", "zap", "starfall"]:
		for i in 4:
			g.grant_weapon(wid)
	g.max_light = 100000.0
	g.light = 100000.0
	for i in 420:
		g.spawn([Data.SHADE, Data.BAT, Data.BLOB, Data.SPITTER][i % 4], g.p + Vector2.from_angle(randf() * TAU) * randf_range(200, 760))
	var frames := 0
	var slowest := 0.0
	var total := 0.0
	var over := 0
	var started := Time.get_ticks_msec()
	while (Time.get_ticks_msec() - started) / 1000.0 < run_seconds:
		g.light = 100000.0
		await get_tree().process_frame
		var dt := get_process_delta_time()
		frames += 1
		total += dt
		slowest = maxf(slowest, dt)
		if dt > 1.0 / 45.0: over += 1
	await _shot("perf_busy")
	print("PERF fps=%.1f slowestMs=%.1f framesUnder45=%d of %d enemies=%d fx=%d lowQuality=%s" % [frames / total, slowest * 1000.0, over, frames, g.enemies.size(), g.fx.size(), str(g.low_quality)])
	get_tree().quit()
