# res://Scripts/GameManager.gd
extends Node

# --- 配置 (Config) ---
# 允许堆积的最大数量 (根据设计调整)
var max_overflow_count: int = 8

# --- 运行时自动获取 (Auto-fetched) ---
var screen_bottom_y: float = 0.0
var bubble_height: float = 0.0 

# --- 状态 (State) ---
var current_stack_index: int = 0

var difficulty_spike_factor: float = 0.2

func _ready():
	# 【严谨】自动获取当前游戏窗口的真实高度
	# 这样你不需要手动改 1080 或 720
	screen_bottom_y = get_viewport().get_visible_rect().size.y
	
	print("[GameManager] 初始化: 屏幕底部 Y = ", screen_bottom_y)

func reset():
	current_stack_index = 0

# 【严谨】由 Bubble 自己告诉我它有多高
# 这样如果你的气泡素材换了大小，堆积高度会自动适应
func get_stack_target_y(bubble_visual_height: float) -> float:
	# 记录一下气泡高度（方便调试）
	bubble_height = bubble_visual_height
	
	# 计算目标位置：屏幕底部 - (当前堆了几个 * 气泡高度)
	# 注意：这里假设气泡的锚点(Origin)在中心。如果在左上角，可能需要微调。
	var target_y = screen_bottom_y - (current_stack_index * bubble_height) - (bubble_height / 2.0)
	return target_y

func add_overflow():
	current_stack_index += 1
	print("[GameManager] 堆积层数: ", current_stack_index)
	
	if current_stack_index >= max_overflow_count:
		trigger_game_over()

func get_compressed_lifetime(base_lifetime: float) -> float:
	# 计算缩减后的寿命
	var reduction = current_stack_index * difficulty_spike_factor
	var new_lifetime = base_lifetime - reduction
	
	# 设置保底时间 (Clamp)
	# 即使堆满了，也要给玩家至少 0.8 秒反应，否则游戏会卡死在逻辑里
	var min_lifetime = 0.8
	
	var final_lifetime = max(new_lifetime, min_lifetime)
	
	# 调试打印，让你在控制台看到难度真的变了
	# print("[Difficulty] Stack: ", current_stack_index, " | New Lifetime: ", final_lifetime)
	
	return final_lifetime

func trigger_game_over():
	print("!!! GAME OVER !!!")
	# 这里后续接 UI
	
	
