#!/usr/bin/env bash

set -euo pipefail

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "${script_dir}/build-relevance.sh"

notes_file="${1:-release-notes.md}"
head_sha="${GITHUB_SHA:-HEAD}"
repository="${GITHUB_REPOSITORY:-$(git config --get remote.origin.url | sed -E 's#(git@github.com:|https://github.com/)##; s#\.git$##')}"
server_url="${GITHUB_SERVER_URL:-https://github.com}"

feat_file=$(mktemp)
fix_file=$(mktemp)
perf_file=$(mktemp)
refactor_file=$(mktemp)
docs_file=$(mktemp)
style_file=$(mktemp)
chore_file=$(mktemp)
revert_file=$(mktemp)
trap 'rm -f "$feat_file" "$fix_file" "$perf_file" "$refactor_file" "$docs_file" "$style_file" "$chore_file" "$revert_file"' EXIT

trim_text() {
    local value=$1

    printf '%s' "$value" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//'
}

strip_commit_type_prefix() {
    local subject=$1
    local commit_prefix_regex='^[A-Za-z]+(\([^)]+\))?(!)?[:：][[:space:]]*(.*)$'

    if [[ "$subject" =~ $commit_prefix_regex ]]; then
        subject=${BASH_REMATCH[3]}
    fi

    trim_text "$subject"
}

raw_commit_type() {
    local subject=$1
    local raw_type
    local commit_type_regex='^([A-Za-z]+)(\([^)]+\))?(!)?[:：]'

    if [[ "$subject" =~ $commit_type_regex ]]; then
        raw_type=${BASH_REMATCH[1]}
        printf '%s' "$raw_type" | tr '[:upper:]' '[:lower:]'
        return
    fi

    printf ''
}

canonical_commit_type() {
    local subject=$1
    local raw_type

    raw_type=$(raw_commit_type "$subject")
    case "$raw_type" in
        feat|feature|add)
            printf 'feat'
            return
            ;;
        fix|bug|bugfix)
            printf 'fix'
            return
            ;;
        perf|performance)
            printf 'perf'
            return
            ;;
        refactor)
            printf 'refactor'
            return
            ;;
        docs|doc)
            printf 'docs'
            return
            ;;
        style|format)
            printf 'style'
            return
            ;;
        chore|build|ci|test|merge)
            printf 'chore'
            return
            ;;
        revert)
            printf 'revert'
            return
            ;;
    esac

    case "$subject" in
        Revert\ *|revert:*|revert：*|回滚*|撤销*)
            printf 'revert'
            ;;
        新增*|增加*|添加*|支持*|引入*|实现*)
            printf 'feat'
            ;;
        修复*|解决*|恢复*|纠正*)
            printf 'fix'
            ;;
        性能*|提速*|加速*|*性能*优化*|*速度*优化*|*加载*优化*)
            printf 'perf'
            ;;
        重构*|简化*|清理*|整理*|调整*|优化*|完善*)
            printf 'refactor'
            ;;
        文档*|README*|readme*|注释*|更新版本号*|版本更新*)
            printf 'docs'
            ;;
        格式*|格式化*)
            printf 'style'
            ;;
        *)
            printf 'chore'
            ;;
    esac
}

version_summary_for_commit() {
    local hash=$1
    local previous_version
    local current_version

    previous_version=$(
        git show "${hash}^:control" 2>/dev/null |
            awk -F': ' '$1 == "Version" { print $2; exit }' || true
    )
    current_version=$(
        git show "${hash}:control" 2>/dev/null |
            awk -F': ' '$1 == "Version" { print $2; exit }' || true
    )

    if [[ -n "$current_version" && "$previous_version" != "$current_version" ]]; then
        if [[ -n "$previous_version" ]]; then
            printf '更新版本号：`%s` → `%s`' "$previous_version" "$current_version"
        else
            printf '设置版本号为 `%s`' "$current_version"
        fi
    fi
}

