extends CharacterBody2D

class_name Enemy

const DEFAULT_BULLET_DAMAGE = 1
const BLINK_ENABLED_SHADER_PARAMETER := &"blink_enabled"
const PICKUP_SCENE := preload("res://scene/pickup.tscn")
const EXPLOSION_QUERY_MAX_RESULTS := 16

# 这个枚举定义了敌人死亡序列的不同阶段，包括没有死亡、正在死亡和爆炸阶段。通过使用这个枚举，可以更清晰地管理敌人在不同阶段的行为和状态。	d
enum DeathSequenceStage{
	NONE,
	DEATH,
	EXPLOSION,
}

@export var config : EnemyConfig

@export var touch_damage : int = 1
# 敌人贴住玩家时造成伤害的间隔，相当于无敌帧
@export var touch_damage_interval : float = 0.5
# 玩家被伤害时闪烁的持续时间
@export var hurt_blink_duration : float = 0.2

# $符号在Godot中用于获取节点的引用。它是一个快捷方式，可以直接通过节点的名称来访问该节点。例如，$AnimatedSprite2D表示获取当前节点下名为AnimatedSprite2D的子节点的引用。同样，$CollisionShape2D表示获取当前节点下名为CollisionShape2D的子节点的引用。这种方式使得代码更简洁，避免了使用get_node()方法来获取节点引用。
# 节点名字可以自定义吗？是的，节点名字是可以自定义的。在Godot编辑器中，你可以为每个节点设置一个唯一的名字，以便在代码中通过$符号来引用它们。只要确保在代码中使用的名字与编辑器中设置的名字一致，就可以正确地获取到对应的节点引用。
@onready var animated_sprite : AnimatedSprite2D = $AnimatedSprite2D
@onready var collision_shape : CollisionShape2D = $CollisionShape2D
@onready var touch_damage_area : Area2D = $TouchDamageArea
@onready var touch_damage_shape : CollisionShape2D = $TouchDamageArea/CollisionShape2D 
@onready var explosion_area : Area2D = $ExplosionArea
@onready var explosion_shape : CollisionShape2D = $ExplosionArea/CollisionShape2D

var target_player: Player = null

var current_health: int = 1

var is_dead : bool = false

var touch_damage_cooldown_timer : float = 0.0

var touched_player : Player = null

var hurt_blink_time_left : float = 0.0

var death_sequence_stage : DeathSequenceStage = DeathSequenceStage.NONE

var death_animation_name_in_use : StringName = &""

var random_generator : RandomNumberGenerator = RandomNumberGenerator.new()

func _ready() -> void:
	random_generator.randomize()
	touch_damage_area.body_entered.connect(_on_touch_damage_area_body_entered)
	touch_damage_area.body_exited.connect(_on_touch_damage_area_body_exited)
	touch_damage_area.area_entered.connect(_on_touch_damage_area_area_entered)
	animated_sprite.animation_finished.connect(_on_animated_sprite_animation_finished)
	_apply_config()


func setup(enemy_config: EnemyConfig, player : Player) -> void:
	config = enemy_config
	target_player = player
	_apply_config()

func set_target_player(player: Player) -> void:
	target_player = player

func apply_damage(damage_amount:int) -> bool:
	if is_dead:
		return false
	if damage_amount <= 0:
		return false
	
	current_health -= damage_amount
	if current_health <= 0:
		die()
		return true
	_start_hurt_blink()
	return true

func _physics_process(delta: float) -> void:
	_update_hurt_blink(delta)
	_update_touch_damage(delta)

	if is_dead:
		velocity = Vector2.ZERO
		return
	
	if not is_instance_valid(target_player):
		velocity = Vector2.ZERO
		move_and_slide()
		return

	var move_direction := global_position.direction_to(target_player.global_position)
	_update_facing(move_direction)


func _update_facing(move_direction: Vector2) -> void:
	if is_zero_approx(move_direction.x):
		return 
	animated_sprite.flip_h = move_direction.x < 0

func _update_hurt_blink(delta: float) -> void:
	if hurt_blink_time_left <= 0.0:
		return
	hurt_blink_time_left = maxf(hurt_blink_time_left - delta, 0.0)
	if hurt_blink_time_left > 0.0:
		return
	
	_set_hurt_blink_enabled(false)

