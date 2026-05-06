#!/usr/bin/env bash
#
# RuoYi-FastAPI 去品牌化 / 项目脚手架重命名脚本
# 用法: bash rebrand.sh
# 安全: 默认 dry-run 模式，加 --apply 才真正执行
# ============================================================

set -euo pipefail

# ── 颜色 ──────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

# ── 工作目录（脚本放在项目根目录执行）──────────────────────
PROJECT_ROOT="$(cd "$(dirname "$0")" && pwd)"

# ── 解析参数 ──────────────────────────────────────────────
DRY_RUN=true
RENAME_DIRS=false
BACKUP=false
while [[ $# -gt 0 ]]; do
    case "$1" in
        --apply)   DRY_RUN=false; shift ;;
        --dirs)    RENAME_DIRS=true; shift ;;
        --backup)  BACKUP=true; shift ;;
        --help|-h)
            echo "用法: bash rebrand.sh [选项]"
            echo ""
            echo "选项:"
            echo "  --apply    真正执行修改（默认是 dry-run 预览）"
            echo "  --dirs     同时重命名顶层目录（默认跳过，风险高）"
            echo "  --backup   修改前备份原文件到 .rebrand-backup/"
            echo ""
            echo "示例:"
            echo "  bash rebrand.sh                  # 预览所有变更"
            echo "  bash rebrand.sh --apply          # 执行文件内容替换"
            echo "  bash rebrand.sh --apply --dirs   # 执行全部（含目录重命名）"
            exit 0
            ;;
        *) echo -e "${RED}未知参数: $1${NC}"; exit 1 ;;
    esac
done

# ── 交互式收集信息 ─────────────────────────────────────────
echo -e "${BOLD}${CYAN}╔══════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${CYAN}║   RuoYi-FastAPI 项目重命名工具              ║${NC}"
echo -e "${BOLD}${CYAN}╚══════════════════════════════════════════════╝${NC}"
echo ""

if $DRY_RUN; then
    echo -e "${YELLOW}[DRY-RUN 模式] 只预览变更，不会实际修改文件${NC}"
    echo -e "${YELLOW}  加上 --apply 参数执行真实修改${NC}"
    echo ""
fi

# 收集输入
read -r -p "$(echo -e "${GREEN}项目英文名（PascalCase，如 MilitaryTrain）: ${NC}")" NEW_PASCAL
NEW_PASCAL=${NEW_PASCAL:-MilitaryTrain}

read -r -p "$(echo -e "${GREEN}项目短名（kebab-case，如 military-train）: ${NC}")" NEW_KEBAB
NEW_KEBAB=${NEW_KEBAB:-military-train}

read -r -p "$(echo -e "${GREEN}项目短名（小写无连字符，如 military）: ${NC}")" NEW_SHORT
NEW_SHORT=${NEW_SHORT:-military}

read -r -p "$(echo -e "${GREEN}项目中文名（如 军训管理系统）: ${NC}")" NEW_CN
NEW_CN=${NEW_CN:-军训管理系统}

read -r -p "$(echo -e "${GREEN}作者/组织名（如 YourCompany）: ${NC}")" NEW_AUTHOR
NEW_AUTHOR=${NEW_AUTHOR:-YourCompany}

read -r -p "$(echo -e "${GREEN}域名（如 yourcompany.com）: ${NC}")" NEW_DOMAIN
NEW_DOMAIN=${NEW_DOMAIN:-yourcompany.com}

read -r -p "$(echo -e "${GREEN}GitHub/Gitee 组织名（如 your-org）: ${NC}")" NEW_ORG
NEW_ORG=${NEW_ORG:-your-org}

read -r -p "$(echo -e "${GREEN}页脚版权年份范围（如 2024-2026）: ${NC}")" NEW_YEARS
NEW_YEARS=${NEW_YEARS:-2024-2026}

