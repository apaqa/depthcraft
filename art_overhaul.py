#!/usr/bin/env python3
"""
DepthCraft 美術精確替換腳本
用法：python art_overhaul.py [--dry-run] [--scan-only]
  --dry-run    顯示要做的修改但不實際寫入
  --scan-only  只掃描目前的貼圖使用狀況
"""

import os
import re
import sys
import glob

PROJECT_ROOT = os.path.dirname(os.path.abspath(__file__))

# ==========================================
# 建築貼圖對應表
# key = 建築 ID 關鍵字（用於在 building_data.gd 裡匹配）
# texture = 新的貼圖路徑
# scale = Vector2 值（給 .tscn 用）
# note = 說明
# ==========================================
BUILDING_MAP = {
    "home_core": {
        "texture": "res://assets/assets2/Castle.png",
        "scale": (0.12, 0.12),
        "note": "家園核心 - 城堡",
    },
    "workbench": {
        "texture": "res://assets/assets2/House1.png",
        "scale": (0.18, 0.18),
        "note": "工作台 - 藍色小民房",
    },
    "cooking": {
        "texture": "res://assets/assets2/Monastery.png",
        "scale": (0.18, 0.18),
        "note": "烹飪台 - 修道院",
    },
    "tavern": {
        "texture": "res://assets/assets2/House2.png",
        "scale": (0.18, 0.18),
        "note": "酒館 - 紅色民房",
    },
    "talent": {
        "texture": "res://assets/column.png",
        "scale": (2.0, 2.0),
        "note": "天賦祭壇 - 石柱",
    },
    "storage": {
        "texture": "res://assets/chest_closed.png",
        "scale": (2.0, 2.0),
        "note": "倉庫 - 關閉寶箱",
    },
    "defense_tower": {
        "texture": "res://assets/assets2/Tower.png",
        "scale": (0.12, 0.12),
        "note": "防禦塔",
    },
    "bounty": {
        "texture": "res://assets/assets2/tile_0326.png",
        "scale": (2.5, 2.5),
        "note": "賞金板 - 木製講台",
    },
    "repair": {
        "texture": "res://assets/assets2/House1_v2.png",
        "scale": (0.18, 0.18),
        "note": "修理台 - 藍色民房變體（如果存在）",
    },
}

# 資源節點貼圖對應表
RESOURCE_MAP = {
    "tree": {
        "texture": "res://assets/assets2/tile_0258.png",
        "scale": (2.5, 2.5),
        "note": "樹木 - 單格松樹",
    },
    "fiber": {
        "texture": "res://assets/assets2/tile_0287.png",
        "scale": (1.0, 1.0),
        "note": "纖維 - 圓形灌木叢",
    },
    "wood": {
        "texture": "res://assets/wood_01a.png",
        "scale": (1.5, 1.5),
        "note": "木頭 - 帶皮原木",
    },
}


def find_files(patterns, root=PROJECT_ROOT):
    """找到所有匹配的檔案"""
    results = []
    for pattern in patterns:
        for f in glob.glob(os.path.join(root, pattern), recursive=True):
            if ".godot" not in f and "node_modules" not in f:
                results.append(f)
    return sorted(set(results))


def scan_textures():
    """掃描專案中所有 .png 引用"""
    print("\n" + "=" * 60)
    print("掃描模式：列出所有 .gd 和 .tscn 裡的貼圖引用")
    print("=" * 60)

    gd_files = find_files(["**/*.gd"])
    tscn_files = find_files(["**/*.tscn"])

    # 收集所有 texture 引用
    texture_refs = {}  # {filepath: [(line_num, line_content)]}

    for f in gd_files + tscn_files:
        try:
            with open(f, "r", encoding="utf-8") as fh:
                lines = fh.readlines()
            for i, line in enumerate(lines, 1):
                if ".png" in line.lower() and ("texture" in line.lower() or "preload" in line.lower() or "load" in line.lower()):
                    rel = os.path.relpath(f, PROJECT_ROOT)
                    if rel not in texture_refs:
                        texture_refs[rel] = []
                    texture_refs[rel].append((i, line.rstrip()))
        except (UnicodeDecodeError, PermissionError):
            pass

    for filepath, refs in sorted(texture_refs.items()):
        print(f"\n📄 {filepath}")
        for line_num, content in refs:
            print(f"  L{line_num}: {content}")

    print(f"\n共掃描 {len(gd_files)} 個 .gd + {len(tscn_files)} 個 .tscn")
    print(f"共找到 {sum(len(v) for v in texture_refs.values())} 處貼圖引用")
    return texture_refs


