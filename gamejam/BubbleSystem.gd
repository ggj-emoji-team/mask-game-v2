extends Node
class_name BubbleSystem

const EMOJI_CORPUS := {
	"LAUGH": {
		"emoji": "😂",
		"lines": [
			"lol",
			"haha",
			"this is fine",
			"nice one",
			"keep going 😂",
			"you’re funny",
			"that was cute",
			"again?",
			"ok ok",
			"lmao"
		]
	},
	"ANGRY": {
		"emoji": "😡",
		"lines": [
			"wrong",
			"no",
			"focus",
			"again",
			"too slow",
			"this is bad",
			"try harder",
			"you failed",
			"not good enough",
			"stop messing up"
		]
	}
}



signal missed_changed(value: int)

@export var bubble_lifetime: float = 3.0
@export var max_on_screen: int = 999
@export var bubble_scene: PackedScene

# 重要：把 AudioStreamPlayer 拖进来
@export var audio_player: AudioStreamPlayer

var missed: int = 0
var _queue: Array[Bubble] = []

# 你的节奏时间表（秒）
var beatmap_times: Array[float] = []
var _beat_idx: int = 0

@onready var bubble_queue_ui: VBoxContainer = get_tree().current_scene.get_node("UI/HUD/BubbleQueue")

func _ready():
	missed = 0
	emit_signal("missed_changed", missed)

func set_beatmap(times: Array[float]) -> void:
	beatmap_times = times
	_beat_idx = 0

func reset():
	missed = 0
	emit_signal("missed_changed", missed)
	_queue.clear()
	for c in bubble_queue_ui.get_children():
		c.queue_free()
	_beat_idx = 0

func _process(_dt: float) -> void:
	if audio_player == null or not audio_player.playing:
		return

	_spawn_by_beatmap()
	_check_expired()

func _spawn_by_beatmap() -> void:
	if beatmap_times.is_empty():
		return
	if bubble_scene == null:
		push_error("BubbleSystem: bubble_scene not assigned!")
		return

	var now := audio_player.get_playback_position()

	# 关键：用 while，避免卡顿时漏生成
	while _beat_idx < beatmap_times.size() and now >= beatmap_times[_beat_idx]:
		_spawn_bubble(now)
		_beat_idx += 1

func _spawn_bubble(now: float) -> void:
	if _queue.size() >= max_on_screen:
		return

	var b := bubble_scene.instantiate() as Bubble

	# --- 随机选情绪 ---
	var emotion_keys := EMOJI_CORPUS.keys()
	var emotion: String = emotion_keys.pick_random()
	var data: Dictionary = EMOJI_CORPUS[emotion]

	# --- 随机选一句话 ---
	var line: String = data["lines"].pick_random()
	var emoji: String = data["emoji"]
	# 最终显示文本
	var text := "%s %s" % [emoji, line]

	b.setup(text, now, bubble_lifetime, emotion)  # ✅ 多传一个 emotion
	bubble_queue_ui.add_child(b)
	_queue.append(b)


func _check_expired() -> void:
	if _queue.is_empty():
		return

	var now: float = 0.0
	if audio_player != null:
		now = audio_player.get_playback_position()
	else:
		now = Time.get_ticks_msec() / 1000.0

	while not _queue.is_empty():
		var head := _queue[0]
		if not is_instance_valid(head):
			_queue.pop_front()
			continue

		if head.is_expired(now):
			head.queue_free()
			_queue.pop_front()
			missed += 1
			emit_signal("missed_changed", missed)
		else:
			break


func consume_oldest_bubble() -> bool:
	if _queue.is_empty():
		return false

	var head: Bubble = _queue.pop_front()
	if is_instance_valid(head):
		head.queue_free()
	return true
	
func peek_oldest_emotion() -> String:
	if _queue.is_empty():
		return ""
	var head: Bubble = _queue[0]
	if not is_instance_valid(head):
		return ""
	return head.emotion
