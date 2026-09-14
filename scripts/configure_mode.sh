#!/usr/bin/env bash
# scripts/configure_mode.sh
# Switches the ios_digital_wallet template between enterprise, lean, and plugin modes.
# Usage: ./scripts/configure_mode.sh <enterprise|lean|plugin> [--prune] [--force] [--root-dir=<path>] [--skip-tuist]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

usage() {
    cat <<EOF
Usage:
  ./scripts/configure_mode.sh <enterprise|lean|plugin> [options]

Modes:
  enterprise  Full enterprise template (3-tab shell, Scanner, Settings, ArchTests)
  lean        Standalone MVP template (2-tab shell, Settings, no Scanner)
  plugin      Flutter plugin devbed (Plugin package, Sample runner, no host Super App)

Options:
  --prune             Physically delete files not needed by the selected mode
  --force             Allow --prune even if git working tree has uncommitted changes
  --root-dir=<path>   Specify repository root directory (default: repo containing this script)
  --skip-tuist        Skip workspace generation via tuist
  -h, --help          Show this help message
EOF
}

die() {
    echo "configure_mode: $1" >&2
    exit 1
}

# --- Parse arguments --------------------------------------------------------
MODE=""
PRUNE=false
FORCE=false
SKIP_TUIST=false
ROOT_DIR="$DEFAULT_ROOT"

for arg in "$@"; do
    case "$arg" in
        enterprise|lean|plugin)
            if [ -n "$MODE" ]; then
                die "cannot specify multiple modes ('$MODE' and '$arg')"
            fi
            MODE="$arg"
            ;;
        --prune)
            PRUNE=true
            ;;
        --force)
            FORCE=true
            ;;
        --skip-tuist)
            SKIP_TUIST=true
            ;;
        --root-dir=*)
            ROOT_DIR="${arg#*=}"
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            die "unknown argument: $arg"
            ;;
    esac
done

if [ -z "$MODE" ]; then
    usage >&2
    die "missing required mode (enterprise, lean, or plugin)"
fi

# --- Guard --prune on dirty git working tree --------------------------------
if [ "$PRUNE" = true ]; then
    if (cd "$ROOT_DIR" && git rev-parse --is-inside-work-tree >/dev/null 2>&1); then
        DIRTY=$(cd "$ROOT_DIR" && git status --porcelain)
        if [ -n "$DIRTY" ] && [ "$FORCE" = false ]; then
            die "--prune refused: working tree has uncommitted modifications. Commit, stash, or pass --force to override."
        fi
    fi
fi

# --- Write ActiveMode.swift -------------------------------------------------
ACTIVE_MODE_FILE="$ROOT_DIR/Tuist/ProjectDescriptionHelpers/ActiveMode.swift"
mkdir -p "$(dirname "$ACTIVE_MODE_FILE")"
cat <<EOF > "$ACTIVE_MODE_FILE"
import ProjectDescription

public enum TemplateMode: String, CaseIterable {
    case enterprise
    case lean
    case plugin
}

public let activeMode: TemplateMode = .$MODE
EOF
echo "configure_mode: activeMode set to .$MODE"
export TUIST_TEMPLATE_MODE="$MODE"

# --- Invalidate Tuist/swifterpm build cache so manifest re-evaluates with new activeMode
rm -rf "$ROOT_DIR/Tuist/.build" "$ROOT_DIR/Tuist/Package.resolved"
if [ -f "$ROOT_DIR/Tuist/Package.swift" ]; then
    touch "$ROOT_DIR/Tuist/Package.swift"
fi

# --- Marker region helper via python3 ---------------------------------------
python3 - "$ROOT_DIR" "$MODE" << 'PYEOF'
import sys
import re
from pathlib import Path

root_dir = Path(sys.argv[1])
mode = sys.argv[2]

app_comp = root_dir / "App/Sources/Composition/AppComposition.swift"
deep_comp = root_dir / "App/Sources/Composition/DeepLinkComposition.swift"
shell_view = root_dir / "Packages/Shell/Sources/Shell/ShellView.swift"
shell_cfg = root_dir / "Packages/Shell/Sources/Shell/ShellConfig.swift"

