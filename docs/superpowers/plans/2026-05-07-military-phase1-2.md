# 军训管理平台阶段1+2实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 基于 Ruoyi-FastAPI 框架，新建 4 张军训业务表并改造 sys_user，实现组织架构（行政树/编制树）和角色授权体系。

**Architecture:** 复用 Ruoyi 现有 DO/DAO/Service/Controller 四层模式，新建 module_military 子模块，通过 APIRouterPro 自动注册路由。前端沿用 `src/api/military/` + `src/views/military/` 结构。

**Tech Stack:** Python 3.10+, FastAPI, SQLAlchemy 2.x async, Pydantic v2, Alembic, Vue 3, Element Plus, Pinia

---

## 文件结构概览

```
新增文件:
  military-train-backend/module_military/
    entity/do/
      training_batch_do.py          # SysTrainingBatch
      military_unit_do.py           # SysMilitaryUnit
      military_assignment_do.py     # SysMilitaryAssignment
      military_role_assignment_do.py  # SysMilitaryRoleAssignment
    entity/vo/
      training_batch_vo.py
      military_unit_vo.py
      military_assignment_vo.py
      military_role_assignment_vo.py
    dao/
      training_batch_dao.py
      military_unit_dao.py
      military_assignment_dao.py
      military_role_assignment_dao.py
    service/
      training_batch_service.py
      military_unit_service.py
      military_assignment_service.py
      military_role_assignment_service.py
    controller/
      training_batch_controller.py
      military_unit_controller.py
      military_assignment_controller.py
      military_role_assignment_controller.py
  military-train-frontend/src/
    api/military/
      trainingBatch.js
      militaryUnit.js
      militaryAssignment.js
      militaryRoleAssignment.js
    views/military/
      training_batch/index.vue
      military_unit/index.vue
      military_assignment/index.vue
      military_role_assignment/index.vue
  military-train-backend/alembic/versions/
    xxxx_add_military_org_and_role.py
  military-train-backend/sql/
    military_seed_dict.sql

修改文件:
  military-train-backend/module_admin/entity/do/user_do.py
  military-train-backend/module_admin/entity/vo/user_vo.py
  military-train-frontend/src/router/index.js
```

---

### Task 1: 创建 module_military 目录结构

**Files:**
- Create: `military-train-backend/module_military/entity/do/__init__.py`
- Create: `military-train-backend/module_military/entity/vo/__init__.py`
- Create: `military-train-backend/module_military/dao/__init__.py`
- Create: `military-train-backend/module_military/service/__init__.py`
- Create: `military-train-backend/module_military/controller/__init__.py`

- [ ] **Step 1: 创建空 __init__.py 文件**

```bash
mkdir -p military-train-backend/module_military/{entity/{do,vo},dao,service,controller}
touch military-train-backend/module_military/entity/do/__init__.py
touch military-train-backend/module_military/entity/vo/__init__.py
touch military-train-backend/module_military/dao/__init__.py
touch military-train-backend/module_military/service/__init__.py
touch military-train-backend/module_military/controller/__init__.py
```

- [ ] **Step 2: 提交**

```bash
git add military-train-backend/module_military/
git commit -m "chore: init module_military directory structure"
```

---

### Task 2: 创建 Alembic Migration

**Files:**
- Create: `military-train-backend/alembic/versions/xxxx_add_military_org_and_role.py`

- [ ] **Step 1: 生成空 migration 文件**

```bash
cd military-train-backend && alembic revision -m "add_military_org_and_role"
```

- [ ] **Step 2: 编写 migration upgrade 内容**

```python
"""add_military_org_and_role

Revision ID: <auto>
Revises: <auto>
Create Date: <auto>

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = '<rev_id>'
down_revision: Union[str, None] = '<prev_rev>'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # 1. sys_training_batches
    op.create_table(
        'sys_training_batches',
        sa.Column('id', sa.BigInteger(), primary_key=True, autoincrement=True, comment='主键'),
        sa.Column('name', sa.String(100), nullable=False, comment='批次名称'),
        sa.Column('code', sa.String(50), nullable=False, comment='批次编码'),
        sa.Column('status', sa.String(20), server_default='draft', comment='draft/active/completed/archived'),
        sa.Column('start_date', sa.Date(), nullable=True, comment='计划开始日期'),
        sa.Column('end_date', sa.Date(), nullable=True, comment='计划结束日期'),
        sa.Column('actual_start_date', sa.Date(), nullable=True, comment='实际开始日期'),
        sa.Column('actual_end_date', sa.Date(), nullable=True, comment='实际结束日期'),
        sa.Column('version', sa.Integer(), server_default='0', comment='乐观锁版本号'),
        sa.Column('del_flag', sa.CHAR(1), server_default='0', comment='删除标志'),
        sa.Column('create_by', sa.String(64), server_default="''", comment='创建者'),
        sa.Column('create_time', sa.DateTime(), comment='创建时间'),
        sa.Column('update_by', sa.String(64), server_default="''", comment='更新者'),
        sa.Column('update_time', sa.DateTime(), comment='更新时间'),
    )
    op.create_unique_constraint('uq_training_batches_code', 'sys_training_batches', ['code'])
    op.create_index('idx_training_batches_status_active', 'sys_training_batches', ['status'],
                    postgresql_where=sa.text("status='active' AND del_flag='0'"))

    # 2. sys_military_units
    op.create_table(
        'sys_military_units',
        sa.Column('id', sa.BigInteger(), primary_key=True, autoincrement=True, comment='主键'),
        sa.Column('training_batch_id', sa.BigInteger(), nullable=False, comment='所属批次'),
        sa.Column('parent_id', sa.BigInteger(), nullable=True, comment='上级编制'),
        sa.Column('unit_type', sa.String(20), nullable=False, comment='regiment/battalion/company/platoon'),
        sa.Column('name', sa.String(100), nullable=False, comment='编制名称'),
        sa.Column('code', sa.String(50), nullable=True, comment='编码'),
        sa.Column('sort_order', sa.Integer(), server_default='0', comment='同级排序'),
        sa.Column('is_active', sa.Boolean(), server_default=sa.text('True'), comment='是否启用'),
        sa.Column('del_flag', sa.CHAR(1), server_default='0', comment='删除标志'),
        sa.Column('create_by', sa.String(64), server_default="''", comment='创建者'),
        sa.Column('create_time', sa.DateTime(), comment='创建时间'),
        sa.Column('update_by', sa.String(64), server_default="''", comment='更新者'),
        sa.Column('update_time', sa.DateTime(), comment='更新时间'),
    )
    op.create_index('idx_military_units_batch_parent', 'sys_military_units', ['training_batch_id', 'parent_id'])

    # 3. sys_military_assignments
    op.create_table(
        'sys_military_assignments',
        sa.Column('id', sa.BigInteger(), primary_key=True, autoincrement=True, comment='主键'),
        sa.Column('user_id', sa.BigInteger(), nullable=False, comment='人员 FK→sys_user'),
        sa.Column('military_unit_id', sa.BigInteger(), nullable=False, comment='编制 FK→sys_military_units'),
        sa.Column('training_batch_id', sa.BigInteger(), nullable=False, comment='批次'),
        sa.Column('assigned_at', sa.DateTime(), server_default=sa.text('CURRENT_TIMESTAMP'), comment='分配时间'),
        sa.Column('removed_at', sa.DateTime(), nullable=True, comment='移除时间 NULL=当前有效'),
        sa.Column('assigned_by', sa.BigInteger(), nullable=True, comment='操作人'),
        sa.Column('del_flag', sa.CHAR(1), server_default='0', comment='删除标志'),
        sa.Column('create_by', sa.String(64), server_default="''", comment='创建者'),
        sa.Column('create_time', sa.DateTime(), comment='创建时间'),
        sa.Column('update_by', sa.String(64), server_default="''", comment='更新者'),
        sa.Column('update_time', sa.DateTime(), comment='更新时间'),
    )
    op.create_index('idx_assignments_user_batch_active', 'sys_military_assignments', ['user_id', 'training_batch_id'],
                    postgresql_where=sa.text("removed_at IS NULL AND del_flag='0'"),
                    unique=True)

    # 4. sys_military_role_assignments
    op.create_table(
        'sys_military_role_assignments',
        sa.Column('id', sa.BigInteger(), primary_key=True, autoincrement=True, comment='主键'),
        sa.Column('user_id', sa.BigInteger(), nullable=False, comment='人员 FK→sys_user'),
        sa.Column('role_code', sa.String(50), nullable=False, comment='角色编码'),
        sa.Column('scope_type', sa.String(20), nullable=False, comment='global/academic/military'),
        sa.Column('scope_dept_id', sa.BigInteger(), nullable=True, comment='学术组织范围 FK→sys_dept'),
        sa.Column('scope_military_unit_id', sa.BigInteger(), nullable=True, comment='军事组织范围 FK→sys_military_units'),
        sa.Column('scope_depth', sa.String(20), server_default='self', comment='self/children/subtree'),
        sa.Column('training_batch_id', sa.BigInteger(), nullable=False, comment='批次'),
        sa.Column('is_active', sa.Boolean(), server_default=sa.text('True'), comment='是否生效'),
        sa.Column('granted_at', sa.DateTime(), server_default=sa.text('CURRENT_TIMESTAMP'), comment='授权时间'),
        sa.Column('revoked_at', sa.DateTime(), nullable=True, comment='撤销时间'),
        sa.Column('granted_by', sa.BigInteger(), nullable=True, comment='授权人'),
        sa.Column('del_flag', sa.CHAR(1), server_default='0', comment='删除标志'),
        sa.Column('create_by', sa.String(64), server_default="''", comment='创建者'),
        sa.Column('create_time', sa.DateTime(), comment='创建时间'),
        sa.Column('update_by', sa.String(64), server_default="''", comment='更新者'),
        sa.Column('update_time', sa.DateTime(), comment='更新时间'),
    )
    op.create_index('idx_role_assignments_user_batch', 'sys_military_role_assignments', ['user_id', 'training_batch_id'])

    # 5. sys_user 扩展
    op.add_column('sys_user', sa.Column('student_no', sa.String(30), nullable=True, comment='学号'))
    op.add_column('sys_user', sa.Column('employee_no', sa.String(30), nullable=True, comment='工号'))
    op.add_column('sys_user', sa.Column('gender', sa.String(5), nullable=True, comment='male/female'))


def downgrade() -> None:
    op.drop_column('sys_user', 'gender')
    op.drop_column('sys_user', 'employee_no')
    op.drop_column('sys_user', 'student_no')
    op.drop_table('sys_military_role_assignments')
    op.drop_table('sys_military_assignments')
    op.drop_table('sys_military_units')
    op.drop_table('sys_training_batches')
```

- [ ] **Step 3: 运行 migration 验证**

```bash
cd military-train-backend && alembic upgrade head
```

预期: 表创建成功，无报错

- [ ] **Step 4: 提交**

```bash
git add military-train-backend/alembic/versions/xxxx_add_military_org_and_role.py
git commit -m "feat: add military tables migration (training batches, units, assignments, role assignments)"
```

---

### Task 3: 创建种子数据 SQL

**Files:**
- Create: `military-train-backend/sql/military_seed_dict.sql`

- [ ] **Step 1: 编写字典种子数据 SQL**

