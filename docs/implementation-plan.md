# 军训训练平台 — 详细实施计划

_基于架构决策文档 (architecture.md)，适配 Ruoyi-FastAPI 项目结构_

---

## 一、项目现状与架构适配

### 1.1 现有项目结构

```
military_train/
├── military-train-backend/       # FastAPI 后端 (Python)
│   ├── module_admin/            # 系统管理模块 (用户/角色/菜单/部门/字典)
│   ├── module_military/         # 军训模块 (仅有示例 student)
│   ├── module_ai/               # AI 模块
│   ├── module_generator/        # 代码生成器
│   ├── module_task/             # 定时任务模块
│   ├── common/                  # 公共组件 (router/annotation/aspect/vo/enums)
│   ├── config/                  # 配置 (database/env)
│   ├── middlewares/             # 中间件
│   ├── exceptions/              # 异常处理
│   ├── utils/                   # 工具类
│   └── alembic/                 # 数据库迁移
├── military-train-frontend/      # Vue 3 前端 (Element Plus)
│   └── src/
│       ├── api/                 # API 调用层
│       ├── views/               # 页面组件
│       ├── router/              # 路由配置
│       └── store/               # Pinia 状态管理
└── military-train-test/          # 测试
```

### 1.2 架构文档 vs Ruoyi 的适配策略

| 架构文档设计 | Ruoyi 适配方案 |
|---|---|
| monorepo `apps/api + apps/admin + apps/weapp + apps/cli` | **保留现有 Ruoyi 结构**，后端在 `module_military/` 下按子域拆分 |
| PostgreSQL + UUID 主键 | **保留 Ruoyi 的 MySQL/PostgreSQL 双兼容**，主键沿用 `BigInteger` 自增 |
| `packages/frontend-sdk` 共享类型 | **前端直接在 `src/api/military/` 写 API 调用**，类型复刻后端 VO |
| `apps/weapp` 小程序 | **一期不开发**，后续作为独立 Taro 项目新建 |
| Worker 进程 + 事件驱动 | Worker 作为 `module_military/worker/` 子包，与 API 同仓独立进程 |
| `domain_events` 事务发件箱 | **一期不建 outbox 表**，Worker 直接通过 APScheduler 定时查询业务表 |

### 1.3 Ruoyi 模块化开发模式

每个后端子域遵循固定的五层结构：

```
module_military/
├── entity/
│   ├── do/   # SQLAlchemy Data Object (数据库表映射)
│   └── vo/   # Pydantic View Object (请求/响应模型)
├── dao/      # Data Access Object (数据库查询)
├── service/  # Business Logic (业务逻辑)
└── controller/  # API Router (接口路由，自动注册)
```

**关键规则：**
- Controller 文件放在 `module_military/controller/` 下自动注册路由
- DO 主键统一 `BigInteger, primary_key=True, autoincrement=True`
- VO 使用 `ConfigDict(alias_generator=to_camel)` 自动转驼峰
- 权限校验使用 `UserInterfaceAuthDependency('military:xxx:xxx')`，与 Ruoyi 菜单权限体系一致
- Service 使用 `@classmethod` + 类方法模式

---

## 二、整体实施路线 (8 个阶段)

```
阶段1: 组织与身份    ████████░░░░░░░░░░░░  基础数据，所有模块的前置依赖
阶段2: 角色体系      ░░░░░░░░████████░░░░  依赖阶段1 (person + org)
阶段3: 规则中心      ░░░░░░░░░░░░░░██████  依赖阶段1 (batch/venue)
阶段4: 工作流引擎    ░░░░░░░░░░░░░░░░░░░░  依赖阶段2 (角色) + 阶段3 (原因分类)
阶段5: 考勤与签到    ░░░░░░░░░░░░░░░░░░░░  依赖阶段3 (规则) + 阶段1
阶段6: 医疗考评预警  ░░░░░░░░░░░░░░░░░░░░  依赖阶段1/4/5
阶段7: 展板与待办    ░░░░░░░░░░░░░░░░░░░░  依赖全部业务模块
阶段8: 批量与审计    ░░░░░░░░░░░░░░░░░░░░  横切关注点
```

**每个阶段的交付物：**
- 后端：DO 模型 → Alembic migration → VO 模型 → DAO → Service → Controller
- 前端：API 封装 → 页面组件 → 路由配置 → 权限菜单
- 测试：Service 单测 → 集成测试

---

## 三、阶段 1：组织与身份模块 (预计 3-4 天)

### 3.1 数据模型

#### 3.1.1 `sys_academic_units` — 学院行政树

| 字段 | 类型 | 说明 |
|---|---|---|
| id | BigInteger PK | 主键 |
| parent_id | BigInteger | 上级单位 (NULL=顶级) |
| unit_type | VARCHAR(20) | school / college / major / class |
| name | VARCHAR(100) | 单位名称 |
| code | VARCHAR(50) | 编码 |
| sort_order | Integer | 同级排序 |
| is_active | Boolean | 是否启用 |
| create_by/update_by | VARCHAR(64) | 审计字段 |
| create_time/update_time | DateTime | 审计字段 |

**索引：** `(parent_id)` B-tree

#### 3.1.2 `sys_military_units` — 军训编制树

| 字段 | 类型 | 说明 |
|---|---|---|
| id | BigInteger PK | 主键 |
| training_batch_id | BigInteger FK | 所属批次 |
| parent_id | BigInteger | 上级单位 |
| unit_type | VARCHAR(20) | regiment / battalion / company / platoon |
| name | VARCHAR(100) | 单位名称 |
| code | VARCHAR(50) | 编码 |
| sort_order | Integer | 同级排序 |
| is_active | Boolean | 是否启用 |
| create_by/update_by | VARCHAR(64) | |
| create_time/update_time | DateTime | |

**索引：** `(training_batch_id, parent_id)` B-tree

#### 3.1.3 `sys_person_profiles` — 人员档案

| 字段 | 类型 | 说明 |
|---|---|---|
| id | BigInteger PK | 主键 |
| academic_unit_id | BigInteger FK | 行政归属 (班级级) |
| name | VARCHAR(50) | 姓名 |
| student_no | VARCHAR(30) | 学号 |
| employee_no | VARCHAR(30) | 工号 |
| gender | VARCHAR(5) | male/female |
| phone | VARCHAR(20) | 联系电话 |
| is_active | Boolean | 是否启用 |
| create_by/update_by | VARCHAR(64) | |
| create_time/update_time | DateTime | |

**索引：** `(academic_unit_id)`, `(student_no)`

> **说明：** `person_profile` 是系统核心身份实体，跨批次复用。同一个人在不同军训批次中可获得不同角色（如去年是学生、今年是小教员）。与 `user_accounts` 是 1:0..1 关系（允许先建档后激活账户）。

#### 3.1.4 `sys_military_assignments` — 军训编制分配

