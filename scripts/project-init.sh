#!/usr/bin/env bash
# =============================================================================
# project-init.sh — 一键初始化新项目的 Claude AI 工作流配置
#
# 用法：
#   ./scripts/project-init.sh <project-name>
#   ./scripts/project-init.sh kkday-ota-api-84
#   ./scripts/project-init.sh kkday-ota-api-84 --force   # 强制重新初始化
#
# 脚本会自动完成以下步骤：
#   Step 1  检查 Claude Code 安装
#   Step 2  初始化 ai-hub-shanghai 项目目录 + MEMORY.md
#   Step 3  在新项目创建 .claude/settings.local.json
#   Step 4  安装 speckit（npx speckit@latest init）
#   Step 5  复制 CLAUDE.md.template 到新项目
#   Step 6  验证所有配置
#   Step 7  记录到 initialized_projects.md
# =============================================================================

set -e

# ---------------------------------------------------------------------------
# 颜色输出
# ---------------------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m' # No Color

info()    { echo -e "${BLUE}[INFO]${NC} $*"; }
success() { echo -e "${GREEN}[✅ OK]${NC} $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $*"; }
error()   { echo -e "${RED}[❌ ERROR]${NC} $*"; }
step()    { echo -e "\n${BOLD}${BLUE}━━ $* ${NC}"; }

# ---------------------------------------------------------------------------
# 参数解析
# ---------------------------------------------------------------------------
FORCE=false
PROJECT_NAME=""

for arg in "$@"; do
  case $arg in
    --force) FORCE=true ;;
    --help|-h)
      echo "用法: $0 <project-name> [--force]"
      echo ""
      echo "  project-name  项目目录名（与 git 仓库名一致）"
      echo "  --force       跳过已初始化检查，强制重新执行所有步骤"
      echo ""
      echo "示例:"
      echo "  $0 kkday-ota-api-84"
      echo "  $0 kkday-ota-api-84 --force"
      exit 0
      ;;
    -*) warn "未知参数: $arg" ;;
    *)  PROJECT_NAME="$arg" ;;
  esac
done

if [ -z "$PROJECT_NAME" ]; then
  error "必须指定项目名称"
  echo "用法: $0 <project-name> [--force]"
  exit 1
fi

# ---------------------------------------------------------------------------
# 路径配置
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AI_HUB_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"                          # ai-hub-shanghai 根目录
PROJECTS_BASE="$(cd "$AI_HUB_DIR/.." && pwd)"                       # 同级目录（存放各项目）
PROJECT_DIR="$PROJECTS_BASE/$PROJECT_NAME"                           # 新项目目录
AI_HUB_PROJECT_DIR="$AI_HUB_DIR/projects/$PROJECT_NAME"             # ai-hub-shanghai 内项目目录
INITIALIZED_FILE="$AI_HUB_DIR/global/initialized_projects.md"
TEMPLATE_DIR="$AI_HUB_DIR/global/templates"
CLAUDE_TEMPLATE="$TEMPLATE_DIR/CLAUDE.md.template"

echo ""
echo -e "${BOLD}🚀 ai-hub-shanghai 项目初始化${NC}"
echo -e "   项目名称: ${BOLD}$PROJECT_NAME${NC}"
echo -e "   项目目录: $PROJECT_DIR"
echo -e "   AI Hub:   $AI_HUB_DIR"
echo ""

# ---------------------------------------------------------------------------
# Step 0 — 检查是否已初始化
# ---------------------------------------------------------------------------
step "Step 0 — 检查初始化状态"

if [ "$FORCE" = false ] && grep -q "| \`$PROJECT_NAME\`" "$INITIALIZED_FILE" 2>/dev/null; then
  RECORD=$(grep "| \`$PROJECT_NAME\`" "$INITIALIZED_FILE")
  # 检查是否所有步骤都是 ✅
  FAIL_COUNT=$(echo "$RECORD" | grep -o "❌" | wc -l | tr -d ' ')
  if [ "$FAIL_COUNT" = "0" ]; then
    success "项目 '$PROJECT_NAME' 已完成全部初始化，跳过"
    echo -e "   记录：$RECORD"
    echo ""
    echo -e "   如需重新初始化，请使用 ${BOLD}--force${NC} 参数"
    exit 0
  else
    warn "项目 '$PROJECT_NAME' 存在 $FAIL_COUNT 个未完成步骤，继续初始化..."
  fi