```sql
-- 军训角色编码
INSERT INTO sys_dict_type (dict_name, dict_type, status, create_by, create_time, update_by, update_time)
VALUES ('军训角色编码', 'military_role_code', '0', 'admin', NOW(), 'admin', NOW());

INSERT INTO sys_dict_data (dict_type, dict_label, dict_value, list_class, is_default, status, create_by, create_time, update_by, update_time)
VALUES
('military_role_code', '管理员', 'admin', '', 'N', '0', 'admin', NOW(), 'admin', NOW()),
('military_role_code', '学校领导', 'school_leader', '', 'N', '0', 'admin', NOW(), 'admin', NOW()),
('military_role_code', '辅导员', 'counselor', '', 'N', '0', 'admin', NOW(), 'admin', NOW()),
('military_role_code', '学院领导', 'college_leader', '', 'N', '0', 'admin', NOW(), 'admin', NOW()),
('military_role_code', '参训学生', 'student', '', 'N', '0', 'admin', NOW(), 'admin', NOW()),
('military_role_code', '小教员', 'assistant_instructor', '', 'N', '0', 'admin', NOW(), 'admin', NOW()),
('military_role_code', '医疗保障组', 'medical_support', '', 'N', '0', 'admin', NOW(), 'admin', NOW());

-- 行政单位类型
INSERT INTO sys_dict_type (dict_name, dict_type, status, create_by, create_time, update_by, update_time)
VALUES ('行政单位类型', 'military_academic_unit_type', '0', 'admin', NOW(), 'admin', NOW());

INSERT INTO sys_dict_data (dict_type, dict_label, dict_value, list_class, is_default, status, create_by, create_time, update_by, update_time)
VALUES
('military_academic_unit_type', '学校', 'school', '', 'N', '0', 'admin', NOW(), 'admin', NOW()),
('military_academic_unit_type', '学院', 'college', '', 'N', '0', 'admin', NOW(), 'admin', NOW()),
('military_academic_unit_type', '专业', 'major', '', 'N', '0', 'admin', NOW(), 'admin', NOW()),
('military_academic_unit_type', '班级', 'class', '', 'N', '0', 'admin', NOW(), 'admin', NOW());

-- 编制类型
INSERT INTO sys_dict_type (dict_name, dict_type, status, create_by, create_time, update_by, update_time)
VALUES ('编制类型', 'military_unit_type', '0', 'admin', NOW(), 'admin', NOW());

INSERT INTO sys_dict_data (dict_type, dict_label, dict_value, list_class, is_default, status, create_by, create_time, update_by, update_time)
VALUES
('military_unit_type', '团', 'regiment', '', 'N', '0', 'admin', NOW(), 'admin', NOW()),
('military_unit_type', '营', 'battalion', '', 'N', '0', 'admin', NOW(), 'admin', NOW()),
('military_unit_type', '连', 'company', '', 'N', '0', 'admin', NOW(), 'admin', NOW()),
('military_unit_type', '排', 'platoon', '', 'N', '0', 'admin', NOW(), 'admin', NOW());

-- 军训菜单
INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, update_by, update_time)
VALUES ('军训管理', 0, 10, 'military', NULL, 1, 0, 'M', '0', '0', NULL, 'guide', 'admin', NOW(), 'admin', NOW());

SET @military_menu_id = LAST_INSERT_ID();

INSERT INTO sys_menu (menu_name, parent_id, order_num, path, component, is_frame, is_cache, menu_type, visible, status, perms, icon, create_by, create_time, update_by, update_time)
VALUES
('军训批次', @military_menu_id, 1, 'training-batches', 'military/training_batch/index', 1, 0, 'C', '0', '0', 'military:training_batch:list', 'list', 'admin', NOW(), 'admin', NOW()),
('编制管理', @military_menu_id, 2, 'military-units', 'military/military_unit/index', 1, 0, 'C', '0', '0', 'military:military_unit:list', 'tree', 'admin', NOW(), 'admin', NOW()),
('编制分配', @military_menu_id, 3, 'assignments', 'military/military_assignment/index', 1, 0, 'C', '0', '0', 'military:assignment:list', 'people', 'admin', NOW(), 'admin', NOW()),
('角色授权', @military_menu_id, 4, 'role-assignments', 'military/military_role_assignment/index', 1, 0, 'C', '0', '0', 'military:role_assignment:list', 'role', 'admin', NOW(), 'admin', NOW());
```

- [ ] **Step 2: 提交**

```bash
git add military-train-backend/sql/military_seed_dict.sql
git commit -m "feat: add military seed data SQL (dict types, menu entries)"
```

---

### Task 4: TrainingBatch DO 模型

**Files:**
- Create: `military-train-backend/module_military/entity/do/training_batch_do.py`

- [ ] **Step 1: 编写 SysTrainingBatch DO**

```python
from datetime import datetime, date

from sqlalchemy import BigInteger, CHAR, Column, Date, DateTime, Integer, String
from sqlalchemy.ext.asyncio import AsyncAttrs

from config.database import Base


class SysTrainingBatch(Base):
    __tablename__ = 'sys_training_batches'
    __table_args__ = (
        {'comment': '军训批次表'}
        if Base.__name__ == 'Base'
        else {'comment': '军训批次表', 'extend_existing': True}
    )

    id = Column(BigInteger, primary_key=True, autoincrement=True, comment='主键')
    name = Column(String(100), nullable=False, comment='批次名称')
    code = Column(String(50), nullable=False, unique=True, comment='批次编码')
    status = Column(String(20), server_default='draft', comment='draft/active/completed/archived')
    start_date = Column(Date, nullable=True, comment='计划开始日期')
    end_date = Column(Date, nullable=True, comment='计划结束日期')
    actual_start_date = Column(Date, nullable=True, comment='实际开始日期')
    actual_end_date = Column(Date, nullable=True, comment='实际结束日期')
    version = Column(Integer, server_default='0', comment='乐观锁版本号')
    del_flag = Column(CHAR(1), server_default='0', comment='删除标志')
    create_by = Column(String(64), server_default="''", comment='创建者')
    create_time = Column(DateTime, default=datetime.now(), comment='创建时间')
    update_by = Column(String(64), server_default="''", comment='更新者')
    update_time = Column(DateTime, default=datetime.now(), comment='更新时间')
```

- [ ] **Step 2: 提交**

```bash
git add military-train-backend/module_military/entity/do/training_batch_do.py
git commit -m "feat: add SysTrainingBatch DO model"
```

---

### Task 5: MilitaryUnit DO 模型

**Files:**
- Create: `military-train-backend/module_military/entity/do/military_unit_do.py`

- [ ] **Step 1: 编写 SysMilitaryUnit DO**

```python
from datetime import datetime

from sqlalchemy import BigInteger, Boolean, CHAR, Column, DateTime, Integer, String

from config.database import Base


class SysMilitaryUnit(Base):
    __tablename__ = 'sys_military_units'
    __table_args__ = (
        {'comment': '军训编制表'}
        if Base.__name__ == 'Base'
        else {'comment': '军训编制表', 'extend_existing': True}
    )

    id = Column(BigInteger, primary_key=True, autoincrement=True, comment='主键')
    training_batch_id = Column(BigInteger, nullable=False, comment='所属批次')
    parent_id = Column(BigInteger, nullable=True, comment='上级编制')
    unit_type = Column(String(20), nullable=False, comment='regiment/battalion/company/platoon')
    name = Column(String(100), nullable=False, comment='编制名称')
    code = Column(String(50), nullable=True, comment='编码')
    sort_order = Column(Integer, server_default='0', comment='同级排序')
    is_active = Column(Boolean, server_default='1', comment='是否启用')
    del_flag = Column(CHAR(1), server_default='0', comment='删除标志')
    create_by = Column(String(64), server_default="''", comment='创建者')
    create_time = Column(DateTime, default=datetime.now(), comment='创建时间')
    update_by = Column(String(64), server_default="''", comment='更新者')
    update_time = Column(DateTime, default=datetime.now(), comment='更新时间')
```

- [ ] **Step 2: 提交**

```bash
git add military-train-backend/module_military/entity/do/military_unit_do.py
git commit -m "feat: add SysMilitaryUnit DO model"
```

---

### Task 6: MilitaryAssignment DO 模型

**Files:**
- Create: `military-train-backend/module_military/entity/do/military_assignment_do.py`

- [ ] **Step 1: 编写 SysMilitaryAssignment DO**

```python
from datetime import datetime

from sqlalchemy import BigInteger, CHAR, Column, DateTime, String

from config.database import Base


class SysMilitaryAssignment(Base):
    __tablename__ = 'sys_military_assignments'
    __table_args__ = (
        {'comment': '军训编制分配表'}
        if Base.__name__ == 'Base'
        else {'comment': '军训编制分配表', 'extend_existing': True}
    )

    id = Column(BigInteger, primary_key=True, autoincrement=True, comment='主键')
    user_id = Column(BigInteger, nullable=False, comment='人员 FK→sys_user')
    military_unit_id = Column(BigInteger, nullable=False, comment='编制 FK→sys_military_units')
    training_batch_id = Column(BigInteger, nullable=False, comment='批次')
    assigned_at = Column(DateTime, default=datetime.now(), comment='分配时间')
    removed_at = Column(DateTime, nullable=True, comment='移除时间 NULL=当前有效')
    assigned_by = Column(BigInteger, nullable=True, comment='操作人')
    del_flag = Column(CHAR(1), server_default='0', comment='删除标志')
    create_by = Column(String(64), server_default="''", comment='创建者')
    create_time = Column(DateTime, default=datetime.now(), comment='创建时间')
    update_by = Column(String(64), server_default="''", comment='更新者')
    update_time = Column(DateTime, default=datetime.now(), comment='更新时间')
```

- [ ] **Step 2: 提交**

```bash
git add military-train-backend/module_military/entity/do/military_assignment_do.py
git commit -m "feat: add SysMilitaryAssignment DO model"
```

---

### Task 7: MilitaryRoleAssignment DO 模型

**Files:**
- Create: `military-train-backend/module_military/entity/do/military_role_assignment_do.py`

- [ ] **Step 1: 编写 SysMilitaryRoleAssignment DO**

```python
from datetime import datetime

from sqlalchemy import BigInteger, Boolean, CHAR, Column, DateTime, String

from config.database import Base


class SysMilitaryRoleAssignment(Base):
    __tablename__ = 'sys_military_role_assignments'
    __table_args__ = (
        {'comment': '军训角色授权表'}
        if Base.__name__ == 'Base'
        else {'comment': '军训角色授权表', 'extend_existing': True}
    )

    id = Column(BigInteger, primary_key=True, autoincrement=True, comment='主键')
    user_id = Column(BigInteger, nullable=False, comment='人员 FK→sys_user')
    role_code = Column(String(50), nullable=False, comment='角色编码')
    scope_type = Column(String(20), nullable=False, comment='global/academic/military')
    scope_dept_id = Column(BigInteger, nullable=True, comment='学术组织范围 FK→sys_dept')
    scope_military_unit_id = Column(BigInteger, nullable=True, comment='军事组织范围 FK→sys_military_units')
    scope_depth = Column(String(20), server_default='self', comment='self/children/subtree')
    training_batch_id = Column(BigInteger, nullable=False, comment='批次')
    is_active = Column(Boolean, server_default='1', comment='是否生效')
    granted_at = Column(DateTime, default=datetime.now(), comment='授权时间')
    revoked_at = Column(DateTime, nullable=True, comment='撤销时间')
    granted_by = Column(BigInteger, nullable=True, comment='授权人')
    del_flag = Column(CHAR(1), server_default='0', comment='删除标志')
    create_by = Column(String(64), server_default="''", comment='创建者')
    create_time = Column(DateTime, default=datetime.now(), comment='创建时间')
    update_by = Column(String(64), server_default="''", comment='更新者')
    update_time = Column(DateTime, default=datetime.now(), comment='更新时间')
```

- [ ] **Step 2: 提交**

```bash
git add military-train-backend/module_military/entity/do/military_role_assignment_do.py
git commit -m "feat: add SysMilitaryRoleAssignment DO model"
```

---

### Task 8: 扩展 SysUser DO + VO

**Files:**
- Modify: `military-train-backend/module_admin/entity/do/user_do.py`
- Modify: `military-train-backend/module_admin/entity/vo/user_vo.py`

- [ ] **Step 1: sys_user DO 加 3 列**

Edit `military-train-backend/module_admin/entity/do/user_do.py`，在 `remark` 字段上方添加:

```python
    student_no = Column(String(30), nullable=True, comment='学号')
    employee_no = Column(String(30), nullable=True, comment='工号')
    gender = Column(String(5), nullable=True, comment='male/female')
```