echo ""
echo -e "${BOLD}──── 配置确认 ──────────────────────────────────${NC}"
echo -e "  英文名 (PascalCase):  ${CYAN}${NEW_PASCAL}${NC}"
echo -e "  短名   (kebab-case):  ${CYAN}${NEW_KEBAB}${NC}"
echo -e "  短名   (lowercase):   ${CYAN}${NEW_SHORT}${NC}"
echo -e "  中文名:               ${CYAN}${NEW_CN}${NC}"
echo -e "  作者/组织:            ${CYAN}${NEW_AUTHOR}${NC}"
echo -e "  域名:                 ${CYAN}${NEW_DOMAIN}${NC}"
echo -e "  Git组织:              ${CYAN}${NEW_ORG}${NC}"
echo -e "  版权年份:             ${CYAN}${NEW_YEARS}${NC}"
echo "──────────────────────────────────────────────────"
echo ""

read -r -p "$(echo -e "${YELLOW}确认以上配置? (y/N): ${NC}")" CONFIRM
if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
    echo "已取消"
    exit 0
fi

echo ""

# ── 替换规则定义 ───────────────────────────────────────────
# 格式: "匹配模式|替换文本|文件类型|描述"
# 注意顺序：长的先替换，避免短字符串误伤（如 ruoyi 先替换 ruoyi-fastapi）

RULES=(
    # ── 品牌标识（长优先） ──
    "RuoYi-FastAPI|${NEW_PASCAL}|py,env,json,md,vue,js,yml,yaml,conf,toml|产品名（标准写法）"
    "RuoYi-FasAPI|${NEW_PASCAL}|py|产品名（修正 typo）"
    "military-train-backend|${NEW_KEBAB}-backend|py,env,json,md,vue,js,yml,yaml,conf,sh|后端目录名"
    "ruoyi-fastapi-frontend|${NEW_KEBAB}-frontend|py,env,json,md,vue,js,yml,yaml,conf|前端目录名"
    "ruoyi-fastapi-test|${NEW_KEBAB}-test|py,env,json,md,vue,js,yml,yaml,conf|测试目录名"
    "ruoyi-fastapi-app|${NEW_KEBAB}-app|json,md,vue,js|移动端目录名"
    "ruoyi-fastapi-pg|${NEW_KEBAB}-pg|sql|PG DDL 文件名"
    "ruoyi-fastapi|${NEW_KEBAB}|py,env,json,md,vue,js,yml,yaml,conf,sql|项目 kebab 名"
    "RuoYi-Vue3-FastAPI|${NEW_PASCAL}|md,json|README 项目名"
    "RuoYi-Vue3|RuoYi-Vue3|NONE|跳过：上游项目名（保留致谢）"

    # ── RuoYi 相关 ──
    "ruoyi.vip|${NEW_DOMAIN}|py,env,json,md,vue,js,yml,yaml,conf|ruoyi官网"
    "ruoyi-network|${NEW_SHORT}-network|yml,yaml|Docker网络"
    "ruoyi-frontend|${NEW_SHORT}-frontend|yml,yaml,conf|Docker容器/服务名"
    "ruoyi-backend-my|${NEW_SHORT}-backend-my|yml,yaml,conf|Docker MySQL后端"
    "ruoyi-backend-pg|${NEW_SHORT}-backend-pg|yml,yaml,conf|Docker PG后端"
    "ruoyi-backend-my-test|${NEW_SHORT}-backend-my-test|yml,yaml|测试后端MySQL"
    "ruoyi-backend-pg-test|${NEW_SHORT}-backend-pg-test|yml,yaml|测试后端PG"
    "ruoyi-mysql|${NEW_SHORT}-mysql|yml,yaml,env|Docker MySQL"
    "ruoyi-pg|${NEW_SHORT}-pg|yml,yaml,env|Docker PG"
    "ruoyi-redis|${NEW_SHORT}-redis|yml,yaml,env|Docker Redis"
    "ruoyi-git|${NEW_SHORT}-git|vue|Navbar组件"
    "ruoyi-doc|${NEW_SHORT}-doc|vue|Navbar组件"

    # ── 显示文字（更具体避免误伤） ──
    "'RuoYi-FastAPI移动端'|'${NEW_CN}移动端'|vue,json|移动端标题"
    "'RuoYi-FastAPI移动端登录'|'${NEW_CN}移动端登录'|vue|移动端登录页"
    "'RuoYi-FastAPI移动端注册'|'${NEW_CN}移动端注册'|vue|移动端注册页"
    "'RuoYi-FastAPI-APP'|'${NEW_CN}-APP'|json,vue,js|移动端APP名"
    "'RuoYi'|'${NEW_CN}'|vue,json|移动端短标题"

    # ── 作者/版权 ──
    "Copyright (c) 2019 ruoyi|Copyright (c) ${NEW_YEARS} ${NEW_AUTHOR}|js|版权声明-2019"
    "Copyright (c) 2022 ruoyi|Copyright (c) ${NEW_YEARS} ${NEW_AUTHOR}|js|版权声明-2022"
    "Copyright (c) 2024 insistence|Copyright (c) ${NEW_YEARS} ${NEW_AUTHOR}|md|LICENSE版权"
    "insistence.tech|${NEW_DOMAIN}|js,py,md|页脚域名"
    "insistence2022|${NEW_ORG}|md,json|Git组织名"
    "insistence|${NEW_AUTHOR}|py,json,md,vue,js|作者名"

    # ── vfadmin → 新短名 ──
    "vfadmin管理系统|${NEW_CN}管理系统|env|VITE标题"
    "vfadmin|${NEW_SHORT}|py,env,json,js,vue,md,conf|vfadmin→新短名"
    "vf_admin|${NEW_SHORT//-/_}|py|Python路径中的vf_admin"

    # ── 中文 ──
    "若依官网|${NEW_CN}官网|sql|菜单项"
    "若依|${NEW_CN}|py,sql|去除若依"

    # ── 移动端法律文件标记（这些需要手动处理） ──
    # 不自动替换，而是输出警告
)

