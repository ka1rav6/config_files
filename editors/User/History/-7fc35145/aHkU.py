#!/usr/bin/env python3
"""
update.py - Single command to update the TechTree website data.

Usage:
    python3 update.py                          # Regenerate all JSON from static/Courses.csv
    python3 update.py --csv path/to/Courses.csv  # Use a specific CSV file
    python3 update.py --validate-only          # Only validate the CSV

Generates:
    static/Courses.json     - DataTable source for course directory
    static/graph.json       - Basic graph for Cytoscape Desktop (reference)
    static/graph_data.json  - Full positioned graph data (loaded via AJAX by bundle.js)
"""

import argparse
import csv
import json
import os
import re
import sys

import numpy as np
import pandas as pd

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
DEFAULT_CSV = os.path.join(SCRIPT_DIR, "static", "Courses.csv")
NETWORKS_JSON = os.path.join(SCRIPT_DIR, "static", "networks.json")
OUTPUT_TABLE_JSON = os.path.join(SCRIPT_DIR, "static", "Courses.json")
OUTPUT_GRAPH_JSON = os.path.join(SCRIPT_DIR, "static", "graph.json")
OUTPUT_GRAPH_DATA_JSON = os.path.join(SCRIPT_DIR, "static", "graph_data.json")

# Matches the word "or" on its own, not "or" as a substring of a course code
# or any other token (fixes the old naive `.split("or")`).
OR_SPLIT_RE = re.compile(r"\bor\b", re.IGNORECASE)


def clean_prereq_text(text):
    if not text or text == "None" or isinstance(text, float):
        return "None"
    text = str(text)
    text = text.replace("\n", " ").replace("\r", " ")
    text = re.sub(r"\s+", " ", text)
    text = re.sub(r"\s*([,;])\s*", r"\1 ", text)
    text = re.sub(r"\s*([()])\s*", r" \1 ", text)
    text = re.sub(r"\s+(or|and)\s+", r" \1 ", text, flags=re.IGNORECASE)
    text = re.sub(r"([A-Za-z])([A-Z][a-z])", r"\1 \2", text)
    text = re.sub(r"([a-z])([A-Z])", r"\1 \2", text)
    text = re.sub(r"([A-Z])([A-Z][a-z])", r"\1 \2", text)
    text = re.sub(r"\s{2,}", " ", text)
    return text.strip()


def split_alternatives(part):
    """Split one comma-separated prerequisite group into its 'or' alternatives,
    on the whole word 'or' rather than the substring 'or'."""
    return [a.strip() for a in OR_SPLIT_RE.split(part)]


def safe_int(value, default=0) -> int:
    """int() that never raises: NaN/None/empty/non-numeric values fall back
    to `default` instead of crashing generation partway through."""
    try:
        if pd.isna(value):
            return default
    except (TypeError, ValueError):
        pass
    try:
        return int(value)
    except (TypeError, ValueError):
        return default


# ---------------------------------------------------------------------------
# CSV Validation
# ---------------------------------------------------------------------------

def validate_csv(csv_path):
    errors = []
    warnings = []
    try:
        data = pd.read_csv(csv_path)
    except Exception as e:
        return [f"Failed to read CSV: {e}"], []

    # Preferable_Prerequisites / Antirequisites are read unconditionally by
    # generate_table_json, so they must be required, not optional.
    required_cols = [
        "Serial Number", "Course Name", "Course Code", "Course Acronym",
        "Prerequisites", "Preferable_Prerequisites", "Antirequisites",
        "Semester", "Professor", "Credits", "Cluster", "OptionalDept",
    ]
    for col in required_cols:
        if col not in data.columns:
            errors.append(f"Missing required column: {col}")

    if errors:
        return errors, warnings

    course_codes_raw = []
    for code in data["Course Code"]:
        if pd.isna(code) or len(str(code).strip()) < 3:
            errors.append(f"Invalid Course Code: {code}")
            continue
        raw = str(code).replace(" ", "")
        course_codes_raw.append(raw)
        for cc in raw.split("/"):
            if len(cc) < 3:
                errors.append(f"Invalid Course Code component: {cc}")

    # Each course must have a unique code (previously silently deduped by a set).
    code_counts = {}
    for raw in course_codes_raw:
        code_counts[raw] = code_counts.get(raw, 0) + 1
    for code, count in code_counts.items():
        if count > 1:
            warnings.append(f"Duplicate Course Code: '{code}' appears {count} times")

    flat_codes = set()
    for raw in course_codes_raw:
        for cc in raw.split("/"):
            flat_codes.add(cc.strip())

    # Prerequisites/Antirequisites must reference a real, known course code
    # (previously computed and never actually checked against anything).
    for idx, (_, row) in enumerate(data.iterrows()):
        for col in ("Prerequisites", "Antirequisites"):
            raw = str(row.get(col, "None"))
            if raw == "nan" or raw.strip() == "":
                continue
            cleaned = clean_prereq_text(raw).replace("'", "").replace('"', "")
            if cleaned == "None":
                continue
            for part in cleaned.split(","):
                for alt in split_alternatives(part):
                    if not alt or alt == "None":
                        continue
                    if alt not in flat_codes:
                        warnings.append(
                            f"Row {idx + 2} ({row.get('Course Code', '?')}): "
                            f"{col} references unknown course code '{alt}'"
                        )

    return errors, warnings