keyword_content_for_subject() {
    local subject=$1
    local commit_type=$2

    case "$subject" in
        *清屏隐藏清屏按钮*)
            printf '清屏按钮隐藏选项'
            ;;
        *清屏隐藏暂停图标*|*暂停图标*)
            if [[ "$commit_type" == "feat" ]]; then
                printf '清屏暂停图标隐藏选项'
            else
                printf '清屏暂停图标显示状态'
            fi
            ;;
        *暂停按钮*)
            if [[ "$commit_type" == "feat" ]]; then
                printf '清屏暂停按钮隐藏选项'
            else
                printf '清屏暂停按钮显示状态'
            fi
            ;;
        *贴边效果*)
            printf '隐藏按钮贴边效果'
            ;;
        *倍速按钮*不显示*|*倍速按钮可能不显示*)
            printf '倍速按钮显示状态'
            ;;
        *倍数悬浮按钮*数字*|*倍速悬浮按钮*数字*)
            printf '倍速悬浮按钮数字恢复状态'
            ;;
        *系统状态栏*|*隐藏状态栏*|*隐藏系统状态栏*)
            if [[ "$commit_type" == "feat" ]]; then
                printf '清屏状态栏隐藏功能'
            else
                printf '清屏状态栏隐藏状态'
            fi
            ;;
        *右侧图标*|*收藏*)
            printf '清屏恢复后的右侧图标显示'
            ;;
        *头像下加号*)
            printf '头像加号替代入口隐藏逻辑'
            ;;
        *圆形底板*)
            printf '头像入口圆形底板隐藏'
            ;;
        *打印所有视图*|*视图的接口*)
            printf '视图调试接口'
            ;;
        *Release*|*release*)
            printf 'Release 更新日志'
            ;;
        *dylib*|*Dylib*)
            printf 'dylib 发布产物'
            ;;
        *Deb*|*deb*)
            printf 'Deb 构建产物'
            ;;
    esac
}

summarize_commit_title() {
    local hash=$1
    local subject=$2
    local commit_type=$3
    local content
    local version_summary
    local revert_regex='^Revert[[:space:]]+"(.*)"$'
    local keyword_content

    if commit_touches_control "$hash"; then
        version_summary=$(version_summary_for_commit "$hash")
        if [[ -n "$version_summary" ]]; then
            printf '%s' "$version_summary"
            return
        fi
    fi

    if commit_touches_path "$hash" "Makefile" &&
       ! commit_touches_direct_build_path "$hash"; then
        printf '调整 Deb 构建配置'
        return
    fi

    content=$(strip_commit_type_prefix "$subject")
    content=$(printf '%s' "$content" | sed -E 's/[[:space:]。；;，,]+$//')

    if [[ "$commit_type" == "revert" && "$content" =~ $revert_regex ]]; then
        content=$(strip_commit_type_prefix "${BASH_REMATCH[1]}")
    fi

    keyword_content=$(keyword_content_for_subject "$subject" "$commit_type")
    if [[ -n "$keyword_content" ]]; then
        content=$keyword_content
    fi

    case "$commit_type" in
        feat)
            content=$(printf '%s' "$content" | sed -E 's/^(新增|增加|添加|支持|引入|实现|优化)[[:space:]:：]*//')
            content=$(trim_text "$content")
            printf '新增%s' "${content:-插件功能}"
            ;;
        fix)
            content=$(printf '%s' "$content" | sed -E 's/^(修复|解决|恢复|纠正|修改|调整)[[:space:]:：]*//; s/的问题$//')
            content=$(printf '%s' "$content" | sed -E 's/不生效/生效异常/g; s/失效/异常/g; s/无法/不能/g')
            content=$(trim_text "$content")
            printf '修正%s' "${content:-已知问题}"
            ;;
        perf)
            content=$(printf '%s' "$content" | sed -E 's/^(性能优化|优化|提升|改善|提速|加速)[[:space:]:：]*//')
            content=$(trim_text "$content")
            printf '优化%s' "${content:-运行性能}"
            ;;
        refactor)
            content=$(printf '%s' "$content" | sed -E 's/^(重构|简化|清理|整理|调整|优化|完善)[[:space:]:：]*//')
            content=$(trim_text "$content")
            printf '整理%s' "${content:-代码结构}"
            ;;
        docs)
            content=$(printf '%s' "$content" | sed -E 's/^(文档|更新|修改|补充)[[:space:]:：]*//')
            content=$(trim_text "$content")
            printf '更新%s' "${content:-文档说明}"
            ;;
        style)
            content=$(printf '%s' "$content" | sed -E 's/^(格式化|格式|规范|调整)[[:space:]:：]*//')
            content=$(trim_text "$content")
            printf '规范%s' "${content:-代码格式}"
            ;;
        revert)
            content=$(printf '%s' "$content" | sed -E 's/^(回滚|撤销|取消)[[:space:]:：]*//')
            content=$(trim_text "$content")
            printf '回滚%s' "${content:-上一项变更}"
            ;;
        *)
            content=$(printf '%s' "$content" | sed -E 's/^(杂项|其他|更新|调整|同步)[[:space:]:：]*//')
            content=$(trim_text "$content")
            printf '调整%s' "${content:-构建与维护项}"
            ;;
    esac
}

