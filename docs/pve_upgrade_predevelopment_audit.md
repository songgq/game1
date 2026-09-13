# 《翡翠纷争》PVE升级开工前仓库盘点与迁移清单

> 文档类型：正式开发前事实盘点 / 迁移基线  
> 对应需求：`/home/admin/game_1/升级开发文档.md` 附录C  
> 客户端：`0.7.7`（第1/3阶段开发构建暂不升正式版本号）  
> 当前战斗引擎：`battle-engine-3.0.0`  
> 盘点日期：2026-08-23  
> 当前状态：盘点已完成；第1阶段与第3阶段已开发验收；第2阶段按产品决定暂缓

---

## 1. 结论

当前工程已经具备以下可复用基础：

- Godot 4.5.2、720×1280竖屏客户端；
- 服务端权威战斗模拟；
- 固定60 Tick/s；
- Strategy 3.0不可变快照、编译绑定和幂等战斗请求；
- 实体弓箭弹道、同Tick伤害/治疗结算；
- 战斗资源、战斗工人、资源入账和肉复活；
- 回放生成、gzip持久化、历史战斗读取；
- 游客/正式账号、PostgreSQL存档和Redis缓存；
- 本地卡组/策略与云同步；
- 已有Python和Godot自动测试。

当前工程尚不存在以下升级模块：

- 配置注册中心及升级文档要求的JSON配置体系；
- 英雄卡、Lv1~15升级和最终属性构建；
- 玩家角色Lv1~30与技能树；
- 装备实例、英雄装备方案、20武器和4护甲；
- 岛屿场景、15地块、农田、建筑和镜头交互；
- 岛屿工人实体、独立队列、Reservation和离线推进；
- 作物、加工、制造、药剂和新工人；
- 体力、PVE章节、关卡进度、星级、Boss和宝箱；
- PVE奖励事务和胜败资源带出；
- AI战术复盘服务。

核心判断：

> 现有工程适合作为战斗与账号基础，但不适合直接在 `game.gd` 中继续堆叠升级功能。Phase A必须先建立服务端配置层、领域层、事务边界和数据库迁移，再让Godot客户端消费服务端事实。

---

## 2. 已确认的升级决策

以下内容已经由产品确认，开发时不再重复询问：

1. 新系统长枪手规范ID为 `spearman`；旧回放继续支持 `lancer`。
2. 旧卡组中的 `lancer` 迁移为 `spearman`。
3. 旧卡组中的 `monk` 迁移为 `mage`；策略原文不做语义替换，旧编译结果失效并要求重编译。
4. 新正式PVE玩家阵容不允许重复英雄；敌人配置允许重复英雄。
5. 战场 `GOLD` 转换为玩家金币，首版配置为 `1 GOLD = 1金币`。
6. 关卡表中的地图资源是全图共享总量，双方工人可以争夺；敌方已入账资源不属于胜利自动扫取范围。
7. 战斗资源节点需要4点采集进度；普通有效采集动作增加1点。
8. 战斗采集速度影响采集动作间隔；技能可以额外增加采集进度。
9. 普通农田、药草/特殊种植位和高级作物区分级开放作物。
10. 一个生产建筑实例同一时间只运行一个任务。
11. 制作材料排队时Reservation，任务进入 `WORKING` 时正式消耗；制作中不可取消。
12. PVE顺序解锁；首通叠加普通金币；额外宝箱每次正式胜利都计算。
13. 1星来自通关，第二和第三条件各增加1星；两个附加条件都完成才是3星，条件可分场完成。
14. 练习模式不解锁关卡、不发星、不发奖励。
15. 宝箱缺失数值可以补充一套保守、完全配置化的首版基线。
16. 固定体力恢复自动补算历史时段，无需上线领取，最终受100点上限约束。
17. Strategy 4.0/BSL 1.0文档稍后提供；依赖其语义的最终实现和验收暂时不得自行猜测。

---

## 3. 当前工程总体结构

### 3.1 客户端

| 项目 | 当前事实 |
|---|---|
| 引擎 | Godot 4.5.2 |
| 主场景 | `main.tscn` |
| 根节点 | `Node2D/EmeraldClash` |
| 主控制器 | `scripts/game.gd`，约2857行 |
| 设计分辨率 | 720×1280 |
| 导出目标 | Web |
| UI构建方式 | 大部分由 `game.gd` 运行时创建节点 |
| 本地存档 | `ConfigFile`，`user://battle_setup.cfg` 与 `user://account.cfg` |

`main.tscn` 当前只有一个挂载 `game.gd` 的根节点。主菜单、账号、编队、策略、历史、战斗、回放、音频和大量UI都集中在 `game.gd`。