- [ ] **Step 2: sys_user VO 加 3 字段**

Edit `military-train-backend/module_admin/entity/vo/user_vo.py`，在 `UserModel` 类的 `remark` 字段上方添加:

```python
    student_no: str | None = Field(default=None, description='学号')
    employee_no: str | None = Field(default=None, description='工号')
    gender: str | None = Field(default=None, description='male/female')
```

- [ ] **Step 3: 提交**

```bash
git add military-train-backend/module_admin/entity/do/user_do.py military-train-backend/module_admin/entity/vo/user_vo.py
git commit -m "feat: add student_no, employee_no, gender to sys_user"
```

---

### Task 9: TrainingBatch VO 模型

**Files:**
- Create: `military-train-backend/module_military/entity/vo/training_batch_vo.py`

- [ ] **Step 1: 编写 VO**

```python
from datetime import date, datetime
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field
from pydantic.alias_generators import to_camel


class TrainingBatchModel(BaseModel):
    model_config = ConfigDict(alias_generator=to_camel, from_attributes=True)

    id: int | None = Field(default=None, description='主键')
    name: str | None = Field(default=None, description='批次名称')
    code: str | None = Field(default=None, description='批次编码')
    status: str | None = Field(default=None, description='draft/active/completed/archived')
    start_date: date | None = Field(default=None, description='计划开始日期')
    end_date: date | None = Field(default=None, description='计划结束日期')
    actual_start_date: date | None = Field(default=None, description='实际开始日期')
    actual_end_date: date | None = Field(default=None, description='实际结束日期')
    version: int | None = Field(default=None, description='乐观锁版本号')
    del_flag: str | None = Field(default=None, description='删除标志')
    create_by: str | None = Field(default=None, description='创建者')
    create_time: datetime | None = Field(default=None, description='创建时间')
    update_by: str | None = Field(default=None, description='更新者')
    update_time: datetime | None = Field(default=None, description='更新时间')


class TrainingBatchQueryModel(BaseModel):
    model_config = ConfigDict(alias_generator=to_camel)

    name: str | None = Field(default=None, description='批次名称')
    code: str | None = Field(default=None, description='批次编码')
    status: str | None = Field(default=None, description='批次状态')


class TrainingBatchStatusModel(BaseModel):
    model_config = ConfigDict(alias_generator=to_camel)

    status: str = Field(description='目标状态 draft/active/completed/archived')
    version: int = Field(description='乐观锁版本号')
```

---

### Task 10: MilitaryUnit + MilitaryAssignment + MilitaryRoleAssignment VO 模型

**Files:**
- Create: `military-train-backend/module_military/entity/vo/military_unit_vo.py`
- Create: `military-train-backend/module_military/entity/vo/military_assignment_vo.py`
- Create: `military-train-backend/module_military/entity/vo/military_role_assignment_vo.py`

- [ ] **Step 1: 编写 MilitaryUnitVO**

`module_military/entity/vo/military_unit_vo.py`:
```python
from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field
from pydantic.alias_generators import to_camel


class MilitaryUnitModel(BaseModel):
    model_config = ConfigDict(alias_generator=to_camel, from_attributes=True)

    id: int | None = Field(default=None, description='主键')
    training_batch_id: int | None = Field(default=None, description='所属批次')
    parent_id: int | None = Field(default=None, description='上级编制')
    unit_type: str | None = Field(default=None, description='regiment/battalion/company/platoon')
    name: str | None = Field(default=None, description='编制名称')
    code: str | None = Field(default=None, description='编码')
    sort_order: int | None = Field(default=None, description='同级排序')
    is_active: bool | None = Field(default=None, description='是否启用')
    del_flag: str | None = Field(default=None, description='删除标志')
    create_by: str | None = Field(default=None, description='创建者')
    create_time: datetime | None = Field(default=None, description='创建时间')
    update_by: str | None = Field(default=None, description='更新者')
    update_time: datetime | None = Field(default=None, description='更新时间')


class MilitaryUnitTreeModel(BaseModel):
    model_config = ConfigDict(alias_generator=to_camel)

    id: int = Field(description='编制id')
    label: str = Field(description='编制名称')
    unit_type: str = Field(description='编制类型')
    parent_id: int | None = Field(default=None, description='父编制id')
    children: list['MilitaryUnitTreeModel'] | None = Field(default=None, description='子编制')


class MilitaryUnitQueryModel(BaseModel):
    model_config = ConfigDict(alias_generator=to_camel)

    training_batch_id: int | None = Field(default=None, description='批次id')
    unit_type: str | None = Field(default=None, description='编制类型')
    name: str | None = Field(default=None, description='编制名称')
```

- [ ] **Step 2: 编写 MilitaryAssignmentVO**

`module_military/entity/vo/military_assignment_vo.py`:
```python
from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field
from pydantic.alias_generators import to_camel


class MilitaryAssignmentModel(BaseModel):
    model_config = ConfigDict(alias_generator=to_camel, from_attributes=True)

    id: int | None = Field(default=None, description='主键')
    user_id: int | None = Field(default=None, description='人员id')
    military_unit_id: int | None = Field(default=None, description='编制id')
    training_batch_id: int | None = Field(default=None, description='批次id')
    assigned_at: datetime | None = Field(default=None, description='分配时间')
    removed_at: datetime | None = Field(default=None, description='移除时间')
    assigned_by: int | None = Field(default=None, description='操作人')
    del_flag: str | None = Field(default=None, description='删除标志')
    create_by: str | None = Field(default=None, description='创建者')
    create_time: datetime | None = Field(default=None, description='创建时间')
    update_by: str | None = Field(default=None, description='更新者')
    update_time: datetime | None = Field(default=None, description='更新时间')


class BatchAssignModel(BaseModel):
    model_config = ConfigDict(alias_generator=to_camel)

    military_unit_id: int = Field(description='编制id（排级）')
    training_batch_id: int = Field(description='批次id')
    user_ids: list[int] = Field(description='分配的用户id列表')


class MilitaryAssignmentQueryModel(BaseModel):
    model_config = ConfigDict(alias_generator=to_camel)

    training_batch_id: int | None = Field(default=None, description='批次id')
    military_unit_id: int | None = Field(default=None, description='编制id')
    user_name: str | None = Field(default=None, description='人员姓名')
```

- [ ] **Step 3: 编写 MilitaryRoleAssignmentVO**

`module_military/entity/vo/military_role_assignment_vo.py`:
```python
from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field
from pydantic.alias_generators import to_camel


class MilitaryRoleAssignmentModel(BaseModel):
    model_config = ConfigDict(alias_generator=to_camel, from_attributes=True)

    id: int | None = Field(default=None, description='主键')
    user_id: int | None = Field(default=None, description='人员id')
    role_code: str | None = Field(default=None, description='角色编码')
    scope_type: str | None = Field(default=None, description='global/academic/military')
    scope_dept_id: int | None = Field(default=None, description='学术组织范围')
    scope_military_unit_id: int | None = Field(default=None, description='军事组织范围')
    scope_depth: str | None = Field(default=None, description='self/children/subtree')
    training_batch_id: int | None = Field(default=None, description='批次id')
    is_active: bool | None = Field(default=None, description='是否生效')
    granted_at: datetime | None = Field(default=None, description='授权时间')
    revoked_at: datetime | None = Field(default=None, description='撤销时间')
    granted_by: int | None = Field(default=None, description='授权人')


class MilitaryRoleAssignmentQueryModel(BaseModel):
    model_config = ConfigDict(alias_generator=to_camel)

    training_batch_id: int | None = Field(default=None, description='批次id')
    role_code: str | None = Field(default=None, description='角色编码')
    user_id: int | None = Field(default=None, description='人员id')
```

- [ ] **Step 4: 提交**

```bash
git add military-train-backend/module_military/entity/vo/
git commit -m "feat: add MilitaryUnit, MilitaryAssignment, MilitaryRoleAssignment VO models"
```

---

### Task 11: TrainingBatch + MilitaryUnit DAO

**Files:**
- Create: `military-train-backend/module_military/dao/training_batch_dao.py`
- Create: `military-train-backend/module_military/dao/military_unit_dao.py`

- [ ] **Step 1: 编写 TrainingBatchDao**

`module_military/dao/training_batch_dao.py`:
```python
from collections.abc import Sequence

from sqlalchemy import func, select, update
from sqlalchemy.ext.asyncio import AsyncSession

from module_military.entity.do.training_batch_do import SysTrainingBatch
from module_military.entity.vo.training_batch_vo import TrainingBatchModel


class TrainingBatchDao:

    @classmethod
    async def get_by_id(cls, db: AsyncSession, batch_id: int) -> SysTrainingBatch | None:
        result = (await db.execute(
            select(SysTrainingBatch).where(SysTrainingBatch.id == batch_id, SysTrainingBatch.del_flag == '0')
        )).scalars().first()
        return result

    @classmethod
    async def get_by_code(cls, db: AsyncSession, code: str) -> SysTrainingBatch | None:
        result = (await db.execute(
            select(SysTrainingBatch).where(SysTrainingBatch.code == code, SysTrainingBatch.del_flag == '0')
        )).scalars().first()
        return result

    @classmethod
    async def get_active_batch(cls, db: AsyncSession) -> SysTrainingBatch | None:
        result = (await db.execute(
            select(SysTrainingBatch).where(SysTrainingBatch.status == 'active', SysTrainingBatch.del_flag == '0')
        )).scalars().first()
        return result

    @classmethod
    async def get_list(cls, db: AsyncSession, query: 'TrainingBatchQueryModel') -> Sequence[SysTrainingBatch]:
        stmt = select(SysTrainingBatch).where(SysTrainingBatch.del_flag == '0')
        if query.name:
            stmt = stmt.where(SysTrainingBatch.name.like(f'%{query.name}%'))
        if query.code:
            stmt = stmt.where(SysTrainingBatch.code.like(f'%{query.code}%'))
        if query.status:
            stmt = stmt.where(SysTrainingBatch.status == query.status)
        stmt = stmt.order_by(SysTrainingBatch.create_time.desc())
        result = (await db.execute(stmt)).scalars().all()
        return result

    @classmethod
    async def add(cls, db: AsyncSession, batch: TrainingBatchModel) -> SysTrainingBatch:
        db_batch = SysTrainingBatch(**batch.model_dump(exclude_unset=True))
        db.add(db_batch)
        await db.flush()
        return db_batch

    @classmethod
    async def update(cls, db: AsyncSession, batch: dict) -> None:
        await db.execute(update(SysTrainingBatch).where(SysTrainingBatch.id == batch['id']), [batch])

    @classmethod
    async def delete(cls, db: AsyncSession, batch: TrainingBatchModel) -> None:
        await db.execute(
            update(SysTrainingBatch).where(SysTrainingBatch.id == batch.id).values(
                del_flag='2', update_by=batch.update_by, update_time=batch.update_time
            )
        )

    @classmethod
    async def check_code_unique(cls, db: AsyncSession, code: str, exclude_id: int | None = None) -> bool:
        stmt = select(func.count(SysTrainingBatch.id)).where(
            SysTrainingBatch.code == code, SysTrainingBatch.del_flag == '0'
        )
        if exclude_id is not None:
            stmt = stmt.where(SysTrainingBatch.id != exclude_id)
        count = (await db.execute(stmt)).scalar()
        return count == 0
```

- [ ] **Step 2: 编写 MilitaryUnitDao**