func _update_touch_damage(delta: float) -> void:
	if touch_damage_cooldown_timer > 0.0:
		touch_damage_cooldown_timer = maxf(touch_damage_cooldown_timer-delta, 0.0)
	
	if touched_player == null:
		return
	if not is_instance_valid(touched_player):
		touched_player = null
		return
	if touch_damage_cooldown_timer > 0.0:
		return 
	_try_deal_touch_damage()

func _apply_config() -> void:
	if config == null:
		return
	
	current_health = config.max_health
	_apply_collision_radius(config.collision_radius)
	_apply_explosion_radius(config.explosion_radius)

	if config.enemy_frames != null:
		animated_sprite.frames = config.enemy_frames
		if config.enemy_frames.has_animation(config.move_animation_name):
			animated_sprite.play(config.move_animation_name)
		else:
			push_warning("Missing enemy move animation: %s " % config.move_animation_name)

func _apply_collision_radius(radius: float) -> void:
	var body_shape := collision_shape.shape as CircleShape2D
	if body_shape != null:
		body_shape.radius = radius

	var damage_shape := touch_damage_shape.shape as CircleShape2D
	if damage_shape != null:
		damage_shape.radius = radius

func _apply_explosion_radius(radius: float) -> void:
	var explosion_circle_shape := explosion_shape.shape as CircleShape2D
	if explosion_circle_shape != null:
		explosion_circle_shape.radius = maxf(0.0, radius)

func _get_move_speed() -> float:
	if config == null:
		return 0.0
	return config.move_speed

# 通过shaderMaterial的参数控制闪烁
func _start_hurt_blink() -> void:
	hurt_blink_time_left = hurt_blink_duration
	_set_hurt_blink_enabled(true)

func _set_hurt_blink_enabled(enabled: bool) -> void:
	var sprite_material := animated_sprite.material as ShaderMaterial
	if sprite_material != null:
		sprite_material.set_shader_parameter(BLINK_ENABLED_SHADER_PARAMETER, enabled)

func die() -> void:
	if is_dead:
		return
	
	is_dead = true
	velocity = Vector2.ZERO
	touched_player = null
	hurt_blink_time_left = 0.0
	_set_hurt_blink_enabled(false)
	collision_shape.set_deferred("disabled", true)
	touch_damage_shape.set_deferred("disabled", true)
	touch_damage_area.set_deferred("monitorable", false)
	touch_damage_area.set_deferred("monitoring", false)
	_try_drop_pickup()
	_start_death_sequence()

func _on_touch_damage_area_body_entered(body:Node2D) -> void:
	if is_dead:
		return
	# 下面这个写法的好处在哪里？这种写法的好处在于它结合了类型检查和变量赋值的功能，使得代码更加简洁和易读。通过使用is关键字，可以直接检查进入碰撞区域的对象是否是Player类型，并且如果是的话，立即将其赋值给touch_player变量。这种方式避免了需要先进行类型检查然后再进行变量赋值的冗长代码，使得逻辑更加清晰。同时，这种写法也减少了潜在的错误，因为它确保了只有当对象确实是Player类型时才会进行赋值操作。
	var player := body as Player
	if player == null:
		return	
	
	touched_player = player
	_try_deal_touch_damage()
		

func _on_touch_damage_area_body_exited(body:Node2D) -> void:
	if body == touched_player:
		touched_player = null

func _on_touch_damage_area_area_entered(area:Area2D) -> void:
	if is_dead:
		return 

	var bullet := area as Bullet
	if bullet == null:
		return 
	var damaged := apply_damage(DEFAULT_BULLET_DAMAGE)
	if damaged:
		bullet.queue_free()

func _try_deal_touch_damage() -> void:
	if touched_player == null:
		return 
	touched_player.apply_damage(touch_damage)
	touch_damage_cooldown_timer = touch_damage_interval

func _try_drop_pickup() -> void:
	if config == null:
		return
	if config.pickup_drop_configs.is_empty():
		return 
	if random_generator.randf() > config.pickup_drop_chance:
		return
	
	var pickup_config := _pick_pickup_drop_config()
	if pickup_config == null:
		return
	
	call_deferred("_spawn_dropped_pickup", pickup_config,global_position)