### 3.2 服务端

| 项目 | 当前事实 |
|---|---|
| HTTP入口 | `server/strategy_api.py` |
| HTTP实现 | Python `ThreadingHTTPServer` |
| 权威数据库 | PostgreSQL，使用 `psycopg` |
| 缓存 | Redis |
| 战斗模拟 | Python启动Godot headless子进程 |
| 战斗脚本 | `server/battle_replay_runner.gd` |
| 数据迁移 | `server/migrations/001~006` |
| 账号认证 | Bearer Token，Session默认180天 |
| 策略模型 | DeepSeek配置；本地解析成功时不调用模型 |

若未配置 `EMERALD_DATABASE_URL`，Strategy 3.0可以使用内存Store进行开发或测试；账号、云存档和正式持久化接口不可用。

### 3.3 当前服务端接口

现有主要接口：

```text
GET  /health

POST /account/guest
POST /account/register
POST /account/login
POST /account/profile
GET  /account/me

GET  /state
POST /state

GET  /battles
GET  /battles/{battleId}/replay

GET  /strategy/v3/metadata
POST /strategy/v3/snapshots
POST /strategy/v3/compile
GET  /strategy/v3/compiles/{compileId}
POST /strategy/v3/confirm-and-simulate

POST /strategy/v3/packages
GET  /strategy/v3/share/{shareCode}
POST /strategy/v3/share/{shareCode}/import

POST /speech/transcribe

POST /compile       旧Strategy 2.0兼容
POST /simulate      旧Strategy 2.0兼容
```

升级文档中的成长、岛屿、工人、PVE、宝箱等API尚未实现。

---

## 4. 附录C第1项：当前Hero实体位置

### 4.1 主要实现

| 职责 | 真实位置 |
|---|---|
| 英雄运行实体 | `scripts/unit.gd` |
| 英雄创建/登记 | `scripts/game.gd::create_unit()` |
| 双方出生 | `scripts/game.gd::spawn_units()` |
| 英雄固定数值 | `scripts/unit.gd::STATS`、`MOVE_SPEEDS`、`ACTION_INTERVAL` |
| 普攻、治疗、采集 | `scripts/unit.gd` |
| 技能测试骨架 | `scripts/unit.gd::configure_skills()`、`update_strategy_skill()` |
| 英雄动画资源选择 | `scripts/unit.gd::animation_info()` |
| 伤害/治疗合并 | `scripts/game.gd::queue_combat_event()`、`resolve_combat_events()` |
| 死亡/复活 | `scripts/game.gd::unit_died()`、`try_revive()` |

### 4.2 当前数据模型限制

当前英雄不是独立领域对象，只是运行时Node：

```text
unit_type
hp / max_hp
attack_power
attack_range
heal_power
move_speed
strategy_slot
skill_configs
```

当前没有：

- `physicalAttack`、`physicalDefense`、`magicDefense`、`skillPower`；
- 英雄等级成长；
- HeroCard；
- 装备槽和装备实例；
- Buff、Debuff、Shield和通用状态容器；
- 玩家技能树加成；
- 药剂加成；
- 可审计的最终属性计算管线。

### 4.3 当前英雄ID

```text
archer
lancer
worker
monk
warrior
```

升级后新ID：

```text
archer
spearman
worker
mage
warrior
```

`lancer` 与 `monk` 的素材和播放能力必须保留在Legacy Replay路径，不能直接删除。

---

## 5. 附录C第2项：当前Battle Snapshot位置

### 5.1 主要实现

| 职责 | 真实位置 |
|---|---|
| 快照构建 | `server/strategy_v3/snapshot.py::build_snapshot()` |
| 当前英雄数值副本 | `server/strategy_v3/snapshot.py::CURRENT_STATS` |
| 快照API | `server/strategy_api.py` 的 `/strategy/v3/snapshots` |
| 规范化哈希 | `server/strategy_v3/canonical_json.py` |
| PostgreSQL快照Store | `server/strategy_v3/postgres_stores.py::PostgresSnapshotStore` |
| 快照表 | `strategy_v3_snapshots` |
| 客户端创建请求 | `scripts/game.gd::compile_strategy_v3()`相关流程 |

### 5.2 当前快照内容

当前快照包含：

- `snapshotId`；
- `gameVersion`；
- `engineVersion`；
- 地图ID、地图版本和支持区域；
- 双方英雄编号、HeroId、Lv1固定属性；
- 当前能力与测试型技能；
- `snapshotHash`。

### 5.3 升级缺口