# ── 需要手动处理的法律文件 ──
LEGAL_FILES=(
    "ruoyi-fastapi-app/src/pages/common/agreement/index.vue"
    "ruoyi-fastapi-app/src/pages/common/privacy/index.vue"
    "ruoyi-fastapi-app/src/pages/mine/help/index.vue"
)

# ── 文件重命名映射 ─────────────────────────────────────────
# 格式: "原路径|新路径"
FILE_RENAMES=(
    "military-train-backend/sql/ruoyi-fastapi.sql|military-train-backend/sql/${NEW_KEBAB}.sql"
    "military-train-backend/sql/ruoyi-fastapi-pg.sql|military-train-backend/sql/${NEW_KEBAB}-pg.sql"
    "ruoyi-fastapi-frontend/src/utils/ruoyi.js|ruoyi-fastapi-frontend/src/utils/${NEW_SHORT}.js"
    "ruoyi-fastapi-frontend/src/assets/styles/ruoyi.scss|ruoyi-fastapi-frontend/src/assets/styles/${NEW_SHORT}.scss"
)

# ── 目录重命名映射 ─────────────────────────────────────────
DIR_RENAMES=(
    "military-train-backend|${NEW_KEBAB}-backend"
    "ruoyi-fastapi-frontend|${NEW_KEBAB}-frontend"
    "ruoyi-fastapi-test|${NEW_KEBAB}-test"
    "ruoyi-fastapi-app|${NEW_KEBAB}-app"
    "ruoyi-fastapi-frontend/src/components/RuoYi|ruoyi-fastapi-frontend/src/components/${NEW_PASCAL}"
)

# ── 函数：按文件类型过滤 ───────────────────────────────────
ext_match() {
    local filename="$1"
    local exts="$2"
    [[ "$exts" == "NONE" ]] && return 1
    # 提取文件扩展名
    local fext="${filename##*.}"
    IFS=',' read -ra EXTS <<< "$exts"
    for e in "${EXTS[@]}"; do
        [[ "$fext" == "$e" ]] && return 0
        # 也匹配无扩展名的特殊文件名
        [[ "$e" == "$filename" ]] && return 0
    done
    return 1
}

