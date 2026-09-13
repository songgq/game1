# Strategy 3.0：自然语言自动对战策略系统实现规范

> 状态：当前版本范围已实现并通过验收（2026-08-20）  
> 目标读者：Codex、后端开发、Godot 战斗逻辑开发、测试人员  
> 适用项目：`battle_game`  
> 当前基线：Strategy 2.0（`strategy-2.0.0`）  
> 目标版本：Strategy 3.0

已实现边界：Strategy 3.0 支持 2–5 名英雄快照、Intent IR 到 Runtime Plan 的确定性编译、运行时状态机与资源仲裁、实体弹道、主动及预测挡线、确定性回放、策略包和分享。当前生产地图仍不开放功能性草丛，当前英雄注册表仍不开放通用技能；这两类未来能力已实现能力门控及专用夹具，不得由客户端提前启用。

最终验收基线：Strategy V3 Python 46 项、兼容/旧版 Python 31 项、Godot 策略运行时/弹道/地图能力/挡线/技能夹具/完整对战/UI/HTTP/云端历史均通过；确定性压力夹具在 100 个独立 Godot headless 进程中产生同一 `normalizedEventHash`：`sha256:4755463fc422e3d5778f40c380aaf7a886e361649a3c7db96e14901aa277d968`。

## 1. 文档目的

本文档定义一套可实际落地的自然语言自动对战策略架构，并给出足够明确的数据契约、编译流程、运行时语义、接口、错误处理和验收标准，使 Codex 可以按阶段实现。

系统的核心链路是：

```text
玩家自然语言
  -> LLM 生成简单意图 Intent IR
  -> 服务器确定性编译 Runtime Plan
  -> 玩家确认系统实际执行描述
  -> 固定 Tick 战斗引擎执行 Runtime Plan
  -> 后台生成确定性回放
  -> 前端只播放回放
```

关键约束：

1. LLM 只负责理解自然语言，不直接控制英雄，不生成最终战斗程序。
2. Runtime Plan 必须由服务器确定性生成、严格校验并版本化。
3. 战斗中禁止调用 LLM。
4. “系统实际执行描述”必须由 Runtime Plan 确定性渲染，不允许 LLM 自由改写。
5. 单条意图失败只影响该意图，不得让整份策略失败。
6. 同一战斗快照、Runtime Plan、随机种子和引擎版本必须产生可复现结果。

## 2. 设计目标与非目标

### 2.1 设计目标

- 支持 2–5 名英雄的动态小队。
- 玩家能够引用英雄编号、英雄类型、状态和相对关系。
- 支持时间、血量、距离、可见性、区域、事件等条件。
- 支持目标筛选、排序、数量限制和 fallback。
- 支持等待、移动、跟随、保持距离、攻击、施法和相对站位。
- 先把当前攻击改造成确定性的实体弹道和首碰撞；后续里程碑再支持功能性草丛、技能和主动挡线策略。
- 支持持续动作、终止条件、目标锁定、重新决策和策略记忆。
- 支持局部接受、局部拒绝以及可解释的系统执行描述。
- 复用当前 Strategy 2.0 的版本校验、动作通道、回放、缓存和上次有效策略回退思想。

### 2.2 非目标

- 不允许模型生成或执行任意代码。
- 不允许 JSON 中出现由 `eval` 执行的任意表达式字符串。
- 不在第一阶段一次性实现需求清单中的全部标签、技能和地图机制。
- 不让 LLM 在战斗中逐 Tick 决策。
- 不把“风筝”“保护”“挡枪”“集火”等玩家战术词直接作为 Runtime opcode。
- 不要求第一阶段兼容所有历史 Strategy 2.0 JSON；历史策略可保留在 2.0 运行时执行。

### 2.3 当前内容和术语基线

本节用于区分“当前已有内容”“当前必须改造的基础能力”和“后续功能”，Codex 不得把后续示例误当成当前已存在的数据。

术语统一：

- 本项目中的“英雄”“参战单位”和策略语境中的 `unit` 指同一类战斗实体。
- 产品文案统一称“英雄”；战斗引擎内部可以继续使用 `Unit`、`unit_id` 等命名。
- `heroInstanceId` 表示某一场战斗中的参战单位实例 ID，不代表另一套独立于单位的实体系统。

当前可用英雄类型只有：

| heroId | 产品名称 | 当前主要能力 |
|---|---|---|
| `archer` | 弓箭手 | 远程普通攻击 |
| `lancer` | 长枪手 | 中距离普通攻击 |
| `worker` | 工人 | 采集资源，满足参战条件后普通攻击 |
| `monk` | 僧侣 | 治疗友方并可普通攻击 |
| `warrior` | 战士 | 近距离普通攻击 |

当前版本队伍仍固定为 5 个槽位；“2–5 人动态小队”是 Strategy 3.0 的目标能力，不是当前现状。

能力状态必须按以下边界理解：

| 能力 | 状态 | 开发约束 |
|---|---|---|
| 五种现有英雄及当前数值 | `CURRENT` | 复用现有单位数据，不得虚构火枪手、骑士、守卫等英雄 |
| 工人采集、资源和肉复活 | `CURRENT` | 重构时必须保留，并纳入后续 economy 规则适配 |
| 后台模拟和前端回放 | `CURRENT` | 在现有链路上扩展，不另建客户端战斗计算 |
| 实体弹道、首碰撞和实际命中目标 | `NOW/P0` | 当前立即改造，是后续策略与挡线能力的基础前置条件 |
| 功能性草丛、隐藏和视野 | `FUTURE/M2` | 当前地图装饰草丛不算功能性草丛 |
| 通用英雄技能、冷却和施法 | `FUTURE/M4` | 僧侣现有治疗不等于完整通用技能系统 |
| 主动寻找挡线位置 | `FUTURE/M3` | 必须建立在实体弹道已稳定的基础上 |

PromptBuilder 和 MetadataRegistry 只能向 LLM 暴露当前战斗快照真正支持的英雄、地图区域、技能和动作。功能性草丛或通用技能上线前，正式编译不得声称能够执行相关能力；对应策略片段应返回“当前版本暂不支持”，不能悄悄改写为其他动作。

当前生产地图的 `supportedAreaTypes` **不得包含 `bush`**。客户端不得自行提交 `enableBush`、区域类型或技能能力；快照能力只能由服务器当前地图和英雄注册表生成。BattleEngine 也必须再次读取快照能力：只有未来地图显式声明 `supportedAreaTypes` 包含 `bush` 时，才注册功能性草丛区域。地图贴图上的灌木装饰不参与隐藏、视野或区域 Selector。未来草丛代码可提前保留，但必须通过能力开关隔离，并分别用“当前地图无草丛”和“未来地图启用草丛”两个夹具验收。

## 3. 三层策略表示

系统必须同时保存三层数据，不得把三层合并成一个 JSON。

### 3.1 Layer A：玩家原始策略

原始策略用于编辑、审计、分享和重新编译。

```json
{
  "messages": [
    {
      "id": "m1",
      "text": "3号开局30秒原地不动，但可以攻击进入射程的敌人。"
    },
    {
      "id": "m2",
      "text": "30秒后进入最近草丛，敌人靠太近时后退。"
    }
  ]
}
```

规则：

- 前端可保存多条消息，但只有玩家点击“理解策略/生成策略”时才提交完整策略。
- 禁止每输入一句就自动调用一次 LLM。
- 消息 ID 由服务器或前端生成，编译后保持稳定。

### 3.2 Layer B：Intent IR

Intent IR 是 LLM 输出的简单语义结构。它表达“玩家想做什么”，但不是最终可执行格式。

```json
{
  "schemaVersion": "intent-1.0",
  "strategyName": "弓箭手草丛战术",
  "intents": [
    {
      "intentId": "i1",
      "sourceMessageIds": ["m1"],
      "acceptanceDependencies": {
        "intentIds": [],
        "policy": "require_all"
      },
      "runtimePrerequisites": [],
      "atomicGroupId": null,
      "actors": {"slots": [3]},
      "trigger": {
        "kind": "comparison",
        "field": "battle.elapsed_time",
        "op": "<",
        "value": 30
      },
      "goal": {
        "kind": "hold_movement",
        "allowCombat": true
      },
      "until": null,
      "fallbackPreference": null
    },
    {
      "intentId": "i2",
      "sourceMessageIds": ["m2"],
      "acceptanceDependencies": {
        "intentIds": [],
        "policy": "require_all"
      },
      "runtimePrerequisites": [],
      "atomicGroupId": null,
      "actors": {"slots": [3]},
      "trigger": {
        "kind": "comparison",
        "field": "battle.elapsed_time",
        "op": ">=",
        "value": 30
      },
      "goal": {
        "kind": "enter_area",
        "areaType": "bush",
        "selection": "nearest_reachable"
      },
      "until": null,
      "fallbackPreference": "hold_position"
    },
    {
      "intentId": "i3",
      "sourceMessageIds": ["m2"],
      "acceptanceDependencies": {
        "intentIds": [],
        "policy": "require_all"
      },
      "runtimePrerequisites": [],
      "atomicGroupId": null,
      "actors": {"slots": [3]},
      "trigger": {"kind": "enemy_too_close"},
      "goal": {"kind": "maintain_attack_distance"},
      "until": null,
      "fallbackPreference": "nearest_safe_position"
    }
  ],
  "ambiguities": [],
  "unsupportedFragments": []
}
```