新PVE快照必须新增并由服务器读取：

- PVE关卡与地图配置版本；
- 玩家英雄真实等级；
- HeroLevelGrowth结算结果；
- 武器、护甲实例和对应Skill2；
- Skill1；
- 玩家技能树快照；
- 药剂效果；
- 最终物攻、物防、魔防、技能强度；
- 敌方等级、装备和AI Tag；
- Boss及技能；
- 资源节点共享配置；
- SafeZone、DangerZone等地图事实；
- 每一层配置的 `configVersion`；
- 战斗模式、关卡ID和奖励上下文ID。

客户端只能提交阵容、装备选择、药剂选择、关卡和策略意图；最终属性必须由服务器计算。

---

## 6. 附录C第3项：当前资源与工人代码位置

### 6.1 战斗资源

| 职责 | 真实位置 |
|---|---|
| 资源Node | `scripts/resource_node.gd` |
| 资源创建 | `scripts/game.gd::spawn_mirrored_resources()`、`create_resource()` |
| 资源入账 | `scripts/game.gd::add_resource()` |
| 战斗库存 | `scripts/game.gd::resource_counts` |
| 工人选择资源 | `scripts/game.gd::get_nearest_resource()` |
| 工人采集与运回 | `scripts/unit.gd::update_worker()` |
| 肉复活 | `scripts/game.gd::try_revive()` |

当前资源ID：

```text
gold
stone
wood
meat
```

每个节点固定4次有效命中后产出1份，工人回出生点24像素内才正式入账。

### 6.2 当前工人不是岛屿工人

当前 `worker` 是PVE参战英雄，逻辑位于 `unit.gd`。它具有：

- 自动寻找本方资源；
- 4点采集；
- 携带1份资源；
- 运回出生位置；
- 非工人战斗单位全灭后切换战斗；
- Strategy 2.0/3.0采集目标选择。

当前完全没有 `IslandWorker[]`、任务队列、Reservation、绝对时间、离线推进或仓库物流模型。

升级时必须创建独立的岛屿工人领域对象，禁止复用PVE `unit.gd` 作为离线经济事实对象。两者只共享视觉概念，不共享生命周期。

### 6.3 战斗资源迁移

- 新配置规范使用 `ORE`；当前运行时使用 `stone`。
- 新正式PVE和新回放使用 `ore`。
- 旧回放继续接受 `stone` 并使用旧石头资源表现。
- 新关卡资源改为全图共享配置，不再调用固定双方镜像数量。
- 旧自动肉复活仅保留在Legacy战斗；新正式PVE由Strategy 4.0决定复活目标和时机。

---

## 7. 附录C第4项：当前账号与云存档模型

### 7.1 服务端账号

主要实现：`server/storage.py`。

现有表：

```text
players
player_sessions
player_states
```

`players` 当前已有：

```text
level
experience
gold
diamonds
```

其中等级、经验、金币和钻石当前主要用于存储与显示，尚未接入完整成长经济。

### 7.2 当前云状态

`player_states` 使用JSONB保存：

```text
decks
strategies
settings
revision
```

客户端还会把同样内容写入：

```text
user://battle_setup.cfg
```

账号Token和玩家ID写入：

```text
user://account.cfg
```

### 7.3 新系统持久化原则

新经济数据不能继续塞进 `player_states` JSONB。以下内容必须使用规范化关系表和事务：

- 玩家角色成长；
- 英雄等级与卡牌；
- 库存和Reservation；
- 装备实例和Loadout；
- 岛屿、地块、工人和队列；
- 资源节点、农田、建筑；
- 体力；
- PVE进度和星级；
- 宝箱实例与开箱结果；
- 语义事件账本；
- 通用写操作幂等记录。

`player_states` 继续负责低风险客户端偏好、5套卡组、20套策略和设置。

### 7.4 玩家成长字段迁移

推荐：

- 新建 `player_growth`，作为角色等级、XP、技能点的唯一新系统权威；
- 从现有 `players.level/experience` 一次性初始化；
- 新系统切换后不再双写旧等级/经验字段；
- 第一版不删除旧字段，避免旧客户端和回滚路径立即失效；
- `players.gold` 继续作为玩家金币唯一权威；
- 战场 `GOLD` 按配置 `1:1` 结算到 `players.gold`。

---

## 8. 附录C第5项：当前主界面与Godot场景结构

### 8.1 当前场景

```text
main.tscn
└── EmeraldClash (Node2D)
    └── scripts/game.gd
```

没有独立的：

- MainMenu场景；
- HeroScreen场景；
- EquipmentScreen场景；
- PveChapterScreen场景；
- PlayerSkillTreeScreen场景；
- IslandScene场景。

