extends Resource
class_name WeaponStats

# —— 新增：子弹弹道类型 ——
enum TrajectoryType {
	STRAIGHT,        # 直线
	HOMING_DIRECT,   # 直接追踪（move_toward，瞬时转向）
	HOMING_DAMPED,   # 阻尼追踪（速度向量惯性转向）
	HOMING_ROTATION, # 旋转转向追踪（lerp_angle 限角速度）
	BEZIER,          # 贝塞尔曲线
}

@export var damage := 1.0
@export_range(0.0,1.0) var accuracy := 0.9
@export_range(0.5,4.0) var cooldown := 1.0
@export_range(0.0,1.0) var crit_channce := 0.05
@export var crit_damage := 1.5
@export var max_range := 150
@export var knockback := 0
@export_range(0.0,1.0) var life_steal := 0.0
@export var recoil := 25
@export_range(0.0,3.0) var recoil_duration := 0.1
@export_range(0.0,1.0) var attack_duration := 0.2
@export_range(0.0,1.0) var back_duration := 0.15
@export var projectile_scene : PackedScene
@export var projectile_speed := 1600
# —— 新增：弹道类型（默认直线，保证旧资源向后兼容） ——
@export var trajectory_type: TrajectoryType = TrajectoryType.STRAIGHT


@export var homing_drag_factor := 0.15        # 阻尼追踪转向系数
@export var homing_turn_rate := 0.07          # 旋转追踪转向速率
@export var bezier_control_multiplier := 1.7  # 贝塞尔控制点倍率