section_file_for_type() {
    case "$1" in
        feat) printf '%s' "$feat_file" ;;
        fix) printf '%s' "$fix_file" ;;
        perf) printf '%s' "$perf_file" ;;
        refactor) printf '%s' "$refactor_file" ;;
        docs) printf '%s' "$docs_file" ;;
        style) printf '%s' "$style_file" ;;
        revert) printf '%s' "$revert_file" ;;
        *) printf '%s' "$chore_file" ;;
    esac
}

commit_touches_control() {
    local hash=$1

    commit_touches_path "$hash" "control"
}

if [[ -n "${PUSH_BEFORE:-}" && "$PUSH_BEFORE" != "$zero_sha" ]] &&
   git cat-file -e "${PUSH_BEFORE}^{commit}" 2>/dev/null; then
    commit_range="${PUSH_BEFORE}..${head_sha}"
else
    previous_tag=$(git tag --list 'DYYY_*-build.*' --sort=-version:refname | head -n 1)
    if [[ -n "$previous_tag" ]]; then
        commit_range="${previous_tag}..${head_sha}"
    elif git rev-parse "${head_sha}^" >/dev/null 2>&1; then
        commit_range="${head_sha}^..${head_sha}"
    else
        commit_range="$head_sha"
    fi
fi

relevant_count=0

while IFS=$'\t' read -r hash subject; do
    [[ -n "$hash" ]] || continue

    parent_count=$(git rev-list --parents -n 1 "$hash" | awk '{ print NF - 1 }')
    if (( parent_count > 1 )) || ! commit_affects_build "$hash"; then
        continue
    fi

    relevant_count=$((relevant_count + 1))
    short_hash=${hash:0:8}
    commit_type=$(canonical_commit_type "$subject")
    summary_title=$(summarize_commit_title "$hash" "$subject" "$commit_type")
    entry="- \`${commit_type}\` **${summary_title}** ([\`${short_hash}\`](${server_url}/${repository}/commit/${hash}))"
    printf '%s\n' "$entry" >> "$(section_file_for_type "$commit_type")"
done < <(git log --reverse --format=$'%H\t%s' "$commit_range")

cat > "$notes_file" <<EOF
# 更新日志

本次构建包含 ${relevant_count} 项插件、版本或构建配置变更，以下为详细更新内容：
EOF

append_section() {
    local title=$1
    local section_file=$2

    if [[ -s "$section_file" ]]; then
        printf '\n## %s\n\n' "$title" >> "$notes_file"
        cat "$section_file" >> "$notes_file"
    fi
}

append_section "新增功能" "$feat_file"
append_section "修复问题" "$fix_file"
append_section "性能优化" "$perf_file"
append_section "代码重构" "$refactor_file"
append_section "文档更新" "$docs_file"
append_section "代码格式" "$style_file"
append_section "杂项/其他" "$chore_file"
append_section "回滚" "$revert_file"

if (( relevant_count == 0 )); then
    printf '\n本次手动构建未检测到新的插件、版本或构建配置变更。\n' >> "$notes_file"
fi

cat >> "$notes_file" <<'EOF'

---

本 Release 随附 Rootful、Rootless、Roothide 三个 Deb 安装包，并额外提供从 arm64e Deb 提取的 dylib，便于按需单独取用。
EOF

cat "$notes_file"
