# 军训管理平台 — 阶段 1+2 设计文档

_基于 Ruoyi-FastAPI 框架，复用现有系统表，扩展军训组织与角色体系_

---

## 一、设计原则

- **复用而非重建**：利用 `sys_user`、`sys_dept`、`sys_role`、`sys_menu`、`sys_dict_data` 等现有表
- **遵循 Ruoyi 四层模式**：DO → VO → DAO → Service → Controller，全部 `@classmethod`
- **APIRouterPro 自动注册**：Controller 放在 `module_military/controller/` 下，按 `order_num` 排序
- **权限走 `sys_menu.perms`**：不新建权限定义表

---

## 二、数据模型

### 2.1 改造现有表

**`sys_user` 新增 3 列：**

| 字段 | 类型 | 说明 |
|---|---|---|
| student_no | VARCHAR(30) | 学号（学生时必填，可空） |
| employee_no | VARCHAR(30) | 工号（教职工时必填，可空） |
| gender | VARCHAR(5) | male / female |

现有字段复用：`user_name`=姓名，`phonenumber`=联系电话，`dept_id`=行政归属（班级级），`status`=是否启用。

**`sys_dept` 表结构不变**，通过字典 `military_academic_unit_type`（school/college/major/class）标注层级。

**`sys_role` + `sys_menu` 不变**，军训权限标识注册到 `sys_menu.perms` 字段。

### 2.2 新建表

**① `sys_training_batches` — 军训批次**

| 字段 | 类型 | 说明 |
|---|---|---|
| id | BigInteger PK | 主键，自增 |
| name | VARCHAR(100) | 批次名称 |
| code | VARCHAR(50) UNIQUE | 批次编码 |
| status | VARCHAR(20) DEFAULT 'draft' | draft / active / completed / archived |
| start_date | DATE | 计划开始日期 |
| end_date | DATE | 计划结束日期 |
| actual_start_date | DATE | 实际开始日期 |
| actual_end_date | DATE | 实际结束日期 |
| version | Integer DEFAULT 0 | 乐观锁 |
| del_flag | CHAR(1) DEFAULT '0' | 删除标记（0存在 2删除） |
| create_by | VARCHAR(64) | 创建者 |
| create_time | DateTime | 创建时间 |
| update_by | VARCHAR(64) | 更新者 |
| update_time | DateTime | 更新时间 |

约束：Partial Unique INDEX `(status)` WHERE `status='active' AND del_flag='0'` — 同一时刻最多一个激活批次。

状态机：`draft → active`（校验至少 1 个编制 + 1 名人员），`active → completed`，`completed → active`。

**② `sys_military_units` — 军训编制树**

| 字段 | 类型 | 说明 |
|---|---|---|
| id | BigInteger PK | 主键，自增 |
| training_batch_id | BigInteger FK | 所属批次 |
| parent_id | BigInteger | 上级编制（NULL=顶级） |
| unit_type | VARCHAR(20) | regiment / battalion / company / platoon |
| name | VARCHAR(100) | 编制名称 |
| code | VARCHAR(50) | 编码 |
| sort_order | Integer DEFAULT 0 | 同级排序 |
| is_active | Boolean DEFAULT True | 是否启用 |
| del_flag | CHAR(1) DEFAULT '0' | 删除标记 |
| create_by | VARCHAR(64) | 创建者 |
| create_time | DateTime | 创建时间 |
| update_by | VARCHAR(64) | 更新者 |
| update_time | DateTime | 更新时间 |

索引：`(training_batch_id, parent_id)`。

**③ `sys_military_assignments` — 军训编制分配**