# ---------------------------------------------------------------------------
# Table JSON Generation (Courses.json for DataTable)
# ---------------------------------------------------------------------------

def generate_table_json(csv_path):
    courses = []
    with open(csv_path) as csv_file:
        reader = csv.DictReader(csv_file)
        for row in reader:
            course_code = list(row["Course Code"].split("/"))[0].replace(" ", "")
            row["Link"] = "/viewDescription/filename?=" + course_code
            courses.append(row)

    for i in range(len(courses)):
        courses[i]["Course Name"] += " # " + courses[i]["Link"]
        courses[i]["Prerequisites"] = clean_prereq_text(courses[i]["Prerequisites"])
        courses[i]["Preferable_Prerequisites"] = clean_prereq_text(courses[i]["Preferable_Prerequisites"])
        courses[i]["Antirequisites"] = clean_prereq_text(courses[i]["Antirequisites"])

    with open(OUTPUT_TABLE_JSON, "w") as f:
        json.dump({"data": courses}, f, indent=4)
    print(f"  Generated {OUTPUT_TABLE_JSON} ({len(courses)} courses)")


# ---------------------------------------------------------------------------
# Basic Graph JSON Generation (graph.json for Cytoscape Desktop)
# ---------------------------------------------------------------------------

def generate_graph_json(csv_path):
    data = pd.read_csv(csv_path)
    nodes = []
    edges = []
    course_to_id = {}

    for i, (_, row) in enumerate(data.iterrows()):
        code = str(row["Course Code"]).replace(" ", "")
        dept = code[0:3] if len(code) >= 3 else code
        node_id = i + 1
        course_to_id[code] = str(node_id)
        nodes.append({"data": {"id": str(node_id), "label": code, "dept": dept}})

    edge_count = len(nodes) + 1
    for i, (_, row) in enumerate(data.iterrows()):
        prereq_str = str(row.get("Prerequisites", "None"))
        if prereq_str == "nan" or prereq_str.strip() == "":
            prereq_str = "None"
        prereq_str = clean_prereq_text(prereq_str).replace("'", "").replace('"', "")
        for part in prereq_str.split(","):
            for alt in split_alternatives(part):
                if alt and alt != "None" and alt in course_to_id:
                    edges.append({
                        "data": {
                            "id": str(edge_count),
                            "source": course_to_id[alt],
                            "target": str(i + 1),
                        }
                    })
                    edge_count += 1

    graph = {"elements": {"nodes": nodes, "edges": edges}}
    with open(OUTPUT_GRAPH_JSON, "w") as f:
        json.dump(graph, f, indent=0)
    print(f"  Generated {OUTPUT_GRAPH_JSON} ({len(nodes)} nodes, {len(edges)} edges)")


# ---------------------------------------------------------------------------
# Positioned Graph JSON Generation (graph_data.json for AJAX loading)
# ---------------------------------------------------------------------------

def load_existing_positions():
    if not os.path.exists(NETWORKS_JSON):
        return {}
    try:
        with open(NETWORKS_JSON) as f:
            data = json.load(f)
        positions = {}
        for node in data["graph.json"]["elements"]["nodes"]:
            orig_id = str(node["data"]["id_original"])
            positions[orig_id] = {
                "x": node["position"]["x"],
                "y": node["position"]["y"],
            }
        return positions
    except (json.JSONDecodeError, KeyError, TypeError) as e:
        print(f"  Warning: couldn't read positions from {NETWORKS_JSON} ({e}). "
              f"All nodes will be freshly laid out.")
        return {}