`module_military/dao/military_unit_dao.py`:
```python
from collections.abc import Sequence

from sqlalchemy import func, select, update
from sqlalchemy.ext.asyncio import AsyncSession

from module_military.entity.do.military_unit_do import SysMilitaryUnit
from module_military.entity.vo.military_unit_vo import MilitaryUnitModel


class MilitaryUnitDao:

    @classmethod
    async def get_by_id(cls, db: AsyncSession, unit_id: int) -> SysMilitaryUnit | None:
        result = (await db.execute(
            select(SysMilitaryUnit).where(SysMilitaryUnit.id == unit_id, SysMilitaryUnit.del_flag == '0')
        )).scalars().first()
        return result

    @classmethod
    async def get_by_name_in_batch(cls, db: AsyncSession, name: str, batch_id: int, parent_id: int | None = None) -> SysMilitaryUnit | None:
        stmt = select(SysMilitaryUnit).where(
            SysMilitaryUnit.name == name,
            SysMilitaryUnit.training_batch_id == batch_id,
            SysMilitaryUnit.del_flag == '0',
        )
        if parent_id is not None:
            stmt = stmt.where(SysMilitaryUnit.parent_id == parent_id)
        result = (await db.execute(stmt)).scalars().first()
        return result

    @classmethod
    async def get_tree_by_batch(cls, db: AsyncSession, batch_id: int) -> Sequence[SysMilitaryUnit]:
        result = (await db.execute(
            select(SysMilitaryUnit).where(
                SysMilitaryUnit.training_batch_id == batch_id,
                SysMilitaryUnit.del_flag == '0',
            ).order_by(SysMilitaryUnit.sort_order)
        )).scalars().all()
        return result

    @classmethod
    async def get_children(cls, db: AsyncSession, parent_id: int) -> Sequence[SysMilitaryUnit]:
        result = (await db.execute(
            select(SysMilitaryUnit).where(
                SysMilitaryUnit.parent_id == parent_id, SysMilitaryUnit.del_flag == '0'
            )
        )).scalars().all()
        return result

    @classmethod
    async def count_children(cls, db: AsyncSession, parent_id: int) -> int:
        count = (await db.execute(
            select(func.count(SysMilitaryUnit.id)).where(
                SysMilitaryUnit.parent_id == parent_id, SysMilitaryUnit.del_flag == '0'
            ).limit(1)
        )).scalar()
        return count

    @classmethod
    async def add(cls, db: AsyncSession, unit: MilitaryUnitModel) -> SysMilitaryUnit:
        db_unit = SysMilitaryUnit(**unit.model_dump(exclude_unset=True))
        db.add(db_unit)
        await db.flush()
        return db_unit

    @classmethod
    async def update(cls, db: AsyncSession, unit: dict) -> None:
        await db.execute(update(SysMilitaryUnit).where(SysMilitaryUnit.id == unit['id']), [unit])

    @classmethod
    async def delete(cls, db: AsyncSession, unit: MilitaryUnitModel) -> None:
        await db.execute(
            update(SysMilitaryUnit).where(SysMilitaryUnit.id == unit.id).values(
                del_flag='2', update_by=unit.update_by, update_time=unit.update_time
            )
        )
```

- [ ] **Step 3: 提交**

```bash
git add military-train-backend/module_military/dao/training_batch_dao.py military-train-backend/module_military/dao/military_unit_dao.py
git commit -m "feat: add TrainingBatch and MilitaryUnit DAO"
```

---

### Task 12: MilitaryAssignment + MilitaryRoleAssignment DAO

**Files:**
- Create: `military-train-backend/module_military/dao/military_assignment_dao.py`
- Create: `military-train-backend/module_military/dao/military_role_assignment_dao.py`

- [ ] **Step 1: 编写 MilitaryAssignmentDao**

`module_military/dao/military_assignment_dao.py`:
```python
from collections.abc import Sequence

from sqlalchemy import and_, func, or_, select, update
from sqlalchemy.ext.asyncio import AsyncSession

from module_military.entity.do.military_assignment_do import SysMilitaryAssignment
from module_military.entity.do.military_unit_do import SysMilitaryUnit
from module_military.entity.vo.military_assignment_vo import MilitaryAssignmentModel


class MilitaryAssignmentDao:

    @classmethod
    async def get_active_by_user_batch(cls, db: AsyncSession, user_id: int, batch_id: int) -> SysMilitaryAssignment | None:
        result = (await db.execute(
            select(SysMilitaryAssignment).where(
                SysMilitaryAssignment.user_id == user_id,
                SysMilitaryAssignment.training_batch_id == batch_id,
                SysMilitaryAssignment.removed_at.is_(None),
                SysMilitaryAssignment.del_flag == '0',
            )
        )).scalars().first()
        return result

    @classmethod
    async def get_list_by_unit(cls, db: AsyncSession, unit_id: int) -> Sequence[SysMilitaryAssignment]:
        result = (await db.execute(
            select(SysMilitaryAssignment).where(
                SysMilitaryAssignment.military_unit_id == unit_id,
                SysMilitaryAssignment.removed_at.is_(None),
                SysMilitaryAssignment.del_flag == '0',
            )
        )).scalars().all()
        return result

    @classmethod
    async def get_user_ids_in_military_subtree(cls, db: AsyncSession, unit_id: int) -> list[int]:
        # 递归查询编制子树下的所有人员
        descendants = await cls._get_unit_descendants(db, unit_id)
        unit_ids = [unit_id] + descendants
        result = (await db.execute(
            select(SysMilitaryAssignment.user_id).where(
                SysMilitaryAssignment.military_unit_id.in_(unit_ids),
                SysMilitaryAssignment.removed_at.is_(None),
                SysMilitaryAssignment.del_flag == '0',
            ).distinct()
        )).scalars().all()
        return list(result)

    @classmethod
    async def _get_unit_descendants(cls, db: AsyncSession, parent_id: int) -> list[int]:
        children = (await db.execute(
            select(SysMilitaryUnit.id).where(
                SysMilitaryUnit.parent_id == parent_id, SysMilitaryUnit.del_flag == '0'
            )
        )).scalars().all()
        ids = list(children)
        for child_id in list(ids):
            ids.extend(await cls._get_unit_descendants(db, child_id))
        return ids

    @classmethod
    async def batch_add(cls, db: AsyncSession, assignments: list[MilitaryAssignmentModel]) -> list[SysMilitaryAssignment]:
        db_assignments = [SysMilitaryAssignment(**a.model_dump(exclude_unset=True)) for a in assignments]
        db.add_all(db_assignments)
        await db.flush()
        return db_assignments

    @classmethod
    async def remove(cls, db: AsyncSession, assignment: MilitaryAssignmentModel) -> None:
        await db.execute(
            update(SysMilitaryAssignment).where(SysMilitaryAssignment.id == assignment.id).values(
                removed_at=assignment.removed_at, update_by=assignment.update_by, update_time=assignment.update_time
            )
        )
```

- [ ] **Step 2: 编写 MilitaryRoleAssignmentDao**

`module_military/dao/military_role_assignment_dao.py`:
```python
from collections.abc import Sequence

from sqlalchemy import func, select, update
from sqlalchemy.ext.asyncio import AsyncSession

from module_military.entity.do.military_role_assignment_do import SysMilitaryRoleAssignment
from module_military.entity.vo.military_role_assignment_vo import MilitaryRoleAssignmentModel


class MilitaryRoleAssignmentDao:

    @classmethod
    async def get_by_id(cls, db: AsyncSession, role_assignment_id: int) -> SysMilitaryRoleAssignment | None:
        result = (await db.execute(
            select(SysMilitaryRoleAssignment).where(
                SysMilitaryRoleAssignment.id == role_assignment_id, SysMilitaryRoleAssignment.del_flag == '0'
            )
        )).scalars().first()
        return result

    @classmethod
    async def get_active_by_user_batch_role(cls, db: AsyncSession, user_id: int, batch_id: int, role_code: str) -> SysMilitaryRoleAssignment | None:
        result = (await db.execute(
            select(SysMilitaryRoleAssignment).where(
                SysMilitaryRoleAssignment.user_id == user_id,
                SysMilitaryRoleAssignment.training_batch_id == batch_id,
                SysMilitaryRoleAssignment.role_code == role_code,
                SysMilitaryRoleAssignment.is_active.is_(True),
                SysMilitaryRoleAssignment.del_flag == '0',
            )
        )).scalars().first()
        return result

    @classmethod
    async def get_list(cls, db: AsyncSession, query: 'MilitaryRoleAssignmentQueryModel') -> Sequence[SysMilitaryRoleAssignment]:
        stmt = select(SysMilitaryRoleAssignment).where(
            SysMilitaryRoleAssignment.is_active.is_(True),
            SysMilitaryRoleAssignment.del_flag == '0',
        )
        if query.training_batch_id:
            stmt = stmt.where(SysMilitaryRoleAssignment.training_batch_id == query.training_batch_id)
        if query.role_code:
            stmt = stmt.where(SysMilitaryRoleAssignment.role_code == query.role_code)
        if query.user_id:
            stmt = stmt.where(SysMilitaryRoleAssignment.user_id == query.user_id)
        stmt = stmt.order_by(SysMilitaryRoleAssignment.granted_at.desc())
        result = (await db.execute(stmt)).scalars().all()
        return result

    @classmethod
    async def get_by_user_batch(cls, db: AsyncSession, user_id: int, batch_id: int) -> Sequence[SysMilitaryRoleAssignment]:
        result = (await db.execute(
            select(SysMilitaryRoleAssignment).where(
                SysMilitaryRoleAssignment.user_id == user_id,
                SysMilitaryRoleAssignment.training_batch_id == batch_id,
                SysMilitaryRoleAssignment.is_active.is_(True),
                SysMilitaryRoleAssignment.del_flag == '0',
            )
        )).scalars().all()
        return result

    @classmethod
    async def add(cls, db: AsyncSession, assignment: MilitaryRoleAssignmentModel) -> SysMilitaryRoleAssignment:
        db_assignment = SysMilitaryRoleAssignment(**assignment.model_dump(exclude_unset=True))
        db.add(db_assignment)
        await db.flush()
        return db_assignment

    @classmethod
    async def update(cls, db: AsyncSession, assignment: dict) -> None:
        await db.execute(
            update(SysMilitaryRoleAssignment).where(SysMilitaryRoleAssignment.id == assignment['id']), [assignment]
        )

    @classmethod
    async def revoke(cls, db: AsyncSession, assignment: MilitaryRoleAssignmentModel) -> None:
        await db.execute(
            update(SysMilitaryRoleAssignment).where(SysMilitaryRoleAssignment.id == assignment.id).values(
                is_active=False, revoked_at=assignment.revoked_at,
                update_by=assignment.update_by, update_time=assignment.update_time
            )
        )
```

- [ ] **Step 3: 提交**

```bash
git add military-train-backend/module_military/dao/military_assignment_dao.py military-train-backend/module_military/dao/military_role_assignment_dao.py
git commit -m "feat: add MilitaryAssignment and MilitaryRoleAssignment DAO"
```

---

### Task 13: TrainingBatch + MilitaryUnit Service

**Files:**
- Create: `military-train-backend/module_military/service/training_batch_service.py`
- Create: `military-train-backend/module_military/service/military_unit_service.py`

- [ ] **Step 1: 编写 TrainingBatchService**