| 字段 | 类型 | 说明 |
|---|---|---|
| id | BigInteger PK | 主键 |
| person_id | BigInteger FK | FK → sys_person_profiles |
| military_unit_id | BigInteger FK | FK → sys_military_units (排级) |
| training_batch_id | BigInteger FK | FK → training_batches |
| assigned_at | DateTime | 分配时间 |
| removed_at | DateTime | NULL=当前有效 |
| assigned_by | BigInteger | 操作人 |

**唯一约束：** `(person_id, training_batch_id)` WHERE `removed_at IS NULL`

### 3.2 后端文件清单

```
module_military/
├── entity/
│   ├── do/
│   │   ├── academic_unit_do.py      # SysAcademicUnit
│   │   ├── military_unit_do.py      # SysMilitaryUnit
│   │   ├── person_profile_do.py     # SysPersonProfile
│   │   └── military_assignment_do.py  # SysMilitaryAssignment
│   └── vo/
│       ├── academic_unit_vo.py      # AcademicUnitModel / TreeModel / QueryModel
│       ├── military_unit_vo.py      # MilitaryUnitModel / TreeModel / QueryModel
│       ├── person_profile_vo.py     # PersonProfileModel / PageQueryModel / DeleteModel
│       └── military_assignment_vo.py  # MilitaryAssignmentModel / BatchAssignModel
├── dao/
│   ├── academic_unit_dao.py
│   ├── military_unit_dao.py
│   ├── person_profile_dao.py
│   └── military_assignment_dao.py
├── service/
│   ├── academic_unit_service.py
│   ├── military_unit_service.py
│   ├── person_profile_service.py
│   └── military_assignment_service.py
└── controller/
    ├── academic_unit_controller.py      # /military/academic-units
    ├── military_unit_controller.py      # /military/military-units
    ├── person_profile_controller.py     # /military/person-profiles
    └── military_assignment_controller.py  # /military/assignments
```

### 3.3 前端文件清单

```
src/
├── api/military/
│   ├── academicUnit.js
│   ├── militaryUnit.js
│   ├── personProfile.js
│   └── militaryAssignment.js
└── views/military/
    ├── academic_unit/
    │   └── index.vue          # 学院树管理 (左侧树 + 右侧表格)
    ├── military_unit/
    │   └── index.vue          # 军训编制树管理 (按批次切换)
    ├── person_profile/
    │   └── index.vue          # 人员档案列表 + 导入
    └── military_assignment/
        └── index.vue          # 编制分配 (拖拽或下拉选择)
```

### 3.4 权限标识清单

```
military:academic_unit:list     # 学院树查看
military:academic_unit:add      # 学院节点新增
military:academic_unit:edit     # 学院节点编辑
military:academic_unit:remove   # 学院节点删除
military:military_unit:list     # 军训编制查看
military:military_unit:add      # 军训编制新增
military:military_unit:edit     # 军训编制编辑
military:military_unit:remove   # 军训编制删除
military:person_profile:list    # 人员列表查看
military:person_profile:add     # 人员新增
military:person_profile:edit    # 人员编辑
military:person_profile:remove  # 人员删除
military:person_profile:query   # 人员详情
military:person_profile:export  # 人员导出
military:assignment:list        # 编制分配查看
military:assignment:edit        # 编制分配修改
```

### 3.5 Alembic Migration

创建一个 migration 文件，包含 4 张新表的建表语句：

```bash
# 在 military-train-backend 目录执行:
alembic revision -m "add_organization_and_people_tables"
```

---

## 四、阶段 2：角色体系 (预计 2-3 天)

### 4.1 数据模型

#### 4.1.1 `sys_role_categories` — 角色类别

| 字段 | 类型 | 说明 |
|---|---|---|
| id | BigInteger PK | 主键 |
| name | VARCHAR(50) | 分类名称 |
| code | VARCHAR(50) UNIQUE | 分类编码 |
| sort_order | Integer | 排序 |

#### 4.1.2 `sys_role_definitions` — 角色定义

| 字段 | 类型 | 说明 |
|---|---|---|
| id | BigInteger PK | 主键 |
| role_category_id | BigInteger FK | 所属类别 |
| name | VARCHAR(50) | 角色名称 |
| code | VARCHAR(50) UNIQUE | 角色编码 |
| description | TEXT | 角色说明 |
| is_system | Boolean | 是否系统内置 |
| is_active | Boolean | 是否启用 |
| version | Integer | 乐观锁版本号 |

#### 4.1.3 `sys_role_assignments` — 角色授权

| 字段 | 类型 | 说明 |
|---|---|---|
| id | BigInteger PK | 主键 |
| person_id | BigInteger FK | FK → sys_person_profiles |
| role_definition_id | BigInteger FK | FK → sys_role_definitions |
| scope_type | VARCHAR(20) | global / academic / military |
| academic_unit_id | BigInteger FK | scope=academic 时必填 |
| military_unit_id | BigInteger FK | scope=military 时必填 |
| training_batch_id | BigInteger FK | 批次绑定 |
| scope_depth | VARCHAR(20) | self / children / subtree |
| is_active | Boolean | 是否生效 |
| granted_at | DateTime | 授权时间 |
| revoked_at | DateTime | 撤销时间 |
| granted_by | BigInteger | 授权人 |

#### 4.1.4 `sys_role_status_tags` — 角色状态标签

| 字段 | 类型 | 说明 |
|---|---|---|
| id | BigInteger PK | 主键 |
| role_assignment_id | BigInteger FK | FK → sys_role_assignments |
| tag_key | VARCHAR(50) | 标签键 |
| tag_value | VARCHAR(50) | 标签值 |
| effective_from | DateTime | 生效开始 |
| effective_until | DateTime | 生效结束 (NULL=持续) |

### 4.2 核心业务逻辑

**角色授予流程：**
```
1. 选择一个 person_profile
2. 选择角色定义 (role_definition) 如 "辅导员"
3. 设定组织范围 (scope_type + scope_depth) 如 "计算机学院, subtree"
4. 绑定批次 (training_batch_id)
5. 保存 role_assignment
6. 递增 user_account.security_version → 触发已有 session 重新登录
```

**数据范围查询逻辑：**
```python
# scope resolver 统一入口 (organization 模块提供)
def resolve_scope_person_ids(assignment: RoleAssignment) -> List[int]:
    if assignment.scope_type == "global":
        return ALL_PERSON_IDS
    elif assignment.scope_type == "academic":
        return get_subtree_person_ids(assignment.academic_unit_id, assignment.scope_depth)
    elif assignment.scope_type == "military":
        return get_subtree_person_ids(assignment.military_unit_id, assignment.scope_depth)
```

### 4.3 种子数据

| role_category | code | role_definitions |
|---|---|---|
| 军训主管部门 | military_admin | 管理员(admin), 学校领导(school_leader) |
| 老师 | teacher | 辅导员(counselor), 学院领导(college_leader) |
| 参训学生 | student | 参训学生(student) |
| 小教员 | assistant_instructor | 小教员(assistant_instructor) |
| 后勤 | logistics | 医疗保障组(medical_support) |