Intent IR 的字段应保持少而稳定。模型不得填写：

- Runtime 规则 ID。
- 最终优先级数值。
- 已绑定的英雄实例 ID。
- 编译器默认距离系数。
- 单位结果、玩家回复或实际执行描述。
- 战斗引擎内部字段。

Intent IR 必须把两种不同依赖分开表达：

- `acceptanceDependencies`：编译接受依赖。前置 intent 无法编译时，当前 intent 是否还能独立成立。
- `runtimePrerequisites`：运行时前置条件。前置 intent 虽然编译成功，但必须在战斗中达到指定状态后，当前 intent 才允许启动。
- `atomicGroupId`：同一组内所有 intent 全有全无。Strategy 3.0 首版不支持组内 optional 成员；可选增强应放在组外，并通过 optional acceptance dependency 关联。

`acceptanceDependencies.policy` 支持：

- `require_all`：所有前置 intent 编译成功。
- `require_any`：至少一个前置 intent 编译成功。
- `optional`：前置 intent 失败不阻止当前 intent 独立编译。

`runtimePrerequisites` 示例：

```json
[
  {
    "intentId": "i_enter_bush",
    "requiredState": "COMPLETED"
  }
]
```

例如“进入草丛后等待3秒再使用伏击技能”：进入草丛无法编译时，后续意图通过 acceptance dependency 被拒绝；全部编译成功时，等待阶段仍必须通过 runtime prerequisite 等待进草规则在战斗中真正完成，不能同时 ACTIVE。

### 3.3 Layer C：Runtime Plan

Runtime Plan 是唯一允许战斗引擎执行的策略格式。它由服务器编译器生成。

```json
{
  "schemaVersion": "3.0",
  "compilerVersion": "strategy-compiler-3.0.0",
  "metadataVersion": "strategy-metadata-3.0.0",
  "snapshotId": "snapshot_123",
  "snapshotHash": "sha256:...",
  "planHash": "sha256:...",
  "units": {
    "hero_instance_3": {
      "rules": []
    }
  },
  "sourceMap": {},
  "compileResults": [],
  "warnings": []
}
```

Runtime Plan 必须满足：

- 只包含白名单字段、操作符和 opcode。
- 不包含任意自然语言表达式。
- 所有英雄、技能、区域类型和字段引用均已解析。
- 所有数字已归一化并通过范围校验。
- 每条规则都具有通道、优先级、终止语义和重新决策语义。
- 对相同输入产生稳定排序和稳定 `planHash`。

## 4. 总体模块

### 4.1 StrategyMetadataRegistry

单一事实来源，维护：

- 支持的 Intent goal。
- 支持的 Runtime opcode。
- 支持的字段和字段类型。
- 支持的比较操作符。
- 支持的 selector scope、filter 和 sort。
- 支持的事件、区域类型、英雄能力和技能能力。
- 每个版本的默认优先级、默认 until、fallback 和重规划策略。

禁止在提示词、编译器、校验器和运行时中分别维护互相不一致的枚举。提示词上下文、JSON Schema 和校验器均应由 Registry 派生。

### 4.2 StrategyPromptBuilder

输入：

- 玩家完整策略消息。
- 2–5 人阵容摘要。
- 当前地图实际支持的区域和机制。
- 英雄实际拥有的技能和能力。
- Intent IR JSON Schema。

输出：一次 LLM 请求。

PromptBuilder 只注入本局可用的元数据，不把全游戏所有标签和技能塞入提示词。

### 4.3 IntentSchemaValidator

负责对 LLM 返回的 Intent IR 做宽容但安全的校验：

- 可忽略未知的非关键附加字段并记录 warning。
- 可为缺失的可选字段补 `null`。
- 不得自动猜测缺失的执行者、技能或核心 goal。
- JSON 完全无法解析时才允许发起一次 LLM 修复请求。
- 单个 intent 不合法时，将该 intent 标为 rejected，继续处理其他 intent。

### 4.4 StrategyCompilerV3

负责将 Intent IR 确定性编译为 Runtime Plan。详细算法见第 7 节。

### 4.5 StrategyRuntimeValidator

对 Runtime Plan 做严格校验：

- 顶层和规则字段集合。
- 字段类型和数值范围。
- 英雄实例、技能和区域引用。
- AST 节点类型。
- opcode 参数。
- fallback 引用。
- 不允许自引用循环或无限 fallback 循环，fallback 最大深度为 2。
- Acceptance dependency、runtime prerequisite 和 atomic group 合法。
- Priority/Specificity Class、目标角色、资源声明、恢复与重触发策略合法。
- `when/until` AST、minActiveTicks 和 cooldownTicks 构成的 hysteresis 语义合法。
- 每个规则通道与 action opcode 兼容。

### 4.6 StrategyTextRenderer

输入 Runtime Plan 和 sourceMap，使用模板生成：

- 整体策略实际执行描述。
- 每条玩家消息的接受、修改、默认解释和拒绝说明。
- 每个单位的策略摘要。

禁止调用 LLM。相同 Runtime Plan 必须生成相同含义的文本。

### 4.7 StrategyRuntimeV3

Godot 战斗运行时，负责：

- 读取 Runtime Plan。
- 维护每个单位的活动规则、锁定目标、动作状态和记忆。
- 周期评估规则和响应事件。
- 各通道独立仲裁。
- 生成本 Tick 的行动意图。

### 4.8 BattleEngine 与 ReplayRecorder

BattleEngine 负责确定性执行行动；ReplayRecorder 记录发生的事实和关键决策原因。前端不得重新计算战斗。

## 5. 战斗快照

编译和战斗执行必须绑定同一份快照。

下例展示的是包含后续 M2 草丛能力的目标快照形态，不表示当前版本已经支持 `forest_01` 或 `use_bush`。当前实现必须根据真实地图删除未上线的区域类型和 capability；弓箭手的数值必须从当局实际单位配置生成，不能照抄示例数值。

```json
{
  "snapshotId": "snapshot_123",
  "gameVersion": "2026.08.17",
  "engineVersion": "battle-engine-3.0.0",
  "map": {
    "mapId": "forest_01",
    "mapVersion": "1.0.0",
    "supportedAreaTypes": ["spawn_zone", "open_ground", "bush", "obstacle"]
  },
  "teams": {
    "blue": {
      "heroes": [
        {
          "heroInstanceId": "hero_instance_3",
          "slotNo": 3,
          "heroId": "archer",
          "level": 5,
          "battleStats": {
            "maxHp": 598,
            "attack": 160,
            "attackCd": 1.1,
            "moveSpeed": 1.0,
            "bodyRadius": 0.4,
            "attackRange": 6.0
          },
          "capabilities": ["move", "basic_attack", "use_bush"],
          "skills": []
        }
      ]
    }
  }
}
```

要求：

- 编译后若阵容、英雄等级、技能配置或地图版本变化，必须重新编译或明确走兼容迁移。
- 战斗过程中不读取玩家养成表的实时数据。
- 回放保存快照 ID、Runtime Plan、随机种子和引擎版本。

## 6. Runtime Plan 数据模型

### 6.1 Rule 标准结构

```json
{
  "id": "r_0001",
  "actorIds": ["hero_instance_3"],
  "channel": "locomotion",
  "priorityClass": "TACTICAL_MOVE",
  "priorityModifier": 0,
  "specificityClass": "EXACT",
  "sourceOrder": 2,
  "when": {},
  "targetBinding": {
    "writeRole": "area_target",
    "selector": null,
    "releasePolicy": "on_rule_end"
  },
  "resourceClaims": [
    {"resource": "MOVE", "mode": "exclusive"},
    {"resource": "TARGET_ROLE:area_target", "mode": "exclusive"}
  ],
  "action": {},
  "until": null,
  "fallback": null,
  "runtimePrerequisites": [],
  "execution": {
    "recoveryPolicy": "resume",
    "retriggerPolicy": "on_condition_reenter",
    "minActiveTicks": 5,
    "cooldownTicks": 0,
    "replanIntervalTicks": 5,
    "replanEvents": ["target_invalid", "path_failed", "damage_received"]
  },
  "sourceMessageIds": ["m2"]
}
```

### 6.2 通道

第一阶段固定支持：

| 通道 | 职责 | 示例 opcode |
|---|---|---|
| `system` | 死亡、眩晕、击退等强制状态 | 仅系统生成 |
| `survival` | 逃生、回血、避险 | `move_to_area`、`move_away_from` |
| `locomotion` | 主动移动和站位 | `hold_position`、`follow`、`move_to_area` |
| `targeting` | 选择攻击或技能目标 | `set_target` |
| `combat` | 普攻和技能 | `basic_attack`、`cast_skill` |
| `facing` | 朝向 | `face_target`、`face_position` |
| `memory` | 写入和清理策略记忆 | `set_memory`、`clear_memory` |