现有 `battle_map.gd` 在运行时创建战斗地图；`unit.gd` 和 `resource_node.gd` 也由 `game.gd` 动态挂载。

### 8.2 建议迁移结构

保留 `main.tscn` 作为应用入口，但将其职责收敛为导航和全局服务连接：

```text
main.tscn
└── AppRoot
    ├── MainMenu
    ├── HeroScreen
    ├── EquipmentScreen
    ├── PlayerSkillTreeScreen
    ├── PveChapterScreen
    ├── TeamSetupScreen
    ├── StrategyScreen
    ├── IslandScene
    ├── BattleReplayScene
    └── GlobalOverlay
```

建议新增目录：

```text
scenes/app/
scenes/island/
scenes/pve/
scenes/heroes/
scenes/replay/

scripts/api/
scripts/app/
scripts/island/
scripts/pve/
scripts/heroes/
scripts/replay/
```

不要求一次性重写全部旧UI。应先建立新场景路由，再逐屏迁移，避免同时破坏现有战斗和回放。

---

## 9. 附录C第6项：当前服务端数据库与持久化方式

### 9.1 数据库

正式服务端使用PostgreSQL，连接来自：

```text
EMERALD_DATABASE_URL
```

Redis用于策略缓存和健康检查。

当前Migration：

| 版本 | 内容 |
|---|---|
| 001 | 账号、Session、玩家JSON状态、旧策略缓存、战斗、回放 |
| 002 | Strategy 3.0快照、编译记录、幂等战斗请求 |
| 003 | Strategy 3.0策略分享包 |
| 004 | Strategy 3.0编译请求幂等索引 |
| 005 | 快照按玩家归属绑定 |
| 006 | 战斗策略标识兼容Strategy 3.0 |

### 9.2 当前事务能力

现有账号创建、注册、战斗保存和Strategy Store已经使用数据库事务或唯一约束，但尚无通用经济事务服务、Inventory锁、玩家级版本锁和通用幂等表。

### 9.3 推荐新增Migration顺序

不得修改001~006历史文件。建议从007开始：

```text
007_growth_and_command_idempotency.sql
008_inventory_heroes_equipment.sql
009_island_core.sql
010_island_workers_and_reservations.sql
011_production_and_crafting.sql
012_stamina_and_pve_progress.sql
013_chests_loot_and_reward_ledger.sql
014_battle_pve_versioning.sql
```

建议职责：

#### 007

- `player_growth`；
- `player_skill_allocations`；
- `domain_command_results`；
- `semantic_events`；
- 现有玩家初始化。

#### 008

- `hero_ownership`；
- `inventory_items`或按资源类型的库存表；
- `equipment_ownership`；
- `hero_loadouts`；
- 新账号5英雄和默认装备初始化。

#### 009

- `island_states`；
- `island_plot_states`；
- `resource_node_states`；
- `farm_plot_states`；
- `building_instances`；
- 初始1~4号地、储物箱、主屋和资源节点。

#### 010

- `island_workers`；
- `island_worker_tasks`；
- `inventory_reservations`；
- `node_reservations`；
- `farm_reservations`；
- 建筑占用约束；
- 每工人稳定FIFO `sequence_no`。

#### 011

- 配方解锁/蓝图归属；
- 制作成品记录；
- 作物、恢复槽和离线推进需要的时间字段；
- 工人2/3制造状态。

#### 012

- `stamina_states`；
- `stamina_grant_slots`；
- `pve_progress`；
- `pve_level_stars`；
- `pve_battle_requests`。

#### 013

- `chest_instances`；
- `chest_open_results`；
- `pve_reward_ledger`；
- Boss材料解锁事实；
- 防止重复结算的唯一键。

#### 014

- 战斗表新增 `pve_level_id`、`battle_engine_version`、`battle_snapshot_hash`、`reward_status`等审计字段；
- 新Replay Schema版本；
- 保留旧Replay行，不做内容重写。

---

## 10. 附录C第7项：当前配置加载方式

### 10.1 当前事实

当前没有升级文档要求的配置注册中心。主要游戏数值散落在：

- `scripts/unit.gd`常量；
- `scripts/resource_node.gd`常量；
- `scripts/game.gd`字典和坐标；
- `server/strategy_v3/snapshot.py::CURRENT_STATS`；
- `server/strategy_v3/metadata.py`枚举；
- `server/strategy_api.py`限制和旧枚举；
- `project.godot`；
- `VERSION`；
- 部署环境变量。

Godot与Python各自保存了一份英雄ID和数值，已经存在重复事实源。