### 4.4 后端文件清单

```
module_military/
├── entity/
│   ├── do/
│   │   ├── role_category_do.py
│   │   ├── role_definition_do.py
│   │   ├── role_assignment_do.py
│   │   └── role_status_tag_do.py
│   └── vo/
│       ├── role_category_vo.py
│       ├── role_definition_vo.py
│       ├── role_assignment_vo.py
│       └── role_status_tag_vo.py
├── dao/
│   ├── role_category_dao.py
│   ├── role_definition_dao.py
│   ├── role_assignment_dao.py
│   └── role_status_tag_dao.py
├── service/
│   ├── role_category_service.py
│   ├── role_definition_service.py
│   ├── role_assignment_service.py
│   └── scope_resolver.py              # 组织范围解析核心
└── controller/
    ├── role_category_controller.py
    ├── role_definition_controller.py
    ├── role_assignment_controller.py
    └── role_status_tag_controller.py
```

### 4.5 前端文件清单

```
src/
├── api/military/
│   ├── roleCategory.js
│   ├── roleDefinition.js
│   ├── roleAssignment.js
│   └── roleStatusTag.js
└── views/military/
    ├── role_category/
    │   └── index.vue
    ├── role_definition/
    │   └── index.vue
    ├── role_assignment/
    │   └── index.vue          # 核心页面：人员 + 角色 + 组织范围选择
    └── role_status_tag/
        └── index.vue
```

---

## 五、阶段 3：规则中心 (预计 3-4 天)

### 5.1 数据模型

#### 5.1.1 `sys_training_batches` — 军训批次

| 字段 | 类型 | 说明 |
|---|---|---|
| id | BigInteger PK | 主键 |
| name | VARCHAR(100) | 批次名称 |
| code | VARCHAR(50) UNIQUE | 批次编码 |
| status | VARCHAR(20) | draft/active/completed/archived |
| start_date | DATE | 计划开始日期 |
| end_date | DATE | 计划结束日期 |
| actual_start_date | DATE | 实际开始日期 |
| actual_end_date | DATE | 实际结束日期 |
| version | Integer | 乐观锁版本号 |

**唯一约束：** Partial Unique `(status)` WHERE `status='active'` — 同一时刻最多一个 active 批次

**状态机规则：**
- `draft → active`：校验至少 1 个训练日 + 1 个排级编制 + 1 名参训学生
- `active → completed`：冻结所有写操作，自动取消 pending 审批
- `completed → active`：可手动恢复
- 所有业务写操作校验批次 `status='active'`

#### 5.1.2 `sys_training_calendar_days` — 训练日历

| 字段 | 类型 | 说明 |
|---|---|---|
| id | BigInteger PK | 主键 |
| training_batch_id | BigInteger FK | 所属批次 |
| training_date | DATE | 训练日期 |
| is_training_day | Boolean | 是否为训练日 |
| version | Integer | 乐观锁 |

#### 5.1.3 `sys_training_time_windows` — 训练时段

| 字段 | 类型 | 说明 |
|---|---|---|
| id | BigInteger PK | 主键 |
| training_calendar_day_id | BigInteger FK | 所属训练日 |
| time_slot | VARCHAR(10) | am / pm |
| start_time | TIME | 开始时间 |
| end_time | TIME | 结束时间 |
| version | Integer | 乐观锁 |

#### 5.1.4 `sys_checkin_policies` — 打卡策略

| 字段 | 类型 | 说明 |
|---|---|---|
| id | BigInteger PK | 主键 |
| training_calendar_day_id | BigInteger FK | 所属训练日 |
| role_type | VARCHAR(20) | counselor / assistant_instructor |
| checkin_before_minutes | Integer | 训练开始前 N 分钟可打卡 |
| checkin_after_minutes | Integer | 训练开始后 N 分钟可打卡 |
| version | Integer | 乐观锁 |

#### 5.1.5 `sys_training_venues` — 训练场地

| 字段 | 类型 | 说明 |
|---|---|---|
| id | BigInteger PK | 主键 |
| training_batch_id | BigInteger FK | 所属批次 |
| name | VARCHAR(100) | 场地名称 |
| location_description | VARCHAR(255) | 位置描述 |
| geo_fence_center_lat | DECIMAL(10,7) | 围栏中心纬度 |
| geo_fence_center_lng | DECIMAL(10,7) | 围栏中心经度 |
| geo_fence_radius_meters | Integer | 围栏半径 (米) |
| is_active | Boolean | 是否启用 |
| version | Integer | 乐观锁 |

#### 5.1.6 `sys_counselor_schedules` — 辅导员排班

| 字段 | 类型 | 说明 |
|---|---|---|
| id | BigInteger PK | 主键 |
| training_batch_id | BigInteger FK | 所属批次 |
| training_calendar_day_id | BigInteger FK | 训练日 |
| academic_unit_id | BigInteger FK | 学院 |
| time_slot | VARCHAR(5) | am/pm |
| counselor_person_id | BigInteger FK | 辅导员 |
| training_venue_id | BigInteger FK | 训练场地 |
| created_by | BigInteger | 排班人 (学院领导) |
| version | Integer | 乐观锁 |

**排班唯一约束：** `(training_calendar_day_id, academic_unit_id, time_slot, counselor_person_id)` — 防止重复录入

### 5.2 后端文件清单

```
module_military/
├── entity/do/
│   ├── training_batch_do.py
│   ├── training_calendar_day_do.py
│   ├── training_time_window_do.py
│   ├── checkin_policy_do.py
│   ├── training_venue_do.py
│   └── counselor_schedule_do.py
├── entity/vo/
│   ├── training_batch_vo.py
│   ├── training_calendar_day_vo.py
│   ├── training_time_window_vo.py
│   ├── checkin_policy_vo.py
│   ├── training_venue_vo.py
│   └── counselor_schedule_vo.py
├── dao/
│   ├── training_batch_dao.py
│   ├── training_calendar_day_dao.py
│   ├── training_time_window_dao.py
│   ├── checkin_policy_dao.py
│   ├── training_venue_dao.py
│   └── counselor_schedule_dao.py
├── service/
│   ├── training_batch_service.py     # 含状态机校验
│   ├── training_calendar_service.py
│   ├── training_time_window_service.py
│   ├── checkin_policy_service.py
│   ├── training_venue_service.py
│   └── counselor_schedule_service.py
└── controller/
    ├── training_batch_controller.py
    ├── training_calendar_controller.py
    ├── training_time_window_controller.py
    ├── checkin_policy_controller.py
    ├── training_venue_controller.py
    └── counselor_schedule_controller.py
```

### 5.3 前端文件清单