else
  info "未找到初始化记录，开始初始化..."
fi

# ---------------------------------------------------------------------------
# Step 1 — 检查 Claude Code 安装
# ---------------------------------------------------------------------------
step "Step 1 — 检查 Claude Code 安装"

if command -v claude &>/dev/null; then
  CLAUDE_VERSION=$(claude --version 2>/dev/null | head -1)
  success "Claude Code 已安装：$CLAUDE_VERSION"
else
  warn "Claude Code 未安装，尝试安装..."
  if command -v npm &>/dev/null; then
    npm install -g @anthropic-ai/claude-code
    success "Claude Code 安装完成"
  else
    error "npm 未安装，请手动安装 Claude Code："
    error "  npm install -g @anthropic-ai/claude-code"
    exit 1
  fi
fi

STEP1_STATUS="✅"

# ---------------------------------------------------------------------------
# Step 2 — 检查项目目录存在
# ---------------------------------------------------------------------------
step "Step 2 — 检查项目目录"

if [ ! -d "$PROJECT_DIR" ]; then
  error "项目目录不存在：$PROJECT_DIR"
  error "请先 clone 项目："
  error "  git clone git@github.com:<org>/$PROJECT_NAME.git $PROJECT_DIR"
  exit 1
fi

if [ ! -d "$PROJECT_DIR/.git" ]; then
  error "$PROJECT_DIR 不是 git 仓库"
  exit 1
fi

success "项目目录存在：$PROJECT_DIR"

# 推断 fork/org 账号
FORK_ACCOUNT=$(cd "$PROJECT_DIR" && git remote -v 2>/dev/null | grep "origin.*fetch" | sed 's/.*[:/]\([^/]*\)\/.*/\1/' | head -1)
ORG_ACCOUNT=$(cd "$PROJECT_DIR" && git remote -v 2>/dev/null | grep "upstream.*fetch" | sed 's/.*[:/]\([^/]*\)\/.*/\1/' | head -1)
info "Fork 账号: ${FORK_ACCOUNT:-（未检测到）}  |  Org 账号: ${ORG_ACCOUNT:-（未检测到，origin 可能是 org）}"

# ---------------------------------------------------------------------------
# Step 3 — 初始化 ai-hub-shanghai 项目目录
# ---------------------------------------------------------------------------
step "Step 3 — 初始化 ai-hub-shanghai 项目目录"

mkdir -p "$AI_HUB_PROJECT_DIR/memory"
mkdir -p "$AI_HUB_PROJECT_DIR/specs"

if [ ! -f "$AI_HUB_PROJECT_DIR/memory/MEMORY.md" ]; then
  cat > "$AI_HUB_PROJECT_DIR/memory/MEMORY.md" << 'EOF'
# Memory Index

| 文件 | 类型 | 摘要 |
|------|------|------|
EOF
  success "MEMORY.md 已创建"
else
  info "MEMORY.md 已存在，跳过"
fi

success "ai-hub-shanghai 项目目录已就绪：$AI_HUB_PROJECT_DIR"
STEP3_STATUS="✅"

# ---------------------------------------------------------------------------
# Step 4 — 创建 .claude/settings.local.json
# ---------------------------------------------------------------------------
step "Step 4 — 创建 .claude/settings.local.json"

mkdir -p "$PROJECT_DIR/.claude"

SETTINGS_LOCAL="$PROJECT_DIR/.claude/settings.local.json"

if [ -f "$SETTINGS_LOCAL" ] && [ "$FORCE" = false ]; then
  # 检查是否已有正确的 autoMemoryDirectory
  if grep -q "ai-hub-shanghai" "$SETTINGS_LOCAL" 2>/dev/null; then
    info "settings.local.json 已存在且包含 ai-hub-shanghai 配置，跳过"
    STEP4_STATUS="✅"
  else
    warn "settings.local.json 存在但未包含 ai-hub-shanghai 配置，将覆盖"
  fi
fi

if [ "$STEP4_STATUS" != "✅" ]; then
  cat > "$SETTINGS_LOCAL" << EOF
{
  "autoMemoryDirectory": "$AI_HUB_PROJECT_DIR/memory/",
  "permissions": {
    "additionalDirectories": [
      "$AI_HUB_PROJECT_DIR/"
    ]
  }
}
EOF
  success "settings.local.json 已创建"
  STEP4_STATUS="✅"
fi