`module_military/service/training_batch_service.py`:
```python
from collections.abc import Sequence
from typing import Any

from sqlalchemy.ext.asyncio import AsyncSession

from common.vo import CrudResponseModel
from exceptions.exception import ServiceException
from module_military.dao.training_batch_dao import TrainingBatchDao
from module_military.entity.vo.training_batch_vo import TrainingBatchModel, TrainingBatchQueryModel, TrainingBatchStatusModel
from utils.common_util import CamelCaseUtil


class TrainingBatchService:

    @classmethod
    async def get_list(cls, query_db: AsyncSession, query: TrainingBatchQueryModel) -> list[dict[str, Any]]:
        result = await TrainingBatchDao.get_list(query_db, query)
        return CamelCaseUtil.transform_result(result)

    @classmethod
    async def get_by_id(cls, query_db: AsyncSession, batch_id: int) -> TrainingBatchModel:
        batch = await TrainingBatchDao.get_by_id(query_db, batch_id)
        if not batch:
            raise ServiceException(message='批次不存在')
        return TrainingBatchModel(**CamelCaseUtil.transform_result(batch))

    @classmethod
    async def add(cls, query_db: AsyncSession, batch: TrainingBatchModel) -> CrudResponseModel:
        if not await TrainingBatchDao.check_code_unique(query_db, batch.code):
            raise ServiceException(message=f'批次编码 {batch.code} 已存在')
        try:
            await TrainingBatchDao.add(query_db, batch)
            await query_db.commit()
            return CrudResponseModel(is_success=True, message='新增成功')
        except Exception as e:
            await query_db.rollback()
            raise e

    @classmethod
    async def update(cls, query_db: AsyncSession, batch: TrainingBatchModel) -> CrudResponseModel:
        existing = await TrainingBatchDao.get_by_id(query_db, batch.id)
        if not existing:
            raise ServiceException(message='批次不存在')
        if not await TrainingBatchDao.check_code_unique(query_db, batch.code, batch.id):
            raise ServiceException(message=f'批次编码 {batch.code} 已存在')
        try:
            edit_batch = batch.model_dump(exclude_unset=True)
            await TrainingBatchDao.update(query_db, edit_batch)
            await query_db.commit()
            return CrudResponseModel(is_success=True, message='更新成功')
        except Exception as e:
            await query_db.rollback()
            raise e

    @classmethod
    async def delete_batch(cls, query_db: AsyncSession, batch: TrainingBatchModel) -> CrudResponseModel:
        existing = await TrainingBatchDao.get_by_id(query_db, batch.id)
        if not existing:
            raise ServiceException(message='批次不存在')
        if existing.status == 'active':
            raise ServiceException(message='激活中的批次不允许删除')
        if existing.status == 'completed':
            raise ServiceException(message='已完成的批次不允许删除')
        try:
            await TrainingBatchDao.delete(query_db, batch)
            await query_db.commit()
            return CrudResponseModel(is_success=True, message='删除成功')
        except Exception as e:
            await query_db.rollback()
            raise e

    @classmethod
    async def change_status(cls, query_db: AsyncSession, batch_id: int, status_model: TrainingBatchStatusModel) -> CrudResponseModel:
        existing = await TrainingBatchDao.get_by_id(query_db, batch_id)
        if not existing:
            raise ServiceException(message='批次不存在')
        from_status = existing.status
        to_status = status_model.status
        if from_status == to_status:
            raise ServiceException(message='批次状态未改变')

        valid_transitions = {
            'draft': ['active'],
            'active': ['completed'],
            'completed': ['active'],
        }
        if to_status not in valid_transitions.get(from_status, []):
            raise ServiceException(message=f'不允许从 {from_status} 切换到 {to_status}')

        try:
            await TrainingBatchDao.update(query_db, {'id': batch_id, 'status': to_status})
            await query_db.commit()
            return CrudResponseModel(is_success=True, message=f'状态切换成功: {from_status} -> {to_status}')
        except Exception as e:
            await query_db.rollback()
            raise e
```

- [ ] **Step 2: 编写 MilitaryUnitService**

`module_military/service/military_unit_service.py`:
```python
from collections.abc import Sequence
from typing import Any

from sqlalchemy.ext.asyncio import AsyncSession

from common.vo import CrudResponseModel
from exceptions.exception import ServiceException
from module_military.dao.military_unit_dao import MilitaryUnitDao
from module_military.entity.do.military_unit_do import SysMilitaryUnit
from module_military.entity.vo.military_unit_vo import MilitaryUnitModel, MilitaryUnitTreeModel, MilitaryUnitQueryModel
from utils.common_util import CamelCaseUtil


class MilitaryUnitService:

    @classmethod
    async def get_tree(cls, query_db: AsyncSession, query: MilitaryUnitQueryModel) -> list[dict[str, Any]]:
        if not query.training_batch_id:
            raise ServiceException(message='请选择批次')
        unit_list = await MilitaryUnitDao.get_tree_by_batch(query_db, query.training_batch_id)
        tree = cls.list_to_tree(unit_list)
        return [t.model_dump(exclude_unset=True, by_alias=True) for t in tree]

    @classmethod
    async def get_by_id(cls, query_db: AsyncSession, unit_id: int) -> MilitaryUnitModel:
        unit = await MilitaryUnitDao.get_by_id(query_db, unit_id)
        if not unit:
            raise ServiceException(message='编制不存在')
        return MilitaryUnitModel(**CamelCaseUtil.transform_result(unit))

    @classmethod
    async def add(cls, query_db: AsyncSession, unit: MilitaryUnitModel) -> CrudResponseModel:
        existing = await MilitaryUnitDao.get_by_name_in_batch(query_db, unit.name, unit.training_batch_id, unit.parent_id)
        if existing:
            raise ServiceException(message=f'同级编制下名称 {unit.name} 已存在')
        try:
            await MilitaryUnitDao.add(query_db, unit)
            await query_db.commit()
            return CrudResponseModel(is_success=True, message='新增成功')
        except Exception as e:
            await query_db.rollback()
            raise e

    @classmethod
    async def update(cls, query_db: AsyncSession, unit: MilitaryUnitModel) -> CrudResponseModel:
        existing = await MilitaryUnitDao.get_by_id(query_db, unit.id)
        if not existing:
            raise ServiceException(message='编制不存在')
        if unit.id == unit.parent_id:
            raise ServiceException(message='上级编制不能是自己')
        try:
            edit_unit = unit.model_dump(exclude_unset=True)
            await MilitaryUnitDao.update(query_db, edit_unit)
            await query_db.commit()
            return CrudResponseModel(is_success=True, message='更新成功')
        except Exception as e:
            await query_db.rollback()
            raise e

    @classmethod
    async def delete(cls, query_db: AsyncSession, unit: MilitaryUnitModel) -> CrudResponseModel:
        existing = await MilitaryUnitDao.get_by_id(query_db, unit.id)
        if not existing:
            raise ServiceException(message='编制不存在')
        child_count = await MilitaryUnitDao.count_children(query_db, unit.id)
        if child_count > 0:
            raise ServiceException(message='存在下级编制，不允许删除')
        try:
            await MilitaryUnitDao.delete(query_db, unit)
            await query_db.commit()
            return CrudResponseModel(is_success=True, message='删除成功')
        except Exception as e:
            await query_db.rollback()
            raise e

    @classmethod
    def list_to_tree(cls, unit_list: Sequence[SysMilitaryUnit]) -> list[MilitaryUnitTreeModel]:
        tree_items = [
            MilitaryUnitTreeModel(id=u.id, label=u.name, unit_type=u.unit_type, parent_id=u.parent_id)
            for u in unit_list
        ]
        mapping: dict[int, MilitaryUnitTreeModel] = dict(zip([i.id for i in tree_items], tree_items))
        container: list[MilitaryUnitTreeModel] = []
        for d in tree_items:
            parent = mapping.get(d.parent_id)
            if parent is None:
                container.append(d)
            else:
                children = parent.children or []
                children.append(d)
                parent.children = children
        return container
```

- [ ] **Step 3: 提交**

```bash
git add military-train-backend/module_military/service/training_batch_service.py military-train-backend/module_military/service/military_unit_service.py
git commit -m "feat: add TrainingBatch and MilitaryUnit Service"
```

---

### Task 14: MilitaryAssignment + MilitaryRoleAssignment Service

**Files:**
- Create: `military-train-backend/module_military/service/military_assignment_service.py`
- Create: `military-train-backend/module_military/service/military_role_assignment_service.py`

- [ ] **Step 1: 编写 MilitaryAssignmentService**

`module_military/service/military_assignment_service.py`:
```python
from typing import Any

from sqlalchemy.ext.asyncio import AsyncSession

from common.vo import CrudResponseModel
from exceptions.exception import ServiceException
from module_military.dao.military_assignment_dao import MilitaryAssignmentDao
from module_military.entity.vo.military_assignment_vo import BatchAssignModel, MilitaryAssignmentModel, MilitaryAssignmentQueryModel
from utils.common_util import CamelCaseUtil


class MilitaryAssignmentService:

    @classmethod
    async def get_list(cls, query_db: AsyncSession, query: MilitaryAssignmentQueryModel) -> list[dict[str, Any]]:
        if not query.military_unit_id:
            raise ServiceException(message='请选择编制')
        result = await MilitaryAssignmentDao.get_list_by_unit(query_db, query.military_unit_id)
        return CamelCaseUtil.transform_result(result)

    @classmethod
    async def batch_assign(cls, query_db: AsyncSession, model: BatchAssignModel, assigned_by: int) -> CrudResponseModel:
        if not model.user_ids:
            raise ServiceException(message='请选择人员')
        try:
            new_assignments = []
            for user_id in model.user_ids:
                existing = await MilitaryAssignmentDao.get_active_by_user_batch(query_db, user_id, model.training_batch_id)
                if existing:
                    raise ServiceException(message=f'人员 {user_id} 在当前批次已有编制分配')
                new_assignments.append(MilitaryAssignmentModel(
                    user_id=user_id,
                    military_unit_id=model.military_unit_id,
                    training_batch_id=model.training_batch_id,
                    assigned_by=assigned_by,
                ))
            await MilitaryAssignmentDao.batch_add(query_db, new_assignments)
            await query_db.commit()
            return CrudResponseModel(is_success=True, message=f'成功分配 {len(model.user_ids)} 人')
        except ServiceException:
            await query_db.rollback()
            raise
        except Exception as e:
            await query_db.rollback()
            raise e

    @classmethod
    async def remove(cls, query_db: AsyncSession, assignment: MilitaryAssignmentModel) -> CrudResponseModel:
        existing = await MilitaryAssignmentDao.get_by_id(query_db, assignment.id)
        if not existing:
            raise ServiceException(message='分配记录不存在')
        try:
            await MilitaryAssignmentDao.remove(query_db, assignment)
            await query_db.commit()
            return CrudResponseModel(is_success=True, message='取消分配成功')
        except Exception as e:
            await query_db.rollback()
            raise e
```

- [ ] **Step 2: 编写 MilitaryRoleAssignmentService (含 scope_resolver)**