```
src/views/military/
├── training_batch/
│   └── index.vue              # 批次列表 + 状态切换
├── training_calendar/
│   └── index.vue              # 日历视图 + 批量设置训练日
├── training_venue/
│   └── index.vue              # 场地列表 + 地图围栏配置
├── training_time_window/
│   └── index.vue              # 时段管理 (按训练日)
├── checkin_policy/
│   └── index.vue              # 打卡窗口策略
└── counselor_schedule/
    └── index.vue              # 排班管理 (辅导员 × 训练日 × 场地)
```

---

## 六、阶段 4：工作流引擎 (预计 4-5 天)

### 6.1 数据模型

#### 6.1.1 `sys_workflow_templates` — 审批模板

| 字段 | 类型 | 说明 |
|---|---|---|
| id | BigInteger PK | 主键 |
| name | VARCHAR(100) | 模板名称 |
| code | VARCHAR(50) UNIQUE | 模板编码 |
| request_type | VARCHAR(30) | 适用申请类型 (NULL=全部) |
| reason_category | VARCHAR(30) | 适用原因分类 |
| version | Integer | 模板版本号 |
| is_active | Boolean | 是否启用 |

**唯一约束：** Partial Unique `(reason_category)` WHERE `is_active=true`

#### 6.1.2 `sys_workflow_template_nodes` — 审批模板节点

| 字段 | 类型 | 说明 |
|---|---|---|
| id | BigInteger PK | 主键 |
| workflow_template_id | BigInteger FK | 所属模板 |
| node_order | Integer | 节点顺序 |
| name | VARCHAR(100) | 节点名称 |
| approver_role_code | VARCHAR(50) | 审批角色编码 |
| approver_scope_resolution | VARCHAR(30) | applicant_academic_unit / global |

**种子模板：**

| 模板 | node_order | name | approver_role_code | scope |
|---|---|---|---|---|
| illness | 1 | 医疗保障组审核 | medical_support | global |
| illness | 2 | 辅导员审批 | counselor | applicant_academic_unit |
| illness | 3 | 学院领导审批 | college_leader | applicant_academic_unit |
| illness | 4 | 军训主管部门审批 | admin | global |
| affair | 1 | 辅导员审批 | counselor | applicant_academic_unit |
| affair | 2 | 学院领导审批 | college_leader | applicant_academic_unit |
| affair | 3 | 军训主管部门审批 | admin | global |

#### 6.1.3 `sys_training_exception_requests` — 训练例外申请

| 字段 | 类型 | 说明 |
|---|---|---|
| id | BigInteger PK | 主键 |
| applicant_person_id | BigInteger FK | 申请人 |
| training_batch_id | BigInteger FK | 所属批次 |
| request_type | VARCHAR(30) | leave / attend_without_training / deferred_training / exempt_training |
| reason_category | VARCHAR(30) | illness / affair / 自定义 |
| reason_detail | TEXT | 申请原因 |
| current_status | VARCHAR(20) | draft/pending/approved/rejected/returned/canceled |
| submission_count | Integer | 提交次数 |
| current_workflow_instance_id | BigInteger FK | 当前活动实例 |
| latest_submitted_at | DateTime | 最近提交时间 |
| version | Integer | 乐观锁 |

#### 6.1.4 `sys_workflow_instances` — 审批实例

| 字段 | 类型 | 说明 |
|---|---|---|
| id | BigInteger PK | 主键 |
| training_exception_request_id | BigInteger FK | 所属申请 |
| workflow_template_id | BigInteger FK | 模板 |
| template_version | Integer | 快照模板版本 |
| instance_version | Integer | 从 1 开始递增 |
| previous_instance_id | BigInteger FK | 上一版本实例 |
| status | VARCHAR(20) | pending/approved/rejected/returned/canceled |
| started_at | DateTime | 开始时间 |
| finished_at | DateTime | 结束时间 |

#### 6.1.5 `sys_workflow_nodes` — 审批节点

| 字段 | 类型 | 说明 |
|---|---|---|
| id | BigInteger PK | 主键 |
| workflow_instance_id | BigInteger FK | 所属实例 |
| template_node_id | BigInteger FK | 模板节点来源 |
| node_order | Integer | 节点顺序 |
| name | VARCHAR(100) | 节点名称 |
| approver_role_code | VARCHAR(50) | 审批角色 |
| assignee_person_id | BigInteger FK | 解析后的实际审批人 |
| status | VARCHAR(20) | pending/active/approved/rejected/returned/skipped |
| activated_at | DateTime | 激活时间 |
| finished_at | DateTime | 结束时间 |

#### 6.1.6 `sys_workflow_actions` — 审批动作

| 字段 | 类型 | 说明 |
|---|---|---|
| id | BigInteger PK | 主键 |
| workflow_node_id | BigInteger FK | 所属节点 |
| actor_person_id | BigInteger FK | 审批人 |
| action_type | VARCHAR(20) | approve / reject / return |
| comment | TEXT | 审批意见 |

### 6.2 核心业务流程

**提交申请流程：**
```
1. 前端 POST /military/exception-requests { request_type, reason_category, reason_detail }
2. Service 校验：
   - 批次 status='active'
   - (request_type, reason_category) → 匹配 workflow_template
   - 匹配不到模板 → 422 WORKFLOW_TEMPLATE_NOT_FOUND
3. 创建 training_exception_request (current_status='pending')
4. 创建 workflow_instance (instance_version=1)
5. 从 workflow_template_nodes 复制节点 → 创建 workflow_nodes
6. 解析每个节点的实际审批人 (按 role_code + scope_resolution)
7. 激活第一个节点 (status='active')
8. 为第一个节点的审批人创建 todo_item
9. current_status → 'pending'
```

**审批动作流程：**
```
1. POST /military/workflow/actions { workflow_node_id, action_type, comment }
2. Service 校验：
   - 当前用户 == workflow_node.assignee_person_id
   - action_type 合法
   - return 动作时 comment 必填
3. 创建 workflow_action
4. 更新 workflow_node.status
5. 如果是 approve：
   - 下一个节点激活，创建新的 todo_item
   - 如果是最后一个节点 → workflow_instance.status='approved' → request.status='approved'
   - workflow projection 回写 student_training_statuses
6. 如果是 reject → 终态：instance.status='rejected', request.status='rejected'
7. 如果是 return：
   - instance.status='returned', request.status='returned'
   - 学生重新提交 → 创建新 instance (instance_version++)
   - 新 instance 按最新模板版本创建节点
```

### 6.3 后端文件清单