同一 Tick 内每个通道至多产生一个获胜行动。不同通道可同时工作，但英雄配置可以声明动作锁，例如攻击前摇锁定 locomotion。

Channel 表达行为来源和策略职责，不代表物理执行资源。`survival` 和 `locomotion` 都可能产生移动，因此 Channel 仲裁后必须继续执行 Action Resource 仲裁，详见第 8.9 节。

### 6.3 优先级类别

设计层禁止散落 `650`、`830` 等魔法数字。Rule 使用优先级类别和有限修正值：

| 类别 | 从高到低的用途 |
|---|---|
| `SYSTEM` | 死亡、眩晕、击退等强制状态 |
| `EMERGENCY_SURVIVAL` | 紧急逃生和避险 |
| `PROTECTION` | 紧急队友防护和弹道挡线 |
| `CRITICAL_SKILL` | 关键技能 |
| `COMBAT_POSITIONING` | 战斗距离和关键站位 |
| `COMBAT` | 攻击和普通技能 |
| `TACTICAL_MOVE` | 进入区域和战术移动 |
| `FOLLOW` | 普通跟随和编队 |
| `IDLE` | 等待、巡逻和默认 AI |

最终稳定比较键为：

```text
priorityClassOrder DESC
priorityModifier DESC
specificityClassOrder DESC
sourceOrder DESC
ruleId ASC
```

`priorityModifier` 必须限制在 Registry 定义的小范围内。LLM 不得输出类别、修正值或最终数值；它只可表达“优先、无论如何、其次”等语义，由编译器映射。

`specificityClass` 只允许以下有限枚举，不得按 AST 节点数量计算，也不得由 Recipe 作者随意填写整数：

- `DEFAULT`：系统生成的默认行为。
- `SCOPED`：按英雄类型、状态或一组对象限定。
- `EXACT`：玩家明确指定槽位、具体单位或具体区域。

条件表达式更长不代表更具体。Compiler 根据 actor 和显式目标引用确定 specificityClass。

### 6.4 条件 AST

禁止任意表达式字符串。使用白名单 AST：

```json
{
  "op": "all",
  "args": [
    {
      "op": "gte",
      "left": {"node": "field", "path": "battle.elapsed_time"},
      "right": {"node": "const", "value": 30}
    },
    {
      "op": "eq",
      "left": {"node": "field", "path": "self.is_in_bush"},
      "right": {"node": "const", "value": false}
    }
  ]
}
```

第一阶段支持的逻辑节点：

- `all`
- `any`
- `not`
- `exists`
- `not_exists`
- `eq`
- `neq`
- `gt`
- `gte`
- `lt`
- `lte`
- `in`
- `not_in`

第一阶段支持的数值节点：

- `const`
- `field`
- `add`
- `subtract`
- `multiply`
- `divide`
- `min`
- `max`

每个 Registry 字段必须声明返回类型和允许使用的上下文。Validator 必须拒绝类型不匹配的比较。

### 6.5 Target Selector

```json
{
  "scope": "visible_enemy_units",
  "filters": [
    {
      "field": "is_alive",
      "op": "eq",
      "value": {"node": "const", "value": true}
    }
  ],
  "sort": [
    {"field": "distance_to_self", "order": "asc"}
  ],
  "limit": 1
}
```

选择器必须稳定排序。若主排序字段相同，自动追加稳定 tie-breaker：

1. `slot_no`（英雄）。
2. `area.id`（区域）。
3. `entity.id`（其他实体）。

目标锁定不得只按通道保存。每个单位维护有语义的目标角色：

- `attack_target`
- `movement_reference`
- `follow_target`
- `protect_target`
- `threat_target`
- `skill_target`
- `area_target`

Rule 通过 `targetBinding.writeRole` 写入一个角色，action 通过 `targetRef` 引用角色。不同角色可以指向不同实体，例如英雄可以远离 `threat_target`，同时攻击 `attack_target`。每个目标角色独立保存锁定期限、失效条件和重选事件。

每个目标角色值必须保存所有权信息：

```json
{
  "role": "attack_target",
  "value": "enemy_1",
  "ownerRuleId": "r_10",
  "acquiredTick": 300,
  "lockUntilTick": 320,
  "generation": 4,
  "releasePolicy": "on_rule_end"
}
```

`releasePolicy` 支持：

- `on_rule_end`
- `on_target_invalid`
- `retain_until_replaced`

写入目标角色等价于申请 `TARGET_ROLE:<role>` 资源；同一 Tick 多条规则写同一角色时由 Action Resource Arbiter 决定。Rule 使用 `resume` 时只有在角色 generation 和所有权仍有效的情况下恢复原目标，否则重新选择或失败。

### 6.6 第一阶段 Runtime opcode

基础 opcode：

- `hold_position`
- `stop`
- `move_to_position`
- `move_to_area`
- `move_towards`
- `move_away_from`
- `move_to_range`
- `follow`
- `face_target`
- `set_target`
- `basic_attack`
- `cast_skill`
- `set_memory`
- `clear_memory`

第二阶段增加：

- `move_to_relative_position`
- `move_to_nearest_safe_position`

第三阶段增加：

- 弹道和站位仍尽量复用 `move_to_position`。`line_block_position` 应实现为位置计算函数，不应成为含糊的“保护”动作。

## 7. StrategyCompilerV3 编译算法

编译器必须按以下顺序执行，禁止跳过阶段。

### 7.1 规范化

- 规范 JSON 整数和浮点数。
- 补齐可选字段的 `null`。
- 规范英雄槽位为整数。
- 规范已知同义枚举。
- 为 intent 生成内部稳定序号。

### 7.2 绑定引用

- `slotNo` -> `heroInstanceId`。
- `skillNo/skillId` -> 快照中的技能实例。
- `areaType` -> 当前地图支持的区域类型。
- 英雄类型引用 -> 当前阵容中匹配的实例集合。

引用不存在时拒绝当前 intent，错误码示例：

- `ACTOR_SLOT_NOT_FOUND`
- `SKILL_NOT_FOUND`
- `AREA_TYPE_UNAVAILABLE`

### 7.3 能力校验

根据快照能力判断 goal 是否可能执行：

- 无移动能力不能生成 locomotion 动作。
- 没有指定技能不能生成 `cast_skill`。
- 地图无草丛不能生成 `enter_area(bush)`。
- 不可降级的明确方式不得静默换成其他行为。

### 7.4 依赖与原子组解析

在生成任何 Runtime Rule 前分别构建编译接受依赖图和运行时前置关系：

- `intentId` 必须唯一。
- acceptance dependency 和 runtime prerequisite 引用必须存在。
- 两类关系图都必须无环。
- `acceptanceDependencies.policy=require_all` 的任一依赖失败时，当前 intent 标记为 `REJECTED_DUE_TO_DEPENDENCY`。
- `acceptanceDependencies.policy=require_any` 的全部依赖失败时，当前 intent 标记为 `REJECTED_DUE_TO_DEPENDENCY`。
- `runtimePrerequisites` 不参与编译成功判断；它们被 Lowering 为 Rule gate 或受限 phaseMachine 转换。
- 同一 `atomicGroupId` 中所有 intent 必须整体接受或整体拒绝。首版不支持组内 optional/required 角色。
- 依赖或原子组失败不得影响无依赖的其他 intent。

依赖解析结果必须写入 compileResults 和 Renderer，禁止静默删除后续意图。

### 7.5 Goal Lowering

将 Intent goal 通过确定性 recipe 展开为基础规则。

第一阶段至少实现以下 recipe：

| Intent goal | Runtime 展开 |
|---|---|
| `hold_movement` | locomotion `hold_position`，不占用 combat |
| `enter_area` | area selector + `move_to_area` + 到达 until |
| `follow_unit` | unit selector + `follow` + 目标失效 fallback |
| `attack_target` | targeting `set_target` + combat `basic_attack` |
| `maintain_attack_distance` | 太近 `move_away_from`，太远 `move_to_range`，合适时停止主动移动 |
| `retreat_to_area` | survival `move_to_area` + 血量/到达 until |
| `cast_skill` | targeting selector + combat `cast_skill` |

高阶 recipe 只存在于编译器，不进入 Runtime opcode。

### 7.6 补默认值

由 Registry 模板补充：

- 通道。
- 优先级类别、修正值和 specificityClass。
- 默认阈值。
- until。
- fallback。
- 目标角色和角色锁定策略。
- 动作资源声明。
- 最短动作持续 Tick。
- 重规划间隔和事件。
- `resume|restart|cancel` 恢复策略。
- retriggerPolicy、cooldownTicks，以及由 `when/until` 驱动的统一 hysteresis 状态。

默认值必须进入 compile result 和系统执行描述。例如玩家说“敌人太近”，系统使用 `attackRange * 0.7` 时必须告知玩家。

### 7.7 冲突分析

编译器至少检测：

- 同一单位、同一通道、条件完全重叠且动作互斥。
- 自跟随。
- 无条件循环跟随。
- fallback 循环。
- Intent 依赖循环。
- 永不可能满足的明显条件。
- 引用已被拒绝 intent 产生的规则。

冲突解决顺序：

