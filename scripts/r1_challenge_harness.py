"""
Milestone R1 Empirical Challenge Verification Harness (Final)
Author: Challenger 1 (critic, specialist)
Tests:
1. Markdown table column consistency in REQUIREMENTS_TRACEABILITY.md and PROJECT.md
2. Point tally calculation (Base = 10.0, Bonus = 3.5, Total = 13.5)
3. Total requirement count (all 48 inventory items accounted for and aligned)
4. Cross-check against RestaurantPosDb.sql (10 tables, 6 indexes, 10 seed rows per table)
5. Heading mathematical consistency within REQUIREMENTS_TRACEABILITY.md
"""

import os
import re
import sys
import json

# Ensure UTF-8 output on Windows
if sys.stdout.encoding != 'utf-8':
    sys.stdout.reconfigure(encoding='utf-8')

def parse_markdown_tables(file_path):
    with open(file_path, "r", encoding="utf-8") as f:
        lines = f.readlines()

    tables = []
    current_table = []
    in_code_block = False

    for line_num, line in enumerate(lines, 1):
        stripped = line.strip()
        if stripped.startswith("```"):
            in_code_block = not in_code_block
            continue

        if in_code_block:
            continue

        if stripped.startswith("|") and stripped.endswith("|"):
            current_table.append((line_num, stripped))
        else:
            if current_table:
                if len(current_table) >= 2:
                    tables.append(current_table)
                current_table = []

    if current_table and len(current_table) >= 2:
        tables.append(current_table)

    return tables


def check_table_consistency(file_path):
    tables = parse_markdown_tables(file_path)
    all_consistent = True
    table_reports = []

    for t_idx, tbl in enumerate(tables, 1):
        start_line = tbl[0][0]
        header_line = tbl[0][1]
        delim_line = tbl[1][1]
        header_cols = [c.strip() for c in header_line.split("|")[1:-1]]
        expected_col_count = len(header_cols)
        
        delim_cols = [c.strip() for c in delim_line.split("|")[1:-1]]
        table_ok = True
        if len(delim_cols) != expected_col_count:
            table_ok = False
            all_consistent = False

        for r_idx, (line_no, row_str) in enumerate(tbl[2:], 3):
            cols = [c.strip() for c in row_str.split("|")[1:-1]]
            if len(cols) != expected_col_count:
                table_ok = False
                all_consistent = False

        table_reports.append({
            "table_index": t_idx,
            "start_line": start_line,
            "columns": expected_col_count,
            "rows": len(tbl) - 2,
            "pass": table_ok
        })

    return all_consistent, table_reports


def check_point_tally(rtm_path):
    with open(rtm_path, "r", encoding="utf-8") as f:
        content = f.read()

    sec3_match = re.search(r'## 3\. Academic Grading Rubric.*?(?=## 4\. F&B Domain Extension)', content, re.DOTALL)
    sec3_content = sec3_match.group(0) if sec3_match else content

    pattern = re.compile(r'\|\s*\*\*([A-Z]+-\d+)\*\*\s*\|\s*(\d+\.\d+)\s*\|(.*?)\|\s*(Bắt buộc|Điểm cộng)\s*\|\s*([\d\.\* ]+)\s*đ\s*\|', re.UNICODE)
    matches = pattern.findall(sec3_content)

    base_points = 0.0
    bonus_points = 0.0
    group_points = {}

    for code, item_num, name, c_type, pts_str in matches:
        try:
            pts_val = eval(pts_str.replace(' ', ''))
        except Exception:
            pts_val = float(pts_str.strip())

        grp = item_num.split('.')[0]
        if grp not in group_points:
            group_points[grp] = {"base": 0.0, "bonus": 0.0, "count": 0}
        
        group_points[grp]["count"] += 1
        if c_type == "Bắt buộc":
            base_points += pts_val
            group_points[grp]["base"] += pts_val
        else:
            bonus_points += pts_val
            group_points[grp]["bonus"] += pts_val

    total_points = base_points + bonus_points

    # Check headings
    headings = re.findall(r'###\s*3\.(\d+)\s*Nhóm\s*\d+:[^—\n]+—\s*(\d+)\s*Items\s*\(([\d\.]+)\s*Base\s*\+\s*([\d\.]+)\s*Bonus\s*=\s*([\d\.]+)\s*Max Points\)', sec3_content)
    heading_analysis = []
    heading_has_contradictions = False

    for grp_id, claimed_items, claimed_base, claimed_bonus, claimed_max in headings:
        calc = group_points.get(grp_id, {"base": 0.0, "bonus": 0.0, "count": 0})
        item_diff = int(claimed_items) - calc["count"]
        base_diff = float(claimed_base) - calc["base"]
        bonus_diff = float(claimed_bonus) - calc["bonus"]
        contradiction = (item_diff != 0 or abs(base_diff) > 0.001 or abs(bonus_diff) > 0.001)
        if contradiction:
            heading_has_contradictions = True

        heading_analysis.append({
            "group": int(grp_id),
            "claimed": {"items": int(claimed_items), "base": float(claimed_base), "bonus": float(claimed_bonus), "max": float(claimed_max)},
            "calculated": {"items": calc["count"], "base": round(calc["base"], 2), "bonus": round(calc["bonus"], 2), "total": round(calc["base"] + calc["bonus"], 2)},
            "contradiction": contradiction
        })

    return {
        "item_count": len(matches),
        "base_points": round(base_points, 2),
        "bonus_points": round(bonus_points, 2),
        "total_points": round(total_points, 2),
        "base_exact_10": abs(base_points - 10.0) < 0.001,
        "bonus_exact_3_5": abs(bonus_points - 3.5) < 0.001,
        "total_exact_13_5": abs(total_points - 13.5) < 0.001,
        "raw_pool_exact_16_75": abs(total_points - 16.75) < 0.001,
        "capped_grade_exact_13_5": abs(min(base_points, 10.0) + min(bonus_points, 3.5) - 13.5) < 0.001,
        "group_breakdown": group_points,
        "heading_analysis": heading_analysis,
        "heading_has_contradictions": heading_has_contradictions,
        "absence_of_contradictory_headings": not heading_has_contradictions
    }