### 10.2 升级要求

建议新增：

```text
config/
├── schemas/
│   ├── heroes.schema.json
│   ├── equipment.schema.json
│   ├── island.schema.json
│   ├── pve.schema.json
│   └── loot.schema.json
├── heroes.json
├── hero_level_growth.json
├── hero_upgrade_cost.json
├── weapons.json
├── armors.json
├── recipes.json
├── player_level.json
├── skill_tree.json
├── island_plots.json
├── resource_nodes.json
├── crops.json
├── buildings.json
├── workers.json
├── stamina.json
├── pve_levels.json
├── bosses.json
├── maps.json
├── chests.json
└── loot_items.json
```

服务端新增建议模块：

```text
server/config/registry.py
server/config/validator.py
server/config/schemas.py
```

原则：

- 服务器启动时一次性完整加载并验证；
- 每个文件必须带 `schemaVersion` 和 `configVersion`；
- ID交叉引用必须验证；
- 关键配置错误时相关模块拒绝启动；
- Battle Snapshot写入实际使用的配置版本；
- 客户端只获取展示所需DTO，不成为经济和数值权威。

---

## 11. 附录C第8项：当前Replay版本兼容方式

### 11.1 当前Replay

| 项目 | 当前事实 |
|---|---|
| 生成器 | `server/battle_replay_runner.gd` |
| Schema | `1.1` |
| 采样 | 每0.1战斗秒 |
| 最大战斗 | 180秒/10800 Tick |
| 存储 | JSON gzip到 `battle_replays.payload` |
| 元信息 | `battles.simulator_version`、`replay_schema_version` |
| 客户端播放 | `scripts/game.gd` 的 replay相关方法 |

回放初始帧和后续帧保存单位 `unit_type`、位置、HP、动作、资源和弹道。客户端读取旧 `unit_type` 后仍调用当前 `create_unit()` 和 `unit.gd` 生成表现。

### 11.2 当前兼容风险

当前没有真正按 `battleEngineVersion` 分派的独立回放播放器。旧回放之所以还能播放，是因为：

- `lancer`、`monk`仍在当前英雄枚举；
- 旧素材仍存在；
- `unit.gd`仍知道旧动画和行为字段；
- Replay帧直接覆盖HP、位置和状态。

如果直接从 `unit.gd` 删除旧ID或旧素材，历史回放会失效。

### 11.3 必须实施的兼容方案

建议新Replay使用Schema `2.0`，并引入版本分派：

```text
ReplayLoader
  ├── LegacyReplayAdapterV1      schema 1.x
  └── PveReplayAdapterV2         schema 2.x
```

Legacy规则：

- 永久识别 `lancer`、`monk`、`stone`；
- 保留对应精灵和资源素材；
- 使用旧动作名适配；
- 不把旧Replay迁移成新战斗结果；
- 不用新英雄配置重新计算旧回放；
- 历史回放只播放已记录事实，不重新模拟。

新Replay需要记录：

- 新英雄ID和外观颜色；
- 武器/护甲；
- Skill1/Skill2施放；
- 物理/魔法/治疗/护盾/状态事件；
- Boss动作与DangerZone；
- 战斗资源Deposit、携带、消耗、自动扫取；
- 星级Telemetry；
- `battleEngineVersion`、`snapshotHash`和配置版本。

---

## 12. 附录C第9项：升级模块到现有文件/类映射