```
module_military/
├── entity/do/
│   ├── workflow_template_do.py
│   ├── workflow_template_node_do.py
│   ├── training_exception_request_do.py
│   ├── workflow_instance_do.py
│   ├── workflow_node_do.py
│   └── workflow_action_do.py
├── entity/vo/
│   ├── workflow_template_vo.py
│   ├── training_exception_request_vo.py
│   ├── workflow_instance_vo.py
│   └── workflow_action_vo.py
├── dao/
│   ├── workflow_template_dao.py
│   ├── training_exception_request_dao.py
│   ├── workflow_instance_dao.py
│   └── workflow_action_dao.py
├── service/
│   ├── workflow_template_service.py
│   ├── workflow_instance_service.py    # 核心：创建实例 + 节点解析
│   ├── workflow_action_service.py      # 核心：审批动作处理
│   └── workflow_scope_resolver.py      # 审批人解析 (按角色+组织范围)
└── controller/
    ├── workflow_template_controller.py
    ├── exception_request_controller.py  # /military/exception-requests
    └── workflow_action_controller.py    # /military/workflow/actions
```

### 6.4 前端文件清单

```
src/
├── api/military/
│   ├── exceptionRequest.js
│   └── workflow.js
└── views/military/
    ├── workflow_template/
    │   └── index.vue              # 模板列表 + 节点编辑 (上下拖拽排序)
    ├── exception_request/
    │   ├── index.vue              # 申请列表 (学生视角：我的申请)
    │   ├── detail.vue             # 申请详情 + 审批时间线
    │   └── create.vue             # 创建申请
    └── workflow_approval/
        └── index.vue              # 我的待审批列表
```

### 6.5 关键业务规则

- 训练例外类型枚举：`leave`（请假）, `attend_without_training`（跟训）, `deferred_training`（缓训）, `exempt_training`（免训）
- 审批动作枚举：`approve`, `reject`, `return`
- `return` 只能退回给学生（发起人），不支持退回到中间节点
- 退回重提创建新 `workflow_instance`，走完整审批链
- 模板修改后：运行中的旧实例按旧版本走完，新实例走新版本
- 工作流实例版本化：`training_exception_request` 是稳定业务对象，`workflow_instance` 每次提交创建新版本

---

## 七、阶段 5：考勤与签到 (预计 2-3 天)

### 7.1 数据模型

#### 7.1.1 `sys_attendance_records` — 打卡记录

| 字段 | 类型 | 说明 |
|---|---|---|
| id | BigInteger PK | 主键 |
| training_batch_id | BigInteger FK | 所属批次 |
| training_calendar_day_id | BigInteger FK | 训练日 |
| training_time_window_id | BigInteger FK | 训练时段 |
| person_id | BigInteger FK | 打卡人 |
| role_type | VARCHAR(20) | counselor / assistant_instructor |
| checkin_at | DateTime | 打卡时间 |
| geo_fence_result | VARCHAR(20) | inside / outside / unavailable |
| idempotency_key | VARCHAR(100) UNIQUE | 幂等键 |

#### 7.1.2 `sys_attendance_location_captures` — 定位明细

| 字段 | 类型 | 说明 |
|---|---|---|
| id | BigInteger PK | 主键 |
| attendance_record_id | BigInteger FK | FK → attendance_records |
| lat | DECIMAL(10,7) | 纬度 |
| lng | DECIMAL(10,7) | 经度 |
| geo_fence_result | VARCHAR(20) | inside/outside/unavailable |
| captured_at | DateTime | 采集时间 |
| expires_at | DateTime | 到期清除 = batch.end_date + 90天 |

#### 7.1.3 `sys_student_training_statuses` — 学生参训状态

| 字段 | 类型 | 说明 |
|---|---|---|
| id | BigInteger PK | 主键 |
| training_batch_id | BigInteger FK | 批次 |
| training_calendar_day_id | BigInteger FK | 训练日 |
| training_time_window_id | BigInteger FK | 训练时段 |
| student_person_id | BigInteger FK | 学生 |
| assistant_instructor_person_id | BigInteger FK | 手签人 (小教员) |
| status | VARCHAR(30) | normal/late/absent/leave/attend_without_training/deferred_training/exempt_training |
| mark_source | VARCHAR(20) | weapp / admin_web / workflow_projection |
| source_request_id | BigInteger FK | 关联审批 |
| comment | TEXT | 说明 |
| marked_at | DateTime | 最后有效写入时间 |

**唯一约束：** `(training_batch_id, training_time_window_id, student_person_id)`

### 7.2 核心业务规则

**辅导员打卡校验：**
```
1. 当天有排班 (counselor_schedules 中存在记录)
2. 在对应场地围栏内 (前端传坐标 → 服务端计算距离 → 与 venue.geo_fence_radius_meters 比较)
3. 在 checkin_policy 允许的打卡时间窗口内
4. Idempotency-Key 防重复提交
```

**小教员手签学生状态：**
```
1. 校验小教员与学生在同一批次同一排级 military_unit (通过 military_assignments 判断)
2. 写入 student_training_statuses (mark_source=admin_web 或 weapp)
3. 记录手签人和时间
```

> **说明：** 学生没有独立定位签到。学生当日参训事实以 `student_training_statuses` 的时段级状态投影为准，由所属小教员手签写入。

### 7.3 后端文件清单

```
module_military/
├── entity/do/
│   ├── attendance_record_do.py
│   ├── attendance_location_capture_do.py
│   └── student_training_status_do.py
├── dao/ (对应)
├── service/
│   ├── attendance_service.py           # 打卡核心逻辑
│   └── student_training_status_service.py  # 手签逻辑
└── controller/
    ├── attendance_controller.py         # /military/attendance (打卡接口)
    └── student_training_status_controller.py  # /military/student-statuses
```

### 7.4 前端文件清单

```
src/
├── api/military/
│   ├── attendance.js
│   └── studentTrainingStatus.js
└── views/military/
    ├── attendance/
    │   └── record.vue               # 打卡记录查看 (含定位明细)
    └── student_status/
        ├── index.vue                # 小教员：学生状态手签页
        └── report.vue               # 按日/排的学生参训情况汇总
```

---

## 八、阶段 6：医疗 + 考评 + 预警 (预计 3-4 天)

### 8.1 数据模型

#### 8.1.1 `sys_medical_visit_records` — 医疗点就医记录

| 字段 | 类型 | 说明 |
|---|---|---|
| id | BigInteger PK | 主键 |
| training_batch_id | BigInteger FK | 批次 |
| person_id | BigInteger FK | 就医学生 |
| visited_at | DateTime | 就医时间 |
| chief_complaint | TEXT | 主诉 |
| diagnosis | TEXT | 诊断 |
| treatment | TEXT | 处置 |
| recorded_by | BigInteger FK | 记录人 (医疗保障组) |

#### 8.1.2 `sys_evaluation_records` — 考评记录

| 字段 | 类型 | 说明 |
|---|---|---|
| id | BigInteger PK | 主键 |
| training_batch_id | BigInteger FK | 批次 |
| training_calendar_day_id | BigInteger FK | 训练日 |
| student_person_id | BigInteger FK | 被考评学生 |
| evaluator_person_id | BigInteger FK | 考评人 (小教员) |
| evaluation_type | VARCHAR(30) | 考评类型 |
| description | TEXT | 考评说明 |
| cumulative_count | Integer | 本批次累计考评次数 (写入时计算) |

