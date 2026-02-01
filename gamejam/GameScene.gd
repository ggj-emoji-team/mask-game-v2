extends Node2D

signal on_hit(accuracy: String, song_time: float, idx: int)  #个脚本挂在主游戏场景上，负责整体流程和判定

enum AttackType {
	LAUGH,   # 😂
	ANGRY   # 😡
}


@onready var bubble_system: BubbleSystem = $Systems/BubbleSystem
@onready var missed_label: Label = $UI/HUD/MissedLabel
@onready var start_panel: Control = $UI/StartPanel
@onready var hud: Control = $UI/HUD
@onready var start_button: Button = $UI/StartPanel/StartButton
@onready var audio: AudioStreamPlayer = $Audio
@onready var accuracy_label: Label = $UI/HUD/AccuracyLabel
@onready var accuracy_timer: Timer = $AccuracyTimer
@onready var attack_emoji_label: Label = $UI/HUD/AttackEmojiLabel
@onready var attack_emoji_timer: Timer = $AttackEmojiTimer
@onready var score_label: Label = $UI/HUD/ScoreLabel
@onready var result_panel: Control = $UI/ResultPanel
@onready var result_label: Label = $UI/ResultPanel/ResultLabel
@onready var restart_button: Button = $UI/ResultPanel/RestartButton
@onready var mode_label: Label = $UI/HUD/ModeLabel
@onready var graveyard: Control = get_node_or_null("UI/HUD/Graveyard")
@onready var wrong_label: Label = $UI/HUD/WrongLabel
@onready var hit_sfx: AudioStreamPlayer = $HitSfx
@onready var wrong_sfx: AudioStreamPlayer = $WrongSfx



var current_attack: AttackType = AttackType.LAUGH

# 你的 beatmap（30秒）
var beatMap_30s: Array[float] = [
	1.0, 1.5, 2.0, 2.5, 3.0, 3.5, 4.0, 4.5, 5.0, 5.5,
	6.0, 6.5, 7.0, 7.5, 8.0, 8.5, 9.0, 9.5, 10.0, 10.5,
	11.0, 11.5, 12.0, 12.5, 13.0, 13.5, 14.0, 14.5, 15.0, 15.5,
	16.0, 16.5, 17.0, 17.5, 18.0, 18.5, 19.0, 19.5, 20.0, 20.5,
	21.0, 21.5, 22.0, 22.5, 23.0, 23.5, 24.0, 24.5, 25.0, 25.5,
	26.0, 26.5, 27.0, 27.5, 28.0, 28.5, 29.0, 29.5, 30.0
]
var hit_idx: int = 0

# 判定窗口（秒）：你可以之后调参
const PERFECT_WINDOW := 0.5
const GOOD_WINDOW := 1.0
# const FAIL_MISSED_LIMIT := 12
var wrong_count: int = 0
const FAIL_WRONG_LIMIT := 12

# 分数（可选）
var score: int = 0
const PERFECT_SCORE := 100
const GOOD_SCORE := 60
const BASE_PER_INPUT := 5
const MISS_PENALTY := 20
const WRONG_PENALTY := 30
const WIN_SCORE := 800

var _shake_time: float = 0.0
var _shake_strength: float = 0.0
var _base_pos: Vector2

func _ready() -> void:
	_base_pos = position
	start_panel.show()
	hud.hide()

	start_button.pressed.connect(_on_start_pressed)

	bubble_system.missed_changed.connect(_on_missed_changed)
	_on_missed_changed(0)
	
	#用来记录on_hit
	on_hit.connect(func(acc: String, t: float, i: int) -> void:
		print("[OnHit] acc=", acc, " t=", "%.2f" % t, " idx=", i)
	)
	
	accuracy_timer.timeout.connect(_on_accuracy_timeout)
	accuracy_label.text = ""
	
	attack_emoji_timer.timeout.connect(_on_attack_emoji_timeout)
	attack_emoji_label.hide()

	result_panel.hide()
	restart_button.pressed.connect(_on_restart_pressed)

	score_label.text = "score: %d" % score
	
	_update_mode_ui()
	
	GameManager.game_over.connect(_on_game_over)
	
	_update_wrong_ui()




var is_playing: bool = false