def force_directed_layout(nodes, edges, fixed_positions=None, iterations=300, k=None):
    """Spring-force layout. Nodes with a saved position in `fixed_positions`
    act as anchors: they still push/pull on everything else, but their own
    position never moves, so new nodes get placed sensibly relative to the
    existing graph instead of drifting or landing at the origin.

    Vectorized with NumPy broadcasting instead of nested Python `for` loops -
    the original pure-Python O(n^2)-per-iteration version took minutes at a
    few hundred nodes (it wasn't hung, just extremely slow interpreted-Python
    work); this does the same math as array operations instead.
    """
    n = len(nodes)
    if n == 0:
        return {}
    if k is None:
        k = np.sqrt(1000.0 / n)

    fixed_positions = fixed_positions or {}
    node_index = {node["id"]: i for i, node in enumerate(nodes)}

    pos = np.random.RandomState(42).randn(n, 2) * 100
    fixed_mask = np.zeros(n, dtype=bool)
    for node_id, idx in node_index.items():
        if node_id in fixed_positions:
            pos[idx] = [fixed_positions[node_id]["x"], fixed_positions[node_id]["y"]]
            fixed_mask[idx] = True

    edge_pairs = []
    for e in edges:
        si, ti = node_index.get(e["source"]), node_index.get(e["target"])
        if si is not None and ti is not None:
            edge_pairs.append((si, ti))
    edge_arr = np.array(edge_pairs, dtype=int) if edge_pairs else np.zeros((0, 2), dtype=int)

    temp = 100.0
    for iteration in range(iterations):
        # Repulsive force between every pair of nodes, all at once instead of
        # a double Python loop. delta[i, j] = pos[i] - pos[j] for every pair.
        delta = pos[:, None, :] - pos[None, :, :]          # (n, n, 2)
        dist = np.linalg.norm(delta, axis=2)               # (n, n)
        np.fill_diagonal(dist, np.inf)                      # no self-force / no div-by-zero
        dist_safe = np.maximum(dist, 0.01)
        repulsive_force = (k * k) / dist_safe               # (n, n)
        direction = delta / dist_safe[:, :, None]
        disp = (direction * repulsive_force[:, :, None]).sum(axis=1)  # (n, 2)

        # Attractive force along each prerequisite edge.
        if len(edge_arr):
            si, ti = edge_arr[:, 0], edge_arr[:, 1]
            e_delta = pos[si] - pos[ti]
            e_dist = np.maximum(np.linalg.norm(e_delta, axis=1), 0.01)
            attract_force = (e_dist * e_dist) / k
            e_disp = (e_delta / e_dist[:, None]) * attract_force[:, None]
            np.add.at(disp, si, -e_disp)
            np.add.at(disp, ti, e_disp)

        disp[fixed_mask] = 0.0  # anchors never move

        disp_norm = np.linalg.norm(disp, axis=1, keepdims=True)
        disp_norm = np.maximum(disp_norm, 0.01)
        pos += disp * (temp / disp_norm) * 0.01
        temp *= 0.95

    return {node["id"]: {"x": float(pos[i, 0]), "y": float(pos[i, 1])} for i, node in enumerate(nodes)}