#### 8.1.3 `sys_warning_events` — 预警事件

| 字段 | 类型 | 说明 |
|---|---|---|
| id | BigInteger PK | 主键 |
| training_batch_id | BigInteger FK | 批次 |
| student_person_id | BigInteger FK | 预警对象 |
| trigger_source_type | VARCHAR(30) | evaluation_cumulative |
| trigger_source_id | BigInteger FK | 触发来源 (evaluation_record) |
| severity | VARCHAR(20) | warning / critical |
| description | TEXT | 预警描述 |
| status | VARCHAR(20) | pending/acknowledged/resolved/dismissed |
| resolved_by | BigInteger FK | 处置人 |
| resolved_at | DateTime | 处置时间 |
| version | Integer | 乐观锁 |

#### 8.1.4 `sys_evidence_files` — 证据文件

| 字段 | 类型 | 说明 |
|---|---|---|
| id | BigInteger PK | 主键 |
| entity_type | VARCHAR(50) | training_exception_request / evaluation_record |
| entity_id | BigInteger FK | 关联业务主键 |
| file_key | VARCHAR(255) | 对象存储键 |
| original_filename | VARCHAR(255) | 原始文件名 |
| content_type | VARCHAR(100) | MIME 类型 |
| file_size_bytes | Integer | 文件大小 |
| uploaded_by | BigInteger FK | 上传人 |

### 8.2 核心业务规则

**考评写入 → 预警触发链路：**
```
1. 小教员提交考评记录 evaluation_record
2. Service 写入时自动计算 cumulative_count = COUNT(*) WHERE student_id + batch_id
3. 同步判断：cumulative_count >= 3 → 触发 warning 级预警
4. 触发预警：
   a. 写入 warning_event (status=pending)
   b. 为辅导员创建 todo_item (todo_type=warning_disposal, priority=high, due_at=4小时)
5. 辅导员查看预警 → 填写处置意见 → 更新 warning_event.status
```

**医疗敏感字段控制：**
- 审批链上的角色（医疗保障组/辅导员/学院领导/军训主管部门）可查看病因
- 小教员**不可**查看学生的 `diagnosis`, `chief_complaint`, `treatment`
- 展板仅显示汇总数字，不暴露个人病因
- Service 层按当前用户角色过滤响应 DTO

### 8.3 后端文件清单

```
module_military/
├── entity/do/
│   ├── medical_visit_record_do.py
│   ├── evaluation_record_do.py
│   ├── warning_event_do.py
│   └── evidence_file_do.py
├── entity/vo/
│   ├── medical_visit_record_vo.py
│   ├── evaluation_record_vo.py
│   ├── warning_event_vo.py
│   └── evidence_file_vo.py
├── dao/ (对应)
├── service/
│   ├── medical_visit_service.py
│   ├── evaluation_service.py      # 含累计计数 + 预警触发
│   ├── warning_service.py         # 预警处置
│   └── evidence_file_service.py
└── controller/
    ├── medical_visit_controller.py
    ├── evaluation_controller.py
    ├── warning_controller.py
    └── evidence_file_controller.py  # 文件上传/下载/删除
```

### 8.4 前端文件清单

```
src/views/military/
├── medical/
│   ├── visit_record.vue         # 医疗保障组：就医登记
│   └── visit_list.vue           # 就医记录查询
├── evaluation/
│   ├── record.vue               # 小教员：考评登记
│   └── evidence_upload.vue      # 证据材料上传
├── warning/
│   ├── list.vue                 # 辅导员：预警列表
│   └── dispose.vue              # 预警处置详情
└── evidence_files/
    └── index.vue                # 证据文件管理
```

---

## 九、阶段 7：展板与待办中心 (预计 3-4 天)

### 9.1 数据模型

#### 9.1.1 `sys_todo_items` — 待办事项

| 字段 | 类型 | 说明 |
|---|---|---|
| id | BigInteger PK | 主键 |
| assignee_person_id | BigInteger FK | 处理人 |
| todo_type | VARCHAR(30) | workflow_approval / warning_disposal / import_review / export_ready |
| source_type | VARCHAR(50) | 来源实体类型 |
| source_id | BigInteger | 来源实体 ID |
| priority | VARCHAR(10) | high / medium / low |
| due_at | DateTime | 处理时限 |
| status | VARCHAR(20) | pending/in_progress/completed/canceled/expired |
| dedupe_key | VARCHAR(100) UNIQUE | 去重键 |
| completed_at | DateTime | 完成时间 |

**待办超时规则：**
- 审批类待办默认 24 小时
- 预警处置类待办默认 4 小时
- APScheduler 每分钟扫描超时 → 自动标记 `expired`
- 前端红色高亮 `expired` 待办

#### 9.1.2 `sys_dashboard_metric_snapshots` — 展板指标快照

| 字段 | 类型 | 说明 |
|---|---|---|
| id | BigInteger PK | 主键 |
| training_batch_id | BigInteger FK | 批次 |
| metric_key | VARCHAR(50) | 指标键 |
| metric_date | DATE | 指标日期 |
| dimension_type | VARCHAR(20) | overall / academic_unit / military_unit |
| dimension_id | BigInteger | 维度实体ID |
| value_numeric | DECIMAL | 指标数值 |
| refreshed_at | DateTime | 本次聚合更新时间 |

### 9.2 一期展板指标清单

| 指标 | metric_key | 刷新频率 |
|---|---|---|
| 军训总人数 | total_students | 每日 |
| 今日应参训人数 | today_expected_attend | 每日 |
| 今日实际参训人数 | today_actual_attend | 准实时 (Worker 每 30 秒) |
| 今日出勤率 | today_attendance_rate | 准实时 |
| 今日请假人数 (按类型) | today_leave_by_type | 准实时 |
| 今日待审批数 | today_pending_approvals | 准实时 |
| 因病请假 (今日/累计) | illness_leave_today / illness_leave_total | 准实时 |
| 医疗点今日就医人次 | today_medical_visits | 准实时 |
| 辅导员/小教员今日到岗率 | counselor_arrival_rate / instructor_arrival_rate | 准实时 |
| 活跃预警数 | active_warnings | 准实时 |
| 今日新增预警数 | today_new_warnings | 准实时 |
| 各学院/各营参训率排名 | attendance_rank_by_college / attendance_rank_by_battalion | 准实时 |

### 9.3 Worker 设计

**技术方案：** 利用 Ruoyi 已有的 `module_task` (APScheduler) 或新增独立 Worker 进程

```
module_military/worker/
├── __init__.py
├── main.py                    # Worker 入口：python -m module_military.worker.main
├── aggregator.py              # 展板指标聚合 (每 30 秒)
├── warning_detector.py        # 预警检测 (每考评记录写入时)
├── todo_manager.py            # 待办派发与管理
├── timeout_scanner.py         # 待办超时扫描 (每 60 秒)
└── cleanup.py                 # 过期数据清理 (每日)
```

