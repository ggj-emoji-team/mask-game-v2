extends PanelContainer

class_name Bubble

var born_time: float = 0.0
var lifetime: float = 3.0
var emotion: String = ""   # ✅ 新增：这个气泡的情绪标签（"LAUGH" / "ANGRY"）
var is_dead: bool = false # 【新增】标记是否已堆积/石化

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
	# 【新增】如果是死气泡，永远不算过期（防止被系统回收）
	if is_dead:
		return false
		
	return (now - born_time) >= lifetime
	
# 【新增】C3 核心功能：变身成底部的堆积物
func become_stone() -> void:
	if is_dead: return # 防止重复调用
	
	is_dead = true
	
	# 1. 视觉变化：变灰，像石头一样
	modulate = Color(0.4, 0.4, 0.4)
	
	# 2. 核心插入：移出自动布局容器
	# 假设你的 Graveyard 节点就在 HUD 下面
	var graveyard = get_tree().current_scene.find_child("Graveyard", true, false)
	if graveyard:
		reparent(graveyard)
	
	# 3. 获取自身真实高度 (PanelContainer 会自动计算 size)
	# 严谨获取，不瞎猜数值
	var my_height = size.y * scale.y
	
	# 4. 问 GameManager 我该去哪里 (读取全局计算)
	var target_y = GameManager.get_stack_target_y(my_height)
	
	# 5. 强行位移到目标位置
	# 注意：因为你是 PanelContainer，如果父节点是 VBoxContainer 等，这行可能无效
	# 但如果是普通的 Control/Node2D 父节点，这行能让它瞬间吸附到底部
	position.y = target_y
	
	# 6. 通知经理：堆积层数+1
	GameManager.add_overflow()