| 升级模块 | 可复用现有位置 | 新增/调整建议 | Phase |
|---|---|---|---|
| Config Registry | 无 | `server/config/*`、`config/*.json` | A |
| PlayerGrowth | `players.level/experience`仅作迁移源 | `server/domain/growth.py`、`player_growth` | A |
| Hero Lv/Card | 无 | `server/domain/heroes.py`、`hero_ownership` | A |
| Inventory | `players.gold`、战斗临时resource_counts | `server/domain/inventory.py`、库存表 | A |
| Reservation | 无 | `server/domain/reservations.py`、预约表 | A/C |
| Event Ledger | 回放audit不是经济事件账本 | `server/domain/events.py`、`semantic_events` | A |
| 岛屿地图 | `battle_map.gd`仅可借画布概念 | `scenes/island/island_scene.tscn`、岛屿脚本 | B |
| 15地块 | 无 | `island_plots.json`、Plot节点/状态表 | B |
| 岛屿资源节点 | `resource_node.gd`仅是战斗资源 | 独立Island Resource表现与服务端状态 | B |
| 农田 | 无 | FarmPlot DTO、场景节点、状态表 | B/C |
| 岛屿工人 | `unit.gd`仅可复用视觉素材 | `IslandWorker`表现、服务端Worker领域 | C |
| 独立队列 | 无 | `worker_tasks.py`、任务表 | C |
| 离线推进 | 无 | `offline_progress.py`，纯绝对时间算法 | C |
| 建筑/制作 | 无 | 配置、建筑表、Craft服务 | D |
| 技能树 | 无 | Growth服务、SkillTree UI | E |
| 装备 | 无 | Equipment服务、Loadout UI | E |
| Ability System | 现有技能仅支持有界伤害/治疗测试 | 新Battle Ability/Status/Shield模块 | E/G |
| Potion | 无 | Inventory消费、Snapshot Buff | E |
| Final Stat Snapshot | `snapshot.py`固定Lv1 | 新 `battle_snapshot_builder.py` | E/F |
| PVE章节 | 无 | PVE服务、Chapter UI、配置 | F |
| 体力 | 无 | Stamina服务和slot账本 | F |
| 地图模板 | `battle_map.gd`双桥 | 配置驱动Map Factory | F |
| Boss | 无 | Boss实体、技能配置和Replay事件 | F/G |
| 战斗资源带出 | 当前只记录临时计数 | Reward/Extraction事务 | F |
| 星级 | 无 | Telemetry判定与首次领取表 | F/H |
| 宝箱 | 无 | Loot服务、实例表、幂等结果 | F |
| Strategy 4.0 | Strategy 3.0可借确定性语义 | 等独立文档后建立4.0并保留3.0兼容 | G |
| AI复盘 | 当前audit较有限 | Telemetry Schema、Review服务和UI | H |

### 12.1 现有模块应保留

- `scripts/projectile_engine.gd`：作为新弹道系统基础；
- `scripts/strategy_v3/*`：作为确定性规则运行时参考和旧策略兼容；
- `server/strategy_v3/canonical_json.py`：复用规范化哈希合同；
- `server/strategy_v3/*_store.py`：复用不可变记录与幂等状态机模式；
- `server/battle_replay_runner.gd`：演进为版本化PVE runner，旧runner路径保留；
- `server/storage.py`：保留账号和连接入口，但新领域SQL不能继续无限堆入单类；
- `scripts/game.gd`：过渡期保留路由和旧界面，逐步拆分。

### 12.2 不应直接复用

- 不把PVE工人 `unit.gd` 当成岛屿离线工人；
- 不把战斗 `resource_counts` 当成玩家永久库存；
- 不把 `player_states` JSONB当经济数据库；
- 不把现有测试型技能结构当作完整Ability System；
- 不让Godot动画完成事件直接发经济奖励；
- 不在客户端计算成熟、掉落、升级或最终属性。

---

## 13. 附录C第10项：迁移清单

### 13.1 数据迁移

1. 保留001~006，不修改历史Migration。
2. 新建007起的领域表和配置版本表。
3. 为所有现有玩家创建 `player_growth`。
4. 从 `players.level/experience` 初始化角色成长；保留旧列但停止作为新系统权威。
5. `players.gold`继续作为金币权威。
6. 为所有现有玩家幂等创建5个Lv1英雄所有权。
7. 为所有现有玩家幂等发放5件黑色默认武器和1件黑·重甲。
8. 为所有现有玩家创建初始岛屿、1~4号开放地、主屋、储物箱、初始节点、农田和1号工人。
9. 为所有现有玩家初始化100体力及slot处理游标。
10. 初始化PVE进度为仅 `1-1` 可挑战。
11. 所有初始化使用唯一约束和可重复执行的Migration/Backfill。

### 13.2 卡组与策略迁移

对本地和云端5套卡组执行：

```text
lancer → spearman
monk   → mage
```

然后：

- 移除同一卡组内重复英雄，按原槽位保留第一次出现；
- 保持2~5人且槽位连续；不足2人时回退新默认阵容；
- 更新默认阵容为新5英雄；
- 策略原始消息不改写；
- 清空Strategy 2.0/3.0旧编译对象与旧编译阵容；
- 标记 `requiresRecompile=true`；
- 如果文本引用僧侣、旧长枪手ID或旧能力，向玩家展示兼容提示。

策略分享包不原地修改。旧版本分享包保持可预览，但因版本不兼容要求复制文本后重新编译。

### 13.3 英雄与素材迁移

- 新增 `spearman`规范配置，视觉初期可映射现有 `lancer`素材；
- 新增 `mage`完整素材和动画；
- 保留 `assets/game/units/lancer`；
- 保留 `assets/game/units/monk`；
- 新正式战斗工厂不再把 `monk`列入可选英雄；
- Legacy Replay Factory继续创建旧英雄表现。

