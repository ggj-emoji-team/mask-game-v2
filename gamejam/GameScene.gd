extends Node2D

signal on_hit(accuracy: String, song_time: float) #个脚本挂在主游戏场景上，负责整体流程和判定

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

# 分数（可选）
var score: int = 0
const PERFECT_SCORE := 100
const GOOD_SCORE := 60


func _ready() -> void:
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



func _on_start_pressed() -> void:
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


func _on_missed_changed(v: int) -> void:
	missed_label.text = "missed: %d" % v


func _unhandled_input(event: InputEvent) -> void:
	if not is_playing:
		return
	if event is InputEventKey and event.echo:
		return

	if event.is_action_pressed("hit"):
		var attack: AttackType = AttackType.LAUGH
		if event is InputEventKey and event.alt_pressed:
			attack = AttackType.ANGRY
		_on_hit_pressed(attack)

# func _on_attack(attack: AttackType) -> void:
# 	_play_attack_emoji(attack)
# 	bubble_system.consume_oldest_bubble()


func _on_hit_pressed(attack: AttackType) -> void:
	_play_attack_emoji(attack)
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
			_show_judgement("WRONG")
			return

		if target_emotion != attack_emotion:
			_show_judgement("WRONG")
			return

		# ✅ 匹配成功才算 PERFECT
		_show_judgement("PERFECT")
		_play_attack_emoji(attack)
		_on_success_hit(PERFECT_SCORE)
		hit_idx += 1
		
	elif diff <= GOOD_WINDOW:
		var target_emotion: String = bubble_system.peek_oldest_emotion()
		var attack_emotion: String = _attack_to_emotion(attack)

		if target_emotion == "" or target_emotion != attack_emotion:
			_show_judgement("WRONG")
			return

		_show_judgement("GOOD")
		_play_attack_emoji(attack)
		_on_success_hit(GOOD_SCORE)
		hit_idx += 1
	else:
		_show_judgement("MISS")
		on_hit.emit("MISS", now, hit_idx) # 即使是 MISS，也要记下来



func _on_success_hit(add: int) -> void:
	# 命中才消一个气泡（FIFO）
	var removed := bubble_system.consume_oldest_bubble()

	# 可选：如果没气泡，就不加分（看你们设计）
	if removed:
		score += add
		# 如果你有 ScoreLabel，就更新它
		# score_label.text = "score: %d" % score


func _show_judgement(text: String) -> void:
	_show_accuracy(text)

func _attack_to_emotion(attack: AttackType) -> String:
	match attack:
		AttackType.LAUGH:
			return "LAUGH"
		AttackType.ANGRY:
			return "ANGRY"
	return ""

	