`module_military/service/military_role_assignment_service.py`:
```python
from typing import Any

from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import AsyncSession

from common.vo import CrudResponseModel
from exceptions.exception import ServiceException
from module_admin.entity.do.dept_do import SysDept
from module_admin.entity.do.user_do import SysUser
from module_military.dao.military_assignment_dao import MilitaryAssignmentDao
from module_military.dao.military_role_assignment_dao import MilitaryRoleAssignmentDao
from module_military.entity.do.military_role_assignment_do import SysMilitaryRoleAssignment
from module_military.entity.vo.military_role_assignment_vo import MilitaryRoleAssignmentModel, MilitaryRoleAssignmentQueryModel
from utils.common_util import CamelCaseUtil


class MilitaryRoleAssignmentService:

    @classmethod
    async def get_list(cls, query_db: AsyncSession, query: MilitaryRoleAssignmentQueryModel) -> list[dict[str, Any]]:
        result = await MilitaryRoleAssignmentDao.get_list(query_db, query)
        return CamelCaseUtil.transform_result(result)

    @classmethod
    async def grant(cls, query_db: AsyncSession, assignment: MilitaryRoleAssignmentModel) -> CrudResponseModel:
        existing = await MilitaryRoleAssignmentDao.get_active_by_user_batch_role(
            query_db, assignment.user_id, assignment.training_batch_id, assignment.role_code
        )
        if existing:
            raise ServiceException(message='该人员在同一批次下已拥有此角色')
        try:
            await MilitaryRoleAssignmentDao.add(query_db, assignment)
            await query_db.commit()
            return CrudResponseModel(is_success=True, message='授权成功')
        except Exception as e:
            await query_db.rollback()
            raise e

    @classmethod
    async def update(cls, query_db: AsyncSession, assignment: MilitaryRoleAssignmentModel) -> CrudResponseModel:
        existing = await MilitaryRoleAssignmentDao.get_by_id(query_db, assignment.id)
        if not existing:
            raise ServiceException(message='授权记录不存在')
        try:
            edit_data = assignment.model_dump(exclude_unset=True)
            await MilitaryRoleAssignmentDao.update(query_db, edit_data)
            await query_db.commit()
            return CrudResponseModel(is_success=True, message='更新成功')
        except Exception as e:
            await query_db.rollback()
            raise e

    @classmethod
    async def revoke(cls, query_db: AsyncSession, assignment: MilitaryRoleAssignmentModel) -> CrudResponseModel:
        existing = await MilitaryRoleAssignmentDao.get_by_id(query_db, assignment.id)
        if not existing:
            raise ServiceException(message='授权记录不存在')
        try:
            await MilitaryRoleAssignmentDao.revoke(query_db, assignment)
            await query_db.commit()
            return CrudResponseModel(is_success=True, message='撤销成功')
        except Exception as e:
            await query_db.rollback()
            raise e

    @classmethod
    async def resolve_scope_user_ids(cls, query_db: AsyncSession, assignment: SysMilitaryRoleAssignment) -> list[int]:
        """
        根据角色授权的组织范围，解析出可见的人员 ID 列表
        """
        if assignment.scope_type == 'global':
            result = (await query_db.execute(
                select(SysUser.user_id).where(SysUser.del_flag == '0')
            )).scalars().all()
            return list(result)

        elif assignment.scope_type == 'academic':
            dept_ids = await cls._get_dept_subtree_ids(query_db, assignment.scope_dept_id, assignment.scope_depth)
            result = (await query_db.execute(
                select(SysUser.user_id).where(SysUser.dept_id.in_(dept_ids), SysUser.del_flag == '0')
            )).scalars().all()
            return list(result)

        elif assignment.scope_type == 'military':
            if assignment.scope_depth == 'self':
                return await MilitaryAssignmentDao.get_user_ids_in_military_subtree(
                    query_db, assignment.scope_military_unit_id
                )
            else:
                # children/subtree: 递归查询编制子树
                return await MilitaryAssignmentDao.get_user_ids_in_military_subtree(
                    query_db, assignment.scope_military_unit_id
                )

        return []

    @classmethod
    async def _get_dept_subtree_ids(cls, db: AsyncSession, dept_id: int, depth: str) -> list[int]:
        if depth == 'self':
            return [dept_id]
        # children: 直接子节点
        children = (await db.execute(
            select(SysDept.dept_id).where(SysDept.parent_id == dept_id, SysDept.del_flag == '0')
        )).scalars().all()
        ids = [dept_id] + list(children)
        if depth == 'subtree':
            # 递归获取所有子孙节点
            for child_id in list(children):
                ids.extend(await cls._get_dept_subtree_ids(db, child_id, 'subtree'))
        return list(set(ids))
```

- [ ] **Step 3: 提交**

```bash
git add military-train-backend/module_military/service/military_assignment_service.py military-train-backend/module_military/service/military_role_assignment_service.py
git commit -m "feat: add MilitaryAssignment and MilitaryRoleAssignment Service with scope resolver"
```

---

### Task 15: TrainingBatch + MilitaryUnit Controller

**Files:**
- Create: `military-train-backend/module_military/controller/training_batch_controller.py`
- Create: `military-train-backend/module_military/controller/military_unit_controller.py`

- [ ] **Step 1: 编写 TrainingBatchController**

`module_military/controller/training_batch_controller.py`:
```python
from datetime import datetime
from typing import Annotated

from fastapi import Path, Query, Request, Response
from sqlalchemy.ext.asyncio import AsyncSession

from common.aspect.db_seesion import DBSessionDependency
from common.aspect.interface_auth import UserInterfaceAuthDependency
from common.aspect.pre_auth import CurrentUserDependency, PreAuthDependency
from common.router import APIRouterPro
from common.vo import DataResponseModel, ResponseBaseModel
from module_admin.entity.vo.user_vo import CurrentUserModel
from module_military.entity.vo.training_batch_vo import TrainingBatchModel, TrainingBatchQueryModel, TrainingBatchStatusModel
from module_military.service.training_batch_service import TrainingBatchService
from utils.log_util import logger
from utils.response_util import ResponseUtil

training_batch_controller = APIRouterPro(
    prefix='/military/training-batches', order_num=10, tags=['军训管理-批次管理'], dependencies=[PreAuthDependency()]
)


@training_batch_controller.get(
    '/list',
    summary='获取批次列表',
    response_model=DataResponseModel[list[TrainingBatchModel]],
    dependencies=[UserInterfaceAuthDependency('military:training_batch:list')],
)
async def get_list(
    request: Request,
    query: Annotated[TrainingBatchQueryModel, Query()],
    query_db: Annotated[AsyncSession, DBSessionDependency()],
) -> Response:
    result = await TrainingBatchService.get_list(query_db, query)
    logger.info('获取批次列表成功')
    return ResponseUtil.success(data=result)


@training_batch_controller.get(
    '/{batch_id}',
    summary='获取批次详情',
    response_model=DataResponseModel[TrainingBatchModel],
    dependencies=[UserInterfaceAuthDependency('military:training_batch:query')],
)
async def get_detail(
    request: Request,
    batch_id: Annotated[int, Path(description='批次id')],
    query_db: Annotated[AsyncSession, DBSessionDependency()],
) -> Response:
    result = await TrainingBatchService.get_by_id(query_db, batch_id)
    return ResponseUtil.success(data=result)


@training_batch_controller.post(
    '',
    summary='新增批次',
    response_model=ResponseBaseModel,
    dependencies=[UserInterfaceAuthDependency('military:training_batch:add')],
)
async def add(
    request: Request,
    add_batch: TrainingBatchModel,
    query_db: Annotated[AsyncSession, DBSessionDependency()],
    current_user: Annotated[CurrentUserModel, CurrentUserDependency()],
) -> Response:
    add_batch.create_by = current_user.user.user_name
    add_batch.create_time = datetime.now()
    add_batch.update_by = current_user.user.user_name
    add_batch.update_time = datetime.now()
    result = await TrainingBatchService.add(query_db, add_batch)
    logger.info(result.message)
    return ResponseUtil.success(msg=result.message)


@training_batch_controller.put(
    '',
    summary='编辑批次',
    response_model=ResponseBaseModel,
    dependencies=[UserInterfaceAuthDependency('military:training_batch:edit')],
)
async def edit(
    request: Request,
    edit_batch: TrainingBatchModel,
    query_db: Annotated[AsyncSession, DBSessionDependency()],
    current_user: Annotated[CurrentUserModel, CurrentUserDependency()],
) -> Response:
    edit_batch.update_by = current_user.user.user_name
    edit_batch.update_time = datetime.now()
    result = await TrainingBatchService.update(query_db, edit_batch)
    logger.info(result.message)
    return ResponseUtil.success(msg=result.message)


@training_batch_controller.delete(
    '/{batch_ids}',
    summary='删除批次',
    response_model=ResponseBaseModel,
    dependencies=[UserInterfaceAuthDependency('military:training_batch:remove')],
)
async def delete(
    request: Request,
    batch_ids: Annotated[str, Path(description='批次id，多个逗号分隔')],
    query_db: Annotated[AsyncSession, DBSessionDependency()],
    current_user: Annotated[CurrentUserModel, CurrentUserDependency()],
) -> Response:
    for bid in batch_ids.split(','):
        batch = TrainingBatchModel(id=int(bid), update_by=current_user.user.user_name, update_time=datetime.now())
        result = await TrainingBatchService.delete_batch(query_db, batch)
    logger.info(f'删除批次 {batch_ids} 成功')
    return ResponseUtil.success(msg='删除成功')


@training_batch_controller.put(
    '/{batch_id}/status',
    summary='切换批次状态',
    response_model=ResponseBaseModel,
    dependencies=[UserInterfaceAuthDependency('military:training_batch:edit')],
)
async def change_status(
    request: Request,
    batch_id: Annotated[int, Path(description='批次id')],
    status_model: TrainingBatchStatusModel,
    query_db: Annotated[AsyncSession, DBSessionDependency()],
) -> Response:
    result = await TrainingBatchService.change_status(query_db, batch_id, status_model)
    logger.info(result.message)
    return ResponseUtil.success(msg=result.message)
```

- [ ] **Step 2: 编写 MilitaryUnitController**

`module_military/controller/military_unit_controller.py`:
```python
from datetime import datetime
from typing import Annotated

from fastapi import Path, Query, Request, Response
from sqlalchemy.ext.asyncio import AsyncSession

from common.aspect.db_seesion import DBSessionDependency
from common.aspect.interface_auth import UserInterfaceAuthDependency
from common.aspect.pre_auth import CurrentUserDependency, PreAuthDependency
from common.router import APIRouterPro
from common.vo import DataResponseModel, ResponseBaseModel
from module_admin.entity.vo.user_vo import CurrentUserModel
from module_military.entity.vo.military_unit_vo import MilitaryUnitModel, MilitaryUnitQueryModel, MilitaryUnitTreeModel
from module_military.service.military_unit_service import MilitaryUnitService
from utils.log_util import logger
from utils.response_util import ResponseUtil

military_unit_controller = APIRouterPro(
    prefix='/military/military-units', order_num=11, tags=['军训管理-编制管理'], dependencies=[PreAuthDependency()]
)


@military_unit_controller.get(
    '/tree',
    summary='获取编制树',
    response_model=DataResponseModel[list[MilitaryUnitTreeModel]],
    dependencies=[UserInterfaceAuthDependency('military:military_unit:list')],
)
async def get_tree(
    request: Request,
    query: Annotated[MilitaryUnitQueryModel, Query()],
    query_db: Annotated[AsyncSession, DBSessionDependency()],
) -> Response:
    result = await MilitaryUnitService.get_tree(query_db, query)
    logger.info('获取编制树成功')
    return ResponseUtil.success(data=result)


@military_unit_controller.get(
    '/{unit_id}',
    summary='获取编制详情',
    response_model=DataResponseModel[MilitaryUnitModel],
    dependencies=[UserInterfaceAuthDependency('military:military_unit:query')],
)
async def get_detail(
    request: Request,
    unit_id: Annotated[int, Path(description='编制id')],
    query_db: Annotated[AsyncSession, DBSessionDependency()],
) -> Response:
    result = await MilitaryUnitService.get_by_id(query_db, unit_id)
    return ResponseUtil.success(data=result)


@military_unit_controller.post(
    '',
    summary='新增编制',
    response_model=ResponseBaseModel,
    dependencies=[UserInterfaceAuthDependency('military:military_unit:add')],
)
async def add(
    request: Request,
    add_unit: MilitaryUnitModel,
    query_db: Annotated[AsyncSession, DBSessionDependency()],
    current_user: Annotated[CurrentUserModel, CurrentUserDependency()],
) -> Response:
    add_unit.create_by = current_user.user.user_name
    add_unit.create_time = datetime.now()
    add_unit.update_by = current_user.user.user_name
    add_unit.update_time = datetime.now()
    result = await MilitaryUnitService.add(query_db, add_unit)
    logger.info(result.message)
    return ResponseUtil.success(msg=result.message)


@military_unit_controller.put(
    '',
    summary='编辑编制',
    response_model=ResponseBaseModel,
    dependencies=[UserInterfaceAuthDependency('military:military_unit:edit')],
)
async def edit(
    request: Request,
    edit_unit: MilitaryUnitModel,
    query_db: Annotated[AsyncSession, DBSessionDependency()],
    current_user: Annotated[CurrentUserModel, CurrentUserDependency()],
) -> Response:
    edit_unit.update_by = current_user.user.user_name
    edit_unit.update_time = datetime.now()
    result = await MilitaryUnitService.update(query_db, edit_unit)
    logger.info(result.message)
    return ResponseUtil.success(msg=result.message)


@military_unit_controller.delete(
    '/{unit_ids}',
    summary='删除编制',
    response_model=ResponseBaseModel,
    dependencies=[UserInterfaceAuthDependency('military:military_unit:remove')],
)
async def delete(
    request: Request,
    unit_ids: Annotated[str, Path(description='编制id，多个逗号分隔')],
    query_db: Annotated[AsyncSession, DBSessionDependency()],
    current_user: Annotated[CurrentUserModel, CurrentUserDependency()],
) -> Response:
    for uid in unit_ids.split(','):
        unit = MilitaryUnitModel(id=int(uid), update_by=current_user.user.user_name, update_time=datetime.now())
        result = await MilitaryUnitService.delete(query_db, unit)
    logger.info('删除编制成功')
    return ResponseUtil.success(msg='删除成功')
```