**一期简化方案（无 Redis）：**
- 展板聚合：APScheduler 定时任务直接查询业务表 → 写入 `dashboard_metric_snapshots`
- 预警检测：在 `evaluation_service` 写入时**同步**判断（不依赖 Worker）
- 待办超时：APScheduler 每分钟扫描
- 过期清理：APScheduler 每日凌晨执行

### 9.4 后端文件清单

```
module_military/
├── entity/do/
│   ├── todo_item_do.py
│   └── dashboard_metric_snapshot_do.py
├── service/
│   ├── todo_service.py
│   └── dashboard_service.py
├── controller/
│   ├── todo_controller.py          # /military/todos (我的待办)
│   └── dashboard_controller.py     # /military/dashboard (展板数据)
└── worker/
    ├── main.py
    ├── aggregator.py
    └── timeout_scanner.py
```

### 9.5 前端文件清单

```
src/
├── api/military/
│   ├── todo.js
│   └── dashboard.js
└── views/military/
    ├── todo/
    │   └── index.vue             # 我的待办中心 (顶部统计卡片 + 多 tab 列表)
    └── dashboard/
        └── index.vue             # 实时展板 (ECharts 图表 + 自动轮询)
```

---

## 十、阶段 8：批量任务 + 审计 (预计 2-3 天)

### 10.1 数据模型

#### 10.1.1 `sys_import_jobs` — 导入任务

| 字段 | 类型 | 说明 |
|---|---|---|
| id | BigInteger PK | 主键 |
| job_type | VARCHAR(30) | people_import / role_import / assignment_import |
| requester_person_id | BigInteger FK | 发起人 |
| source_file_key | VARCHAR(255) | 导入文件存储键 |
| status | VARCHAR(20) | uploaded/validating/preview_ready/applying/completed/failed |
| total_rows | Integer | 总行数 |
| success_rows | Integer | 成功 |
| error_rows | Integer | 失败 |
| error_report_file_key | VARCHAR(255) | 错误报告 |
| version | Integer | 乐观锁 |

#### 10.1.2 `sys_import_job_rows` — 导入行校验

| 字段 | 类型 | 说明 |
|---|---|---|
| id | BigInteger PK | 主键 |
| import_job_id | BigInteger FK | 所属任务 |
| row_number | Integer | 原始行号 |
| status | VARCHAR(20) | valid / invalid / applied / skipped |
| error_code | VARCHAR(50) | 错误码 |
| error_message | TEXT | 错误信息 |
| normalized_payload | JSON | 规范化行数据 |

#### 10.1.3 `sys_export_jobs` — 导出任务

| 字段 | 类型 | 说明 |
|---|---|---|
| id | BigInteger PK | 主键 |
| export_type | VARCHAR(30) | dashboard_detail/people/attendance/workflow |
| requester_person_id | BigInteger FK | 发起人 |
| filter_snapshot | JSON | 筛选条件快照 |
| status | VARCHAR(20) | queued/processing/completed/failed/expired |
| output_file_key | VARCHAR(255) | 导出文件 |
| expires_at | DateTime | 下载失效时间 |

#### 10.1.4 `sys_audit_logs` — 审计日志

| 字段 | 类型 | 说明 |
|---|---|---|
| id | BigInteger PK | 主键 |
| training_batch_id | BigInteger FK | 批次 (可为空) |
| actor_person_id | BigInteger FK | 操作人 |
| action | VARCHAR(50) | 操作类型 |
| entity_type | VARCHAR(50) | 操作对象类型 |
| entity_id | BigInteger | 操作对象 ID |
| changes | JSON | 变更前后值 |
| ip_address | VARCHAR(50) | 请求 IP |
| user_agent | VARCHAR(255) | User-Agent |
| created_at | DateTime | 操作时间 |

#### 10.1.5 `sys_idempotency_records` — 幂等记录

| 字段 | 类型 | 说明 |
|---|---|---|
| id | BigInteger PK | 主键 |
| actor_person_id | BigInteger FK | 操作人 |
| client_type | VARCHAR(10) | admin / weapp / cli |
| endpoint_signature | VARCHAR(200) | HTTP方法+path |
| idempotency_key | VARCHAR(100) | 客户端提交的幂等键 |
| request_hash | VARCHAR(100) | 请求体哈希 |
| resource_type | VARCHAR(50) | 创建的资源类型 |
| resource_id | BigInteger | 创建的资源ID |
| response_code | Integer | 首次执行响应码 |
| expires_at | DateTime | 记录失效时间 |

### 10.2 导入流程

```
1. POST /military/imports 上传 Excel → status=uploaded
2. Worker 异步校验 (按 500 行批次) → status=validating → status=preview_ready
3. GET /military/imports/{id}/preview → 前端展示校验结果 (成功/失败明细)
4. POST /military/imports/{id}/apply → 用户确认 → status=applying → Worker 落库
5. status=completed → 生成错误报告 (可下载)
6. 导入上限：20,000 行 / 10 MB，校验超时 5 分钟
```

### 10.3 需要审计留痕的操作

| 操作 | action |
|---|---|
| 导入下级名单 | people_imported |
| 新建/修改角色 | role_created / role_updated |
| 修改角色状态标签 | role_status_tag_changed |
| 调整训练时间 | training_time_window_updated |
| 审批动作 | workflow_approved / workflow_rejected / workflow_returned |
| 预警触发 | warning_triggered |
| 证据上传/删除 | evidence_uploaded / evidence_deleted |
| 排班修改 | schedule_updated |
| 天气调整 | calendar_adjusted |

### 10.4 后端文件清单

```
module_military/
├── entity/do/
│   ├── import_job_do.py
│   ├── import_job_row_do.py
│   ├── export_job_do.py
│   ├── audit_log_do.py
│   └── idempotency_record_do.py
├── dao/ (对应)
├── service/
│   ├── import_service.py
│   ├── export_service.py
│   ├── audit_service.py
│   └── idempotency_service.py      # 幂等中间件
├── controller/
│   ├── import_controller.py
│   ├── export_controller.py
│   └── audit_controller.py
└── worker/
    ├── import_processor.py          # 异步导入处理
    └── export_processor.py          # 异步导出生成
```

### 10.5 前端文件清单

```
src/
├── api/military/
│   ├── import.js
│   ├── export.js
│   └── audit.js
└── views/military/
    ├── import/
    │   └── index.vue              # 导入管理 (上传 → 预览 → 确认 → 查看结果)
    ├── export/
    │   └── index.vue              # 导出管理 (发起导出 → 下载)
    └── audit/
        └── index.vue              # 审计日志查询
```

---

## 十一、数据库 Migration 汇总