def update_region(content: str, begin_tag: str, end_tag: str, transform_fn) -> str:
    pattern = re.compile(rf"([ \t]*//[ \t]*{re.escape(begin_tag)}\n)(.*?)(\n[ \t]*//[ \t]*{re.escape(end_tag)})", re.DOTALL)
    def replacer(match):
        prefix = match.group(1)
        body = match.group(2)
        suffix = match.group(3)
        return prefix + transform_fn(body) + suffix
    return pattern.sub(replacer, content)

def comment_lines(body: str) -> str:
    lines = []
    for line in body.split("\n"):
        if not line.strip():
            lines.append(line)
        elif line.lstrip().startswith("// "):
            lines.append(line)
        else:
            indent_len = len(line) - len(line.lstrip())
            indent = line[:indent_len]
            lines.append(indent + "// " + line[indent_len:])
    return "\n".join(lines)

def uncomment_lines(body: str) -> str:
    lines = []
    for line in body.split("\n"):
        if not line.strip():
            lines.append(line)
        elif line.lstrip().startswith("// "):
            indent_len = len(line) - len(line.lstrip())
            indent = line[:indent_len]
            rest = line.lstrip()[3:]
            lines.append(indent + rest)
        else:
            lines.append(line)
    return "\n".join(lines)

# 1. AppComposition.swift
if app_comp.exists():
    text = app_comp.read_text(encoding="utf-8")
    if mode == "lean":
        def transform_imports(b):
            return b.replace("import Scanner", "// import Scanner") if "// import Scanner" not in b else b
        def transform_providers(b):
            res = []
            for l in b.split("\n"):
                if ("scannerProvider" in l or "router.register(scannerProvider)" in l) and not l.lstrip().startswith("// "):
                    idx = len(l) - len(l.lstrip())
                    res.append(l[:idx] + "// " + l[idx:])
                else:
                    res.append(l)
            return "\n".join(res)
        text = update_region(text, "app:feature-imports:begin", "app:feature-imports:end", transform_imports)
        text = update_region(text, "app:route-providers:begin", "app:route-providers:end", transform_providers)
    elif mode == "enterprise":
        def restore_imports(b):
            return b.replace("// import Scanner", "import Scanner")
        def restore_providers(b):
            res = []
            for l in b.split("\n"):
                if ("scannerProvider" in l or "router.register(scannerProvider)" in l) and l.lstrip().startswith("// "):
                    idx = len(l) - len(l.lstrip())
                    res.append(l[:idx] + l.lstrip()[3:])
                else:
                    res.append(l)
            return "\n".join(res)
        text = update_region(text, "app:feature-imports:begin", "app:feature-imports:end", restore_imports)
        text = update_region(text, "app:route-providers:begin", "app:route-providers:end", restore_providers)
    app_comp.write_text(text, encoding="utf-8")

# 2. ShellView.swift
if shell_view.exists():
    text = shell_view.read_text(encoding="utf-8")
    if mode == "lean":
        text = update_region(text, "shell:scanner-tab:begin", "shell:scanner-tab:end", comment_lines)
        def set_settings_tab_1(b):
            b_uncommented = uncomment_lines(b)
            b_uncommented = b_uncommented.replace("tabStack(index: 2)", "tabStack(index: 1)")
            b_uncommented = b_uncommented.replace(".tag(2)", ".tag(1)")
            return b_uncommented
        text = update_region(text, "shell:settings-tab:begin", "shell:settings-tab:end", set_settings_tab_1)
    elif mode == "enterprise":
        text = update_region(text, "shell:scanner-tab:begin", "shell:scanner-tab:end", uncomment_lines)
        def set_settings_tab_2(b):
            b_uncommented = uncomment_lines(b)
            b_uncommented = b_uncommented.replace("tabStack(index: 1)", "tabStack(index: 2)")
            b_uncommented = b_uncommented.replace(".tag(1)", ".tag(2)")
            return b_uncommented
        text = update_region(text, "shell:settings-tab:begin", "shell:settings-tab:end", set_settings_tab_2)
    shell_view.write_text(text, encoding="utf-8")