def replace_in_file(filepath, replacements, dry_run=False):
    """
    在檔案中執行多個字串替換
    replacements: [(old_str, new_str, description)]
    返回實際替換的數量
    """
    try:
        with open(filepath, "r", encoding="utf-8") as f:
            content = f.read()
    except (UnicodeDecodeError, PermissionError) as e:
        print(f"  ❌ 無法讀取 {filepath}: {e}")
        return 0

    count = 0
    original = content
    for old, new, desc in replacements:
        if old in content:
            content = content.replace(old, new)
            count += 1
            print(f"  ✅ {desc}")
            print(f"     舊: {old.strip()}")
            print(f"     新: {new.strip()}")
        else:
            # 嘗試用 regex 做更寬鬆的匹配
            pass

    if count > 0 and not dry_run:
        with open(filepath, "w", encoding="utf-8") as f:
            f.write(content)
        print(f"  💾 已寫入 {os.path.relpath(filepath, PROJECT_ROOT)}")
    elif count > 0:
        print(f"  🔍 (dry-run) 會寫入 {os.path.relpath(filepath, PROJECT_ROOT)}")

    return count


def replace_texture_in_gd(filepath, keyword, new_texture, dry_run=False):
    """
    在 .gd 檔案中，找到包含 keyword 的建築定義區塊，
    替換其中的 texture/preview_texture 路徑
    """
    try:
        with open(filepath, "r", encoding="utf-8") as f:
            content = f.read()
    except (UnicodeDecodeError, PermissionError):
        return 0

    count = 0

    # 模式 1: preload("res://...") 格式
    # 找包含 keyword 的行附近的 texture 定義
    lines = content.split("\n")
    new_lines = []
    in_block = False
    block_indent = 0

    for i, line in enumerate(lines):
        # 檢查是否進入了包含 keyword 的定義區塊
        if keyword.lower() in line.lower() and ("=" in line or ":" in line):
            in_block = True
            block_indent = len(line) - len(line.lstrip())

        # 如果在區塊內，找到 texture 相關的行
        if in_block:
            # 匹配 "preview_texture": preload("...") 或 texture = preload("...")
            texture_pattern = r'(preload\()"(res://[^"]*\.png)"(\))'
            match = re.search(texture_pattern, line)
            if match and ("texture" in line.lower() or "preview" in line.lower() or "icon" in line.lower()):
                old_path = match.group(2)
                new_line = line.replace(old_path, new_texture)
                new_lines.append(new_line)
                count += 1
                print(f"  ✅ [{keyword}] L{i+1}: {old_path} → {new_texture}")
                continue

            # 也匹配 "texture_path": "res://..." 字串格式
            str_pattern = r'"(res://[^"]*\.png)"'
            match = re.search(str_pattern, line)
            if match and ("texture" in line.lower() or "preview" in line.lower()):
                old_path = match.group(1)
                new_line = line.replace(old_path, new_texture)
                new_lines.append(new_line)
                count += 1
                print(f"  ✅ [{keyword}] L{i+1}: {old_path} → {new_texture}")
                continue

            # 如果遇到下一個同級定義（相同縮排），離開區塊
            if i > 0 and line.strip() and not line.strip().startswith("#"):
                current_indent = len(line) - len(line.lstrip())
                if current_indent <= block_indent and "}" not in line and "]" not in line:
                    if keyword.lower() not in line.lower():
                        in_block = False

        new_lines.append(line)

    if count > 0:
        new_content = "\n".join(new_lines)
        if not dry_run:
            with open(filepath, "w", encoding="utf-8") as f:
                f.write(new_content)

    return count


def replace_scale_in_tscn(filepath, texture_name, scale_x, scale_y, dry_run=False):
    """
    在 .tscn 檔案中，找到引用特定貼圖的 Sprite2D 節點，
    設定或修改其 scale
    """
    try:
        with open(filepath, "r", encoding="utf-8") as f:
            content = f.read()
    except (UnicodeDecodeError, PermissionError):
        return 0

    if texture_name not in content:
        return 0

    lines = content.split("\n")
    new_lines = []
    found_sprite = False
    found_texture = False
    scale_set = False
    count = 0

    for i, line in enumerate(lines):
        # 找到 [node] 定義
        if line.startswith("[node") and "Sprite2D" in line:
            found_sprite = True
            found_texture = False
            scale_set = False

        # 在 Sprite2D 節點裡找到貼圖引用
        if found_sprite and texture_name in line:
            found_texture = True

        # 如果已找到貼圖，處理 scale
        if found_sprite and found_texture:
            # 如果有現有的 scale 行，替換它
            if line.startswith("scale = ") or line.startswith("transform = "):
                if line.startswith("scale = "):
                    new_lines.append(f"scale = Vector2({scale_x}, {scale_y})")
                    scale_set = True
                    count += 1
                    print(f"  ✅ [{os.path.basename(filepath)}] 修改 scale: Vector2({scale_x}, {scale_y})")
                    continue

            # 如果遇到下一個 [node]，在前面插入 scale
            if line.startswith("[node") and not scale_set:
                new_lines.append(f"scale = Vector2({scale_x}, {scale_y})")
                scale_set = True
                count += 1
                print(f"  ✅ [{os.path.basename(filepath)}] 新增 scale: Vector2({scale_x}, {scale_y})")
                found_sprite = False

        # 如果遇到空行或新節點，且還沒設 scale
        if found_sprite and found_texture and not scale_set:
            if line.strip() == "" or (line.startswith("[") and line != lines[0]):
                new_lines.append(f"scale = Vector2({scale_x}, {scale_y})")
                scale_set = True
                count += 1
                found_sprite = False

        new_lines.append(line)

    if count > 0 and not dry_run:
        with open(filepath, "w", encoding="utf-8") as f:
            f.write("\n".join(new_lines))
        print(f"  💾 已寫入 {os.path.relpath(filepath, PROJECT_ROOT)}")

    return count


