#!/usr/bin/env python3
"""
merge_localizations.py
----------------------
Multi-module localization merger, Slang-style code generator, and Backend JSON synchronizer for iOS.

1. Discovers all module-level `Localizable.xcstrings` in `Packages/` and `Features/`.
2. Merges them into a unified master catalog at:
   - `App/Resources/Localizable.xcstrings` (for the main application bundle)
   - `Packages/Platform/Resources/Localizable.xcstrings` (for Platform package fallback)
3. Automatically generates typed Slang-style Swift accessors in:
   - `Packages/Platform/Sources/Platform/Localization/Translations.generated.swift`
4. Exports Backend-compatible nested JSON files matching the remote API schema:
   - `App/Resources/backend_translations/{lang}.json` (e.g., en.json, vi.json)

Usage:
    python3 scripts/merge_localizations.py
"""

import glob
import json
import os
import re
import sys

def validate_catalogs(source_files, repo_root):
    """
    Validates all discovered module catalogs against DOs & DON'Ts rules:
    1. Schema version: must have "version": "1.0"
    2. Minimum segments: must be at least <feature>.<key> (>= 2 parts)
    3. camelCase: every segment must match ^[a-z][a-zA-Z0-9]*$
    4. Namespace ownership: first segment must match module name (e.g. 'settings', 'scanner', 'shell', 'home')
    5. Structural collision: no leaf key can be a prefix of another key (e.g. 'settings.account' vs 'settings.account.profile')
    """
    errors = []
    camel_case_regex = re.compile(r"^[a-z][a-zA-Z0-9]*$")
    all_keys = set()
    key_to_file = {}

    for file_path in source_files:
        rel_file = os.path.relpath(file_path, repo_root)
        try:
            with open(file_path, "r", encoding="utf-8") as fp:
                data = json.load(fp)
        except Exception as e:
            errors.append(f"{rel_file}: Invalid JSON file: {e}")
            continue

        if data.get("version") != "1.0":
            errors.append(f"{rel_file}: Missing or invalid 'version' field. Must be '\"version\": \"1.0\"'.")

        expected_prefixes = []
        parts = rel_file.split(os.sep)
        if "Features" in parts:
            idx = parts.index("Features")
            if idx + 1 < len(parts):
                feat_name = parts[idx + 1]
                expected_prefixes.append(feat_name[:1].lower() + feat_name[1:])
        elif "Packages" in parts:
            idx = parts.index("Packages")
            if idx + 1 < len(parts):
                pkg_name = parts[idx + 1]
                p_camel = pkg_name[:1].lower() + pkg_name[1:]
                expected_prefixes.append(p_camel)
                if p_camel == "shell":
                    expected_prefixes.append("home")

        strings = data.get("strings", {})
        if not isinstance(strings, dict):
            errors.append(f"{rel_file}: 'strings' must be a dictionary.")
            continue

        for key, entry in strings.items():
            segments = key.split(".")
            if len(segments) < 2:
                errors.append(
                    f"{rel_file}: Key '{key}' has only {len(segments)} segment. "
                    f"Must have at least 2 segments (<feature>.<key>), e.g. '{expected_prefixes[0] if expected_prefixes else 'feature'}.{key}'."
                )

            for seg in segments:
                if not camel_case_regex.match(seg):
                    errors.append(
                        f"{rel_file}: Key '{key}' contains segment '{seg}' which is not valid camelCase (^[a-z][a-zA-Z0-9]*$). "
                        f"Avoid snake_case, kebab-case, or starting with uppercase."
                    )

            if expected_prefixes and segments[0] not in expected_prefixes:
                errors.append(
                    f"{rel_file}: Key '{key}' begins with '{segments[0]}', but module is '{rel_file}'. "
                    f"Expected prefix from: {expected_prefixes}."
                )

            all_keys.add(key)
            key_to_file[key] = rel_file

    sorted_keys = sorted(all_keys)
    for i in range(len(sorted_keys) - 1):
        k1 = sorted_keys[i]
        k2 = sorted_keys[i + 1]
        if k2.startswith(k1 + "."):
            f1 = key_to_file[k1]
            f2 = key_to_file[k2]
            errors.append(
                f"Structural Collision: Key '{k1}' ({f1}) is a leaf string, but '{k2}' ({f2}) defines it as a branch/subfeature. "
                f"Rename '{k1}' (e.g. to '{k1}.title') so it does not conflict with child properties."
            )

    return errors