| 字段 | 类型 | 说明 |
|---|---|---|
| id | BigInteger PK | 主键，自增 |
| user_id | BigInteger FK → sys_user | 人员 |
| military_unit_id | BigInteger FK → sys_military_units | 编制（排级） |
| training_batch_id | BigInteger FK → sys_training_batches | 所属批次 |
| assigned_at | DateTime DEFAULT now() | 分配时间 |
| removed_at | DateTime | 移除时间（NULL=当前有效） |
| assigned_by | BigInteger | 操作人 user_id |
| del_flag | CHAR(1) DEFAULT '0' | 删除标记 |
| create_by | VARCHAR(64) | 创建者 |
| create_time | DateTime | 创建时间 |
| update_by | VARCHAR(64) | 更新者 |
| update_time | DateTime | 更新时间 |

唯一约束：Partial Unique INDEX `(user_id, training_batch_id)` WHERE `removed_at IS NULL AND del_flag='0'`。

**④ `sys_military_role_assignments` — 军训角色授权**

| 字段 | 类型 | 说明 |
|---|---|---|
| id | BigInteger PK | 主键，自增 |
| user_id | BigInteger FK → sys_user | 人员 |
| role_code | VARCHAR(50) | 军训角色编码 |
| scope_type | VARCHAR(20) | global / academic / military |
| scope_dept_id | BigInteger FK → sys_dept | 学术组织范围 |
| scope_military_unit_id | BigInteger FK → sys_military_units | 军事组织范围 |
| scope_depth | VARCHAR(20) DEFAULT 'self' | self / children / subtree |
| training_batch_id | BigInteger FK → sys_training_batches | 批次绑定 |
| is_active | Boolean DEFAULT True | 是否生效 |
| granted_at | DateTime DEFAULT now() | 授权时间 |
| revoked_at | DateTime | 撤销时间 |
| granted_by | BigInteger | 授权人 user_id |
| del_flag | CHAR(1) DEFAULT '0' | 删除标记 |
| create_by | VARCHAR(64) | 创建者 |
| create_time | DateTime | 创建时间 |
| update_by | VARCHAR(64) | 更新者 |
| update_time | DateTime | 更新时间 |

### 2.3 表关系

```
sys_dept (学院行政树)
    ├── sys_user.dept_id
    ├── sys_military_role_assignments.scope_dept_id → sys_dept
    └── sys_military_role_assignments.scope_military_unit_id → sys_military_units

sys_training_batches
    ├── sys_military_units.training_batch_id
    ├── sys_military_assignments.training_batch_id
    └── sys_military_role_assignments.training_batch_id

sys_role + sys_menu (Ruoyi 权限体系，不变)
```

---

## 三、后端代码

### 3.1 文件清单

```
module_military/
├── entity/
│   ├── do/
│   │   ├── military_unit_do.py
│   │   ├── military_assignment_do.py
│   │   ├── military_role_assignment_do.py
│   │   └── training_batch_do.py
│   └── vo/
│       ├── military_unit_vo.py
│       ├── military_assignment_vo.py
│       ├── military_role_assignment_vo.py
│       └── training_batch_vo.py
├── dao/
│   ├── military_unit_dao.py
│   ├── military_assignment_dao.py
│   ├── military_role_assignment_dao.py
│   └── training_batch_dao.py
├── service/
│   ├── military_unit_service.py
│   ├── military_assignment_service.py
│   ├── military_role_assignment_service.py   # 含 scope_resolver
│   └── training_batch_service.py             # 含状态机
└── controller/
    ├── military_unit_controller.py
    ├── military_assignment_controller.py
    ├── military_role_assignment_controller.py
    └── training_batch_controller.py
```

### 3.2 额外改动

| 文件 | 改动 |
|---|---|
| `module_admin/entity/do/user_do.py` | 加 student_no, employee_no, gender 列 |
| `module_admin/entity/vo/user_vo.py` | 对应加 3 字段 |
| Alembic | 1 个 migration：4 新表 + sys_user 加列 |
| 种子 SQL | sys_dict_data 新增 military_role_code, military_academic_unit_type, military_unit_type 字典 |
| 种子 SQL | sys_menu 新增军训菜单树及 14 条权限标识 |

### 3.3 API 路由

