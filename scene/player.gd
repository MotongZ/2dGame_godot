extends CharacterBody2D
# 玩家角色脚本，处理玩家的移动、动画和射击逻辑。
# 为什么需要一个前缀？因为玩家有两套动画，一套是普通状态的动画，另一套是武装状态的动画。通过使用前缀，可以方便地根据当前状态切换不同的动画系列，而不需要为每个状态单独管理动画名称。这种方式使得代码更简洁，易于维护和扩展。

const NORMAL_ANIMATION_PREFIX := &"normal"
# 定义一些常量，例如预加载子弹场景、动画前缀、默认射速倍率等。
const BULLET_SCENE := preload("res://scene/bullet.tscn")
# 同理，武装状态的前缀。
const ARMED_ANIMATION_PREFIX := &"armed"
# 默认射速倍率，可以通过游戏中的某些机制（如升级或道具）进行调整。
const DEFAULT_FIRE_RATE_MULTIPLIER := 1.0
# 武装状态下的射速倍率
const SPIRAL_PHASE_STEP := PI/12

# 定义常量用于区分玩家的模式
const PLAYER_FROM_MODE_NORMAL := 0
const PLAYER_FROM_MODE_ARMED := 1
# 定义常量用于区分设计模式
const SHOT_PATTERN_NORMAL := 0
const SHOT_PATTERN_SPIRAL := 1
'''
上面的区分玩家模式和设计模式可否使用枚举完成？使用枚举可以使代码更清晰，增加可读性，并且减少使用魔法数字的风险。以下是如何使用枚举来替代常量：
定义枚举用于区分玩家的模式
enum PlayerFormMode {
	NORMAL,
	ARMED
}

# 定义枚举用于区分设计模式
enum ShotPattern {
	NORMAL,
	SPIRAL
}
'''

# 角色动画节点，用于播放四方向动画。
# onready关键字表示在节点准备就绪后才会获取该节点的引用，确保在访问节点时它已经存在。
# body_sprite节点用于显示玩家角色的动画。
@onready var body_sprite: AnimatedSprite2D = $BodySprite

# armed_effect_sprite节点，用于显示武装状态的特效动画。
@onready var armed_effect_sprite: AnimatedSprite2D = $ArmedEffectSprite

# shooting_timer: 用于控制射击间隔，确保玩家不能过快地射击。
@onready var shooting_timer: Timer = $ShootingTimer

# facing_suffix变量用于确定当前角色面向的方向，默认是向右。
# &符号表示这是一个StringName类型的常量，适合用作动画名称的后缀。
# 在Godot中，&符号用于创建一个StringName类型的常量，这种类型在Godot内部被优化用于快速比较和查找字符串。使用StringName可以提高性能，特别是在需要频繁比较字符串的情况下，例如动画名称。相比于普通的字符串，StringName在内存中只存储一次，并且通过引用来使用，这样可以减少内存占用和提高效率。因此，在定义动画名称等需要频繁使用的字符串时，使用&符号创建StringName是一个好的实践。
var facing_suffix : StringName = &"right"

# rapid_fire_rate_multiplier变量用于调整射击速率的倍率，默认值为DEFAULT_FIRE_RATE_MULTIPLIER。
var rapid_fire_rate_multiplier : float = DEFAULT_FIRE_RATE_MULTIPLIER

# from_fire_rate_multiplier变量用于调整射击速率的倍率，默认值为DEFAULT_FIRE_RATE_MULTIPLIER。
var from_fire_rate_multiplier : float = DEFAULT_FIRE_RATE_MULTIPLIER

var current_form_mode : int = PLAYER_FROM_MODE_NORMAL

var current_shot_pattern : int = SHOT_PATTERN_NORMAL

# spiral_phase变量用于控制螺旋射击模式下子弹的发射角度，初始值为0.0。
var spiral_phase : float = 0.0

@export var move_speed : float = 120.0

# fire_interval变量用于控制射击间隔时间，单位为秒，默认值为0.18秒。
@export var fire_interval : float = 0.18

@export var bullet_spawn_distance : float = 18.0

func _ready() -> void:
	# 测试强化模式
	current_form_mode = PLAYER_FROM_MODE_ARMED
	current_shot_pattern = SHOT_PATTERN_SPIRAL
	from_fire_rate_multiplier = 20.0
	spiral_phase = 0.0

	shooting_timer.one_shot = true
	shooting_timer.wait_time = _get_effective_fire_interval()
	_update_animation()
	_update_armed_effect()

func _update_animation() -> void:
	var animation_name := StringName("%s_%s" % [_get_animation_prefix(),facing_suffix])
	
	if not body_sprite.sprite_frames.has_animation(animation_name):
		var fallback_animation_name := StringName("%s_%s" %[NORMAL_ANIMATION_PREFIX,facing_suffix])
		if not body_sprite.sprite_frames.has_animation(fallback_animation_name):
			push_warning("Missing Player animation : %s" % animation_name)
			return 
		
	if body_sprite.animation != animation_name:
		body_sprite.play(animation_name)
		