# 3. DeepLinkComposition.swift
if deep_comp.exists():
    text = deep_comp.read_text(encoding="utf-8")
    if mode == "lean":
        text = update_region(text, "app:tab-resolver-scanner:begin", "app:tab-resolver-scanner:end", comment_lines)
    elif mode == "enterprise":
        text = update_region(text, "app:tab-resolver-scanner:begin", "app:tab-resolver-scanner:end", uncomment_lines)
    deep_comp.write_text(text, encoding="utf-8")

# 4. ShellConfig.swift
if shell_cfg.exists():
    text = shell_cfg.read_text(encoding="utf-8")
    if mode == "lean":
        def set_cfg_lean(b):
            return b.replace("tabCount: Int = 3, initialTab: Int = 2", "tabCount: Int = 2, initialTab: Int = 1")
        text = update_region(text, "shell:config-defaults:begin", "shell:config-defaults:end", set_cfg_lean)
    elif mode == "enterprise":
        def set_cfg_enterprise(b):
            return b.replace("tabCount: Int = 2, initialTab: Int = 1", "tabCount: Int = 3, initialTab: Int = 2")
        text = update_region(text, "shell:config-defaults:begin", "shell:config-defaults:end", set_cfg_enterprise)
    shell_cfg.write_text(text, encoding="utf-8")

# 5. Packages/Shell/Package.swift
shell_pkg = root_dir / "Packages/Shell/Package.swift"
if shell_pkg.exists():
    text = shell_pkg.read_text(encoding="utf-8")
    if mode == "lean":
        def set_exclude_lean(b):
            return '            exclude: ["ScannerTabTests.swift"]'
        text = update_region(text, "shell:test-excludes:begin", "shell:test-excludes:end", set_exclude_lean)
    elif mode == "enterprise":
        def set_exclude_enterprise(b):
            return '            exclude: []'
        text = update_region(text, "shell:test-excludes:begin", "shell:test-excludes:end", set_exclude_enterprise)
    shell_pkg.write_text(text, encoding="utf-8")

PYEOF

# --- Plugin mode handling ---------------------------------------------------
if [ "$MODE" = "plugin" ]; then
    BOOTSTRAP_SCRIPT="$ROOT_DIR/scripts/bootstrap_devbed.sh"
    if [ ! -f "$BOOTSTRAP_SCRIPT" ]; then
        die "Plugin mode is not yet implemented (requires bootstrap_devbed.sh from Task 5)"
    fi
    "$BOOTSTRAP_SCRIPT" --root-dir="$ROOT_DIR"
fi

# --- Handle --prune ---------------------------------------------------------
if [ "$PRUNE" = true ]; then
    echo "configure_mode: pruning unused files for mode '$MODE'..."
    if [ "$MODE" = "lean" ]; then
        if [ -d "$ROOT_DIR/Features/Scanner" ]; then
            rm -rf "$ROOT_DIR/Features/Scanner"
            echo "  pruned Features/Scanner"
        fi
        for f in \
            "Packages/Shell/Tests/ShellTests/ScannerTabTests.swift" \
            "App/Tests/AppTests/ScannerCompositionTests.swift" \
            "App/Tests/AppTests/ScannerDeepLinkTests.swift" \
            "App/UITests/ScannerTabUITests.swift"; do
            if [ -f "$ROOT_DIR/$f" ]; then
                rm -f "$ROOT_DIR/$f"
                echo "  pruned $f"
            fi
        done
    elif [ "$MODE" = "plugin" ]; then
        rm -rf "$ROOT_DIR/App" "$ROOT_DIR/Packages" "$ROOT_DIR/Features" "$ROOT_DIR/ArchTests"
        echo "  pruned App, Packages, Features, ArchTests"
    fi
fi

# --- Regenerate Tuist workspace ---------------------------------------------
if [ "$SKIP_TUIST" = false ]; then
    if which tuist >/dev/null 2>&1 || (cd "$ROOT_DIR" && which mise >/dev/null 2>&1); then
        echo "configure_mode: regenerating Xcode workspace with tuist..."
        (
            cd "$ROOT_DIR"
            export TUIST_TEMPLATE_MODE="$MODE"
            if which tuist >/dev/null 2>&1; then
                tuist install
                tuist generate --no-open
            else
                mise exec -- tuist install
                mise exec -- tuist generate --no-open
            fi
        )
    fi
fi

echo "configure_mode: mode '$MODE' configured successfully."