- [ ] **Step 3: 提交**

```bash
git add military-train-backend/module_military/controller/training_batch_controller.py military-train-backend/module_military/controller/military_unit_controller.py
git commit -m "feat: add TrainingBatch and MilitaryUnit Controller"
```

---

### Task 16: MilitaryAssignment + MilitaryRoleAssignment Controller

**Files:**
- Create: `military-train-backend/module_military/controller/military_assignment_controller.py`
- Create: `military-train-backend/module_military/controller/military_role_assignment_controller.py`

- [ ] **Step 1: 编写 MilitaryAssignmentController**

`module_military/controller/military_assignment_controller.py`:
```python
from datetime import datetime
from typing import Annotated

from fastapi import Path, Query, Request, Response
from sqlalchemy.ext.asyncio import AsyncSession

from common.aspect.db_seesion import DBSessionDependency
from common.aspect.interface_auth import UserInterfaceAuthDependency
from common.aspect.pre_auth import CurrentUserDependency, PreAuthDependency
from common.router import APIRouterPro
from common.vo import DataResponseModel, ResponseBaseModel
from module_admin.entity.vo.user_vo import CurrentUserModel
from module_military.entity.vo.military_assignment_vo import BatchAssignModel, MilitaryAssignmentModel, MilitaryAssignmentQueryModel
from module_military.service.military_assignment_service import MilitaryAssignmentService
from utils.log_util import logger
from utils.response_util import ResponseUtil

military_assignment_controller = APIRouterPro(
    prefix='/military/assignments', order_num=12, tags=['军训管理-编制分配'], dependencies=[PreAuthDependency()]
)


@military_assignment_controller.get(
    '/list',
    summary='获取编制分配列表',
    response_model=DataResponseModel[list[MilitaryAssignmentModel]],
    dependencies=[UserInterfaceAuthDependency('military:assignment:list')],
)
async def get_list(
    request: Request,
    query: Annotated[MilitaryAssignmentQueryModel, Query()],
    query_db: Annotated[AsyncSession, DBSessionDependency()],
) -> Response:
    result = await MilitaryAssignmentService.get_list(query_db, query)
    return ResponseUtil.success(data=result)


@military_assignment_controller.post(
    '/batch',
    summary='批量分配编制',
    response_model=ResponseBaseModel,
    dependencies=[UserInterfaceAuthDependency('military:assignment:edit')],
)
async def batch_assign(
    request: Request,
    batch_model: BatchAssignModel,
    query_db: Annotated[AsyncSession, DBSessionDependency()],
    current_user: Annotated[CurrentUserModel, CurrentUserDependency()],
) -> Response:
    result = await MilitaryAssignmentService.batch_assign(query_db, batch_model, current_user.user.user_id)
    logger.info(result.message)
    return ResponseUtil.success(msg=result.message)


@military_assignment_controller.delete(
    '/{assignment_id}',
    summary='取消分配',
    response_model=ResponseBaseModel,
    dependencies=[UserInterfaceAuthDependency('military:assignment:edit')],
)
async def remove(
    request: Request,
    assignment_id: Annotated[int, Path(description='分配记录id')],
    query_db: Annotated[AsyncSession, DBSessionDependency()],
    current_user: Annotated[CurrentUserModel, CurrentUserDependency()],
) -> Response:
    assignment = MilitaryAssignmentModel(
        id=assignment_id,
        removed_at=datetime.now(),
        update_by=current_user.user.user_name,
        update_time=datetime.now(),
    )
    result = await MilitaryAssignmentService.remove(query_db, assignment)
    logger.info(result.message)
    return ResponseUtil.success(msg=result.message)
```

- [ ] **Step 2: 编写 MilitaryRoleAssignmentController**

`module_military/controller/military_role_assignment_controller.py`:
```python
from datetime import datetime
from typing import Annotated

from fastapi import Path, Query, Request, Response
from sqlalchemy.ext.asyncio import AsyncSession

from common.aspect.db_seesion import DBSessionDependency
from common.aspect.interface_auth import UserInterfaceAuthDependency
from common.aspect.pre_auth import CurrentUserDependency, PreAuthDependency
from common.router import APIRouterPro
from common.vo import DataResponseModel, ResponseBaseModel
from module_admin.entity.vo.user_vo import CurrentUserModel
from module_military.entity.vo.military_role_assignment_vo import MilitaryRoleAssignmentModel, MilitaryRoleAssignmentQueryModel
from module_military.service.military_role_assignment_service import MilitaryRoleAssignmentService
from utils.log_util import logger
from utils.response_util import ResponseUtil

military_role_assignment_controller = APIRouterPro(
    prefix='/military/role-assignments', order_num=13, tags=['军训管理-角色授权'], dependencies=[PreAuthDependency()]
)


@military_role_assignment_controller.get(
    '/list',
    summary='获取角色授权列表',
    response_model=DataResponseModel[list[MilitaryRoleAssignmentModel]],
    dependencies=[UserInterfaceAuthDependency('military:role_assignment:list')],
)
async def get_list(
    request: Request,
    query: Annotated[MilitaryRoleAssignmentQueryModel, Query()],
    query_db: Annotated[AsyncSession, DBSessionDependency()],
) -> Response:
    result = await MilitaryRoleAssignmentService.get_list(query_db, query)
    return ResponseUtil.success(data=result)


@military_role_assignment_controller.post(
    '',
    summary='授予角色',
    response_model=ResponseBaseModel,
    dependencies=[UserInterfaceAuthDependency('military:role_assignment:edit')],
)
async def grant(
    request: Request,
    assignment: MilitaryRoleAssignmentModel,
    query_db: Annotated[AsyncSession, DBSessionDependency()],
    current_user: Annotated[CurrentUserModel, CurrentUserDependency()],
) -> Response:
    assignment.granted_by = current_user.user.user_id
    assignment.create_by = current_user.user.user_name
    assignment.create_time = datetime.now()
    assignment.update_by = current_user.user.user_name
    assignment.update_time = datetime.now()
    result = await MilitaryRoleAssignmentService.grant(query_db, assignment)
    logger.info(result.message)
    return ResponseUtil.success(msg=result.message)


@military_role_assignment_controller.put(
    '/{assignment_id}',
    summary='修改授权范围',
    response_model=ResponseBaseModel,
    dependencies=[UserInterfaceAuthDependency('military:role_assignment:edit')],
)
async def update(
    request: Request,
    assignment_id: Annotated[int, Path(description='授权记录id')],
    assignment: MilitaryRoleAssignmentModel,
    query_db: Annotated[AsyncSession, DBSessionDependency()],
    current_user: Annotated[CurrentUserModel, CurrentUserDependency()],
) -> Response:
    assignment.id = assignment_id
    assignment.update_by = current_user.user.user_name
    assignment.update_time = datetime.now()
    result = await MilitaryRoleAssignmentService.update(query_db, assignment)
    logger.info(result.message)
    return ResponseUtil.success(msg=result.message)


@military_role_assignment_controller.delete(
    '/{assignment_id}',
    summary='撤销角色授权',
    response_model=ResponseBaseModel,
    dependencies=[UserInterfaceAuthDependency('military:role_assignment:remove')],
)
async def revoke(
    request: Request,
    assignment_id: Annotated[int, Path(description='授权记录id')],
    query_db: Annotated[AsyncSession, DBSessionDependency()],
    current_user: Annotated[CurrentUserModel, CurrentUserDependency()],
) -> Response:
    assignment = MilitaryRoleAssignmentModel(
        id=assignment_id,
        revoked_at=datetime.now(),
        update_by=current_user.user.user_name,
        update_time=datetime.now(),
    )
    result = await MilitaryRoleAssignmentService.revoke(query_db, assignment)
    logger.info(result.message)
    return ResponseUtil.success(msg=result.message)
```

- [ ] **Step 3: 提交**

```bash
git add military-train-backend/module_military/controller/military_assignment_controller.py military-train-backend/module_military/controller/military_role_assignment_controller.py
git commit -m "feat: add MilitaryAssignment and MilitaryRoleAssignment Controller"
```

---

### Task 17: 验证后端路由自动注册

- [ ] **Step 1: 启动后端验证**

```bash
cd military-train-backend && python -c "
from app import app
from common.router import auto_register_routers
auto_register_routers(app)
routes = [r.path for r in app.routes]
military_routes = [r for r in routes if '/military/' in str(r)]
print(f'Military routes: {len(military_routes)}')
for r in sorted(military_routes):
    print(f'  {r}')
"
```

预期输出: 至少 16 条 `/military/` 开头路由

- [ ] **Step 2: 提交 (如有更改)**

```bash
git status
```

---

### Task 18: 前端 API 封装

**Files:**
- Create: `military-train-frontend/src/api/military/trainingBatch.js`
- Create: `military-train-frontend/src/api/military/militaryUnit.js`
- Create: `military-train-frontend/src/api/military/militaryAssignment.js`
- Create: `military-train-frontend/src/api/military/militaryRoleAssignment.js`

- [ ] **Step 1: 编写 trainingBatch.js**

```javascript
import request from '@/utils/request'

export function listBatch(query) {
  return request({ url: '/military/training-batches/list', method: 'get', params: query })
}

export function getBatch(batchId) {
  return request({ url: '/military/training-batches/' + batchId, method: 'get' })
}

export function addBatch(data) {
  return request({ url: '/military/training-batches', method: 'post', data: data })
}

export function updateBatch(data) {
  return request({ url: '/military/training-batches', method: 'put', data: data })
}

export function delBatch(batchIds) {
  return request({ url: '/military/training-batches/' + batchIds, method: 'delete' })
}

export function changeBatchStatus(batchId, data) {
  return request({ url: '/military/training-batches/' + batchId + '/status', method: 'put', data: data })
}
```

- [ ] **Step 2: 编写 militaryUnit.js**

```javascript
import request from '@/utils/request'

export function getTree(query) {
  return request({ url: '/military/military-units/tree', method: 'get', params: query })
}

export function getUnit(unitId) {
  return request({ url: '/military/military-units/' + unitId, method: 'get' })
}

export function addUnit(data) {
  return request({ url: '/military/military-units', method: 'post', data: data })
}

export function updateUnit(data) {
  return request({ url: '/military/military-units', method: 'put', data: data })
}

export function delUnit(unitIds) {
  return request({ url: '/military/military-units/' + unitIds, method: 'delete' })
}
```

- [ ] **Step 3: 编写 militaryAssignment.js**

```javascript
import request from '@/utils/request'

export function listAssignment(query) {
  return request({ url: '/military/assignments/list', method: 'get', params: query })
}

export function batchAssign(data) {
  return request({ url: '/military/assignments/batch', method: 'post', data: data })
}

export function removeAssignment(assignmentId) {
  return request({ url: '/military/assignments/' + assignmentId, method: 'delete' })
}
```

- [ ] **Step 4: 编写 militaryRoleAssignment.js**

```javascript
import request from '@/utils/request'

export function listRoleAssignment(query) {
  return request({ url: '/military/role-assignments/list', method: 'get', params: query })
}

export function grantRole(data) {
  return request({ url: '/military/role-assignments', method: 'post', data: data })
}

export function updateRoleAssignment(assignmentId, data) {
  return request({ url: '/military/role-assignments/' + assignmentId, method: 'put', data: data })
}

export function revokeRole(assignmentId) {
  return request({ url: '/military/role-assignments/' + assignmentId, method: 'delete' })
}
```