1. 系统规则高于玩家规则。
2. 生存规则高于普通战术规则。
3. 玩家明确的优先词可在模板允许范围内调整优先级。
4. 更具体的条件高于宽泛条件。
5. 同类规则默认后消息覆盖前消息。
6. 无法安全判断时标记 `AMBIGUOUS_CONFLICT`，不擅自执行冲突部分。

### 7.8 生成稳定 Plan

- 按 actor、channel、priority class、modifier、specificityClass、source order 和 rule ID 稳定排序。
- 生成稳定 rule ID。
- 建立 sourceMap。
- 序列化时固定键顺序。
- 计算 `planHash`。
- 交给 StrategyRuntimeValidator 严格验证。

### 7.9 Canonical Plan 与 planHash

`planHash` 只能由服务器计算。Hash 输入固定为以下可执行载荷，禁止调用方自行增删字段：

```json
{
  "schemaVersion": "...",
  "compilerVersion": "...",
  "metadataVersion": "...",
  "snapshotId": "...",
  "snapshotHash": "...",
  "units": {}
}
```

`planHash`、`sourceMap`、`compileResults` 和 `warnings` 不进入 planHash；它们不改变战斗执行语义。完整编译记录仍由不可变 compile store 保存，若以后需要审计完整包，使用独立 `compilePackageHash`，不得改变 planHash 的含义。

Canonical Serialization Contract：

1. 所有文本先规范化为 Unicode NFC，再编码为无 BOM 的 UTF-8。
2. Runtime Plan 使用完整规范形状；Schema 要求存在的 `null` 必须保留。
3. Object key 按 Unicode code point 升序排列。
4. Array 保留 Compiler 已完成的稳定顺序，Canonicalizer 不重新猜测业务排序。
5. 使用无多余空格的 JSON。
6. 禁止 NaN 和 Infinity，`-0.0` 规范化为 `0`。
7. 数学上为整数的数字规范化为整数，使 `1` 与 `1.0` 等价。
8. 非整数有限数字采用 RFC 8785/JCS 兼容的最短可往返表示。
9. Hash 算法固定为 SHA-256，表示格式固定为小写十六进制 `sha256:<hex>`。

项目只能有一份服务器 Canonicalizer，并提供跨模块共享测试向量。Godot Runtime 校验服务器提供的 canonical plan bytes 或服务器签名，不得另写一套行为不同的 Hash 生成逻辑。

## 8. Runtime Semantics Contract

本节是 Strategy 3.0 的强制运行时契约。Milestone 1 开始前必须完成对应类型、状态机和测试，不得把语义留给各 Recipe 自行决定。

### 8.1 确定性范围

必须保证：

1. 相同服务器 BattleEngine 构建、战斗快照、Runtime Plan 和随机种子重新模拟时，产生相同的规范化事件流 Hash。
2. 相同服务器生成的 battle request 幂等键重复请求时，返回相同 battle ID、结果和回放。
3. 前端只播放回放，不参与模拟。

当前不要求不同 Godot 版本、操作系统和 CPU 架构逐位一致。战斗记录必须保存 Godot 版本、BattleEngine 构建版本和模拟器版本；跨构建重算不属于确定性承诺。

### 8.2 Tick 阶段顺序

BattleEngine 必须使用固定 Tick，并按以下顺序执行：

```text
TICK_START
  1. CONTINUE_ACTIVE_ACTIONS
  2. PROCESS_SYSTEM_STATUS
  3. COLLECT_PRIOR_TICK_EVENTS
  4. SORT_EVENTS
  5. UPDATE_MEMORY
  6. STRATEGY_REPLAN
  7. CHANNEL_ARBITRATION
  8. ACTION_RESOURCE_ARBITRATION
  9. ACTION_COMMIT
 10. MOVEMENT
 11. ATTACK_AND_CAST_WINDUP
 12. PROJECTILE_ADVANCE
 13. COLLISION_RESOLUTION
 14. DAMAGE_AND_HEAL_RESOLUTION
 15. DEATH_RESOLUTION
 16. VICTORY_CHECK
 17. REPLAY_COMMIT
TICK_END
```

禁止任何子系统绕过阶段直接结算另一个阶段的结果。

Command 生命周期固定为：

```text
Rule Decision
  -> Action Intent
  -> Channel Arbitration
  -> Action Resource Arbitration
  -> Action Commit
  -> Active Action State
  -> 本 Tick 后续 Battle Phase 消费 Active Action
```

`CONTINUE_ACTIVE_ACTIONS` 只推进和检查上一 Tick 尚未完成的移动、前摇、active、recovery 等状态，不再次执行上一 Tick command。当前 Tick 在 `ACTION_COMMIT` 成功提交的新动作，由同一 Tick 后续的 `MOVEMENT`、`ATTACK_AND_CAST_WINDUP` 等阶段消费；不得同时在下一 Tick 重复应用。

### 8.3 稳定排序规则

所有集合都必须显式排序，不得依赖 Dictionary、HashMap、节点树或物理引擎返回的天然顺序。

事件排序键：

```text
phaseOrder ASC
eventTypeOrder ASC
sourceEntityId ASC
targetEntityId ASC
eventSequence ASC
```

同 Tick 伤害和治疗先收集，再按稳定顺序批量结算。碰撞候选距离相同时按碰撞时间、实体类别顺序和实体 ID 排序。Navigation 返回等价路径时，必须通过固定邻居顺序或路径点稳定排序选择。

随机行为只能使用战斗种子派生的命名 RNG 流，例如 `targeting_rng`、`spawn_rng`；增加一个子系统的随机调用不得改变其他子系统的 RNG 序列。

### 8.4 Tick 与决策频率

- 战斗物理 Tick：固定为项目配置值，例如 30 或 60 Hz。
- 策略周期评估：第一阶段为固定 5–10 Hz，由 Tick 计数触发。
- 禁止使用真实墙钟时间决定策略。
- 阶段 3 `COLLECT_PRIOR_TICK_EVENTS` 是本 Tick 策略可见事件的封口点。阶段 1–2 产生的系统事件可在阶段 3 纳入本 Tick；阶段 3 之后产生的所有事件都写入 `next_tick_event_queue`，在下一 Tick 的阶段 3 处理。
- “紧急事件立即重评”表示跳过普通重规划间隔，在下一个合法 `STRATEGY_REPLAN` 阶段处理；禁止当前 Tick 从后续阶段回跳到阶段 6。

重评事件示例：

- `damage_received`
- `target_dead`
- `target_invisible`
- `skill_ready`
- `path_failed`
- `ally_dead`
- `entered_area`
- `left_area`

### 8.5 Rule 状态机

每条单位规则必须处于以下状态之一：

```text
INACTIVE
PENDING
ACTIVE
SUSPENDED
COMPLETED
FAILED
CANCELLED
```

允许的核心转换：

```text
INACTIVE  -> PENDING    when 从 false 变为 true
PENDING   -> ACTIVE     通过通道与动作资源仲裁并成功 Action Commit
PENDING   -> INACTIVE   仲裁前 when 失效
ACTIVE    -> SUSPENDED  被可恢复的高优先级规则打断
SUSPENDED -> ACTIVE     打断结束且原目标、条件仍有效
SUSPENDED -> FAILED     原目标失效或恢复条件不成立
ACTIVE    -> COMPLETED  until 成立
ACTIVE    -> FAILED     目标永久失效或执行失败超过上限
ACTIVE    -> CANCELLED  策略替换、依赖失效或明确取消
```

对一次规则激活而言，`COMPLETED|FAILED|CANCELLED` 是终态。Recipe 必须声明完成后的重新触发策略；只有 retriggerPolicy 明确允许且满足重新武装条件时，规则才可回到 `INACTIVE`，禁止默认无限重复。

`execution.retriggerPolicy` 第一阶段支持：

- `never`：到达终态后不再启动。
- `on_condition_reenter`：终态后必须先观察到 `when=false`，等待 cooldown 完成，再在 `when` 重新变为 true 时回到 `INACTIVE -> PENDING`。

后续可扩展 `after_cooldown|per_target|per_event`。未实现的策略值必须被 Validator 拒绝。

### 8.6 暂停、恢复和重启

`execution.recoveryPolicy` 固定支持：

- `resume`：恢复被打断前的目标、目的地和进度。
- `restart`：重新评估 selector 并从头开始动作。
- `cancel`：被打断后当前规则结束，不自动恢复。

例如“前往草丛”被紧急后退打断后默认使用 `resume`，继续原草丛目标；只有原草丛失效时才重新选择。该规则是全局运行时语义，不得只在示例中实现。

### 8.7 单位运行状态

```text
rule_state_by_id
active_rule_by_channel
active_action_by_channel
target_roles
action_started_tick
last_replan_tick
path_failure_count
memory
```

`target_roles` 保存语义目标及各自的锁定期限、选择规则、失效原因和上次变化 Tick，不再使用 `locked_target_by_channel`。

### 8.8 通道仲裁算法

每次需要决策时，对每个单位、每个通道：

