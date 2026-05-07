extends Area2D

class_name Bullet

# 和第几层的物理碰撞，使用位掩码，1<<0表示第一层，1<<1表示第二层，以此类推。
const WORLD_COLLISION_MASK := 1

# 子弹飞行速度
@export var speed: float = 320.0

# 子弹存活时间
@export var max_lifetime: float = 2.0

# 子弹当前飞行方向
var direction: Vector2 = Vector2.RIGHT
# 子弹剩余存活时间
var remaining_lifetime: float = 0.0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	remaining_lifetime = max_lifetime
	area_entered.connect(_on_area_entered)

# 实例化子弹
func setup(initial_direction: Vector2) -> void:
	if initial_direction != Vector2.ZERO:
		direction = initial_direction.normalized()

	rotation = direction.angle()

func _physics_process(delta: float) -> void:
	var current_position := global_position
	var next_position := current_position + direction * speed * delta

	if _will_hit_world(current_position, next_position):
		# queuefree对于对象的删除：避免大量对象积累导致性能问题，及时清理不再需要的对象。
		queue_free()
		return

	global_position = next_position

	remaining_lifetime -= delta
	if remaining_lifetime <= 0.0:
		queue_free()

func _will_hit_world(from_position: Vector2, to_position: Vector2) -> bool:
	var space_state := get_world_2d().direct_space_state
	if space_state == null:
		return false
	
	var query := PhysicsRayQueryParameters2D.create(
		from_position,
		to_position,
		WORLD_COLLISION_MASK)
	query.collide_with_bodies = true
	query.collide_with_areas = false
	var hit_result := space_state.intersect_ray(query)
	return not hit_result.is_empty()

func _on_area_entered(area: Area2D) -> void:
	if area is Bullet:
		return
	
	queue_free()