# 加入 .gitignore
GITIGNORE="$PROJECT_DIR/.gitignore"
if [ -f "$GITIGNORE" ]; then
  if ! grep -q "\.claude/settings\.local\.json" "$GITIGNORE"; then
    echo ".claude/settings.local.json" >> "$GITIGNORE"
    success ".claude/settings.local.json 已加入 .gitignore"
  else
    info ".gitignore 已包含 settings.local.json，跳过"
  fi
else
  echo ".claude/settings.local.json" > "$GITIGNORE"
  success ".gitignore 已创建"
fi

# ---------------------------------------------------------------------------
# Step 5 — 初始化 speckit 目录结构
# ---------------------------------------------------------------------------
step "Step 5 — 初始化 speckit 目录结构"

SPECIFY_DIR="$PROJECT_DIR/.specify"

if [ -d "$SPECIFY_DIR" ] && [ "$FORCE" = false ]; then
  success "speckit 已初始化（.specify/ 目录存在）"
  STEP5_STATUS="✅"
else
  info "从模板复制 speckit 目录结构..."

  # 查找参考项目（优先使用 kkday-kkpartners-api）
  REFERENCE_SPECIFY=""
  for candidate in "$PROJECTS_BASE/kkday-kkpartners-api/.specify" "$AI_HUB_DIR/../kkday-kkpartners-api/.specify"; do
    if [ -d "$candidate" ]; then
      REFERENCE_SPECIFY="$candidate"
      break
    fi
  done

  if [ -n "$REFERENCE_SPECIFY" ]; then
    mkdir -p "$SPECIFY_DIR/memory" "$SPECIFY_DIR/scripts" "$SPECIFY_DIR/templates"
    cp "$REFERENCE_SPECIFY/init-options.json" "$SPECIFY_DIR/init-options.json"
    [ -d "$REFERENCE_SPECIFY/scripts" ] && cp -r "$REFERENCE_SPECIFY/scripts/." "$SPECIFY_DIR/scripts/"

    # 使用 global 通用需求模板
    if [ -f "$TEMPLATE_DIR/requirements-template.md" ]; then
      cp "$TEMPLATE_DIR/requirements-template.md" "$SPECIFY_DIR/templates/requirements-template.md"
    fi

    success "speckit 目录结构已创建（从 $(basename $(dirname $REFERENCE_SPECIFY)) 复制）"
    info "⚠️  /speckit.constitution 需在 Claude Code 中手动执行（交互式，无法自动化）"
    STEP5_STATUS="✅"
  else
    warn "未找到参考项目的 .specify 目录，请手动执行："
    warn "  cd $PROJECT_DIR && specify init --here"
    warn "  或手动创建 .specify/ 目录结构"
    STEP5_STATUS="❌"
  fi
fi

# ---------------------------------------------------------------------------
# Step 6 — 复制 CLAUDE.md.template
# ---------------------------------------------------------------------------
step "Step 6 — 复制 CLAUDE.md 模板"

CLAUDE_MD="$PROJECT_DIR/CLAUDE.md"

if [ -f "$CLAUDE_MD" ] && [ "$FORCE" = false ]; then
  info "CLAUDE.md 已存在，跳过（使用 --force 覆盖）"
  STEP6_STATUS="✅"
elif [ -f "$CLAUDE_TEMPLATE" ]; then
  cp "$CLAUDE_TEMPLATE" "$CLAUDE_MD"
  # 替换模板变量
  PROJECT_NAME_UPPER=$(echo "$PROJECT_NAME" | tr '[:lower:]' '[:upper:]' | tr '-' '_')
  sed -i.bak "s/{{REPO_SLUG}}/$PROJECT_NAME/g" "$CLAUDE_MD"
  sed -i.bak "s/{{FORK_ACCOUNT}}/${FORK_ACCOUNT:-YOUR_FORK}/g" "$CLAUDE_MD"
  sed -i.bak "s/{{ORG_ACCOUNT}}/${ORG_ACCOUNT:-YOUR_ORG}/g" "$CLAUDE_MD"
  sed -i.bak "s/{{AI_HUB_DIR}}/$(echo "$AI_HUB_DIR" | sed 's/\//\\\//g')/g" "$CLAUDE_MD"
  rm -f "$CLAUDE_MD.bak"
  success "CLAUDE.md 已从模板创建（请手动补充项目特定内容）"
  STEP6_STATUS="✅"