```
GET    /military/training-batches/list              # 批次列表
GET    /military/training-batches/{id}              # 批次详情
POST   /military/training-batches                   # 新建批次
PUT    /military/training-batches                   # 编辑批次
PUT    /military/training-batches/{id}/status       # 状态切换
DELETE /military/training-batches/{ids}             # 删除批次

GET    /military/military-units/tree                # 编制树（按 batch_id）
GET    /military/military-units/{id}                # 编制详情
POST   /military/military-units                     # 新增编制
PUT    /military/military-units                     # 编辑编制
DELETE /military/military-units/{ids}               # 删除编制

GET    /military/assignments/list                   # 编制分配列表
POST   /military/assignments/batch                  # 批量分配
PUT    /military/assignments                        # 调整分配
DELETE /military/assignments/{id}                   # 取消分配

GET    /military/role-assignments/list              # 角色授权列表
POST   /military/role-assignments                   # 授予角色
PUT    /military/role-assignments/{id}              # 修改授权范围
DELETE /military/role-assignments/{id}              # 撤销角色授权
```

### 3.4 Scope Resolver 核心逻辑

```python
def resolve_scope_user_ids(assignment) -> list[int]:
    # global → 全批次人员
    # academic → 按 scope_dept_id + scope_depth(self/children/subtree) 查 sys_user.dept_id
    # military → 按 scope_military_unit_id + scope_depth 查 military_assignments
```

### 3.5 批次状态机规则

- `draft → active`：校验批次下至少 1 个编制节点 + 1 条分配记录
- `active → completed`：完成后拒绝所有业务写操作
- `completed → active`：可手动恢复，不可删除已完成批次
- `archived`：手动归档，归档后不可恢复

---

## 四、前端设计

### 4.1 文件清单

```
src/
├── api/military/
│   ├── trainingBatch.js
│   ├── militaryUnit.js
│   ├── militaryAssignment.js
│   └── militaryRoleAssignment.js
└── views/military/
    ├── training_batch/
    │   └── index.vue              # 批次列表 + 状态切换
    ├── military_unit/
    │   └── index.vue              # 编制树管理
    ├── military_assignment/
    │   └── index.vue              # 编制分配
    └── military_role_assignment/
        └── index.vue              # 角色授权
```

### 4.2 路由

```javascript
{
  path: '/military',
  component: Layout,
  name: 'Military',
  meta: { title: '军训管理' },
  children: [
    { path: 'training-batches', ...meta: { title: '军训批次' } },
    { path: 'military-units', ...meta: { title: '编制管理' } },
    { path: 'assignments', ...meta: { title: '编制分配' } },
    { path: 'role-assignments', ...meta: { title: '角色授权' } },
  ]
}
```

### 4.3 复用组件

RightToolbar、Pagination、v-hasPermi、DictTag、Treeselect — 全部来自现有 `src/components/`。

---

## 五、迁移与种子数据

### 5.1 Migration

1 个文件 `xxxx_add_military_org_and_role.py`：
- CREATE TABLE 4 张新表
- ALTER TABLE sys_user ADD COLUMN student_no, employee_no, gender
- 建索引和唯一约束

### 5.2 种子数据

**sys_dict_data：**

| 字典类型 | 字典值 |
|---|---|
| military_role_code | admin, school_leader, counselor, college_leader, student, assistant_instructor, medical_support |
| military_academic_unit_type | school, college, major, class |
| military_unit_type | regiment, battalion, company, platoon |

**sys_menu：** 军训一级菜单 + 子菜单（每模块 list/add/edit/remove/query）

### 5.3 权限标识

```
military:training_batch:list/add/edit/remove/query
military:military_unit:list/add/edit/remove
military:assignment:list/edit
military:role_assignment:list/edit/remove
```

---

## 六、测试

- Service 单测：核心校验分支（名称唯一性、批次状态机、scope_resolver 三种范围类型）
- Controller 集成测试：happy path + 403 拒绝 + 422 校验失败
- 前端：一期手动验证，4 个页面量少