func _play_attack_emoji(attack: AttackType) -> void:
	match attack:
		AttackType.LAUGH:
			attack_emoji_label.text = "😂"
		AttackType.ANGRY:
			attack_emoji_label.text = "😡"

	attack_emoji_label.show()
	attack_emoji_timer.stop()
	attack_emoji_timer.start()



func _on_attack_emoji_timeout() -> void:
	attack_emoji_label.hide()


func _show_accuracy(text: String) -> void:
	accuracy_label.text = text
	accuracy_timer.stop()
	accuracy_timer.start()

func _on_accuracy_timeout() -> void:
	accuracy_label.text = ""

func _update_mode_ui() -> void:
	match current_attack:
		AttackType.LAUGH:
			mode_label.text = "mode: 😂"
		AttackType.ANGRY:
			mode_label.text = "mode: 😡"


func _on_start_pressed() -> void:
	GameManager.reset()
	start_panel.hide()
	hud.show()

	# 重要：先重置系统，再塞 beatmap
	bubble_system.reset()
	bubble_system.set_beatmap(beatMap_30s)

	# 播放音乐（让 bubble_system 用播放时间当时钟）
	audio.stop()
	audio.play()

	is_playing = true
	
	hit_idx = 0
	score = 0
	wrong_count = 0
	_update_wrong_ui()
	score_label.text = "score: %d" % score
	result_panel.hide()

	current_attack = AttackType.LAUGH
	_update_mode_ui()

	if graveyard != null:
		for c in graveyard.get_children():
			c.queue_free()


func _on_missed_changed(v: int) -> void:
	missed_label.text = "missed: %d" % v

	#if is_playing and v >= FAIL_MISSED_LIMIT:
	#	_on_game_over("MISSED")



func _unhandled_input(event: InputEvent) -> void:
	if not is_playing:
		return
	if event is InputEventKey and event.echo:
		return

	# 1) 切换模式：↑ / ↓
	if event.is_action_pressed("ui_up"):
		current_attack = AttackType.LAUGH
		_update_mode_ui()
		return

	if event.is_action_pressed("ui_down"):
		current_attack = AttackType.ANGRY
		_update_mode_ui()
		return

	# 2) 攻击：Space（走你的 Perfect/Good/Miss）
	if event.is_action_pressed("hit"):
		_add_score(BASE_PER_INPUT)          # ✅ 基础分（每次输入）
		_on_hit_pressed(current_attack)

func _add_score(delta: int) -> void:
	score = max(score + delta, 0)
	score_label.text = "score: %d" % score

	if score >= WIN_SCORE:
		_win()


# func _on_attack(attack: AttackType) -> void:
# 	_play_attack_emoji(attack)
# 	bubble_system.consume_oldest_bubble()


func _on_hit_pressed(attack: AttackType) -> void:
	# _play_attack_emoji(attack) # 不要在这里播放攻击emoji！只在命中且匹配成功时播放
	# bubble_system.consume_oldest_bubble()

	# 下面原本的 Perfect/Good/Miss 判定你可以先留着或暂时 return
	# 如果你想暂时不判定，就直接 return：
	# return
	
	if hit_idx >= beatMap_30s.size():
		_show_judgement("MISS")
		return

	var now: float = audio.get_playback_position()

	# ✅ 自动推进：如果当前时间已经超过目标拍子太多，就把这些拍子判成“漏掉”
	while hit_idx < beatMap_30s.size() and now > beatMap_30s[hit_idx] + GOOD_WINDOW:
		# 你可以在这里统计“missed_notes”，先 print 也行
		print("AUTO MISS (late): idx=", hit_idx, " target=", beatMap_30s[hit_idx], " now=", now)
		hit_idx += 1

	# 推进后可能已经打完
	if hit_idx >= beatMap_30s.size():
		_show_judgement("MISS")
		return

	var target: float = beatMap_30s[hit_idx]
	var diff: float = abs(now - target)

	# ✅ 调试输出：让你看清楚你差了多少秒
	print("PRESS: idx=", hit_idx, " target=", target, " now=", now, " diff=", diff)

	if diff <= PERFECT_WINDOW:
			# ✅ 先检查匹配
		var target_emotion: String = bubble_system.peek_oldest_emotion()
		var attack_emotion: String = _attack_to_emotion(attack)

	# 没气泡：你可以当作 WRONG 或者直接不处理（这里我当作 WRONG 更直观）
		if target_emotion == "":
			_on_wrong()
			return

		if target_emotion != attack_emotion:
			_on_wrong()
			return


		# ✅ 匹配成功才算 PERFECT
		_show_judgement("PERFECT")
		_play_attack_emoji(attack)
		_on_success_hit(PERFECT_SCORE)
		_do_hit_feedback(true)
		hit_idx += 1
		on_hit.emit("PERFECT", now, hit_idx)

		
	elif diff <= GOOD_WINDOW:
		var target_emotion: String = bubble_system.peek_oldest_emotion()
		var attack_emotion: String = _attack_to_emotion(attack)

		if target_emotion == "" or target_emotion != attack_emotion:
			_on_wrong()
			return


		_show_judgement("GOOD")
		_play_attack_emoji(attack)
		_on_success_hit(GOOD_SCORE)
		_do_hit_feedback(false)
		hit_idx += 1
		on_hit.emit("GOOD", now, hit_idx)

	else:
		_show_judgement("MISS")
		_add_score(-MISS_PENALTY)
		on_hit.emit("MISS", now, hit_idx) # 即使是 MISS，也要记下来