1. 找出 actor 匹配、依赖有效且 `when` 成立的规则。
2. 将新满足规则从 `INACTIVE` 转为 `PENDING`。
3. 去除 selector 失败且没有可执行 fallback 的规则。
4. 按 priority class、modifier、specificityClass、source order 和 rule ID 稳定排序。
5. 比较获胜规则与当前 `ACTIVE` 规则。
6. 仅在当前规则结束/失败、声明的重评事件发生或新规则优先级更高时尝试切换。
7. 每个 Channel 输出候选 Action Intent，不在此阶段假设它已经获得身体执行权。
8. 当前 Active Rule 在资源仲裁和 Commit 成功前保持原状态，不得提前转为 `SUSPENDED`。
9. 把 Channel winner 交给 Action Resource Arbiter；只有新动作成功 Commit 后，才按 recoveryPolicy 更新被抢占规则状态。

不得每个 Tick 无条件重新选择目标。

### 8.9 Action Resource / Actuator 仲裁

Channel 表达策略职责，Action Resource 表达单位真实可以同时使用的执行器。第一阶段资源：

- `MOVE`
- `FACING`
- `PRIMARY_COMBAT`
- `SKILL_SLOT:<slot>`
- `TARGET_ROLE:<role>`
- `MEMORY_KEY:<key>`

每个 Action Intent 声明一组 `resourceClaims`。一个动作需要的全部 exclusive 资源必须原子获得；不得只获得部分资源后执行半个动作。

仲裁流程：

1. 收集各 Channel winner 和当前 Active Action 持有的资源租约。
2. 按 Priority Class、modifier、specificityClass、source order、rule ID 稳定排序候选 action bundle。
3. 检查资源冲突和 Interrupt Matrix。
4. 一个 bundle 的全部资源都可获得时一次性授予；否则全部不授予。
5. 被拒绝的新候选保留为 `PENDING`，当前不可打断动作继续持有租约。
6. 获准 bundle 在 Action Commit 成功后，将被抢占的可恢复规则转为 `SUSPENDED`；Commit 失败则回滚本次资源授予和状态变化。
7. 记录 `RESOURCE_CONFLICT|ACTION_LOCKED|PREEMPTED|COMMIT_ROLLBACK` 等稳定 reason code。

示例：`survival` 和 `locomotion` 同时产生 MOVE，最终只有优先级更高且允许打断当前动作的候选获得 MOVE。两个 memory action 写不同 key 可以同时成功；写同一 key 时通过 `MEMORY_KEY:<key>` 冲突仲裁。

### 8.10 Action Lock / Interrupt Matrix

每个动作定义：

- 当前阶段：`windup|active|recovery`。
- 锁定的动作资源。
- 可打断它的 interrupt class。
- 被打断后的取消、冷却和资源处理。

基础矩阵：

| 当前动作 | `SYSTEM_FORCE` | `EMERGENCY_SURVIVAL` | `COMBAT` | `TACTICAL_MOVE` |
|---|---:|---:|---:|---:|
| 普攻前摇 | 是 | 由英雄配置 | 否 | 否 |
| 普攻后摇 | 是 | 是 | 否 | 由英雄配置 |
| 普通技能施法 | 是 | 由技能配置 | 否 | 否 |
| 霸体技能施法 | 仅白名单状态 | 否 | 否 | 否 |
| 普通移动 | 是 | 是 | 否 | 可替换 |
| 击退/眩晕 | 不适用 | 否 | 否 | 否 |

技能快照至少声明：

```json
{
  "locks": ["MOVE", "FACING", "PRIMARY_COMBAT"],
  "interruptibleBy": ["stun", "knockback", "death"],
  "cancelPolicy": "lose_cast",
  "refundCooldownOnCancel": false
}
```

BattleEngine 是动作锁的最终裁决者，Runtime Plan 不得覆盖技能和系统的硬限制。

### 8.11 Hysteresis 与防抖

Hysteresis 不另建一套阈值字段，直接复用 Rule 的受限 AST：

```json
{
  "when": {
    "op": "lt",
    "left": {"node": "field", "path": "self.distance_to_threat"},
    "right": {"node": "multiply", "args": [
      {"node": "field", "path": "self.attack_range"},
      {"node": "const", "value": 0.7}
    ]}
  },
  "until": {
    "op": "gte",
    "left": {"node": "field", "path": "self.distance_to_threat"},
    "right": {"node": "multiply", "args": [
      {"node": "field", "path": "self.attack_range"},
      {"node": "const", "value": 0.85}
    ]}
  },
  "execution": {
    "minActiveTicks": 10,
    "cooldownTicks": 5,
    "retriggerPolicy": "on_condition_reenter"
  }
}
```

- `when` 负责进入规则。
- `until` 负责退出规则。
- `minActiveTicks` 防止刚进入就退出。
- `cooldownTicks` 防止刚退出就重新进入。

保持距离、低血撤退、危险区域、保护队友和目标重选必须复用统一机制，禁止各 Recipe 私自实现防抖状态。

### 8.12 Fallback 语义

fallback 只能是一个基础 action 或一个受限制的 Rule 引用。首版最多包含两个执行节点：Primary 和一个显式 Fallback，Default AI 是固定终点：

```text
Primary
  -> failed
Fallback
  -> failed
Default AI
```

- fallback 不得拥有新的 fallback 链。
- fallback 不得形成循环。
- fallback 成功后何时回到主规则由主规则 recoveryPolicy 决定。
- selector 暂时无结果与永久不可执行必须使用不同 reason code。

### 8.13 受限记忆与阶段

第一阶段只允许以下记忆值：

- boolean
- integer/float（有限范围）
- entity ID
- area ID
- tick
- Registry enum

LLM 可以表达“第一次、之后、完成后、等待若干秒”等关系，但不得自由编写状态机。需要阶段的复合意图由 Compiler 生成受限 `phaseMachine`：

```json
{
  "id": "ambush_flow",
  "initial": "approach",
  "states": ["approach", "waiting", "attack", "retreat"],
  "transitions": []
}
```

必须限制每份策略的 phaseMachine 数量、每个状态机的状态数和转换数，禁止递归、动态状态和任意代码。通用 phaseMachine 延后到 Milestone 2 之后实现。

### 8.14 默认 AI

未被玩家规则覆盖的通道继续使用默认 AI。默认 AI 以 `IDLE` 类别规则存在，不得散落为单位代码中的不可审计特殊分支。

## 9. 典型策略编译示例

玩家输入：

> 3号开局30秒原地不动，但可以攻击进入射程的敌人。30秒后进入最近草丛。敌人距离低于攻击距离的70%时后退。

预期编译结果：

1. locomotion 规则：`elapsed_time < 30` 时 `hold_position`，类别 `IDLE`。
2. targeting 默认规则：选择射程内最近可见敌人，类别 `COMBAT`。
3. combat 默认规则：目标合法且可攻击时 `basic_attack`，类别 `COMBAT`。
4. locomotion 规则：`elapsed_time >= 30 && !is_in_bush` 时前往最近可达草丛，类别 `TACTICAL_MOVE`。
5. locomotion 规则：敌人距离 `< attack_range * 0.7` 时 `move_away_from`，类别 `COMBAT_POSITIONING`。
6. 后退 until：距离 `>= attack_range * 0.85`。
7. 后退结束后继续之前锁定的草丛目标，除非草丛不可达。

系统实际执行描述必须明确：

> 3号在开局前30秒不主动移动，但仍会攻击进入射程的可见敌人。30秒后，3号前往最近且可达的草丛。若可见敌人距离低于攻击距离的70%，3号会暂时中断进草并后退，直到距离恢复到攻击距离的85%；之后继续执行进草规则。

## 10. 弹道挡线的实现边界

第三阶段支持玩家表达：

> 如果2号被攻击，3号挡在敌人和2号中间。

不得生成含糊 opcode `protect`。编译器应展开为：

1. selector：选择 `intended_attack_target_id == hero_instance_2` 的敌人。
2. sort：按威胁等级和到2号距离稳定排序。
3. position function：计算 `line_block_position(attacker, protected, blocker)`。
4. path check：选择最近可达的合法挡线点。
5. locomotion action：`move_to_position`。
6. until：敌人不再瞄准2号、任一相关单位死亡或威胁失效。
7. replan：攻击者、2号或3号显著移动时重算位置。
8. fallback：无法到达挡线点时移动到2号附近。

ProjectileEngine 必须提供真实的首碰撞结果，ReplayRecorder 记录：

- intended target。
- actual hit target。
- first hit object。
- 是否被障碍物或其他敌方单位阻挡。

## 11. API 设计

### 11.1 编译策略

`POST /strategy/v3/compile`

请求：

```json
{
  "snapshotId": "snapshot_123",
  "strategyName": "弓箭手草丛战术",
  "messages": [
    {"id": "m1", "text": "3号开局30秒原地不动，但可以攻击。"},
    {"id": "m2", "text": "30秒后进入最近草丛。"}
  ]
}
```

成功响应：