def main():
    script_dir = os.path.dirname(os.path.abspath(__file__))
    repo_root = os.path.dirname(script_dir)

    # Destination paths for merged catalogs (Apple .xcstrings format)
    dest_paths = [
        os.path.abspath(os.path.join(repo_root, "App", "Resources", "Localizable.xcstrings")),
        os.path.abspath(os.path.join(repo_root, "Packages", "Platform", "Resources", "Localizable.xcstrings")),
    ]

    # 1. Discover all module-level xcstrings (exclude destination catalogs)
    patterns = [
        os.path.join(repo_root, "Packages", "**", "Localizable.xcstrings"),
        os.path.join(repo_root, "Features", "**", "Localizable.xcstrings"),
    ]

    source_files = []
    for pattern in patterns:
        for path in glob.glob(pattern, recursive=True):
            abs_path = os.path.abspath(path)
            if ".build" in abs_path or "DerivedData" in abs_path:
                continue
            if abs_path in dest_paths:
                continue
            source_files.append(abs_path)

    source_files = sorted(set(source_files))
    print(f"📦 Discovered {len(source_files)} module catalog(s):")
    for f in source_files:
        rel = os.path.relpath(f, repo_root)
        print(f"   • {rel}")

    # 2. Validate all catalogs against DOs & DON'Ts rules
    validation_errors = validate_catalogs(source_files, repo_root)
    if validation_errors:
        print("\n❌ Localization Validation FAILED (DOs & DON'Ts violations):", file=sys.stderr)
        for err in validation_errors:
            print(f"   • {err}", file=sys.stderr)
        sys.exit(1)

    print("🛡️  All module catalogs passed DOs & DON'Ts validation rules.")

    # 3. Merge all catalogs
    merged_strings = {}
    source_language = "en"

    for file_path in source_files:
        try:
            with open(file_path, "r", encoding="utf-8") as fp:
                data = json.load(fp)
                if "sourceLanguage" in data:
                    source_language = data["sourceLanguage"]
                strings = data.get("strings", {})
                for key, entry in strings.items():
                    if key in merged_strings:
                        existing_locs = merged_strings[key].setdefault("localizations", {})
                        new_locs = entry.get("localizations", {})
                        for lang, loc in new_locs.items():
                            existing_locs[lang] = loc
                    else:
                        merged_strings[key] = entry
        except Exception as e:
            print(f"⚠️  Error reading {file_path}: {e}", file=sys.stderr)

    merged_catalog = {
        "sourceLanguage": source_language,
        "strings": {k: merged_strings[k] for k in sorted(merged_strings.keys())},
        "version": "1.0"
    }

    # 3. Write merged catalogs (Apple .xcstrings format)
    for dest in dest_paths:
        os.makedirs(os.path.dirname(dest), exist_ok=True)
        with open(dest, "w", encoding="utf-8") as fp:
            json.dump(merged_catalog, fp, indent=2, ensure_ascii=False)
            fp.write("\n")
        print(f"✅ Written merged catalog ({len(merged_strings)} keys) -> {os.path.relpath(dest, repo_root)}")

    # 4. Generate Swift Code (Translations.generated.swift)
    code = generate_swift_code(merged_strings)
    generated_swift_path = os.path.join(
        repo_root,
        "Packages",
        "Platform",
        "Sources",
        "Platform",
        "Localization",
        "Translations.generated.swift"
    )

    os.makedirs(os.path.dirname(generated_swift_path), exist_ok=True)
    with open(generated_swift_path, "w", encoding="utf-8") as fp:
        fp.write(code)

    print(f"🚀 Generated Slang-style Swift accessors -> {os.path.relpath(generated_swift_path, repo_root)}")

    # 5. Export Backend-compatible Nested JSON (matching GET /api/v1/translations/{lang})
    export_backend_json(merged_strings, repo_root)

def unflatten_to_nested(flat_dict):
    """
    Reconstructs nested dictionary from dot-separated keys:
    e.g. {"settings.account.profile": "Edit Profile"} -> {"settings": {"account": {"profile": "Edit Profile"}}}
    """
    nested = {}
    for key, value in sorted(flat_dict.items()):
        parts = key.split(".")
        curr = nested
        for part in parts[:-1]:
            if part not in curr or not isinstance(curr[part], dict):
                curr[part] = {}
            curr = curr[part]
        curr[parts[-1]] = value
    return nested