def generate_graph_data_json(csv_path):
    data = pd.read_csv(csv_path)
    existing_positions = load_existing_positions()

    nodes_data = []
    course_to_id = {}

    for i, (_, row) in enumerate(data.iterrows()):
        code = str(row["Course Code"]).replace(" ", "")
        name = str(row["Course Name"])
        dept = code[0:3] if len(code) >= 3 else code
        node_id = i + 1
        course_to_id[code] = str(node_id)

        raw_prereq = str(row.get("Prerequisites", "None"))
        if raw_prereq == "nan" or raw_prereq.strip() == "":
            raw_prereq = "None"
        prereq_cleaned = clean_prereq_text(raw_prereq).replace("'", "").replace('"', "")

        raw_pref = str(row.get("Preferable_Prerequisites", "None"))
        if raw_pref == "nan":
            raw_pref = "None"
        pref_cleaned = clean_prereq_text(raw_pref).replace("'", "").replace('"', "")

        raw_antireq = str(row.get("Antirequisites", "None"))
        if raw_antireq == "nan":
            raw_antireq = "None"
        antireq_cleaned = clean_prereq_text(raw_antireq).replace("'", "").replace('"', "")

        credits_val = safe_int(row.get("Credits", 0))

        nodes_data.append({
            "data": {
                "id": str(node_id),
                "selected": False,
                "cytoscape_alias_list": [name],
                "canonicalName": name,
                "SUID": node_id,
                "NodeType": dept,
                "CourseCode": code,
                "Prof": str(row.get("Professor", "")),
                "Semester": str(row.get("Semester", "")),
                "credits": str(credits_val),
                "name": name,
                "shared_name": name,
                "Prerequisites": prereq_cleaned,
                "Preferable_Prerequisites": pref_cleaned,
                "Antirequisites": antireq_cleaned,
            },
            "position": {"x": 0.0, "y": 0.0},
            "selected": False,
        })

    node_ids = [nd["data"]["id"] for nd in nodes_data]
    matched_ids = [nid for nid in node_ids if nid in existing_positions]
    unmatched_ids = [nid for nid in node_ids if nid not in existing_positions]

    if matched_ids:
        print(f"  Using existing positions for {len(matched_ids)} known node(s)...")
    if unmatched_ids:
        print(f"  Computing force-directed layout for {len(unmatched_ids)} new node(s)...")

    layout_nodes = [{"id": nd["data"]["id"]} for nd in nodes_data]
    layout_edges = []
    for nd in nodes_data:
        prereqs = nd["data"]["Prerequisites"]
        if prereqs == "None" or not prereqs:
            continue
        target_id = nd["data"]["id"]
        for part in prereqs.split(","):
            for alt in split_alternatives(part):
                if alt and alt != "None" and alt in course_to_id:
                    layout_edges.append({
                        "source": course_to_id[alt],
                        "target": target_id,
                    })

    # Every node gets passed through, but matched ones are pinned via
    # fixed_positions and come back out unchanged; only unmatched_ids
    # actually move. This replaces the old all-or-nothing has_existing branch,
    # which left brand-new nodes stuck at (0, 0) whenever *any* node matched.
    positions = force_directed_layout(layout_nodes, layout_edges, fixed_positions=existing_positions)
    for nd in nodes_data:
        nd["position"] = positions[nd["data"]["id"]]

    edges_data = []
    edge_count = len(nodes_data) + 1
    for nd in nodes_data:
        prereqs = nd["data"]["Prerequisites"]
        if prereqs == "None" or not prereqs:
            continue
        target_id = nd["data"]["id"]
        alt_count = 0  # counts actual "or" groups only, not every comma-group
        for part in prereqs.split(","):
            alts = split_alternatives(part)

            if len(alts) == 1:
                interaction = "cc"
            elif alt_count == 0:
                interaction = "ORP1"
                alt_count += 1
            else:
                interaction = "ORP2"
                alt_count += 1

            for alt in alts:
                if not alt or alt == "None" or alt not in course_to_id:
                    continue
                source_id = course_to_id[alt]
                # "-" separator makes this collision-free, unlike the old
                # source_id + str(target_index) concatenation (e.g. "1"+"23"
                # and "12"+"3" both used to produce "123").
                edge_name = f"{source_id}-{target_id}"

                edges_data.append({
                    "data": {
                        "id": str(edge_count),
                        "source": source_id,
                        "target": target_id,
                        "selected": False,
                        "canonicalName": edge_name,
                        "SUID": edge_count,
                        "name": edge_name,
                        "interaction": interaction,
                        "shared_interaction": interaction,
                        "shared_name": edge_name,
                    },
                    "selected": False,
                })
                edge_count += 1

    graph_data = {"nodes": nodes_data, "edges": edges_data}
    with open(OUTPUT_GRAPH_DATA_JSON, "w") as f:
        json.dump(graph_data, f)
    print(f"  Generated {OUTPUT_GRAPH_DATA_JSON} ({len(nodes_data)} nodes, {len(edges_data)} edges)")


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(description="Update TechTree website data")
    parser.add_argument("--csv", default=DEFAULT_CSV, help="Path to Courses CSV file")
    parser.add_argument("--validate-only", action="store_true", help="Only validate the CSV")
    args = parser.parse_args()

    csv_path = os.path.abspath(args.csv)
    if not os.path.exists(csv_path):
        print(f"Error: CSV file not found: {csv_path}")
        sys.exit(1)

    print(f"Using CSV: {csv_path}")

    print("\n[1/4] Validating CSV...")
    errors, warnings = validate_csv(csv_path)
    if errors:
        print(f"  Found {len(errors)} error(s):")
        for e in errors:
            print(f"    - {e}")
        sys.exit(1)
    if warnings:
        print(f"  {len(warnings)} warning(s) (non-fatal):")
        for w in warnings[:5]:
            print(f"    - {w}")
    print("  CSV validation passed.")

    if args.validate_only:
        print("\nDone (validate-only mode).")
        return

    print("\n[2/4] Generating table JSON (Courses.json)...")
    generate_table_json(csv_path)

    print("\n[3/4] Generating basic graph JSON (graph.json)...")
    generate_graph_json(csv_path)

    print("\n[4/4] Generating positioned graph data (graph_data.json)...")
    generate_graph_data_json(csv_path)

    print("\nDone! All JSON files regenerated.")
    print("No changes to bundle.js needed - graph_data.json is loaded via AJAX.")


if __name__ == "__main__":
    main()