else
  warn "模板文件不存在：$CLAUDE_TEMPLATE"
  warn "请手动创建 CLAUDE.md，参考 projects/kkday-kkpartners-api/CLAUDE.md"
  STEP6_STATUS="❌"
fi

# ---------------------------------------------------------------------------
# Step 7 — 验证所有配置
# ---------------------------------------------------------------------------
step "Step 7 — 验证配置"

VERIFY_PASS=true

check() {
  local label="$1"
  local result="$2"
  if [ "$result" = "ok" ]; then
    success "$label"
  else
    error "$label"
    VERIFY_PASS=false
  fi
}

check "Claude Code 已安装" "$(command -v claude &>/dev/null && echo ok || echo fail)"
check "ai-hub-shanghai/memory/MEMORY.md 存在" "$([ -f "$AI_HUB_PROJECT_DIR/memory/MEMORY.md" ] && echo ok || echo fail)"
check ".claude/settings.local.json 存在" "$([ -f "$SETTINGS_LOCAL" ] && echo ok || echo fail)"
check "settings.local.json 包含 autoMemoryDirectory" "$(grep -q autoMemoryDirectory "$SETTINGS_LOCAL" 2>/dev/null && echo ok || echo fail)"
check ".gitignore 包含 settings.local.json" "$(grep -q settings.local.json "$GITIGNORE" 2>/dev/null && echo ok || echo fail)"
check "speckit 已安装（.specify/ 存在）" "$([ -d "$PROJECT_DIR/.specify" ] && echo ok || echo fail)"
check "CLAUDE.md 存在" "$([ -f "$CLAUDE_MD" ] && echo ok || echo fail)"

# ---------------------------------------------------------------------------
# Step 8 — 记录到 initialized_projects.md
# ---------------------------------------------------------------------------
step "Step 8 — 记录初始化状态"

CONSTITUTION_STATUS="❌"
[ -f "$PROJECT_DIR/.specify/constitution.md" ] && CONSTITUTION_STATUS="✅"

TODAY=$(date +%Y-%m-%d)
NEW_RECORD="| \`$PROJECT_NAME\` | \`$PROJECT_DIR\` | $TODAY | $STEP1_STATUS | $STEP3_STATUS | $STEP4_STATUS | $STEP5_STATUS | $CONSTITUTION_STATUS | $STEP6_STATUS | $([ "$VERIFY_PASS" = true ] && echo ✅ || echo ❌) |"

# 检查是否已有记录，有则替换，无则追加
if grep -q "| \`$PROJECT_NAME\`" "$INITIALIZED_FILE" 2>/dev/null; then
  # 替换已有记录
  TMP_FILE=$(mktemp)
  while IFS= read -r line; do
    if echo "$line" | grep -q "| \`$PROJECT_NAME\`"; then
      echo "$NEW_RECORD"
    else
      echo "$line"
    fi
  done < "$INITIALIZED_FILE" > "$TMP_FILE"
  mv "$TMP_FILE" "$INITIALIZED_FILE"
  info "已更新初始化记录"
else
  echo "$NEW_RECORD" >> "$INITIALIZED_FILE"
  info "已追加初始化记录"
fi

# ---------------------------------------------------------------------------
# 完成汇报
# ---------------------------------------------------------------------------
echo ""
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
if [ "$VERIFY_PASS" = true ]; then
  echo -e "${GREEN}${BOLD}🎉 项目 '$PROJECT_NAME' 初始化完成！${NC}"
else
  echo -e "${YELLOW}${BOLD}⚠️  项目 '$PROJECT_NAME' 初始化完成（部分步骤需手动处理）${NC}"
fi
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "  下一步（手动）："
echo "  1. 在 $PROJECT_DIR 中打开 Claude Code："
echo "     cd $PROJECT_DIR && claude"
echo ""
echo "  2. 在 Claude 对话中执行 constitution（首次必须手动）："
echo "     /speckit.constitution"
echo ""
if [ "$STEP6_STATUS" = "✅" ]; then
  echo "  3. 补充 CLAUDE.md 中的项目特定内容："
  echo "     - Project Overview（项目目标、用户、技术栈）"
  echo "     - Common Development Commands"
  echo "     - Codebase Architecture"
fi
echo ""
echo "  4. 提交 ai-hub-shanghai 变更："
echo "     cd $AI_HUB_DIR && git add projects/$PROJECT_NAME global/initialized_projects.md && git commit -m 'init: add $PROJECT_NAME'"
echo ""
