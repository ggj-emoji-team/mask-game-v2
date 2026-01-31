extends PanelContainer
class_name Bubble

var born_time: float = 0.0
var lifetime: float = 3.0
var emotion: String = ""   # ✅ 新增：这个气泡的情绪标签（"LAUGH" / "ANGRY"）

func setup(message: String, now: float, life: float, emo: String) -> void:
	# 关键：不要用 @onready 变量，直接现找节点
	var label := get_node("Text") as Label
	if label != null:
		label.text = message
	else:
		push_error("Bubble: cannot find child Label named 'Text'")

	born_time = now
	lifetime = life
	emotion = emo   # ✅ 记录情绪

func is_expired(now: float) -> bool:
	return (now - born_time) >= lifetime
