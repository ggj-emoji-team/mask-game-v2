extends Node
class_name BubbleSystem

signal missed_changed(value: int)

@export var bubble_lifetime: float = 3.0
@export var max_on_screen: int = 999
@export var bubble_scene: PackedScene
@export var audio_player: AudioStreamPlayer

# 两种情绪语料库
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

var missed: int = 0
var _queue: Array[Bubble] = []

var beatmap_times: Array[float] = []
var _beat_idx: int = 0

@onready var bubble_queue_ui: VBoxContainer = get_tree().current_scene.get_node_or_null("UI/HUD/BubbleQueue")


func _ready() -> void:
	missed = 0
	emit_signal("missed_changed", missed)


func set_beatmap(times: Array[float]) -> void:
	beatmap_times = times
	_beat_idx = 0


func reset() -> void:
	missed = 0
	emit_signal("missed_changed", missed)

	_queue.clear()
	if bubble_queue_ui != null:
		for c in bubble_queue_ui.get_children():
			c.queue_free()

	_beat_idx = 0


func _process(_dt: float) -> void:
	if audio_player == null or not audio_player.playing:
		return
	if bubble_queue_ui == null:
		# 避免刷屏：只报一次也行，但 jam 阶段先这样
		push_error("BubbleSystem: cannot find UI/HUD/BubbleQueue")
		return

	_spawn_by_beatmap()
	_check_expired()


func _spawn_by_beatmap() -> void:
	if beatmap_times.is_empty():
		return
	if bubble_scene == null:
		push_error("BubbleSystem: bubble_scene not assigned!")
		return

	var now: float = audio_player.get_playback_position()

	while _beat_idx < beatmap_times.size() and now >= beatmap_times[_beat_idx]:
		_spawn_bubble(now)
		_beat_idx += 1


func _spawn_bubble(now: float) -> void:
	if _queue.size() >= max_on_screen:
		return

	var b: Bubble = bubble_scene.instantiate() as Bubble
	if b == null:
		push_error("BubbleSystem: bubble_scene is not a Bubble (check Bubble.tscn root script)!")
		return

	# 随机选情绪与台词
	var emotion_keys: Array = EMOJI_CORPUS.keys()
	var emotion: String = emotion_keys.pick_random()
	var data: Dictionary = EMOJI_CORPUS[emotion]

	var lines: Array = data["lines"]
	var line: String = lines.pick_random()
	var emoji: String = data["emoji"]

	var text: String = "%s %s" % [emoji, line]

# ✅ 修改点：动态计算寿命
	var dynamic_life = GameManager.get_compressed_lifetime(bubble_lifetime)

	# 使用动态寿命进行 setup
	b.setup(text, now, dynamic_life, emotion)

	bubble_queue_ui.add_child(b)
	_queue.append(b)


func _check_expired() -> void:
	if _queue.is_empty():
		return

	var now: float = audio_player.get_playback_position()

	while not _queue.is_empty():
		var head: Bubble = _queue[0]

		if not is_instance_valid(head):
			_queue.pop_front()
			continue

		if head.is_expired(now):
			# head.queue_free()  <--- 注释掉或删掉这行
			head.become_stone()  # <--- 改成这一行！召唤石化逻辑！
			
			_queue.pop_front()   # 继续把它从“待消除队列”里移除，保证它不会挡住下一个气泡

			missed += 1
			emit_signal("missed_changed", missed)
		else:
			break


# 给 GameScene：消掉队首气泡（FIFO）
func consume_oldest_bubble() -> bool:
	if _queue.is_empty():
		return false

	var head: Bubble = _queue.pop_front()
	if is_instance_valid(head):
		head.queue_free()
	return true


# 给 GameScene：查看队首气泡情绪（用于 WRONG 判定）
func peek_oldest_emotion() -> String:
	if _queue.is_empty():
		return ""
	var head: Bubble = _queue[0]
	if not is_instance_valid(head):
		return ""
	return head.emotion