```json
{
  "ok": true,
  "compileId": "compile_789",
  "snapshotHash": "sha256:...",
  "planHash": "sha256:...",
  "metadataVersion": "strategy-metadata-3.0.0",
  "compilerVersion": "strategy-compiler-3.0.0",
  "expiresAt": "2026-08-18T12:00:00Z",
  "status": "accepted",
  "originalText": "...",
  "renderedText": "...",
  "intentResults": [
    {
      "intentIndex": 1,
      "sourceMessageIds": ["m1"],
      "status": "accepted",
      "notes": []
    }
  ],
  "unitSummaries": {
    "3": "开局30秒不主动移动，之后进入最近可达草丛"
  },
  "warnings": [],
  "requiresConfirmation": true
}
```

部分成功响应仍使用 HTTP 200，`status` 为 `partial`。只有请求、认证、服务或完全无法生成任何可执行结果时才返回错误状态。

服务器必须把 `compileId` 保存为不可变编译记录，并强绑定：

```text
userId
snapshotId + snapshotHash
planHash
metadataVersion
compilerVersion
createdAt + expiresAt
compileStatus
```

记录一旦进入 `ready` 状态，不允许原地修改 Runtime Plan；策略修改必须生成新的 compileId。

### 11.2 确认并模拟

`POST /strategy/v3/confirm-and-simulate`

```json
{
  "compileId": "compile_789",
  "confirmed": true,
  "battleRequestId": "battle_request_456",
  "mode": "ranked",
  "snapshotHash": "sha256:...",
  "planHash": "sha256:..."
}
```

该接口不得再次调用 LLM。服务器读取已保存的 Runtime Plan 和快照，模拟并返回 replay ID 或完整回放。

确认时必须重新验证：

- 当前用户等于 compile 绑定用户。
- compile 未过期且状态为 `ready`。
- 当前 snapshotHash 等于 compile.snapshotHash。
- 存储的规范化 Runtime Plan Hash 等于 compile.planHash。
- metadataVersion 和 compilerVersion 可用。

Seed 权限：

- `ranked|reward|official_pvp`：客户端禁止提交 seed。`battleRequestId` 由匹配/挑战服务签发，服务器在首次抢占请求时生成并冻结 seed，可使用安全随机数或 `HMAC(serverSecret, battleRequestId + compileId)`。
- `practice|developer`：允许可选 `practiceSeed`，但结果不得产生正式奖励、排位或不可撤销战绩。
- `mode`、奖励资格和对手信息必须由服务器根据 battleRequestId 判定，不得信任客户端字符串。

该接口必须支持并发幂等。数据库表为幂等记录提供 `UNIQUE(user_id, battle_request_id)`，状态固定为：

```text
PENDING
RUNNING
COMPLETED
FAILED_RETRYABLE
FAILED_FINAL
```

处理规则：

1. 请求先以数据库唯一约束原子抢占记录，再开始模拟，禁止“先查询、后创建”。
2. `RUNNING` 重复请求返回当前任务状态，不启动第二次模拟。
3. `COMPLETED` 重复请求返回原 battle ID、结果和回放。
4. 网络、进程和存储等基础设施失败进入 `FAILED_RETRYABLE`，同一 battleRequestId 可恢复重试且 seed 不变。
5. Runtime Plan 非法、确定性契约失败等进入 `FAILED_FINAL`，重复请求返回相同失败。
6. 正式战斗不得通过更换客户端 seed 产生新的结果。

### 11.3 查询编译结果

`GET /strategy/v3/compiles/{compileId}`

用于移动端重连和异步处理。不得要求用户因为页面切换重新调用 LLM。

## 12. LLM 调用策略

正常提交最多调用一次 LLM：

```text
完整玩家策略 -> 一次 Intent IR 请求
```

以下阶段调用次数均为 0：

- Runtime 编译。
- Runtime 校验。
- 实际执行描述生成。
- 玩家确认。
- 战斗模拟。
- 回放生成。

仅在 LLM 返回内容完全无法解析时允许一次修复调用。禁止无限重试。

优先顺序：

1. 完整请求缓存命中：0 次。
2. 确定性本地编译器完整覆盖：0 次。
3. 正常复杂策略：1 次。
4. JSON 完全无法解析：最多 2 次。

服务端必须记录 `source=cache|local|model`、尝试次数、耗时和失败阶段，不得记录密钥。

## 13. 错误与局部结果

### 13.1 编译结果状态

- `accepted`
- `partial`
- `rejected`
- `ambiguous`
- `unsupported`

### 13.2 错误分类

- `REQUEST_*`：请求问题。
- `UPSTREAM_*`：LLM 超时或服务问题。
- `INTENT_*`：Intent IR 格式问题。
- `BINDING_*`：英雄、技能、区域引用问题。
- `CAPABILITY_*`：能力不支持。
- `CONFLICT_*`：规则冲突。
- `DEPENDENCY_*`：Intent 依赖、原子组或阶段关系问题。
- `ARBITRATION_*`：动作资源冲突、动作锁或抢占问题。
- `BATTLE_REQUEST_*`：Seed权限、幂等状态或正式战斗请求问题。
- `RUNTIME_PLAN_*`：最终规则不合法。
- `SIMULATION_*`：模拟器问题。

前端必须区分：

- “AI理解服务超时”。
- “策略有一部分无法执行”。
- “策略存在歧义”。
- “策略已编译，但模拟器暂时不可用”。
- “战斗行为违反运行时契约”。

不得统一显示“队员没听清”。

### 13.3 上次有效策略

- 编译失败时保留上次有效 Runtime Plan。
- 新计划只有在严格校验通过后才替换旧计划。
- 模拟器基础设施失败不得删除已编译策略。
- 行为契约验收失败应显示具体规则和观测事实，不得要求玩家盲目改写自然语言。

## 14. 系统实际执行描述

Renderer 必须覆盖：

- actor。
- trigger。
- target selection。
- action。
- until。
- fallback。
- 默认阈值。
- 可能打断该动作的高优先级行为。

模板示例：

```text
{actor}在{trigger}时{action}，直到{until}。
如果{failure_condition}，则{fallback}。
{default_interpretation_note}
```

Renderer 输出应有快照测试，任何 Runtime Plan 字段变更都要同步更新 Renderer 或明确无需展示。

Renderer 是安全契约，不只是 UI 文案。Registry 中每个会影响玩家可观察行为的字段必须声明：

```json
{
  "field": "execution.retriggerPolicy",
  "explainability": {
    "required": true,
    "rendererKey": "retrigger_policy"
  }
}
```

- 开发和 CI：required 字段没有 Renderer 覆盖时，测试必须失败。
- 生产：若编译器生成未覆盖的 required 字段，视为内部错误，保留上次有效策略并上报告警。
- 不得把 Renderer 覆盖缺失显示成“玩家策略不合法”。
- 所有默认阈值、恢复策略、fallback 和显著打断关系都必须可解释。

## 15. 回放与复盘

Replay 至少记录：

- 单位出生、移动、攻击、施法、伤害、治疗、状态、死亡和胜负。
- 关键规则启用、结束和被打断事件。
- 目标选择变化及原因。
- fallback 触发原因。
- 路径失败。
- 进入和离开区域。

策略复盘信息不需要记录每个 Tick 的全部条件计算，只记录关键变化：

```json
{
  "tick": 680,
  "type": "strategy_rule_switched",
  "unitId": "hero_instance_3",
  "fromRuleId": "r_enter_bush",
  "toRuleId": "r_keep_distance",
  "reason": "higher_priority_rule_became_true"
}
```

## 16. 安全、确定性与性能

### 16.1 安全

- 玩家文本是数据，不得进入系统提示词规则区。
- 所有 AST 和 opcode 使用白名单。
- 禁止 `eval`、动态脚本和任意字段路径。
- 限制消息数量、单条长度、intent 数量、规则数量和 AST 深度。
- selector 的 limit 必须有上限。

### 16.2 确定性

- 严格遵守第 8 节 Runtime Semantics Contract 中的确定性约束。
- 使用固定 Tick 和固定阶段顺序。
- 同分 selector、事件、伤害、碰撞和路径候选使用稳定 tie-breaker。
- 随机行为使用战斗种子派生的命名 RNG 流。
- 禁止依赖系统时间。
- Plan 序列化顺序固定。
- 战斗快照冻结。

### 16.3 性能

- 物理 Tick 与策略决策 Tick 分离。
- selector 可按存活队伍、可见集合和区域索引预过滤。
- 条件 AST 编译成内部节点，不在每 Tick 解析 JSON。
- 事件驱动规则只在相关事件发生时重算。
- 设定每单位最大规则数和每次决策最大 selector 扫描量。

### 16.4 版本化资源上限

Milestone 0 使用以下首版默认值，集中存放在版本化配置中，禁止散落硬编码；后续只能依据压测和产品规则调整：

| 配置 | 首版默认值 |
|---|---:|
| `maxMessages` | 30 |
| `maxMessageChars` | 500 |
| `maxIntentCount` | 60 |
| `maxRulesPerUnit` | 40 |
| `maxAstNodesPerRule` | 128 |
| `maxAstDepth` | 12 |
| `maxSelectorCandidates` | 128 |
| `maxPhaseMachines` | 8 |
| `maxStatesPerMachine` | 16 |
| `maxTransitionsPerMachine` | 32 |
| `maxPathFailures` | 5 |
| `maxBattleTicks` | 10800 |
| `maxSimulationWallSeconds` | 15 |