def add_scale_to_dynamic_generation(filepath, resource_type, texture_path, scale_x, scale_y, dry_run=False):
    """
    在世界生成腳本中，找到生成特定資源的邏輯，
    確保動態生成的節點也套用 scale
    """
    try:
        with open(filepath, "r", encoding="utf-8") as f:
            content = f.read()
    except (UnicodeDecodeError, PermissionError):
        return 0

    # 找到 resource_type 相關的生成函數
    if resource_type.lower() not in content.lower():
        return 0

    print(f"\n  ⚠️  {os.path.relpath(filepath, PROJECT_ROOT)} 包含 '{resource_type}' 相關邏輯")
    print(f"     需要手動確認動態生成的 {resource_type} 是否套用了：")
    print(f"     texture = preload(\"{texture_path}\")")
    print(f"     scale = Vector2({scale_x}, {scale_y})")

    return 0  # 不自動修改，只報告


def main():
    dry_run = "--dry-run" in sys.argv
    scan_only = "--scan-only" in sys.argv

    if dry_run:
        print("🔍 DRY RUN 模式 — 只顯示會做的修改，不實際寫入\n")

    # 第一步：掃描
    texture_refs = scan_textures()

    if scan_only:
        print("\n掃描完成。")
        return

    print("\n" + "=" * 60)
    print("開始美術替換")
    print("=" * 60)

    total_changes = 0

    # 第二步：找到 building_data.gd
    building_data_files = find_files(["**/building_data.gd", "**/building_data*.gd"])
    if building_data_files:
        for bdf in building_data_files:
            print(f"\n📄 處理 building_data: {os.path.relpath(bdf, PROJECT_ROOT)}")
            for keyword, config in BUILDING_MAP.items():
                count = replace_texture_in_gd(
                    bdf, keyword, config["texture"], dry_run
                )
                total_changes += count
    else:
        print("\n⚠️  找不到 building_data.gd，搜尋其他可能的建築定義檔...")
        # 搜尋所有 .gd 找包含建築定義的檔案
        for gd in find_files(["**/*.gd"]):
            try:
                with open(gd, "r", encoding="utf-8") as f:
                    content = f.read()
                if "home_core" in content or "workbench" in content or "tavern" in content:
                    print(f"  找到可能的建築定義：{os.path.relpath(gd, PROJECT_ROOT)}")
            except (UnicodeDecodeError, PermissionError):
                pass

    # 第三步：處理 .tscn 檔案的 scale
    print("\n" + "-" * 40)
    print("處理 .tscn 場景檔 scale")
    print("-" * 40)

    tscn_files = find_files(["**/*.tscn"])
    for tscn in tscn_files:
        # 建築
        for keyword, config in BUILDING_MAP.items():
            tex_name = os.path.basename(config["texture"])
            sx, sy = config["scale"]
            count = replace_scale_in_tscn(tscn, tex_name, sx, sy, dry_run)
            total_changes += count

        # 資源節點
        for keyword, config in RESOURCE_MAP.items():
            tex_name = os.path.basename(config["texture"])
            sx, sy = config["scale"]
            count = replace_scale_in_tscn(tscn, tex_name, sx, sy, dry_run)
            total_changes += count

    # 第四步：檢查動態生成邏輯
    print("\n" + "-" * 40)
    print("檢查動態生成邏輯（需要手動確認）")
    print("-" * 40)

    gen_files = find_files([
        "**/world_generator.gd",
        "**/test_overworld.gd",
        "**/overworld*.gd",
        "**/chunk*.gd",
    ])
    for gf in gen_files:
        for keyword, config in RESOURCE_MAP.items():
            add_scale_to_dynamic_generation(
                gf, keyword, config["texture"],
                config["scale"][0], config["scale"][1], dry_run
            )

    # 第五步：總結
    print("\n" + "=" * 60)
    print(f"完成！共修改 {total_changes} 處")
    if dry_run:
        print("（dry-run 模式，實際未寫入任何檔案）")
    print("=" * 60)

    # 輸出修改報告
    report_path = os.path.join(PROJECT_ROOT, "art_overhaul_report.txt")
    with open(report_path, "w", encoding="utf-8") as f:
        f.write("# 美術替換報告\n")
        f.write(f"# 生成時間：{__import__('datetime').datetime.now()}\n\n")
        f.write("## 建築對應表\n")
        for k, v in BUILDING_MAP.items():
            f.write(f"{k}: {v['texture']} scale=({v['scale'][0]}, {v['scale'][1]}) # {v['note']}\n")
        f.write("\n## 資源節點對應表\n")
        for k, v in RESOURCE_MAP.items():
            f.write(f"{k}: {v['texture']} scale=({v['scale'][0]}, {v['scale'][1]}) # {v['note']}\n")
    print(f"\n報告已輸出到 {os.path.relpath(report_path, PROJECT_ROOT)}")


if __name__ == "__main__":
    main()