func _vector_to_facing_suffix(direction:Vector2) -> StringName:
		if abs(direction.x) >= abs(direction.y):
			return &"right" if direction.x > 0.0 else &"left"
		
		return &"down" if direction.y > 0.0 else &"up"
 
# 默认自己计数处理，与刷新率无关。

func _physics_process(delta: float) -> void:
	var move_input := Input.get_vector("move_left","move_right","move_up","move_down")
	var shoot_input := Input.get_vector("shoot_left","shoot_right","shoot_up","shoot_down")
	
	velocity = move_input * move_speed
	move_and_slide()
	
	if current_shot_pattern == SHOT_PATTERN_SPIRAL:
		_try_auto_sprial_shoot()
	elif shoot_input != Vector2.ZERO:
		_try_shoot(shoot_input)
	
	_update_facing(move_input, shoot_input)	
	_update_animation()
	_update_armed_effect() 


func _update_facing(move_input:Vector2, shoot_input:Vector2) -> void:
	if current_shot_pattern == SHOT_PATTERN_SPIRAL:
		if move_input != Vector2.ZERO:
			facing_suffix = _vector_to_facing_suffix(move_input)
		return
	
	if shoot_input != Vector2.ZERO:
		facing_suffix = _vector_to_facing_suffix(shoot_input)
	elif move_input != Vector2.ZERO:
		facing_suffix = _vector_to_facing_suffix(move_input)

func _try_shoot(shoot_input: Vector2) -> void:
	if not shooting_timer.is_stopped():
		return
	
	var shoot_direction := shoot_input.normalized()
	var has_spawn_bullet := _fire_bullets(shoot_direction)
	if has_spawn_bullet:
		shooting_timer.start(_get_effective_fire_interval())

func _fire_bullets(base_direction: Vector2) -> bool:
	if current_shot_pattern == SHOT_PATTERN_SPIRAL:
		var has_spawn_forward_bullet := _spwan_bullet(base_direction)
		var has_spawn_backward_bullet := _spwan_bullet(base_direction.rotated(PI))
		spiral_phase = wrapf(spiral_phase + SPIRAL_PHASE_STEP,0.0, TAU)
		return has_spawn_backward_bullet or has_spawn_forward_bullet
	return _spwan_bullet(base_direction)

func _spwan_bullet(shoot_direction: Vector2) -> bool:
	var bullet := BULLET_SCENE.instantiate() as Bullet
	if bullet == null:
		return false
	
	bullet.top_level = true
	bullet.setup(shoot_direction)

	var spawn_parent := get_tree().current_scene
	if spawn_parent == null:
		return false
	
	spawn_parent.add_child(bullet)
	bullet.global_position = global_position + shoot_direction * bullet_spawn_distance
	return true

func _try_auto_sprial_shoot() -> void:
	if not shooting_timer.is_stopped():
		return

	var spiral_direction := Vector2.RIGHT.rotated(spiral_phase)
	var has_spwan_bullet := _fire_bullets(spiral_direction)
	if has_spwan_bullet:
		shooting_timer.start(_get_effective_fire_interval())

func _get_effective_fire_interval() -> float:
	return maxf(fire_interval / _get_effective_fire_rate_multiplier(), 0.01)

func _get_effective_fire_rate_multiplier() -> float:
	if _has_activate_form_override():
		return maxf(from_fire_rate_multiplier,0.01)

	return maxf(from_fire_rate_multiplier,0.02)

func _has_activate_form_override() -> bool:
	return (
		current_form_mode != PLAYER_FROM_MODE_NORMAL
		or 
		current_shot_pattern != SHOT_PATTERN_NORMAL
	)

func _update_armed_effect() -> void:
	var is_armed := current_form_mode == PLAYER_FROM_MODE_ARMED
	if not is_armed:
		if armed_effect_sprite.visible:
			armed_effect_sprite.visible = false
		if armed_effect_sprite.is_playing():
			armed_effect_sprite.stop()
		return

	if not armed_effect_sprite.visible:
		armed_effect_sprite.visible = true
	if armed_effect_sprite.is_playing():
		return
	if armed_effect_sprite.sprite_frames == null:
		return
	
	if armed_effect_sprite.sprite_frames.has_animation(&"default"):
		armed_effect_sprite.play(&"default")
	else:
		push_warning("Missing Player Armed Effect animation : %s" % "armed_effect")

func _get_animation_prefix() -> StringName:
	if current_form_mode == PLAYER_FROM_MODE_ARMED:
		return ARMED_ANIMATION_PREFIX
	return NORMAL_ANIMATION_PREFIX