在 60 Hz 下 `maxBattleTicks=10800` 等于180秒。达到游戏 Tick 上限是合法游戏结果 `TIME_LIMIT_DRAW`；超过服务器计算墙钟上限是基础设施错误 `SIMULATION_TIMEOUT`，不得生成正式胜负或奖励。

### 16.5 Determinism Torture Test

Milestone 0.5 必须使用独立 Godot headless 进程重复运行压力场景，比较 canonical normalizedEventHash。场景至少包含：

- 5个英雄和大量障碍物。
- 同距离 selector。
- 同 Tick 伤害和死亡。
- 同位置碰撞和等价路径。
- 路径重规划。
- 多条规则争夺 MOVE。
- 多条规则写同一 Target Role。
- 命名 RNG 随机目标。
- 运行到 maxBattleTicks。

执行层级：

- PR CI：每个核心夹具独立进程运行5～10次。
- Nightly：代表性夹具独立进程运行100次。
- Release：多地图、多阵容、多seed分别运行100次。

如果 Hash 不稳定，必须修复 BattleEngine 或 Runtime；禁止仅对回放事件重新排序来掩盖实际模拟差异。

## 17. Strategy 2.0 迁移策略

不得直接在现有 Strategy 2.0 Schema 上无限追加字段。实施方式：

1. 保留 `StrategyRules` 和 `StrategyRuntime` 2.0。
2. 新建独立 Strategy 3.0 编译器、校验器和运行时。
3. 战斗快照声明 `strategySchemaVersion`。
4. 历史 2.0 策略继续使用旧运行时。
5. 新策略默认使用 3.0。
6. 可为有限的 2.0 action 编写确定性迁移器，但迁移后必须重新展示实际执行描述并由玩家确认。

当前可复用能力：

- 后台 HTTP 服务框架。
- 策略缓存。
- 上次有效策略回退。
- Godot headless 模拟和回放。
- 当前动作通道概念。
- 战斗种子和模拟审计。

不应原样复用：

- 固定五人校验。
- 写死兵种能力的枚举。
- 由模型生成最终完整 Strategy JSON。
- 全文档一处错误即全部失败。
- 单随机种子行为契约失败即认定玩家策略非法。

## 18. 推荐代码组织

Python 服务端建议：

```text
server/strategy_v3/
  metadata.py
  schemas.py
  prompt_builder.py
  intent_validator.py
  dependency_resolver.py
  compiler.py
  recipes.py
  runtime_validator.py
  canonical_json.py
  text_renderer.py
  compile_store.py
  battle_request_store.py
  idempotency.py
  errors.py
```

Godot 建议：

```text
scripts/strategy_v3/
  strategy_runtime_v3.gd
  condition_evaluator.gd
  selector_engine.gd
  rule_arbiter.gd
  action_resource_arbiter.gd
  rule_state_machine.gd
  target_roles.gd
  interrupt_matrix.gd
  deterministic_event_queue.gd
  action_state.gd
  strategy_memory.gd
```

测试建议：

```text
tests/strategy_v3/
  test_intent_validator.py
  test_dependency_resolver.py
  test_compiler.py
  test_recipes.py
  test_runtime_validator.py
  test_canonical_json.py
  test_text_renderer.py
  test_compile_idempotency.py
  test_resource_limits.py
  runtime_semantics_test.gd
  deterministic_replay_test.gd
  strategy_runtime_v3_test.gd
  strategy_v3_full_playtest.gd
```

## 19. 分阶段开发计划

### Milestone 0：契约和脚手架

实现：

- StrategyMetadataRegistry。
- Intent IR Schema。
- Runtime Plan Schema。
- Canonical JSON、planHash 测试向量和唯一服务器实现。
- 版本化资源上限配置。
- 统一错误对象。
- 空 Compiler、Validator、Renderer 模块。
- 不可变 compile store 和 battle request 幂等状态表。
- Strategy 2.0/3.0 路由分流。

验收：

- Schema 有独立单元测试。
- 相同 Runtime Plan 序列化结果稳定。
- `1|1.0`、`-0.0|0`、Unicode等Canonical测试向量稳定。
- 数据库唯一约束可以阻止并发创建重复battle request。
- 2.0 现有测试不回归。

### Milestone 0.5：Runtime Semantics Contract

在实现任何大规模 Recipe 前完成：

- 固定 Tick 阶段顺序。
- 稳定事件、伤害、碰撞和 selector 排序。
- 命名 RNG 流。
- Rule 状态机。
- `never|on_condition_reenter` 重触发策略。
- `resume|restart|cancel` 恢复语义。
- Command 生命周期和次 Tick 事件延迟。
- Channel Arbitration 后的 Action Resource Arbitration。
- Action Lock / Interrupt Matrix。
- Priority Class 和稳定仲裁键。
- Specificity Class。
- 语义目标角色的所有权、generation 和释放策略。
- 复用 `when/until` 的统一 hysteresis。
- fallback 最大深度和恢复规则。
- acceptance dependency、runtime prerequisite 和全有全无 atomic group。
- 正式战斗服务器 Seed、练习战斗可选 Seed。
- compile 不可变绑定和并发模拟幂等状态机。
- Explainability Coverage 检查。

验收：

- 使用纯规则夹具覆盖每个合法状态转换和非法转换。
- 覆盖高优先级可打断、不可打断和延后执行三种情况。
- survival 与 locomotion 同时申请 MOVE 时只提交一个动作。
- 需要多个资源的技能只能全部获得或全部失败。
- 进入阈值附近反复波动时不发生规则抖动。
- `never` 不重新触发，`on_condition_reenter` 必须观察 false -> true 后重触发。
- 被打断的进草规则按 `resume` 恢复原目标，按 `restart` 重新选目标。
- 编译依赖失败会拒绝后续 intent；运行时前置只阻止提前 ACTIVE；独立 intent 仍可成功。
- Atomic Group 任意成员失败时整组拒绝。
- Tick 后半段事件只在下一 Tick Replan 生效，不发生阶段回跳。
- 正式模式客户端提交 Seed 被拒绝，练习模式 Seed 不产生正式结果。
- 同一模拟夹具运行多次得到相同规范化事件 Hash。
- 同一 `userId + battleRequestId` 的并发请求只产生一次模拟结果。

### Milestone 0.75：当前弹道系统改造（P0）

本阶段不是后续增强项，必须在依赖真实命中结果的 Strategy 3.0 战斗 Recipe 前完成。它只解决“攻击如何飞行和命中”，暂不实现英雄主动寻找挡线位置。

必须支持：

- 普通攻击生成独立弹道实体，不再把伤害直接绑定到发射时选定的目标。
- 发射时记录 `sourceUnitId`、`intendedTargetId`、发射位置、方向、速度、半径、最大距离和生成 Tick。
- 弹道按固定 Tick 推进，并使用 swept shape/raycast 等连续检测方式，避免高速弹道穿透。
- 障碍物可以阻挡普通攻击弹道；当前地图中只有被配置为 `blocks_projectile=true` 的对象参与检测。
- 敌方单位阻挡弹道并成为 `actualHitTargetId`；己方单位默认不阻挡己方弹道。
- 同一步进内命中多个候选对象时，先按沿弹道的命中时间/距离排序，再按碰撞类型和稳定实体 ID 决胜，禁止依赖 Godot 返回顺序。
- 弹道命中第一个合法对象、到达最大距离或超时后立即销毁，并且伤害只结算一次。
- 回放记录 `projectile_spawned`、`projectile_moved`（或可重建轨迹数据）、`projectile_blocked`、`projectile_hit` 和 `projectile_expired`。
- 命中事件同时保留 `intendedTargetId` 与 `actualHitTargetId`，为后续“谁在替谁挡弹道”查询提供事实数据。

基础普通攻击配置：

```json
{
  "requiresVisibleTarget": true,
  "requiresRange": true,
  "blockedByObstacle": true,
  "blockedByEnemyUnit": true,
  "blockedByAllyUnit": false,
  "hitFirstEnemyUnit": true,
  "pierceEnemyUnit": false
}
```

必须验收：

- 敌人 A 瞄准我方2号，若我方3号先进入弹道路径，`intendedTargetId=2号`、`actualHitTargetId=3号`。
- 我方2号攻击敌人时，我方3号站在二者之间不会阻挡该弹道。
- 可阻挡弹道的障碍物先被命中时，英雄不受伤。
- 目标在弹道飞行期间移动时，按真实轨迹和碰撞结果判定，不自动追踪并必中原目标。
- 相同快照、输入、Seed 和引擎构建重复运行得到相同命中事件 Hash。
- 现有弓箭视觉表现改为消费真实弹道/回放事件，不得保留一套与伤害判定分离的“假箭”。

### Milestone 1：最小可执行闭环

支持：

- 2–5 人快照。
- 按槽位绑定 actor。
- 时间、血量、距离条件。
- `hold_position`、`move_to_position`、`follow`、`set_target`、`basic_attack`。
- priority class、until、fallback。
- 按通道和动作资源两层仲裁。
- 确定性 Renderer。

