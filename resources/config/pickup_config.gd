extends Resource

class_name PickupConfig

enum PickupType{
    SPEED,
    RAPID,
    SPIRAL,
}

enum PlayerFormMode{
    NORMAL,
    ARMED,
}

enum ShotPattern{
    NORMAL,
    SPIRAL,
}


# export_group字段的作用是将相关的导出变量分组显示在Godot编辑器的Inspector面板中，
#这样可以提高变量的组织性和可读性。通过使用export_group，可以将相关的变量放在一起，方便开发者在编辑器中找到和修改它们。例如，在这个PickupConfig资源中，可以使用export_group将与速度提升相关的变量分组在一起，将与射速提升相关的变量分组在一起，以此类推。这种分组方式使得编辑器界面更加清晰，减少了寻找特定变量的时间，提高了开发效率。
@export_group("基础信息")
# pickup_type变量用于指定道具的类型，使用枚举PickupType来定义不同的道具类型。
@export var pickup_type : PickupType = PickupType.SPEED

@export var display_name : String = "移速道具"

@export_range(0.0,1000.0,0.1,"or_greater") var drop_weight : float = 1.0

################

@export_group("显示资源")

@export var icon_texture: Texture2D

################

@export_group("Buff 效果")

@export_range(0.0, 120.0, 0.1, "or_greater") var duration : float = 5.0

@export_range(0.0, 5.0,0.05,"or_greater") var move_speed_multiplier : float = 1.0

@export_range(0.1,5.0,0.05,"or_greater") var fire_rate_multiplier : float = 1.0

################

@export_group("形态与弹幕")

@export var player_form_mode : PlayerFormMode = PlayerFormMode.NORMAL

@export var shot_pattern : ShotPattern = ShotPattern.NORMAL