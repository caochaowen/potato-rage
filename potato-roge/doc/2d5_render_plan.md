# 2D → 2.5D 视角改造方案：把精灵“立起来”（参照 ss_render.gml）

> 目标：参照仓库根目录 `ss_render.gml` 的 `ss_stand_matrix()`，把本项目从**纯俯视 2D** 改为 **2.5D 倾斜视角**——即地面是倾斜平面、角色/敌人/武器精灵像“立牌”一样站在地面上的效果。
>
> 前置阅读：建议先了解现有单位渲染结构，参见 [`attack_and_shooting_system.md`](./attack_and_shooting_system.md)（尤其第 2 节的场景结构）。

---

## 目录

1. [GML 源码解析](#1-gml-源码解析)
2. [核心结论：GML 广告牌 ≡ Godot Sprite3D 广告牌](#2-核心结论gml-广告牌--godot-sprite3d-广告牌)
3. [坐标系映射](#3-坐标系映射)
4. [方案对比与推荐](#4-方案对比与推荐)
5. [方案 A：真实 3D 化（推荐·忠实复刻）](#5-方案-a真实-3d-化推荐忠实复刻)
6. [方案 B：纯 2D 仿 2.5D（低风险·近似）](#6-方案-b纯-2d-仿-25d低风险近似)
7. [逐文件改动清单](#7-逐文件改动清单)
8. [验证清单](#8-验证清单)
9. [风险与注意事项](#9-风险与注意事项)

---

## 1. GML 源码解析

`ss_render.gml` 全文只有一个函数：

```gml
// stand a sprite up on its feet
function ss_stand_matrix(x, y, z){
    var R = tilt_rot;                     // 相机俯仰旋转矩阵（绕 X 轴转 tilt 角）
    var t1 = y - (x*R[1]+ y*R[5]);
    var t2 = -z - (x*R[2]+ y*R[6]);
    return [R[0],R[1],R[2],0,
            R[4],R[5],R[6],0,
            R[8],R[9]，R[10]，0,
            0,t1,t2,1];
}
```

### 1.1 它在做什么

GameMaker 的矩阵是**列主序（column-major）**，`matrix_get` 返回的 16 元素数组按“列”排列：下标 `0~3` 是第一列（X 轴），`4~7` 第二列（Y 轴），`8~11` 第三列（Z 轴），`12~15` 是平移列。因此上面的返回值是一个 4×4 世界矩阵：

```text
列0(X轴)  列1(Y轴)  列2(Z轴)  平移列
[ R[0]    R[4]    R[8]    0   ]
[ R[1]    R[5]    R[9]    t1  ]
[ R[2]    R[6]    R[10]   t2  ]
[ 0       0       0       1   ]
```

`tilt_rot` 是“绕 X 轴旋转 `tilt` 角”的旋转矩阵。绕 X 轴旋转 θ 的旋转矩阵为：

```text
      X轴      Y轴         Z轴
[ 1      0          0      ]
[ 0      cosθ      -sinθ   ]
[ 0      sinθ       cosθ   ]
```

代入后（列主序，`R[0]=1, R[1]=0, R[2]=0, R[4]=0, R[5]=cosθ, R[6]=sinθ, R[8]=0, R[9]=-sinθ, R[10]=cosθ`）：

```text
t1 = y - (x·0 + y·cosθ) = y·(1 - cosθ)
t2 = -z - (x·0 + y·sinθ) = -z - y·sinθ
```

所以 `ss_stand_matrix` 等价于：**先把精灵绕 X 轴旋转 `tilt`（和相机俯仰角对齐），再平移 `(0, t1, t2)` 把精灵的“脚底”锚定到地面坐标 `(x, y, z)`**。整体效果就是：把一块本来平躺在地面上的精灵“扶起来”，变成**垂直于地面、面向相机的立牌（billboard / 广告牌）**，脚底正好落在地面位置。

> 注：`tilt_rot`、`tilt` 变量以及相机本身的构建代码不在本片段里（`ss_render.gml` 是截取的一个函数）。上面是按 GameMaker 列主序矩阵与“绕 X 轴俯仰”这一最主流约定做的推导；不同教程的手性（Y-up / Z-up）与旋转正负号可能不同，但**“垂直广告牌”这一本质不变**。

---

## 2. 核心结论：GML 广告牌 ≡ Godot Sprite3D 广告牌

这个矩阵要做的“垂直广告牌”变换，**Godot 引擎已经原生实现**，无需手写矩阵：

| GML 手工矩阵 | Godot 等价物 |
| --- | --- |
| `ss_stand_matrix()` 返回的世界矩阵 | `Sprite3D.billboard = BILLBOARD_FIXED_Y`（保持 Y 轴垂直，仅水平转向相机） |
| 相机俯仰 `tilt_rot` | `Camera3D` 的 `rotation.x = -tilt`（俯视地面） |
| 精灵平躺的地面 | `MeshInstance3D` + `PlaneMesh`（XZ 平面，法线 +Y） |
| 精灵“脚底对齐地面” | `Sprite3D` 的 `pixel_size` + 把节点 Y 抬高半个精灵高度 |

两种广告牌模式的选择：

- `BILLBOARD_ENABLED`：完全面向相机（俯仰 + 偏航都跟随），俯视角度很陡时会“后仰”。 
- `BILLBOARD_FIXED_Y`：**只做水平转向、保持 Y 轴垂直（世界向上）**，正是 `ss_stand_matrix` 的“站在脚上”语义，**推荐使用**。

因此，本方案的核心不是逐行复刻那段矩阵，而是：**把 2D 场景换成 3D 世界 + 广告牌 `Sprite3D` + 倾斜 `Camera3D`**。

---

## 3. 坐标系映射

GameMaker 与 Godot 的 3D 上方向不同，移植时必须重映射：

| 含义 | GML（本片段约定） | Godot 3D |
| --- | --- | --- |
| 左右 | `x` | `x` |
| 前后 / 纵深 | `y` | `z` |
| 上下 | `z` | `y` |
| 绕 X 轴俯仰 `tilt` | `rotation.x = tilt` | `Camera3D.rotation.x = -tilt` |

本项目当前的 2D 逻辑坐标 `(x, y)`（`Node2D.position`）直接映射为 3D 地面坐标 `(x, 0, y)`：即 `Vector2(x, y) → Vector3(x, 0, y)`，高度（Y）固定为 0（贴地），需要“抬高/站立”的部分由精灵自身的广告牌高度表达。

---

## 4. 方案对比与推荐

| 维度 | 方案 A：真实 3D 化 | 方案 B：纯 2D 仿 2.5D |
| --- | --- | --- |
| 忠实度 | **完全复刻** GML 效果（真透视、真立牌） | 近似（地面压缩 + 立绘偏移，无真透视收敛） |
| 改动量 | 大：世界/相机/单位/武器/弹道/碰撞全量换 3D | 小：只动背景容器缩放 + 可选 shader |
| 风险 | 中高：物理层、旋转语义、UI 都要重测 | 低：可逆、不动逻辑 |
| 适用 | 想要真正 3/4 俯视倾斜视角 | 只想低成本“看起来有点 2.5D” |

**推荐：方案 A**。因为你的目标是“参照 ss_render.gml 实现”，那段代码本质是 3D 广告牌，方案 A 才能忠实还原；方案 B 只能做出“伪 2.5D”。若暂时不想动物理与碰撞，可先只做方案 A 的**渲染层**（第 5.2~5.5 节），逻辑暂用 2D 过渡（见第 5.7 节“分阶段落地”）。

---

## 5. 方案 A：真实 3D 化（推荐·忠实复刻）

整体思路：把 `Arena` 根节点从 `Node2D` 换成 `Node3D`，地面、单位、武器、弹道全部换成 3D 节点；逻辑坐标仍是“地面平面”，只是从 `Vector2` 变成 `Vector3(x, 0, z)`。UI（血条、浮动文字、升级面板）**保持不变，仍留在 `CanvasLayer`**。

### 5.1 世界根节点与地面

文件：`scenes/arena/arena.tscn`

- `Arena` 根节点：`Node2D` → `Node3D`（脚本 `scripts/arena.gd` 同步改 `extends Node3D`）。
- 原 `BlackBG` / `GrassBG`（两个 `Sprite2D`）→ 两个地面 `MeshInstance3D`：
  - 各挂 `PlaneMesh`，`size` 与场景尺寸对应（当前 BG 为 2048×2048、Map 为 1024×512，`scale` 为 2 倍）。
  - 材质用 `StandardMaterial3D`，`albedo_texture` 指向 `BG.png` / `Map.png`，`shading_mode` 建议 `UNSHADED`（纯 2D 贴图观感）。
  - 平面默认法线 +Y、位于 XZ 平面，正好是地面；上下叠放顺序用 `position.y` 微调（`BlackBG` 放 `y=0`，`GrassBG` 放 `y=0.01` 避免 Z-fighting）。

### 5.2 相机

文件：`scripts/camera_2d.gd` → 新建 `scripts/camera_3d.gd`（`extends Camera3D`）

```gdscript
extends Camera3D
class_name Camera3DFollow

@export var tilt_deg := 55.0     # 俯仰角（越大越接近纯俯视，越小越接近平视）
@export var height := 20.0       # 相机离地高度（世界单位，需与场景尺度匹配）
@export var back_offset := 12.0  # 相机向玩家后方偏移，形成“前低后高”

func _process(_delta: float) -> void:
    if not is_instance_valid(Global.player):
        return
    var p: Vector3 = Global.player.global_position
    position = p + Vector3(0, height, back_offset)
    rotation_degrees = Vector3(-tilt_deg, 0, 0)
```

> 关键：`rotation.x = -tilt_deg` 正是 GML 里 `tilt_rot` 的俯仰角。`tilt_deg = 0` 相当于现在 Camera2D 的纯俯视，`tilt_deg = 55~70` 是典型的 3/4 俯视观感，可按需调。

### 5.3 单位（玩家/敌人）改立牌

文件：`scenes/unit.tscn`、`scenes/player/player_well_rounded.tscn`、`scenes/enemy/*.tscn`

现有结构是“影子 + 立绘”（`Visuals` 里 `Shadow` 在 `(0,0)`、`Sprite` 上移 62px），这正是 2D 版的“立牌”。3D 化后映射如下：

| 现有节点 | 改为 | 说明 |
| --- | --- | --- |
| `Unit`（Area2D） | `Area3D` | 脚本 `unit.gd` 改 `extends Area3D`（或 `Node3D`） |
| `Visuals`（Node2D, scale 0.5） | `Node3D` | `scale = Vector3(0.5, 0.5, 0.5)` |
| `Shadow`（Sprite2D） | `Sprite3D`（平躺贴地） | `billboard = BILLBOARD_DISABLED`，`rotation_degrees.x = -90`，`y = 0.01` |
| `Sprite`（Sprite2D，pos `(0,-62)`） | `Sprite3D`（立牌） | `billboard = BILLBOARD_FIXED_Y`，见下方“脚底对齐” |
| `CollisionShape2D` | `CollisionShape3D` | `CircleShape2D` → `SphereShape3D` / `CylinderShape3D` |
| `AnimationPlayer` | 保持不变 | 动画轨道里的 `Sprite2D` 属性路径需改为 `Sprite3D` 属性 |

**立牌“脚底对齐地面”**（`Sprite3D` 的核心设置）：

```gdscript
# 单位脚底应落在地面 y=0，节点位置只表达地面 (x, 0, z)
@onready var sprite: Sprite3D = %Sprite

func _ready() -> void:
    sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
    # pixel_size：一个像素对应的世界单位，决定立牌在世界里的高宽
    # 例如原 2D 下精灵视觉高度约 150px × 0.5 缩放 = 75px，
    # 若期望世界高度约 1.5 单位，则 pixel_size ≈ 1.5 / 150 ≈ 0.01
    sprite.pixel_size = 0.01
    # Sprite3D 默认以中心为原点，脚底在“中心 - 高度/2”处；
    # 把节点 Y 抬高半个世界高度，脚底就贴到地面 y=0
    sprite.position.y = sprite.texture.get_height() * sprite.pixel_size * 0.5
```

> 朝向翻转：原来 `visuals.scale.x = -0.5 / 0.5` 改成分立牌自身的左右朝向，可直接用 `sprite.flip_h = true/false`（`Sprite3D` 自带属性），逻辑不变。

### 5.4 武器

文件：`scenes/weapon/weapon.gd`、`scenes/weapon/weapon_base.tscn`、`scenes/weapon/weapon_punch.tscn`、`scenes/weapon/weapon_sword.tscn`、`scenes/weapon/range/weapon_pistol.tscn`

- 武器实体 `Weapon` 从 `Node2D` → `Node3D`，`Sprite2D` → `Sprite3D`（同样 `billboard = BILLBOARD_FIXED_Y`）。
- 武器原先“绕玩家在平面内旋转”用 2D 的 `rotation`（绕 Z 轴），3D 下改为绕 Y 轴的偏航 `rotation.y`：
  - `rotation = direction.angle()` → `rotation.y = atan2(direction.x, direction.z)`（`Vector3` 的水平夹角）。
  - 索敌/瞄准方向：`global_position.direction_to(target.global_position).angle()` → 用 `Vector3(x,0,z)` 的 `direction_to` 后取水平角。
- 近战挥砍（`melee_behavior.gd`）里的 `weapon.sprite.position` 位移仍是局部空间，保持 `Vector3` 即可（`recoil` / `attack` / `back` 三档位移方向改为局部 `Vector3.RIGHT`）。
- 多武器布局（`weapon_container.gd` 的 Marker2D）→ `Marker3D`，坐标 `Vector2(x,y)` → `Vector3(x, 0, y)`。

### 5.5 弹道

文件：`scenes/projectile/projectile.gd`、`scenes/projectile/*.tscn`、`scenes/weapon/range/range_behavior.gd`

- `Projectile`：`Node2D` → `Node3D`，`Sprite2D` → `Sprite3D`（立牌，同 5.3）。
- 直线飞行：`position += velocity * delta`，`velocity` 由 `Vector2` → `Vector3(x, 0, z)`（Y 保持 0，贴地飞行）。
- 出膛方向：原 `Vector2.RIGHT.rotated(weapon.rotation) * speed` → `Vector3.RIGHT.rotated(Vector3.UP, weapon.rotation.y) * speed`。
- 追踪类弹道（若已按 `projectile_trajectory_merge_plan.md` 接入）：`move_toward / lerp / direction_to / angle` 全部换成 `Vector3` 对应方法，追踪目标仍取“最近敌人”，只是目标位置换成 `Vector3`。
- 敌人扇形射击 `shooting_behavior.gd`：`fire_pos` 的 `Marker2D` → `Marker3D`，`direction.rotated(angle)` 绕 Y 轴旋转：`direction.rotated(Vector3.UP, angle)`。

### 5.6 物理与碰撞层

文件：`project.godot`

- `[layer_names]` 下 6 个 `2d_physics/layer_N` → `3d_physics/layer_N`，名称与含义不变（Player / Enemy / HitboxEnemy / HurtboxEnemy / HitboxPlayer / HurtboxPlayer）。
- 各 `Area2D` → `Area3D`，`collision_layer / collision_mask` 数值不变（见 `attack_and_shooting_system.md` 第 3 节）。
- `HitboxComponent` / `HurtboxComponent` 脚本由 `extends Area2D` → `extends Area3D`，信号 `area_entered(area: Area2D)` → `area_entered(area: Area3D)`，其余逻辑（enable/disable/setup）不变。
- 敌人群聚分离（`enemy.gd` 的 `get_overlapping_areas()`）逻辑不变，只是返回 `Area3D`、`global_position` 变为 `Vector3`。

### 5.7 脚本层通用改动（`Vector2 → Vector3`）

所有涉及位置/方向的脚本按下面规则机械替换：

| 2D 写法 | 3D 写法 |
| --- | --- |
| `position` / `global_position` | 不变（类型变为 `Vector3`） |
| `Vector2(x, y)` | `Vector3(x, 0, y)`（贴地） |
| `move_dir * speed`（`move_dir` 来自 `Input.get_vector`） | `Vector3(move_dir.x, 0, move_dir.y) * speed` |
| `position.x/y` 的 clamp | 对 `x`、`z` 分别 clamp |
| `direction_to / distance_to / move_toward / lerp / normalized` | 同名 `Vector3` 方法 |
| `Vector2.RIGHT.rotated(a)` | `Vector3.RIGHT.rotated(Vector3.UP, a)` |
| `velocity.angle()` | `atan2(velocity.x, velocity.z)`（水平角） |
| `rotation`（绕 Z） | `rotation.y`（绕 Y 偏航） |
| `visuals.scale.x = ±0.5`（左右翻转） | `sprite.flip_h = true/false` |

> **分阶段落地（降低风险）**：可以先只做“渲染层 3D + 逻辑层 2D”的过渡版本——即保留 `Unit/Player/Enemy` 的 `Node2D` 逻辑与 2D 碰撞不动，只在地面/背景/相机切到 3D，并给每个单位挂一个 `Sprite3D` 立牌作为“视觉镜像”，每帧把 `Node2D.global_position` 同步到 `Sprite3D.position = Vector3(p.x, 0, p.y)`。等视觉满意后，再逐步把逻辑与碰撞也迁到 3D。这样可先看到效果、再决定是否全量投入。

---

## 6. 方案 B：纯 2D 仿 2.5D（低风险·近似）

如果完全不想动物理/碰撞，可用 2D 手法“看起来像 2.5D”。**注意：这不是真透视，无法产生“近大远小”的透视收敛，只是俯仰的近似**。

1. **地面透视压缩**：把 `BlackBG`、`GrassBG` 放进一个 `Node2D` 容器（如 `Ground`），`scale = Vector2(1, cos(tilt_rad))`（`tilt=45°` 时约 `0.707`）。地面被纵向压扁，模拟“向后倾斜”的透视缩短感。
2. **角色“站立”**：项目已有的 `Shadow(0,0)` + `Sprite(0,-62)` 结构本来就是 2D 立牌，无需改动；可再给 `Sprite` 加一个绕脚底轴的 `skew` 或轻微 `rotation` 让立绘“向后仰”，配合压扁的地面形成倾斜视角。
3. **Y 排序**：给世界根节点开 `y_sort_enabled = true`，各单位的 `z_index` 按 `global_position.y` 设置，保证“下方（离镜头近）的物体遮挡上方（远）的物体”。
4. **可选：整体倾斜 shader**：给 `Ground` 与所有单位共用一个 `CanvasItem` shader，对 UV 做一次 `y = y / cos(tilt)` 的逆变换，把“立起来的角色”压回与地面一致的透视比例（此步效果有限，可省略）。

> 方案 B 无法复刻 GML 里“精灵真正垂直于地面、随相机俯仰自动转向”的核心效果，仅作低成本视觉增强。

---

## 7. 逐文件改动清单

### 方案 A（真实 3D）

| 文件 | 状态 | 说明 |
| --- | --- | --- |
| `project.godot` | 修改 | `2d_physics/layer_*` → `3d_physics/layer_*` |
| `scenes/arena/arena.tscn` | 修改 | 根节点 `Node3D`、地面 MeshInstance3D、相机换 3D |
| `scripts/arena.gd` | 修改 | `extends Node3D`；浮动文字/UI 仍走 CanvasLayer |
| `scripts/camera_2d.gd` | 弃用 | 替换为 `scripts/camera_3d.gd`（`extends Camera3D`） |
| `scenes/unit.tscn` | 修改 | `Area3D` + `Sprite3D` 立牌 + `Sprite3D` 影子 + `CollisionShape3D` |
| `scripts/unit.gd` | 修改 | `extends Area3D`；受击/闪白逻辑不变 |
| `scripts/player.gd` | 修改 | `Vector3` 移动、clamp、朝向翻转改 `flip_h` |
| `scripts/enemy.gd` | 修改 | `Vector3` 寻敌/群聚/击退 |
| `scenes/player/player_well_rounded.tscn` 等玩家场景 | 修改 | 继承 `unit.tscn` 自动生效；`Trail`（Line2D）→ 3D 线或立牌 |
| `scenes/enemy/*.tscn`、`charge_behavior.gd`、`shooting_behavior.gd` | 修改 | 敌人与行为换 3D |
| `scenes/weapon/weapon.gd`、`weapon_base.tscn`、近战/远程武器场景 | 修改 | `Node3D` + `Sprite3D` + 绕 Y 偏航 |
| `scripts/weapon_behavior.gd`、`melee_behavior.gd`、`range_behavior.gd` | 修改 | 位移/方向改 `Vector3` |
| `scripts/weapon_container.gd` | 修改 | `Marker2D` → `Marker3D` |
| `scenes/projectile/projectile.gd`、`projectile_*.tscn` | 修改 | `Node3D` + `Sprite3D` + `Vector3` 飞行 |
| `scripts/hitbox_component.gd`、`hurtbox_component.gd` | 修改 | `Area2D` → `Area3D` |
| `scripts/health_bar.gd`、`floating_text.gd`、UI 相关 | 无需改动 | 仍驻留在 `CanvasLayer` 2D 覆盖层 |
| `scripts/trail.gd`（`Line2D`） | 修改 | 换成 `ImmediateMesh` 3D 拖尾，或降级为立牌粒子 |

### 方案 B（纯 2D 仿 2.5D）

| 文件 | 状态 | 说明 |
| --- | --- | --- |
| `scenes/arena/arena.tscn` | 修改 | `BlackBG`/`GrassBG` 包进 `Ground` 容器，`scale.y = cos(tilt)` |
| `scripts/arena.gd` 或场景内 | 修改 | 根节点 `y_sort_enabled = true` |
| （可选）新增 `effects/tilt.gdshader` | 新增 | 地面/角色统一倾斜补偿 shader |
| 其余脚本/资源 | 无需改动 | 逻辑、物理、碰撞完全不动 |

---

## 8. 验证清单

1. 打开 `project.godot`，确认 `3d_physics/layer_*` 已替换、主场景仍为 `arena.tscn`，Godot 无解析错误。
2. 运行后地面（BG/Map）平铺在 XZ 平面、无 Z-fighting 闪烁。
3. 相机俯仰后，玩家立牌“脚底”贴地、头顶朝上，左右移动时立牌水平翻转正确。
4. 敌人寻敌、群聚分离、击退位移在 3D 下方向正确（不再出现“上下颠倒”）。
5. 近战挥砍、手枪射击、弹道飞行、敌人扇形弹幕均命中判定正常（碰撞层迁移后 `area_entered` 正常触发）。
6. 血条、浮动伤害数字、升级面板仍正常显示（确认未随 3D 视角变形）。
7. `tilt_deg` 从 `0` 调到 `70`，观察俯仰过渡是否符合预期（`0` 应接近原纯俯视观感）。

---

## 9. 风险与注意事项

1. **物理层切换是破坏性改动**：`2d_physics` → `3d_physics` 后所有 `Area2D`/`CollisionShape2D` 必须同步换成 3D，否则碰撞静默失效。建议先做渲染层、后迁逻辑（见第 5.7 节“分阶段落地”）。
2. **旋转语义**：2D 的 `rotation`（绕 Z）与 3D 的“朝向”不同，武器瞄准/弹道方向是最容易出错的地方，务必统一为“绕 Y 轴的偏航角”。
3. **精灵资产**：本项目的角色贴图已经是“站立立绘”（配合影子在脚底），可直接当广告牌用；若换成纯俯视贴图，立起来会显得“躺平”，需另备侧/正面素材。
4. **尺度与 `pixel_size`**：3D 世界里 1 单位代表多少像素需统一定标（建议固定一个 `PIXEL_SIZE` 常量放 `Global`），否则立牌大小、相机高度、`max_range` 半径会互相不匹配。
5. **阴影**：原 `Shadow` 是 2D 椭圆贴图，3D 下作为平躺 Sprite3D 即可；若追求方向性投影，可用 `Decal` 或投影 `Light3D` 替换（非必须）。
6. **性能**：`Sprite3D` 广告牌数量随敌人数上升；本项目敌人不多，通常无压力，但大规模刷怪时注意 Draw Call（可后续用 `MultiMeshInstance3D` 优化）。

---

## 附：改动文件清单汇总（方案 A 主路径）

| 文件 | 状态 |
| --- | --- |
| `project.godot` | 修改 |
| `scenes/arena/arena.tscn` | 修改 |
| `scripts/arena.gd` | 修改 |
| `scripts/camera_2d.gd` → `scripts/camera_3d.gd` | 替换 |
| `scenes/unit.tscn` | 修改 |
| `scripts/unit.gd` | 修改 |
| `scripts/player.gd` | 修改 |
| `scripts/enemy.gd` | 修改 |
| `scenes/player/*.tscn` | 修改 |
| `scenes/enemy/*.tscn`、`*_behavior.gd` | 修改 |
| `scenes/weapon/*`、`scripts/weapon_*.gd`、`melee_behavior.gd` | 修改 |
| `scenes/projectile/*` | 修改 |
| `scripts/hitbox_component.gd`、`hurtbox_component.gd` | 修改 |
| `scripts/trail.gd` | 修改 |
| UI / 资源 / 升级系统 | 无需改动 |

*文档生成时间：2026-10-07*