验收策略：

> 3号开局10秒不主动移动，但可以攻击；10秒后跟随2号。

必须验证：

- 前10秒3号不主动移动。
- 射程内存在敌人时仍可攻击。
- 10秒后切换到跟随。
- 2号死亡时触发 fallback。
- 全过程只有一次或零次 LLM 调用。

### Milestone 2：区域、视野和相对站位

支持：

- 草丛和区域 selector。
- 可见敌人集合。
- 最近可达区域。
- `move_to_area`、`move_to_range`、`move_away_from`。
- 目标角色所有权、锁定和防抖。

验收策略：

> 3号30秒后进入最近草丛，敌人靠近时后退保持攻击距离。

此 Milestone 属于未来地图能力。当前版本的正式快照对此策略必须返回 partial/rejected，并明确显示“当前地图没有可执行的目标区域”；不得在当前地图生成隐藏草丛。未来地图夹具显式启用 `bush` 后，再执行本节的移动、隐藏、同草丛视野和恢复目标验收。

### Milestone 2.5：事件、记忆和受限阶段

支持：

- 第一次受到攻击、单位死亡、进入区域、攻击完成等事件条件。
- 最近攻击者、最后看见位置、阶段开始 Tick 等受限记忆。
- Compiler 生成的有限 phaseMachine。
- “之后、完成后、等待若干秒、第一次”等先后关系。
- Acceptance dependency、runtime prerequisite 和 atomic group 在动态阶段中的失效传播。

验收策略：

> 3号进入草丛后等待3秒，再攻击最近敌人；完成一次攻击后立刻后退。

必须验证进入草丛失败时，等待和伏击阶段不会脱离依赖单独执行。

### Milestone 3 前置条件

Milestone 0.75 的实体弹道、静态首碰撞和移动单位真实拦截必须已经完成并通过确定性测试。Milestone 3 不得再实现另一套弹道判定，只能消费同一 ProjectileEngine 暴露的命中事实和查询接口。

### Milestone 3C：静态主动挡线

实现 `line_block_position(attacker, protected, blocker)` 位置函数。策略可以让3号对当前静止攻击者和2号计算可达挡线点并移动。

### Milestone 3D：持续重规划挡线

攻击者、保护目标或挡线者移动超过阈值时持续重算挡线位置；多攻击者按稳定威胁排序选择。必须使用目标角色、hysteresis 和 replan interval 防止抖动。

### Milestone 3E：时间预测挡线

把弹丸速度、攻击前摇、单位移动速度和预计相交时间纳入挡线点计算。该阶段属于增强能力，不是3A～3C基础弹道正确性的前置条件。

Milestone 3C～3E 的共同验收策略：

> 如果2号被攻击，3号移动到敌人和2号之间挡住弹道。

### Milestone 4：技能、策略包和分享

支持：

- 技能选择和施放。
- 策略包持久化。
- 分享码。
- 版本兼容检查和导入预览。

## 20. 测试要求

### 20.1 编译器单元测试

- 每个 recipe 至少一个成功、一个局部拒绝、一个默认值测试。
- 相同输入多次编译的 Plan 和 hash 完全一致。
- 不存在 actor、技能、区域时只拒绝相关 intent。
- 后消息覆盖同类前消息。
- 自跟随和 fallback 循环被拒绝。
- Intent 依赖循环被拒绝。
- `require_all|require_any|optional` 的编译接受结果正确。
- runtime prerequisite 不被错误当成编译拒绝。
- 同一 atomic group 全有全无，组外独立 intent 不受影响。
- AST 类型不匹配被拒绝。

### 20.2 Renderer 测试

- 每个 opcode 和默认解释具有快照测试。
- 文本包含默认阈值、until 和 fallback。
- rejected intent 的原因可读。
- Registry 中每个 required explainability 字段都有 Renderer 覆盖。
- 未覆盖 required 字段在 CI 中必须使测试失败。

### 20.3 Godot 运行时测试

- 通道独立：hold movement 不影响 combat。
- 高优先级生存行为打断普通移动。
- 高优先级结束后恢复低优先级行为。
- Rule 每个状态和状态转换都有测试。
- `resume|restart|cancel` 行为符合第 8 节定义。
- Interrupt Matrix 的允许、拒绝和延后三种结果都有测试。
- 不同 Channel 争夺同一资源时只产生一个 Action Commit。
- 多资源 action bundle 原子获得或原子失败。
- Tick N 后半段事件只在 Tick N+1 的 Replan 生效。
- Active Action 在 Tick 间连续推进且不重复应用 command。
- 目标角色锁定期间不抖动。
- 目标角色 ownership、generation 和 releasePolicy 正确。
- enter/exit threshold 附近波动时不抖动。
- `never|on_condition_reenter` 重触发语义正确。
- 目标死亡立即重选或 fallback。
- fallback 超过最大深度时进入默认 AI。
- 固定服务器构建、快照、Plan 和种子的规范化事件 Hash 可复现。

### 20.4 端到端测试

至少覆盖：

1. 本地编译 0 次模型调用。
2. 正常模型编译 1 次调用。
3. 模型完全无效时最多重试 1 次。
4. 一条合法、一条非法时返回 partial。
5. 编译成功后确认和模拟不再调用模型。
6. 前端展示的执行描述与 Runtime Plan 一致。
7. 移动端重连不重复编译。
8. 相同 `userId + battleRequestId` 的并发和重复请求返回同一 battle ID 和回放。
9. 快照或 Plan Hash 变化后 confirm 被拒绝。
10. 编译预览与实际模拟绑定同一不可变 Runtime Plan。
11. 正式模式拒绝客户端seed，练习模式结果不写正式奖励和战绩。
12. `TIME_LIMIT_DRAW` 与 `SIMULATION_TIMEOUT` 被正确区分。

## 21. Codex 实施规则

Codex 开发本方案时必须遵守：

1. 一次只实施一个 Milestone，先测试再进入下一阶段。
2. 不为通过示例而在 Runtime 中写死完整战术句子。
3. 新字段先加入 Registry 和 Schema，再进入编译器和运行时。
4. 不使用任意字符串表达式或 `eval`。
5. 不修改 Strategy 2.0 行为来伪装完成 3.0。
6. 所有默认解释必须进入 Renderer。
7. 所有局部错误必须保留 sourceMessageIds。
8. 每个规则切换必须有稳定、可回放的 reason code。
9. 所有选择器必须有稳定 tie-breaker。
10. 所有 Rule 状态变化必须通过统一状态机，禁止 Recipe 直接修改状态。
11. Channel winner 必须经过 Action Resource Arbiter 后才能 Commit。
12. 所有动作打断必须通过统一 Interrupt Matrix。
13. 所有阈值防抖必须通过 `when/until` 和统一 hysteresis 状态实现。
14. 正式战斗 Seed 只能由服务器生成并冻结。
15. Renderer 覆盖是 CI 强制契约，缺失不能以玩家错误呈现。
16. Milestone 0.5 未完成前不得批量实现 Recipe。
17. Milestone 0.75 完成前，不得实现任何依赖 `actualHitTargetId`、弹道拦截或主动挡线的 Recipe。
18. 完成每个阶段后运行 Python 单元测试、Godot headless 测试和至少一个完整模拟。

## 22. 完成定义

Strategy 3.0 核心完成需同时满足：

- 玩家完整策略正常只调用一次 LLM。
- LLM 只输出 Intent IR。
- 服务器可确定性编译 Runtime Plan。
- 单条 intent 失败不影响其他合法 intent。
- 有依赖或同一 atomic group 的 intent 按组合语义接受或拒绝。
- 编译接受依赖和运行时前置条件具有不同、可测试的语义。
- Runtime Plan 能生成准确的系统执行描述。
- 战斗运行时按 Rule 状态机、重触发策略、Channel、Action Resource、Priority Class、until、hysteresis、Interrupt Matrix 和 fallback 执行。
- 战斗过程中不调用 LLM。
- 同服务器构建、快照、Plan、种子和版本可以复现规范化事件流。
- compile 预览、确认和模拟通过 snapshotHash 与 planHash 不可变绑定。
- 相同幂等键不会重复模拟或生成不同回放。
- 正式战斗不能通过客户端更换 Seed 刷结果。
- Canonical Plan、规范化事件流和资源上限都有固定契约与测试。
- 当前普通攻击已经使用唯一的实体弹道伤害判定，能够稳定区分 intended target 与 actual hit target。
- 前端只播放后台回放。
- 当前地图中，跟随后排和弹道挡线按对应 Milestone 的验收标准通过；等待进草必须稳定返回可读的局部拒绝，且不影响同策略中的独立合法意图。
- 未来草丛能力夹具显式启用 `bush` 后，等待进草、隐藏、同草丛视野和被打断后恢复原区域目标通过对应 Milestone 验收；该夹具不得改变当前生产地图能力。

---

本方案的最终原则是：玩家负责提出战术，大模型负责拆解意图，服务器负责把意图编译为合法且明确的规则，战斗引擎负责持续观察战场并确定性执行。任何无法解释、无法校验或无法复现的行为，都不得进入 Runtime Plan。