### 13.4 战斗引擎迁移

1. 将英雄基础数值从 `unit.gd`与`snapshot.py`迁入权威配置。
2. `unit.gd`改为接收完整Battle Stats，不自行按HeroId查新数值。
3. 增加物防、魔防、技能强度和整数伤害公式。
4. 增加Ability、Buff、Debuff、Shield、Control和位移执行层。
5. 普攻全部标记PHYSICAL；保留射手实体弹道。
6. 新战斗工人使用4点采集和配置化采集间隔。
7. 新正式PVE移除自动复活；保留Legacy自动复活。
8. 战斗资源改为关卡配置的共享节点。
9. 胜利自动扫取、失败保留Deposit资源由服务端奖励事务结算，不能由Replay客户端结算。
10. PVE超时按失败处理；Legacy回放仍展示原结果。

### 13.5 Battle Snapshot迁移

1. 保留Strategy 3.0旧快照构建器用于旧流程。
2. 新建PVE Snapshot Builder，不在旧函数上无限增加可选参数。
3. Snapshot Builder在单个服务端事务/一致性读取中加载英雄、装备、技能树、药剂、关卡和敌人。
4. 使用现有Canonical JSON生成 `snapshotHash`。
5. Snapshot保存配置版本和Battle Engine版本。
6. Battle Request绑定Snapshot、体力扣除、药剂消费与奖励上下文。

### 13.6 客户端迁移

1. 建立场景路由和API Client，降低 `game.gd`职责。
2. 新增首页聚合接口客户端模型。
3. 新增英雄、装备、技能树、岛屿和PVE场景。
4. 岛屿动画只消费服务端任务状态。
5. 客户端倒计时使用 `readyAt - serverNow`。
6. 断线重连后先同步并展示离线Summary，不重放全部动画。
7. 新编队阻止重复HeroId。
8. 新Replay按Schema选择Adapter。

### 13.7 API迁移

现有 `strategy_api.py` 已达约1749行。建议保留进程入口，但将路由和领域服务拆分：

```text
server/api/accounts.py
server/api/home.py
server/api/heroes.py
server/api/island.py
server/api/pve.py
server/api/chests.py
server/api/strategy.py

server/domain/growth.py
server/domain/inventory.py
server/domain/reservations.py
server/domain/island.py
server/domain/workers.py
server/domain/offline_progress.py
server/domain/crafting.py
server/domain/stamina.py
server/domain/pve.py
server/domain/loot.py
server/domain/events.py
```

不要求立即更换HTTP框架；先保持现有协议和部署方式，避免将框架迁移与玩法升级捆绑。

### 13.8 部署迁移

- 延续现有systemd服务和OpenResty反向代理；
- 配置目录必须包含在部署包并只读挂载；
- 正式启动先运行Migration，再验证配置，再启动HTTP服务；
- 增加配置健康状态与版本到 `/health`；
- 离线推进不能依赖常驻Godot进程；
- Godot headless只用于战斗模拟和必要的战斗确定性测试。

---

## 14. 新模块的事务边界

### 14.1 通用写命令

每个经济写操作必须在同一数据库事务内：

```text
验证requestId幂等记录
→ Fast Forward玩家离线状态
→ 锁定玩家/相关库存行
→ 读取配置并校验
→ 修改领域状态
→ 写Semantic Event
→ 保存首次响应
→ Commit
```

同一 `playerId + commandType + requestId` 重复请求返回第一次结果。

### 14.2 PVE开始

```text
锁定玩家
→ 补算体力
→ 验证关卡/阵容/装备/药剂
→ 构建不可变Snapshot
→ 创建PVE Battle Request
→ 扣体力
→ 正式模式扣药剂
→ Commit
→ 启动权威模拟
```

创建失败事务回滚。模拟基础设施失败时使用同一请求重试，不重复扣体力或药剂。

### 14.3 PVE结算

```text
锁定Battle Request
→ 验证未结算
→ 验证Replay/Snapshot绑定
→ 计算胜败带出资源
→ 计算金币/卡牌/宝箱/首通/星级
→ 更新库存和进度
→ 写Reward Ledger
→ 标记已结算
→ Commit
```

不得接受客户端提交的奖励数值。

---

## 15. 推荐实施顺序

### Phase 0：升级基础收口

在原Phase A前增加一个短阶段：

1. 固化本文确认决策；
2. 建立配置目录、Schema和Registry；
3. 新建领域包结构；
4. 建立通用幂等、事件账本和玩家事务入口；
5. 增加Legacy ID映射与Replay版本分派骨架；
6. 建立开发进度MD；
7. 保证现有测试继续通过。