# ── 函数：预览变更 ─────────────────────────────────────────
preview_change() {
    local file="$1" pattern="$2" replacement="$3" desc="$4"
    local count
    count=$(grep -c "$pattern" "$file" 2>/dev/null || true)
    if [[ "$count" -gt 0 ]]; then
        echo -e "  ${YELLOW}${count}处${NC} | ${desc}"
        if ! $DRY_RUN; then
            if $BACKUP; then
                local backup_dir="${PROJECT_ROOT}/.rebrand-backup"
                mkdir -p "$(dirname "${backup_dir}/${file}")"
                cp "$file" "${backup_dir}/${file}"
            fi
            # macOS 和 Linux 兼容
            if [[ "$(uname)" == "Darwin" ]]; then
                sed -i '' "s|${pattern}|${replacement}|g" "$file"
            else
                sed -i "s|${pattern}|${replacement}|g" "$file"
            fi
        fi
    fi
}

# ── 收集所有待处理文件 ─────────────────────────────────────
echo -e "${BOLD}正在扫描文件...${NC}"
FILES=()
while IFS= read -r -d '' file; do
    # 跳过 .git, node_modules, .venv, __pycache__, dist, .rebrand-backup
    case "$file" in
        */.git/*|*/node_modules/*|*/.venv/*|*/__pycache__/*|*/dist/*|*/.rebrand-backup/*) continue ;;
        */.git|*/node_modules|*/.venv|*/__pycache__|*/dist|*/.rebrand-backup) continue ;;
        *.pyc|*.jpg|*.png|*.ico|*.zip|*.gz|*.tar|*.whl) continue ;;
    esac
    FILES+=("$file")
done < <(find "$PROJECT_ROOT" -type f -not -path '*/\.*' -print0 2>/dev/null || true)

echo -e "  找到 ${#FILES[@]} 个文件"
echo ""

# ── 执行内容替换（每个规则、每个文件） ─────────────────────
TOTAL_CHANGES=0
TOTAL_FILES=0

echo -e "${BOLD}──── 内容替换 ──────────────────────────────────${NC}"
echo ""

for rule in "${RULES[@]}"; do
    IFS='|' read -r pattern replacement exts desc <<< "$rule"

    rule_files=0
    rule_changes=0

    for file in "${FILES[@]}"; do
        rel="${file#$PROJECT_ROOT/}"
        ext_match "$rel" "$exts" || continue

        count=$(grep -c "$pattern" "$file" 2>/dev/null || true)
        if [[ "$count" -gt 0 ]]; then
            rule_changes=$((rule_changes + count))
            rule_files=$((rule_files + 1))
            preview_change "$file" "$pattern" "$replacement" ""
        fi
    done

    if [[ $rule_changes -gt 0 ]]; then
        echo -e "  ${GREEN}✓${NC} [${pattern}] → [${replacement}]"
        echo -e "     ${rule_files} 个文件, ${rule_changes} 处修改  (${desc})"
        TOTAL_CHANGES=$((TOTAL_CHANGES + rule_changes))
        TOTAL_FILES=$((TOTAL_FILES + rule_files))
    fi
done

echo ""
echo -e "${BOLD}──── 文件重命名 ────────────────────────────────${NC}"
echo ""

RENAMED_FILES=0
for rename in "${FILE_RENAMES[@]}"; do
    IFS='|' read -r old_path new_path <<< "$rename"
    old_abs="${PROJECT_ROOT}/${old_path}"

    if [[ -f "$old_abs" ]]; then
        echo -e "  ${GREEN}✓${NC} ${old_path}"
        echo -e "    → ${new_path}"
        if ! $DRY_RUN; then
            mv "$old_abs" "${PROJECT_ROOT}/${new_path}"
        fi
        RENAMED_FILES=$((RENAMED_FILES + 1))
    else
        echo -e "  ${YELLOW}跳过${NC} ${old_path} (文件不存在，可能已重命名)"
    fi
done

echo ""
echo -e "${BOLD}──── 目录重命名 ────────────────────────────────${NC}"
echo ""