| 阶段 | Migration 文件 | 包含表 |
|---|---|---|
| 1 | `xxx_add_org_and_people.py` | academic_units, military_units, person_profiles, military_assignments |
| 2 | `xxx_add_roles.py` | role_categories, role_definitions, role_assignments, role_status_tags |
| 2-seed | `xxx_seed_roles.py` | 系统预置角色类别 + 角色定义 + 训练例外类型 + 原因分类 |
| 3 | `xxx_add_rules.py` | training_batches, training_calendar_days, training_time_windows, checkin_policies, training_venues, counselor_schedules |
| 4 | `xxx_add_workflow.py` | workflow_templates, workflow_template_nodes, training_exception_requests, workflow_instances, workflow_nodes, workflow_actions |
| 4-seed | `xxx_seed_workflow.py` | 因病审批链(4节点) + 因事审批链(3节点) |
| 5 | `xxx_add_attendance.py` | attendance_records, attendance_location_captures, student_training_statuses |
| 6 | `xxx_add_medical_eval.py` | medical_visit_records, evaluation_records, warning_events, evidence_files |
| 7 | `xxx_add_todo_dashboard.py` | todo_items, dashboard_metric_snapshots |
| 8 | `xxx_add_import_export_audit.py` | import_jobs, import_job_rows, export_jobs, audit_logs, idempotency_records |

---

## 十二、前端路由规划

```javascript
// router/index.js 中新增
{
  path: '/military',
  component: Layout,
  name: 'Military',
  meta: { title: '军训管理', icon: 'military' },
  children: [
    // 阶段1
    { path: 'academic-units', name: 'AcademicUnits', component: ... },
    { path: 'military-units', name: 'MilitaryUnits', component: ... },
    { path: 'person-profiles', name: 'PersonProfiles', component: ... },
    { path: 'assignments', name: 'Assignments', component: ... },
    // 阶段2
    { path: 'role-categories', name: 'RoleCategories', component: ... },
    { path: 'role-definitions', name: 'RoleDefinitions', component: ... },
    { path: 'role-assignments', name: 'RoleAssignments', component: ... },
    { path: 'role-status-tags', name: 'RoleStatusTags', component: ... },
    // 阶段3
    { path: 'training-batches', name: 'TrainingBatches', component: ... },
    { path: 'training-calendar', name: 'TrainingCalendar', component: ... },
    { path: 'training-venues', name: 'TrainingVenues', component: ... },
    { path: 'counselor-schedules', name: 'CounselorSchedules', component: ... },
    { path: 'checkin-policies', name: 'CheckinPolicies', component: ... },
    // 阶段4
    { path: 'workflow-templates', name: 'WorkflowTemplates', component: ... },
    { path: 'exception-requests', name: 'ExceptionRequests', component: ... },
    { path: 'workflow-approvals', name: 'WorkflowApprovals', component: ... },
    // 阶段5
    { path: 'attendance', name: 'Attendance', component: ... },
    { path: 'student-statuses', name: 'StudentStatuses', component: ... },
    // 阶段6
    { path: 'medical-visits', name: 'MedicalVisits', component: ... },
    { path: 'evaluations', name: 'Evaluations', component: ... },
    { path: 'warnings', name: 'Warnings', component: ... },
    { path: 'evidence-files', name: 'EvidenceFiles', component: ... },
    // 阶段7
    { path: 'todos', name: 'Todos', component: ... },
    { path: 'dashboard', name: 'Dashboard', component: ... },
    // 阶段8
    { path: 'imports', name: 'Imports', component: ... },
    { path: 'exports', name: 'Exports', component: ... },
    { path: 'audit-logs', name: 'AuditLogs', component: ... },
  ]
}
```

---

## 十三、开发约定

### 13.1 命名规则

| 维度 | 规则 | 示例 |
|---|---|---|
| 数据库表名 | 复数 `snake_case`，统一 `sys_` 前缀 | `sys_person_profiles` |
| 数据库字段 | `snake_case`，布尔 `is_` 前缀 | `is_active`, `training_batch_id` |
| API URL | 复数 `kebab-case` | `/military/person-profiles` |
| API JSON key | `camelCase` | `{ "studentName": "张三" }` |
| Python 文件/模块 | `snake_case` | `person_profile_service.py` |
| Python class | PascalCase | `PersonProfileService` |
| Vue 组件 | `PascalCase.vue` | `PersonProfile/index.vue` |
| Vue Pinia store | `useXxxStore` | `useMilitaryStore` |

### 13.2 代码模板

**新建模块遵循 Ruoyi 固定模式：**

```python
# 1. DO: entity/do/xxx_do.py
class SysXxx(Base):
    __tablename__ = 'sys_xxx'
    id = Column(BigInteger, primary_key=True, autoincrement=True)
    # ... 业务字段
    create_by = Column(String(64))
    create_time = Column(DateTime, default=datetime.now())
    update_by = Column(String(64))
    update_time = Column(DateTime, default=datetime.now())

# 2. VO: entity/vo/xxx_vo.py
class XxxModel(BaseModel):
    model_config = ConfigDict(alias_generator=to_camel, from_attributes=True)
    # ... 字段

class XxxPageQueryModel(XxxModel):
    page_num: int = Field(default=1)
    page_size: int = Field(default=10)

# 3. DAO: dao/xxx_dao.py — 使用 SQLAlchemy 2.x 语法
# 4. Service: service/xxx_service.py — @classmethod 类方法模式
# 5. Controller: controller/xxx_controller.py — APIRouterPro 自动注册
```

### 13.3 API 响应格式

```json
// 成功
{ "data": {...}, "meta": {...} }
// 失败
{ "error": { "code": "WORKFLOW_TEMPLATE_NOT_FOUND", "message": "..." }, "traceId": "..." }
// 分页
{ "rows": [...], "total": 100, "code": 200, "msg": "查询成功" }
```

### 13.4 乐观锁使用

以下实体需要 `version` 字段 (SQLAlchemy `__mapper_args__ = {"version_id_col": version}`)：
- counselor_schedule, training_time_window, checkin_policy, training_calendar_day
- workflow_template, role_definition, training_venue
- training_exception_request, warning_event, import_job, training_batch

---

## 十四、实施建议

1. **先完成阶段 1+2**（组织+角色），因为所有后续模块都需要权限和组织结构支撑
2. **每个阶段自测通过再进入下一阶段**，避免大量未测试代码堆积
3. **善用 Ruoyi 的代码生成器** (`module_generator`) 快速生成标准 CRUD，然后手动修改业务逻辑
4. **前端复用 Ruoyi 已有的组件**：`pagination`、`dict-tag`、`right-toolbar`、`v-hasPermi` 指令等
5. **字典数据**统一通过 Ruoyi 的 `sys_dict_data` 体系管理，不要在前端硬编码
6. **权限标识**注册到 `sys_menu` 表中，确保权限校验链路完整
7. **一期先不做小程序**，Web 端完成后可作为小程序 API 的后端
