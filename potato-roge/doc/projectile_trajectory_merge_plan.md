# 弹道系统合并方案：将 BezierBullet 的多种弹道并入项目

> 目标：把独立项目 `BezierBullet/`（位于仓库根目录）中的 5 种子弹弹道（直线 / 直接追踪 / 阻尼追踪 / 旋转转向追踪 / 贝塞尔曲线）作为**子弹的可选参数**并入 `potato-roge`，使每一把射击武器（远程武器）都能通过数值资源配置自己的弹道类型。
>
> 前置阅读：本文假定你已了解现有攻击系统，参见 [`attack_and_shooting_system.md`](./attack_and_shooting_system.md)。

---

## 目录

1. [设计思路与现状对照](#1-设计思路与现状对照)
2. [改动总览](#2-改动总览)
3. [改动点 1：WeaponStats 新增弹道类型枚举](#3-改动点-1weaponstats-新增弹道类型枚举)
4. [改动点 2：Projectile 弹道逻辑重构](#4-改动点-2projectile-弹道逻辑重构)
5. [改动点 3：RangeBehavior 传递弹道类型与目标](#5-改动点-3rangebehavior-传递弹道类型与目标)
6. [改动点 4：武器数值资源 .tres 配置弹道类型](#6-改动点-4武器数值资源-tres-配置弹道类型)
7. [向后兼容性](#7-向后兼容性)
8. [五种弹道在项目中的映射](#8-五种弹道在项目中的映射)
9. [验证清单](#9-验证清单)
10. [可选扩展](#10-可选扩展)

---

## 1. 设计思路与现状对照

### 1.1 现状

| 项目 | 子弹实现 | 追踪方式 |
| --- | --- | --- |
| `potato-roge` | `scenes/projectile/projectile.gd`，仅直线飞行 `position += velocity * delta` | 无 |
| `BezierBullet` | `arrow.gd`，`action1~action5` 五种弹道 | 通过 `get_first_node_in_group("enemy")` 取第一个敌人 |

### 1.2 关键差异与对应方案

| BezierBullet 写法 | potato-roge 对应方案 |
| --- | --- |
| 子弹用 `type`（1~5）切换弹道 | 用 `WeaponStats` 上的**枚举 `trajectory_type`** 配置，由武器资源驱动 |
| 通过 `get_first_node_in_group("enemy")` 取追踪目标 | 项目**敌人不在分组**，改为由武器在发射时把 `closest_target` **直接传入子弹** |
| 弹道参数硬编码在 `arrow.gd`（`drag_factor`、`0.07`、`1.7` 等） | 收敛到 `WeaponStats`，做成**可导出字段**（可选） |
| 使用 `_physics_process` | 沿用项目现有 `_process` 约定（`player.gd` / `enemy.gd` / `weapon.gd` 均用 `_process`），降低改动风险 |

### 1.3 总体思路

遵循项目既有的 **“资源驱动 + 行为多态”** 架构，弹道类型作为**数据**写入 `WeaponStats`，子弹（`Projectile`）读取该数据并用 `match` 分发到不同移动函数。这样：

- 每种武器只需在 `.tres` 里改一个 `trajectory_type` 即可切换弹道；
- 近战武器（`MeleeBehavoir`）天然不受影响（不读取该字段）；
- 敌人子弹（`ShootingBehavior`）默认保持直线，**零改动兼容**。

---

## 2. 改动总览

| # | 文件 | 改动性质 | 说明 |
| --- | --- | --- | --- |
| 1 | `scripts/weapon_stats.gd` | 修改 | 新增 `TrajectoryType` 枚举 + `trajectory_type` 字段（+可选调优字段） |
| 2 | `scenes/projectile/projectile.gd` | 修改 | 重构移动逻辑，支持 5 种弹道 + 目标追踪 |
| 3 | `scenes/weapon/range/range_behavior.gd` | 修改 | 发射时把弹道类型与目标传入子弹 |
| 4 | `resources/items/weapon/range/pistol/stats_pistol_1.tres`（及其它远程武器 stats） | 修改 | 配置 `trajectory_type` |
| 5 | `scenes/enemy/shooting_behavior.gd` | 无需改动 | 默认参数保证敌人子弹仍为直线 |

> 无需新增文件，无需改动碰撞层（命中盒 `HitboxComponent` 的 layer/mask 逻辑与弹道无关，子弹命中判定保持不变）。

---

## 3. 改动点 1：WeaponStats 新增弹道类型枚举

文件：`scripts/weapon_stats.gd`

在脚本顶部（`class_name WeaponStats` 之后）新增枚举，并在字段末尾新增导出字段：

```gdscript
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

# ... 原有字段保持不变 ...

@export var projectile_scene : PackedScene
@export var projectile_speed := 1600

# —— 新增：弹道类型（默认直线，保证旧资源向后兼容） ——
@export var trajectory_type: TrajectoryType = TrajectoryType.STRAIGHT
```

### 可选：把弹道调优参数也做成可导出（推荐）

BezierBullet 里硬编码的 `drag_factor=0.15`、`0.07`、`1.7` 建议提取为字段，便于每种武器单独调校：

```gdscript
@export var homing_drag_factor := 0.15        # 阻尼追踪转向系数
@export var homing_turn_rate := 0.07          # 旋转追踪转向速率
@export var bezier_control_multiplier := 1.7  # 贝塞尔控制点倍率
```

> 说明：枚举值在 `.tres` 中按**整数下标**序列化（见第 6 节映射表）。枚举放在 `WeaponStats` 与项目既有风格一致（`ItemWeapon.WeaponType`、`UnitStats.UnitType`、`ItemBase.ItemType` 均定义在数据类里）。

---

## 4. 改动点 2：Projectile 弹道逻辑重构

文件：`scenes/projectile/projectile.gd`

用以下代码**整体替换**该文件。要点：

- 保留 `velocity` 字段与 `set_projectile(velocity, damage, critical, knockback, unit)` 的前 5 个参数，确保敌人射击调用点无需改动。
- 新增 `trajectory_type`、`target`、`speed`、`direction` 等字段。
- 用 `match trajectory_type` 分发到 5 个移动函数，与 `BezierBullet/arrow.gd` 的 `action1~5` 一一对应。

```gdscript
extends Node2D
class_name Projectile

@export var hitbox: HitboxComponent

# —— 弹道类型（由 WeaponStats 驱动） ——
var trajectory_type: WeaponStats.TrajectoryType = WeaponStats.TrajectoryType.STRAIGHT

# —— 弹道基础参数 ——
var velocity: Vector2                 # 保留：初始速度向量（向后兼容）
var speed := 1600.0                   # 速度大小（由 velocity 长度初始化）
var direction := Vector2.RIGHT        # 初始朝向（单位向量）
var target: Node2D = null             # 追踪目标（由武器在发射时传入）

# —— 追踪弹道内部状态 ——
var current_velocity := Vector2.ZERO  # 阻尼追踪的当前速度（带惯性）
var drag_factor := 0.15               # 阻尼追踪转向系数
var turn_rate := 0.07                 # 旋转追踪转向速率
var bezier_control_multiplier := 1.7  # 贝塞尔控制点倍率

# —— 贝塞尔曲线状态 ——
var next_point := Vector2.ZERO
var current_time := 0.0


func _process(delta: float) -> void:
    match trajectory_type:
        WeaponStats.TrajectoryType.STRAIGHT:
            _move_straight(delta)
        WeaponStats.TrajectoryType.HOMING_DIRECT:
            _move_homing_direct(delta)
        WeaponStats.TrajectoryType.HOMING_DAMPED:
            _move_homing_damped(delta)
        WeaponStats.TrajectoryType.HOMING_ROTATION:
            _move_homing_rotation(delta)
        WeaponStats.TrajectoryType.BEZIER:
            _move_bezier(delta)


# —— 弹道 1：直线 ——
func _move_straight(delta: float) -> void:
    position += direction * speed * delta


# —— 弹道 2：直接追踪（对应 BezierBullet action2） ——
func _move_homing_direct(delta: float) -> void:
    if not _has_valid_target():
        _move_straight(delta)
        return
    global_position = global_position.move_toward(target.global_position, speed * delta)
    look_at(target.global_position)


# —— 弹道 3：阻尼追踪（对应 BezierBullet action3） ——
func _move_homing_damped(delta: float) -> void:
    if not _has_valid_target():
        _move_straight(delta)
        return
    var desired := global_position.direction_to(target.global_position) * speed
    current_velocity = current_velocity.lerp(desired, drag_factor)
    position += current_velocity * delta
    rotation = current_velocity.angle()


# —— 弹道 4：旋转转向追踪（对应 BezierBullet action4） ——
func _move_homing_rotation(delta: float) -> void:
    if not _has_valid_target():
        _move_straight(delta)
        return
    var target_rot := (target.global_position - global_position).angle()
    rotation = lerp_angle(rotation, target_rot, turn_rate)
    position += Vector2(speed, 0).rotated(rotation) * delta


# —— 弹道 5：贝塞尔曲线（对应 BezierBullet action5） ——
func _move_bezier(delta: float) -> void:
    if not _has_valid_target():
        _move_straight(delta)
        return
    current_time += delta
    var distance := global_position.distance_to(target.global_position)
    var t := minf(current_time / (distance / speed), 1.0)
    var control := direction * speed * bezier_control_multiplier
    next_point = global_position.bezier_interpolate(control, target.global_position, target.global_position, t)
    look_at(next_point)
    global_position = global_position.move_toward(next_point, speed * delta)


# —— 目标有效性检测 ——
func _has_valid_target() -> bool:
    return is_instance_valid(target)


func set_projectile(
    velocity: Vector2,
    damage: float,
    critical: bool,
    knockback: float,
    unit: Node2D,
    trajectory_type: WeaponStats.TrajectoryType = WeaponStats.TrajectoryType.STRAIGHT,
    target: Node2D = null
) -> void:
    self.velocity = velocity
    self.speed = velocity.length()
    self.direction = velocity.normalized()
    self.trajectory_type = trajectory_type
    self.target = target
    self.current_velocity = velocity      # 阻尼追踪的初始速度
    rotation = velocity.angle()           # 初始朝向
    next_point = global_position
    current_time = 0.0
    if hitbox:
        hitbox.setup(damage, critical, knockback, unit)


# —— 以下两个信号处理函数保持不变 ——
func _on_visible_on_screen_notifier_2d_screen_exited() -> void:
    queue_free()


func _on_hitbox_component_on_hit_hurtbox(hurtbox: HurtboxComponent) -> void:
    print("碰撞触发")
    queue_free()
```

### 关键说明

1. **速度来源**：`speed = velocity.length()`，而发射端传入的 `velocity = Vector2.RIGHT.rotated(rotation) * projectile_speed`，故 `speed == projectile_speed`，各弹道的速度基准一致。
2. **初始方向**：`direction = velocity.normalized()` 即发射瞬间枪口朝向，等价于 BezierBullet 里 `_ready` 记录的 `direction`。
3. **目标传入**：追踪目标不再依赖分组，而是由武器把 `closest_target` 传入。目标失效（`queue_free` 后）自动回退直线，不会报错。
4. **直线等价**：直线分支 `direction * speed * delta` 与旧版 `velocity * delta` 数学等价，行为不变。

---

## 5. 改动点 3：RangeBehavior 传递弹道类型与目标

文件：`scenes/weapon/range/range_behavior.gd`

只需修改 `creat_projectile()`，把 `trajectory_type` 和 `closest_target` 传给 `set_projectile`：

```gdscript
func creat_projectile() -> void:
    var instance := weapon.data.stats.projectile_scene.instantiate() as Projectile
    get_tree().root.add_child(instance)
    instance.global_position = muzzle.global_position

    var velocity := Vector2.RIGHT.rotated(weapon.rotation) * weapon.data.stats.projectile_speed
    instance.set_projectile(
        velocity,
        get_damage(),
        critical,
        weapon.data.stats.knockback,
        weapon.get_parent(),
        weapon.data.stats.trajectory_type,   # 新增：弹道类型
        weapon.closest_target                # 新增：追踪目标（Weapon 已维护）
    )
```

> `weapon.closest_target` 由 `Weapon._process` 每帧更新，是距离武器最近的敌人（`Enemy`，也是 `Node2D` 子类，可直接作为 `target`）。追踪弹因此天然锁定**最近敌人**，比 BezierBullet 里“取组内第一个”更合理。

### 若采用了第 3 节的可选调优字段，需同时透传

```gdscript
    instance.drag_factor = weapon.data.stats.homing_drag_factor
    instance.turn_rate = weapon.data.stats.homing_turn_rate
    instance.bezier_control_multiplier = weapon.data.stats.bezier_control_multiplier
```

---

## 6. 改动点 4：武器数值资源 .tres 配置弹道类型

文件：`resources/items/weapon/range/pistol/stats_pistol_1.tres`（以及其它远程武器 stats）

枚举在 `.tres` 中按整数下标存储，映射关系：

| `trajectory_type` 值 | 枚举 | 弹道 |
| --- | --- | --- |
| `0` | `STRAIGHT` | 直线（默认） |
| `1` | `HOMING_DIRECT` | 直接追踪 |
| `2` | `HOMING_DAMPED` | 阻尼追踪 |
| `3` | `HOMING_ROTATION` | 旋转转向追踪 |
| `4` | `BEZIER` | 贝塞尔曲线 |

### 示例 1：手枪改为“直接追踪”

```gdscript
[gd_resource type="Resource" script_class="WeaponStats" format=3 uid="uid://2x3b6qmoiyrv"]

[ext_resource type="Script" uid="uid://dykkwq0grks3l" path="res://scripts/weapon_stats.gd" id="1_3i8bm"]
[ext_resource type="PackedScene" uid="uid://bvyf3btogwr35" path="res://scenes/projectile/projectile_pistol.tscn" id="1_qr7sw"]

[resource]
script = ExtResource("1_3i8bm")
max_range = 600
projectile_scene = ExtResource("1_qr7sw")
trajectory_type = 1
metadata/_custom_type_script = "uid://dykkwq0grks3l"
```

> 只多出一行 `trajectory_type = 1`。在 Godot 编辑器中也可以直接在 `WeaponStats` 面板的 `Trajectory Type` 下拉框里选择，编辑器会自动写回该字段。

### 示例 2：某武器改为“贝塞尔曲线”

```gdscript
trajectory_type = 4
bezier_control_multiplier = 2.5   # 可选：调整弧线弯曲程度
```

---

## 7. 向后兼容性

- **旧 `.tres` 无需修改**：未写 `trajectory_type` 的资源默认取 `STRAIGHT(0)`，行为与现在完全一致。
- **敌人子弹无需改动**：`scenes/enemy/shooting_behavior.gd:45` 调用的是 `set_projectile(velocity, damage, false, 0, enemy)`，新签名的 `trajectory_type` 与 `target` 都有默认值（`STRAIGHT`、`null`），敌人子弹仍为直线。
- **近战武器无需改动**：`MeleeBehavoir` 不调用 `set_projectile`，`trajectory_type` 字段对近战无影响。
- **碰撞层无需改动**：命中判定仍由 `HitboxComponent` 的 `area_entered` 驱动，与子弹如何移动无关。

---

## 8. 五种弹道在项目中的映射

| BezierBullet | 本项目实现 | 适用武器设想 |
| --- | --- | --- |
| `action1` 直线 | `_move_straight` | 手枪、步枪等传统枪械 |
| `action2` 直接追踪 | `_move_homing_direct` | 必中魔弹、跟踪箭 |
| `action3` 阻尼追踪 | `_move_homing_damped` | 导弹、有惯性的能量球 |
| `action4` 旋转转向追踪 | `_move_homing_rotation` | 机头式追踪箭 |
| `action5` 贝塞尔 | `_move_bezier` | 甩弧弹道、弹幕武器 |

> 每种弹道的数学原理、轨迹特点与优缺点，见仓库根目录 `BezierBullet/弹道代码分析.md`。

---

## 9. 验证清单

1. 修改 `weapon_stats.gd` 后，Godot 编辑器无解析错误（枚举被 `Projectile` 引用，需保证 `class_name WeaponStats` 已注册）。
2. 手枪 `.tres` 设 `trajectory_type = 0`，确认子弹仍是直线（回归测试，验证向后兼容）。
3. 依次设 `1/2/3/4`，观察：
   - `1` 子弹紧贴追踪最近敌人；
   - `2` 子弹带惯性甩尾追踪；
   - `3` 子弹恒定速率弧线转弯追踪；
   - `4` 子弹先冲出再拐弯命中敌人。
4. 追踪目标被击杀后，子弹应回退直线飞行，**不报错**（验证 `_has_valid_target()`）。
5. 敌人 `ShootingBehavior` 的扇形弹幕仍为直线，未被影响。
6. 近战武器（拳头）攻击正常，`trajectory_type` 字段不影响近战。

---

## 10. 可选扩展

### 10.1 出膛加速（还原 BezierBullet 手感）

BezierBullet 中阻尼追踪弹初始速度为 `speed * 2.5`，有“出膛加速”效果。可在 `set_projectile` 中改为：

```gdscript
    self.current_velocity = velocity * 2.5   # 可选：阻尼追踪弹的出膛加速
```

### 10.2 目标存活检测更严谨

`_has_valid_target()` 目前仅用 `is_instance_valid`。若担心目标处于死亡动画尚未销毁，可追加：

```gdscript
func _has_valid_target() -> bool:
    if not is_instance_valid(target) or target.is_queued_for_deletion():
        return false
    if target is Enemy and target.health_component.current_health <= 0:
        return false
    return true
```

### 10.3 帧率无关化（可选）

现有项目统一用 `_process`，与 `BezierBullet` 的 `_physics_process` 不同。若追求运动确定性，可将 `Projectile` 的移动改到 `_physics_process`，并把 `drag_factor` / `turn_rate` 改为按 `delta` 归一化的写法（详见 `BezierBullet/弹道代码分析.md` 第 5 节建议）。

### 10.4 更多弹道形态

- 为 `BEZIER` 增加“末段散开/多段曲线”控制点配置；
- 新增“螺旋环绕”“追踪后折返”等形态，只需在 `TrajectoryType` 枚举中加一项并在 `_process` 的 `match` 中加一个分支，扩展成本极低。

---

## 附：改动文件清单汇总

| 文件 | 状态 |
| --- | --- |
| `scripts/weapon_stats.gd` | 修改（新增枚举 + 字段） |
| `scenes/projectile/projectile.gd` | 修改（重构弹道逻辑） |
| `scenes/weapon/range/range_behavior.gd` | 修改（透传弹道类型与目标） |
| `resources/items/weapon/range/pistol/stats_pistol_1.tres` | 修改（按需设 `trajectory_type`） |
| `scenes/enemy/shooting_behavior.gd` | 无需改动 |

*文档生成时间：2026-10-05*