def check_feature_inventory(rtm_path, project_path):
    with open(project_path, "r", encoding="utf-8") as f:
        p_text = f.read()

    inv_text = p_text.split('## Feature Inventory')[1].split('## Milestones')[0]
    p_rows = [l.strip() for l in inv_text.splitlines() if l.strip().startswith('|') and not l.strip().startswith('|---') and not '| Feature |' in l]

    with open(rtm_path, "r", encoding="utf-8") as f:
        r_text = f.read()

    sec6_text = r_text.split('## 6. Comprehensive 48-Feature Traceability Master Table')[1].split('## 7. Member Readiness Scorecards')[0]
    r_rows = [l.strip() for l in sec6_text.splitlines() if l.strip().startswith('|') and not l.strip().startswith('|:---:') and not '| Code |' in l]

    mismatches = []
    if len(p_rows) != 48:
        mismatches.append(f"PROJECT.md count is {len(p_rows)}, expected 48")
    if len(r_rows) != 48:
        mismatches.append(f"RTM Section 6 count is {len(r_rows)}, expected 48")

    aligned_count = 0
    for i in range(min(len(p_rows), len(r_rows))):
        p_cols = [c.strip() for c in p_rows[i].split('|')[1:-1]]
        r_cols = [c.strip() for c in r_rows[i].split('|')[1:-1]]
        
        p_id = int(p_cols[0])
        r_id = int(r_cols[0])
        p_ms = p_cols[3]
        r_ms = r_cols[3]
        r_status = r_cols[6].replace('*', '').strip()

        if p_id != i + 1 or r_id != i + 1 or p_ms != r_ms:
            mismatches.append(f"Row {i+1} misaligned")
        else:
            aligned_count += 1

    return {
        "project_count": len(p_rows),
        "rtm_count": len(r_rows),
        "aligned_count": aligned_count,
        "all_48_aligned": (len(p_rows) == 48 and len(r_rows) == 48 and len(mismatches) == 0),
        "mismatches": mismatches
    }


def check_sql_cross_reference(sql_path, rtm_path):
    with open(sql_path, "r", encoding="utf-8") as f:
        sql_content = f.read()

    tables = re.findall(r'CREATE\s+TABLE\s+(\w+)', sql_content, re.IGNORECASE)
    indexes = re.findall(r'CREATE\s+(?:NONCLUSTERED\s+)?INDEX\s+(\w+)\s+ON\s+(\w+)\s*\((.*?)\)', sql_content, re.IGNORECASE)
    inserts = re.findall(r'INSERT\s+INTO\s+(\w+)\s*\((.*?)\)\s*VALUES\s*(.*?);', sql_content, re.DOTALL | re.IGNORECASE)
    
    seeds_per_table = {}
    for tbl, cols, vals in inserts:
        val_lines = [v.strip() for v in vals.strip().split('\n') if v.strip().startswith('(')]
        seeds_per_table[tbl] = len(val_lines)

    with open(rtm_path, "r", encoding="utf-8") as f:
        rtm_content = f.read()

    has_10_tables = ("10 tables" in rtm_content or "10 bảng" in rtm_content)
    has_6_indexes = ("6 non-clustered indexes" in rtm_content or "6 chỉ mục" in rtm_content or "6 non-clustered index" in rtm_content)
    has_10_seeds = ("10 seeds" in rtm_content or "10 dòng" in rtm_content)

    sql_exact = (len(tables) == 10 and len(indexes) == 6 and len(seeds_per_table) == 10 and all(v == 10 for v in seeds_per_table.values()))

    return {
        "tables_count": len(tables),
        "indexes_count": len(indexes),
        "seeds_per_table": seeds_per_table,
        "total_seeds": sum(seeds_per_table.values()),
        "sql_exact_10_6_100": sql_exact,
        "rtm_mentions": {
            "has_10_tables": has_10_tables,
            "has_6_indexes": has_6_indexes,
            "has_10_seeds": has_10_seeds
        }
    }


def main():
    rtm_file = os.path.abspath("docs/acceptance/REQUIREMENTS_TRACEABILITY.md")
    proj_file = os.path.abspath("PROJECT.md")
    sql_file = os.path.abspath("RestaurantPosDb.sql")

    rtm_table_ok, rtm_tables = check_table_consistency(rtm_file)
    proj_table_ok, proj_tables = check_table_consistency(proj_file)
    point_results = check_point_tally(rtm_file)
    inv_results = check_feature_inventory(rtm_file, proj_file)
    sql_results = check_sql_cross_reference(sql_file, rtm_file)

    report = {
        "table_consistency": {
            "rtm_tables_count": len(rtm_tables),
            "rtm_consistent": rtm_table_ok,
            "proj_tables_count": len(proj_tables),
            "proj_consistent": proj_table_ok
        },
        "point_tally": point_results,
        "feature_inventory": inv_results,
        "sql_cross_reference": sql_results
    }

    print(json.dumps(report, indent=2, ensure_ascii=False))


if __name__ == "__main__":
    main()