### Phase A：数据与领域骨架

按升级文档执行，但推荐内部顺序：

```text
Config Registry
→ Generic Command Idempotency
→ Event Ledger
→ PlayerGrowth
→ HeroOwnership/Card Upgrade
→ Inventory
→ Reservation
→ Equipment Data
```

### Phase B~F

可以在Strategy 4.0文档到达前推进，但必须通过接口隔离Strategy相关语义：

- Skill1/Skill2先做配置和Ability数据入口，不猜自然语言触发DSL；
- Boss可以先做数值、形状和确定性技能执行，不猜BSL事件表达；
- Revive先做资源服务API，不猜策略语法；
- Telemetry先定义通用战斗事件，不提前固定AI复盘提示词。

### Phase G

必须在完整阅读Strategy 4.0/BSL 1.0文档后开始最终接入和验收。

---

## 16. 当前验证基线

本次盘点执行了以下只读/非业务变更验证：

| 验证 | 结果 |
|---|---|
| Godot 4.5.2 Headless工程加载 | 通过 |
| Python顶层测试发现 | 31项通过 |
| Strategy 3.0 Python专项测试 | 46项通过 |
| Strategy V3 Runtime Semantics | 通过 |
| Projectile Engine | 通过 |
| 当前地图无功能草丛 | 通过 |
| 挡线策略 | 通过，有退出时对象泄漏警告 |
| 技能执行骨架 | 通过，有退出时对象泄漏警告 |
| Strategy V3 Full Playtest | 通过，有退出时对象泄漏警告 |
| Replay Client | 通过，388帧回放 |

对象泄漏警告没有导致用例失败，但应作为测试清理技术债登记，不能在新场景大量增加后忽略。

这些结果只证明当前0.7.7基线可运行，不代表PVE升级功能已经实现或验收。

---

## 17. 已识别的主要工程风险

### P0

1. Strategy 4.0/BSL 1.0文档尚未提供，Phase G不可完成。
2. 当前回放没有真正的版本化播放工厂，删除旧ID会破坏历史回放。
3. 当前游戏数值在Godot和Python重复硬编码，必须先建立单一权威配置。
4. 当前经济没有Inventory Reservation和通用幂等事务，不能直接增加多工人并发。
5. 当前主客户端和HTTP服务端均为大文件，继续堆功能会显著增加回归风险。

### P1

1. 旧 `player_states` 允许客户端整体覆盖JSON，不能承载新经济事实。
2. 当前战斗保存函数仍含旧默认敌方阵容假设，新PVE必须从Snapshot保存真实敌方。
3. 当前技能骨架只支持单次有界伤害/治疗，距离完整Ability System较远。
4. 当前资源节点是双方镜像和队伍所有制，新PVE需要共享资源竞争模型。
5. 当前PVE工人全灭后自动参战和自动肉复活都需要按新模式版本化。

### P2

1. README仍主要描述Strategy 2.0，与当前Strategy 3.0事实不完全一致。
2. 若干Godot专项测试退出时报告对象泄漏，需要补清理。
3. 当前UI绝大部分代码创建，后续界面扩张会降低维护性和可视化编辑效率。

---

## 18. Phase A开工条件

现在已经满足：

- 当前工程真实文件与模块已盘点；
- 升级模块映射已给出；
- 数据与兼容迁移顺序已给出；
- 2~12项产品歧义已确认；
- 当前测试基线已记录。

Phase A可以开始，但应遵守：

1. 先完成Phase 0基础收口；
2. 不改坏旧回放；
3. 不删除Strategy 2.0/3.0兼容路径；
4. 不在Strategy 4.0文档缺失时猜DSL；
5. 每个Phase完成后按升级文档执行编译、单测、Schema、Migration和进度文档验收。

---

## 19. 最终文件责任边界

```text
config/*.json
    负责静态平衡配置

server/config/*
    负责配置校验、版本和跨引用

server/domain/*
    负责成长、库存、岛屿、队列、体力、PVE、宝箱等权威规则

server/storage.py + repository层
    负责连接、事务和持久化，不负责UI语义

server/strategy_v3/*
    保留Strategy 3.0与旧策略兼容

未来server/strategy_v4/*
    负责Strategy 4.0/BSL 1.0

Godot scenes/scripts
    负责输入、展示、动画和回放，不负责经济发奖

Battle Snapshot
    连接局外成长事实与单场确定性战斗

Replay
    记录并播放战斗事实，不重新推导奖励
```

这份边界作为正式开发前的工程基线。