func _pick_pickup_drop_config() -> PickupConfig:
	if config == null:
		return null
	
	var avaliable_pickup_configs : Array[PickupConfig] = []
	var total_weight := 0.0
	for pickup_config in config.pickup_drop_configs:
		if pickup_config == null:
			continue
		if pickup_config.drop_weight <= 0.0:
			continue
		
		avaliable_pickup_configs.append(pickup_config)
		total_weight += pickup_config.drop_weight
	if avaliable_pickup_configs.is_empty():
		return null
	if total_weight <= 0.0:
		return null
	
	var target_weight := random_generator.randf_range(0.0, total_weight)
	var current_weight := 0.0

	for pickup_config in avaliable_pickup_configs:
		current_weight += pickup_config.drop_weight
		if target_weight <= current_weight:
			return pickup_config
	
	return avaliable_pickup_configs.back()

func _start_death_sequence() -> void:

	if config == null:
		queue_free()
		return

	if _play_death_sequence_animation(config.death_animation_name, DeathSequenceStage.DEATH):
		return
	
	_finish_after_death_animation()
	
func _play_death_sequence_animation(animation_name: StringName, stage: DeathSequenceStage) -> bool:
	death_sequence_stage = stage
	death_animation_name_in_use = animation_name

	if config == null:
		return false
	if config.enemy_frames == null:
		return false
	if not config.enemy_frames.has_animation(animation_name):
		return false
	
	animated_sprite.play(animation_name)
	return true

func _finish_after_death_animation() -> void:
	if _should_play_explosion_sequence():
		_start_explosion_sequence()
		return
	
	queue_free()

func _should_play_explosion_sequence() -> bool:
	return config != null and config.explosion_with_death

func _start_explosion_sequence() -> void:
	if not _should_play_explosion_sequence():
		queue_free()
		return
	
	_try_apply_explosion_damage()

	if _play_death_sequence_animation(config.explosion_animation_name, DeathSequenceStage.EXPLOSION):
		return
	queue_free()

func _try_apply_explosion_damage() -> void:
	if config == null:
		return
	if not config.explosion_with_death:
		return
	if config.explosion_damage <= 0 or config.explosion_radius <= 0.0:
		return	
	if explosion_area == null:
		return
	
	var space_state := get_world_2d().direct_space_state
	if space_state == null:
		return 

	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = explosion_shape.shape
	query.transform = explosion_shape.global_transform
	query.collision_mask = explosion_area.collision_mask
	query.collide_with_bodies = true
	query.collide_with_areas = false
	query.exclude = [get_rid()]
	var query_res := space_state.intersect_shape(query, EXPLOSION_QUERY_MAX_RESULTS)
	if query_res.is_empty():
		return
	
	var damage_collider_ids: Dictionary = {}

	for res in query_res:
		var collider := res.get("collider") as Node
		if collider == null:
			continue
		if collider == self:
			continue
		
		var collider_id := collider.get_instance_id()
		if damage_collider_ids.has(collider_id):
			continue
		damage_collider_ids[collider_id] = true

		var hit_player := collider as Player
		if hit_player != null:
			hit_player.apply_damage(config.explosion_damage)
			continue
		
		var hit_enemy := collider as Enemy
		if hit_enemy != null:
			hit_enemy.apply_damage(config.explosion_damage)

func _spawn_dropped_pickup(pickup_config: PickupConfig, spawn_position: Vector2) -> void:
	var drop_parent := get_parent()
	if drop_parent == null:
		return
	
	var pickup_instance := PICKUP_SCENE.instantiate() as Pickup
	if pickup_instance == null:
		return
		
	pickup_instance.config = pickup_config
	drop_parent.add_child(pickup_instance)
	pickup_instance.global_position = spawn_position

func _on_animated_sprite_animation_finished() -> void:
	if not is_dead:
		return
	if death_animation_name_in_use == &"":
		return
	if animated_sprite.animation != death_animation_name_in_use:
		return
	
	match death_sequence_stage:
		DeathSequenceStage.DEATH:
			_finish_after_death_animation()
		DeathSequenceStage.EXPLOSION:
			queue_free()
		_:
			queue_free()