func _on_success_hit(add: int) -> void:
	var removed: bool = bubble_system.consume_oldest_bubble()
	if removed:
		_add_score(add)


func _win() -> void:
	is_playing = false
	audio.stop()

	# 可选：把判定文字清掉
	accuracy_label.text = ""

	result_label.text = "YOU WIN! (%d/%d)" % [score, WIN_SCORE]
	result_panel.show()

func _on_restart_pressed() -> void:
	_on_start_pressed()




func _show_judgement(text: String) -> void:
	_show_accuracy(text)

func _attack_to_emotion(attack: AttackType) -> String:
	match attack:
		AttackType.LAUGH:
			return "LAUGH"
		AttackType.ANGRY:
			return "ANGRY"
	return ""

func _on_game_over(reason: String) -> void:
	if not is_playing:
		return

	is_playing = false
	audio.stop()
	accuracy_label.text = ""

	match reason:
		"OVERFLOW":
			result_label.text = "YOU LOSE!\nEmotion Overflow"
		"WRONG":
			result_label.text = "YOU LOSE!\nWrong Emotion Too Many Times"
		_:
			result_label.text = "YOU LOSE!"

	result_panel.show()

	

func _on_wrong() -> void:
	wrong_count += 1
	_update_wrong_ui()
	_show_judgement("WRONG")
	_add_score(-WRONG_PENALTY)

	print("[WRONG] count = ", wrong_count)

	if is_playing and wrong_count >= FAIL_WRONG_LIMIT:
		_on_game_over("WRONG")
	
	if wrong_sfx != null:
		wrong_sfx.play()


func _update_wrong_ui() -> void:
	if wrong_label == null:
		return
	wrong_label.text = "wrong: %d" % wrong_count
	
func _hit_stop(duration: float = 0.04) -> void:
	Engine.time_scale = 0.05
	await get_tree().create_timer(duration * 0.05).timeout
	Engine.time_scale = 1.0


func _process(delta: float) -> void:
	# 你如果 GameScene 没有 _process，就新加；有的话就合并进去
	if _shake_time > 0.0:
		_shake_time -= delta
		position = _base_pos + Vector2(
			randf_range(-_shake_strength, _shake_strength),
			randf_range(-_shake_strength, _shake_strength)
		)
	else:
		position = _base_pos

func _shake(strength: float = 4.0, time: float = 0.08) -> void:
	_shake_strength = strength
	_shake_time = time
	
	
func _punch_attack_emoji() -> void:
	if attack_emoji_label == null:
		return

	var tween := create_tween()
	attack_emoji_label.scale = Vector2.ONE
	tween.tween_property(attack_emoji_label, "scale", Vector2(1.35, 1.35), 0.06)
	tween.tween_property(attack_emoji_label, "scale", Vector2.ONE, 0.10)

func _do_hit_feedback(is_perfect: bool) -> void:
	# 音效
	if hit_sfx != null:
		hit_sfx.pitch_scale = 1.10 if is_perfect else 1.00
		hit_sfx.play()

	# 轻微停顿（很爽）
	_hit_stop(0.05 if is_perfect else 0.04)

	# 抖动
	_shake(6.0, 0.08) if is_perfect else _shake(4.0, 0.06)

	# emoji 弹一下
	_punch_attack_emoji()