def export_backend_json(merged_strings, repo_root):
    # Detect all available languages
    languages = set()
    for entry in merged_strings.values():
        languages.update(entry.get("localizations", {}).keys())

    if not languages:
        languages = {"en"}

    backend_dir = os.path.join(repo_root, "App", "Resources", "backend_translations")
    os.makedirs(backend_dir, exist_ok=True)

    locale_mapping = {
        "en": {"code": "en_US", "name": "English (US)", "is_default": True},
        "vi": {"code": "vi_VN", "name": "Tiếng Việt", "is_default": False},
    }

    for lang in sorted(languages):
        flat = {}
        for key, entry in merged_strings.items():
            loc = entry.get("localizations", {}).get(lang, {})
            val = loc.get("stringUnit", {}).get("value")
            if val is not None:
                flat[key] = val

        nested = unflatten_to_nested(flat)
        meta = locale_mapping.get(lang, {"code": lang, "name": lang, "is_default": False})

        be_payload = {
            "language_code": meta["code"],
            "language_name": meta["name"],
            "version": "1.0.0",
            "is_default": meta["is_default"],
            "is_active": True,
            "translations": nested
        }

        # Write {lang}.json (e.g., en.json, vi.json)
        out_file = os.path.join(backend_dir, f"{lang}.json")
        with open(out_file, "w", encoding="utf-8") as fp:
            json.dump(be_payload, fp, indent=2, ensure_ascii=False)
            fp.write("\n")

        # Also write {locale}.json (e.g., en_US.json, vi_VN.json) for direct BE API matching
        full_code = meta["code"]
        if full_code != lang:
            out_full = os.path.join(backend_dir, f"{full_code}.json")
            with open(out_full, "w", encoding="utf-8") as fp:
                json.dump(be_payload, fp, indent=2, ensure_ascii=False)
                fp.write("\n")

        print(f"🌐 Exported Backend JSON ({lang} & {full_code}, {len(flat)} keys) -> {os.path.relpath(out_file, repo_root)}")

def make_node():
    return {"children": {}, "leaves": {}}

def pascal_case(s: str) -> str:
    if not s:
        return ""
    return s[:1].upper() + s[1:]

def sanitize_identifier(s: str) -> str:
    keywords = {"default", "init", "subscript", "case", "class", "struct", "enum", "func", "var", "let"}
    if s in keywords:
        return f"`{s}`"
    return s

def generate_swift_code(strings_dict: dict) -> str:
    root = make_node()

    for key, entry in strings_dict.items():
        parts = key.split(".")
        en_val = entry.get("localizations", {}).get("en", {}).get("stringUnit", {}).get("value", key)
        curr = root
        for p in parts[:-1]:
            if p not in curr["children"]:
                curr["children"][p] = make_node()
            curr = curr["children"][p]
        leaf = parts[-1]
        curr["leaves"][leaf] = (key, en_val)

    lines = [
        "// Generated by scripts/merge_localizations.py. DO NOT EDIT DIRECTLY.",
        "// Re-run `./scripts/merge_localizations.py` to regenerate after modifying .xcstrings files.",
        "",
        "import Core",
        "import Foundation",
        "",
        "// MARK: - Root Translations Extension",
        "",
        "public extension Translations {",
    ]

    for i, root_name in enumerate(sorted(root["children"].keys())):
        if i > 0:
            lines.append("")
        type_name = pascal_case(root_name) + "Translations"
        lines.append(f"    var {sanitize_identifier(root_name)}: {type_name} {{")
        lines.append(f"        {type_name}(manager: manager)")
        lines.append("    }")

    lines.append("}")
    lines.append("")

    lines.append("// MARK: - Generated Feature & Component Translation Namespaces")
    lines.append("")

    def write_structs(node, path):
        sub_lines = []
        type_name = "".join(pascal_case(p) for p in path) + "Translations"

        sub_lines.append("@MainActor")
        sub_lines.append(f"public struct {type_name} {{")
        sub_lines.append("    private let manager: any LocalizationService")
        sub_lines.append("")
        sub_lines.append("    public init(manager: any LocalizationService) {")
        sub_lines.append("        self.manager = manager")
        sub_lines.append("    }")

        # Children
        for child_name in sorted(node["children"].keys()):
            child_type = "".join(pascal_case(p) for p in path + [child_name]) + "Translations"
            sub_lines.append("")
            sub_lines.append(f"    public var {sanitize_identifier(child_name)}: {child_type} {{")
            sub_lines.append(f"        {child_type}(manager: manager)")
            sub_lines.append("    }")

        # Leaves
        for leaf_name, (full_key, en_val) in sorted(node["leaves"].items()):
            safe_val = en_val.replace("\\", "\\\\").replace("\"", "\\\"").replace("\n", "\\n")
            sub_lines.append("")
            call_str = f'manager.translate("{full_key}", default: "{safe_val}")'
            if len(f"        {call_str}") > 100:
                sub_lines.append(f"    public var {sanitize_identifier(leaf_name)}: String {{")
                sub_lines.append("        manager.translate(")
                sub_lines.append(f'            "{full_key}",')
                sub_lines.append(f'            default: "{safe_val}"')
                sub_lines.append("        )")
                sub_lines.append("    }")
            else:
                sub_lines.append(f"    public var {sanitize_identifier(leaf_name)}: String {{")
                sub_lines.append(f"        {call_str}")
                sub_lines.append("    }")

        sub_lines.append("}")
        sub_lines.append("")

        for child_name in sorted(node["children"].keys()):
            sub_lines.extend(write_structs(node["children"][child_name], path + [child_name]))

        return sub_lines

    for root_name in sorted(root["children"].keys()):
        lines.extend(write_structs(root["children"][root_name], [root_name]))

    return "\n".join(lines).strip() + "\n"

if __name__ == "__main__":
    main()