- [ ] **Step 5: 提交**

```bash
git add military-train-frontend/src/api/military/
git commit -m "feat: add frontend API wrappers for military modules"
```

---

### Task 19: 前端 Vue 页面 — 军训批次

**Files:**
- Create: `military-train-frontend/src/views/military/training_batch/index.vue`

- [ ] **Step 1: 编写批次管理页面**

页面参考 `views/system/dept/index.vue` 的模式（搜索栏 + 操作栏 + 表格 + 弹窗），具体实现：

| 功能 | UI实现 |
|---|---|
| 搜索栏 | 批次名称(input)、编码(input)、状态下拉(字典`military_batch_status`) |
| 操作栏 | 新增按钮(`v-hasPermi="['military:training_batch:add']"`) |
| 表格列 | 名称、编码、状态(dict-tag)、计划开始、计划结束、操作(编辑/删除/状态切换) |
| 新增弹窗 | 名称、编码、计划日期范围 |
| 编辑弹窗 | 同新增，附加乐观锁 version 隐藏域 |
| 状态切换 | el-popconfirm 确认后调用 changeBatchStatus |

- [ ] **Step 2: 提交**

```bash
git add military-train-frontend/src/views/military/training_batch/
git commit -m "feat: add training batch management page"
```

---

### Task 20: 前端 Vue 页面 — 编制管理 + 编制分配 + 角色授权

**Files:**
- Create: `military-train-frontend/src/views/military/military_unit/index.vue`
- Create: `military-train-frontend/src/views/military/military_assignment/index.vue`
- Create: `military-train-frontend/src/views/military/military_role_assignment/index.vue`

- [ ] **Step 1: 编制管理页面**

参考 `views/system/dept/index.vue` 树形表格模式：

| 功能 | UI实现 |
|---|---|
| 批次选择 | 顶部 el-select 选择批次（默认 active），切换触发重新加载树 |
| 左侧树 | el-table tree-props 展示团/营/连/排层级 |
| 操作 | 树节点右键或行内按钮：新增子节点、编辑、删除（`v-hasPermi`） |
| 弹窗 | 上级编制(treeselect)、编制类型(select 字典`military_unit_type`)、名称、编码、排序 |

- [ ] **Step 2: 编制分配页面**

| 功能 | UI实现 |
|---|---|
| 左侧编制树 | el-tree 展示排级及以下（按批次切换），点击排节点触发加载分配列表 |
| 右侧表格 | 已分配人员列表（姓名、学号/工号、部门、分配时间），支持移除 |
| 批量分配 | el-dialog 弹窗，左侧未分配人员列表(支持搜索)，穿梭框或勾选后点击确认 |

- [ ] **Step 3: 角色授权页面**

| 功能 | UI实现 |
|---|---|
| 搜索 | 批次选择 + 角色编码下拉(字典) + 人员搜索 |
| 列表 | 人员姓名、角色编码(dict-tag)、范围类型、授权时间、操作（编辑/撤销） |
| 授权弹窗 | 人员选择(select搜索)、角色编码(select字典)、范围类型(radio: global/academic/military)、联动显示组织选择器(treeselect) |

- [ ] **Step 4: 提交**

```bash
git add military-train-frontend/src/views/military/
git commit -m "feat: add military unit, assignment, role assignment pages"
```

---

### Task 21: 前端路由配置

**Files:**
- Modify: `military-train-frontend/src/router/index.js`

- [ ] **Step 1: 添加军训路由**

找到 `// 公共路由` 或 roleRoutes 部分，在 system 路由同级添加:

```javascript
{
  path: '/military',
  component: Layout,
  redirect: '/military/training-batches',
  name: 'Military',
  meta: { title: '军训管理', icon: 'guide' },
  children: [
    {
      path: 'training-batches',
      component: () => import('@/views/military/training_batch/index.vue'),
      name: 'TrainingBatches',
      meta: { title: '军训批次' }
    },
    {
      path: 'military-units',
      component: () => import('@/views/military/military_unit/index.vue'),
      name: 'MilitaryUnits',
      meta: { title: '编制管理' }
    },
    {
      path: 'assignments',
      component: () => import('@/views/military/military_assignment/index.vue'),
      name: 'Assignments',
      meta: { title: '编制分配' }
    },
    {
      path: 'role-assignments',
      component: () => import('@/views/military/military_role_assignment/index.vue'),
      name: 'RoleAssignments',
      meta: { title: '角色授权' }
    }
  ]
}
```

- [ ] **Step 2: 提交**

```bash
git add military-train-frontend/src/router/index.js
git commit -m "feat: add military module routes"
```

---

### Task 22: 编写 Service 单元测试

**Files:**
- Create: `military-train-backend/tests/test_training_batch_service.py`
- Create: `military-train-backend/tests/test_military_role_assignment_service.py`

- [ ] **Step 1: 编写 TrainingBatchService 测试**

`tests/test_training_batch_service.py`:
```python
import pytest
from unittest.mock import AsyncMock, patch
from module_military.service.training_batch_service import TrainingBatchService
from module_military.entity.vo.training_batch_vo import TrainingBatchModel, TrainingBatchStatusModel
from exceptions.exception import ServiceException


@pytest.mark.asyncio
async def test_add_batch_code_conflict():
    """批次编码重复时抛出异常"""
    mock_db = AsyncMock()
    with patch('module_military.dao.training_batch_dao.TrainingBatchDao.check_code_unique', return_value=False):
        with pytest.raises(ServiceException, match='已存在'):
            await TrainingBatchService.add(mock_db, TrainingBatchModel(name='test', code='DUP'))


@pytest.mark.asyncio
async def test_add_batch_success():
    """批次新增成功"""
    mock_db = AsyncMock()
    with patch('module_military.dao.training_batch_dao.TrainingBatchDao.check_code_unique', return_value=True):
        with patch('module_military.dao.training_batch_dao.TrainingBatchDao.add', new_callable=AsyncMock):
            result = await TrainingBatchService.add(mock_db, TrainingBatchModel(name='test', code='NEW'))
            assert result.is_success is True


@pytest.mark.asyncio
async def test_status_transition_draft_to_active():
    """draft -> active 合法跳转"""
    mock_db = AsyncMock()
    with patch('module_military.dao.training_batch_dao.TrainingBatchDao.get_by_id', new_callable=AsyncMock) as mock_get:
        mock_get.return_value = type('obj', (), {'id': 1, 'status': 'draft', 'del_flag': '0'})()
        with patch('module_military.dao.training_batch_dao.TrainingBatchDao.update', new_callable=AsyncMock):
            result = await TrainingBatchService.change_status(
                mock_db, 1, TrainingBatchStatusModel(status='active', version=0)
            )
            assert result.is_success is True


@pytest.mark.asyncio
async def test_status_transition_invalid():
    """非法跳转（active -> archived 直接不可达）"""
    mock_db = AsyncMock()
    with patch('module_military.dao.training_batch_dao.TrainingBatchDao.get_by_id', new_callable=AsyncMock) as mock_get:
        mock_get.return_value = type('obj', (), {'id': 1, 'status': 'active', 'del_flag': '0'})()
        with pytest.raises(ServiceException, match='不允许从 active 切换到 archived'):
            await TrainingBatchService.change_status(
                mock_db, 1, TrainingBatchStatusModel(status='archived', version=0)
            )
```

- [ ] **Step 2: 编写 ScopeResolver 测试**

`tests/test_military_role_assignment_service.py`:
```python
import pytest
from unittest.mock import AsyncMock, patch
from module_military.service.military_role_assignment_service import MilitaryRoleAssignmentService
from module_military.entity.do.military_role_assignment_do import SysMilitaryRoleAssignment
from exceptions.exception import ServiceException


@pytest.mark.asyncio
async def test_scope_resolver_global():
    """global scope 返回所有人员"""
    mock_db = AsyncMock()
    assignment = SysMilitaryRoleAssignment()
    assignment.scope_type = 'global'

    with patch('sqlalchemy.ext.asyncio.AsyncSession.execute', new_callable=AsyncMock) as mock_exec:
        mock_result = AsyncMock()
        mock_result.scalars.return_value.all.return_value = [1, 2, 3]
        mock_exec.return_value = mock_result
        mock_db.execute = mock_exec
        result = await MilitaryRoleAssignmentService.resolve_scope_user_ids(mock_db, assignment)
        assert result == [1, 2, 3]


@pytest.mark.asyncio
async def test_scope_resolver_academic_self():
    """academic scope + self depth 返回指定部门人员"""
    mock_db = AsyncMock()
    assignment = SysMilitaryRoleAssignment()
    assignment.scope_type = 'academic'
    assignment.scope_dept_id = 10
    assignment.scope_depth = 'self'

    with patch.object(MilitaryRoleAssignmentService, '_get_dept_subtree_ids', return_value=[10]):
        with patch('sqlalchemy.ext.asyncio.AsyncSession.execute', new_callable=AsyncMock) as mock_exec:
            mock_result = AsyncMock()
            mock_result.scalars.return_value.all.return_value = [5, 6]
            mock_exec.return_value = mock_result
            mock_db.execute = mock_exec
            result = await MilitaryRoleAssignmentService.resolve_scope_user_ids(mock_db, assignment)
            assert result == [5, 6]


@pytest.mark.asyncio
async def test_grant_role_duplicate():
    """同一批次同一角色重复授权抛出异常"""
    mock_db = AsyncMock()
    with patch('module_military.dao.military_role_assignment_dao.MilitaryRoleAssignmentDao.get_active_by_user_batch_role',
               new_callable=AsyncMock) as mock_get:
        mock_get.return_value = type('obj', (), {'id': 1})()
        with pytest.raises(ServiceException, match='已拥有此角色'):
            await MilitaryRoleAssignmentService.grant(
                mock_db,
                type('obj', (), {
                    'user_id': 1, 'training_batch_id': 1, 'role_code': 'student',
                    'model_dump': lambda **kw: {}
                })(),
            )
```

- [ ] **Step 3: 运行测试验证**

```bash
cd military-train-backend && python -m pytest tests/test_training_batch_service.py tests/test_military_role_assignment_service.py -v
```

预期: 6 tests passed

- [ ] **Step 4: 提交**

```bash
git add military-train-backend/tests/
git commit -m "test: add TrainingBatchService and scope resolver unit tests"
```

---

## 验证清单

完成所有 Task 后执行：

```bash
# 1. 后端路由注册
cd military-train-backend && python -c "
from app import app
from common.router import auto_register_routers
auto_register_routers(app)
military_routes = [(r.path, r.methods) for r in app.routes if '/military/' in str(r.path)]
assert len(military_routes) >= 16, f'Expected >=16 routes, got {len(military_routes)}'
print(f'OK: {len(military_routes)} military routes registered')
"

# 2. 单元测试
cd military-train-backend && python -m pytest tests/test_training_batch_service.py tests/test_military_role_assignment_service.py -v

# 3. 前端编译
cd military-train-frontend && npm run build -- --mode production 2>&1 | tail -5
```

---

## 实施顺序

| 顺序 | Task | 依赖 |
|---|---|---|
| 1 | Task 1: 目录结构 | 无 |
| 2 | Task 2: Migration | Task 1 |
| 3 | Task 3: 种子 SQL | Task 2 |
| 4 | Task 4-7: DO 模型 | Task 2 |
| 5 | Task 8: 扩展 SysUser | 无 (独立修改) |
| 6 | Task 9-10: VO 模型 | Task 4-7 |
| 7 | Task 11-12: DAO | Task 4-10 |
| 8 | Task 13-14: Service | Task 11-12 |
| 9 | Task 15-16: Controller | Task 13-14 |
| 10 | Task 17: 路由验证 | Task 15-16 |
| 11 | Task 18: 前端 API | Task 15-16 |
| 12 | Task 19-20: 前端页面 | Task 18 |
| 13 | Task 21: 路由配置 | Task 19-20 |
| 14 | Task 22: 测试 | Task 13-14 |