if $RENAME_DIRS; then
    RENAMED_DIRS=0
    for rename in "${DIR_RENAMES[@]}"; do
        IFS='|' read -r old_dir new_dir <<< "$rename"
        old_abs="${PROJECT_ROOT}/${old_dir}"

        if [[ -d "$old_abs" ]]; then
            echo -e "  ${GREEN}✓${NC} ${old_dir}"
            echo -e "    → ${new_dir}"
            if ! $DRY_RUN; then
                mv "$old_abs" "${PROJECT_ROOT}/${new_dir}"
            fi
            RENAMED_DIRS=$((RENAMED_DIRS + 1))
        else
            echo -e "  ${YELLOW}跳过${NC} ${old_dir} (目录不存在，可能已重命名)"
        fi
    done
else
    echo -e "  ${YELLOW}跳过目录重命名（加上 --dirs 参数启用）${NC}"
    for rename in "${DIR_RENAMES[@]}"; do
        IFS='|' read -r old_dir new_dir <<< "$rename"
        old_abs="${PROJECT_ROOT}/${old_dir}"
        if [[ -d "$old_abs" ]]; then
            echo -e "    待处理: ${old_dir} → ${new_dir}"
        fi
    done
fi

echo ""
echo -e "${BOLD}──── 需要手动处理 ──────────────────────────────${NC}"
echo ""
echo -e "  ${RED}⚠${NC}  以下文件包含法律文本，必须手动审查修改："
for f in "${LEGAL_FILES[@]}"; do
    if [[ -f "${PROJECT_ROOT}/${f}" ]]; then
        echo -e "     ${CYAN}${f}${NC}"
    fi
done
echo ""
echo -e "  ${RED}⚠${NC}  以下内容需要手动替换："
echo -e "     ${CYAN}favicon.ico${NC} — 检查并替换默认图标"
echo -e "     ${CYAN}src/assets/logo/logo.png${NC} — 检查并替换默认Logo"
echo -e "     ${CYAN}README.md${NC} — 需要重写（截图URL、仓库地址、功能描述）"
echo -e "     ${CYAN}CHANGELOG.md${NC} — 版本标题中的项目名"

# ── 汇总 ───────────────────────────────────────────────────
echo ""
echo -e "${BOLD}${CYAN}╔══════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${CYAN}║  汇总                                      ║${NC}"
echo -e "${BOLD}${CYAN}╚══════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  内容修改:  ${GREEN}${TOTAL_CHANGES}${NC} 处替换"
echo -e "  文件重命名: ${GREEN}${RENAMED_FILES}${NC} 个"
if $RENAME_DIRS; then
    echo -e "  目录重命名: ${GREEN}${RENAMED_DIRS}${NC} 个"
else
    echo -e "  目录重命名: ${YELLOW}跳过${NC} (加 --dirs 启用)"
fi

if $DRY_RUN; then
    echo ""
    echo -e "  ${YELLOW}这是预览模式，未做任何实际修改${NC}"
    echo -e "  ${YELLOW}确认无误后运行: bash rebrand.sh --apply${NC}"
    echo -e "  ${YELLOW}含目录重命名:   bash rebrand.sh --apply --dirs${NC}"
    echo -e "  ${YELLOW}含备份:         bash rebrand.sh --apply --dirs --backup${NC}"
fi

echo ""
echo -e "${BOLD}完成后请手动做以下事情：${NC}"
echo -e "  1. 替换 public/favicon.ico 为你自己的图标"
echo -e "  2. 替换 src/assets/logo/logo.png 为你自己的Logo"
echo -e "  3. 重写移动端法律文件（agreement, privacy, help）"
echo -e "  4. 重写 README.md"
echo -e "  5. 更新 .git/config 中的 remote URL（如需要）"
echo -e "  6. 全局搜索确认无遗漏: grep -r 'ruoyi\|若依\|RuoYi\|vfadmin' --exclude-dir=.git"
echo -e "  7. git diff 检查所有变更后再提交"
