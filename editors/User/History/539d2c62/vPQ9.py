#!/usr/bin/env python3
"""Plot benchmark results from bench_results.json."""
import json
import sys
import os

try:
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt
    import numpy as np
    HAS_MPL = True
except ImportError:
    HAS_MPL = False
    print("matplotlib not installed. Install with: pip install matplotlib numpy")
    print("Falling back to ASCII table output.")

RESULTS_DIR = os.path.join(os.getcwd(), "results")


def load_results(path=None):
    if path is None:
        path = os.path.join(RESULTS_DIR, "bench_results.json")
    if not os.path.exists(path):
        print(f"No results found at {path}. Run the bench binary first.")
        sys.exit(1)
    with open(path) as f:
        data = json.load(f)
    results = data.get("results", [])
    nonskipped = [r for r in results if not r.get("skipped")]
    return nonskipped


def human_ns(ns):
    if ns < 1:
        return f"{ns:.3f} ns"
    elif ns < 1000:
        return f"{ns:.1f} ns"
    elif ns < 1_000_000:
        return f"{ns/1000:.1f} µs"
    else:
        return f"{ns/1_000_000:.2f} ms"


def table_output(results):
    categories = {}
    for r in results:
        cat = r.get("category", "Other")
        categories.setdefault(cat, []).append(r)

    for cat in sorted(categories):
        items = categories[cat]
        print(f"\n{'=' * 60}")
        print(f"  {cat}")
        print(f"{'=' * 60}")
        print(f"  {'Benchmark':<40s} {'ns/op':>12s} {'Total':>12s}")
        print(f"  {'-' * 40} {'-' * 12} {'-' * 12}")
        for r in items:
            name = r.get("name", "?")
            ns = r.get("ns_per_op", 0)
            total_ns = r.get("total_ns", 0)
            print(f"  {name:<40s} {human_ns(ns):>12s} {human_ns(total_ns):>12s}")


def plot_vm_results(results):
    vm = [r for r in results if r.get("category") == "VM"]
    if not vm:
        return
    names = [r.get("name", "").replace("vm_", "") for r in vm]
    ns_per_op = [r.get("ns_per_op", 0) for r in vm]

    fig, ax = plt.subplots(figsize=(10, 5))
    bars = ax.bar(range(len(names)), ns_per_op, color="steelblue")
    ax.set_xticks(range(len(names)))
    ax.set_xticklabels(names, rotation=25, ha="right", fontsize=9)
    ax.set_ylabel("ns per operation")
    ax.set_title("VM Throughput Microbenchmarks")
    for bar, val in zip(bars, ns_per_op):
        ax.text(bar.get_x() + bar.get_width() / 2, bar.get_height(),
                f"{val:.1f}", ha="center", va="bottom", fontsize=8)
    fig.tight_layout()
    fig.savefig(os.path.join(RESULTS_DIR, "vm_benchmarks.png"), dpi=150)
    print(f"  Saved vm_benchmarks.png")


def plot_engine_results(results):
    eng = [r for r in results if r.get("category") == "Engine"]
    if not eng:
        return
    fig, ax = plt.subplots(figsize=(8, 4))
    names = [r.get("name", "") for r in eng]
    vals = [r.get("ns_per_op", 0) for r in eng]
    bars = ax.bar(range(len(names)), vals, color="coral")
    ax.set_xticks(range(len(names)))
    ax.set_xticklabels(names, rotation=20, ha="right", fontsize=8)
    ax.set_ylabel("ns per operation")
    ax.set_title("Engine Benchmarks")
    for bar, val in zip(bars, vals):
        ax.text(bar.get_x() + bar.get_width() / 2, bar.get_height(),
                f"{val:.1f}", ha="center", va="bottom", fontsize=7)
    fig.tight_layout()
    fig.savefig(os.path.join(RESULTS_DIR, "engine_benchmarks.png"), dpi=150)
    print(f"  Saved engine_benchmarks.png")


def plot_incremental_results(results):
    incr = [r for r in results if r.get("category") == "Incremental"]
    if not incr:
        return
    fig, ax = plt.subplots(figsize=(9, 5))
    names = [r.get("name", "") for r in incr]
    vals = [r.get("ns_per_op", 0) for r in incr]
    bars = ax.bar(range(len(names)), vals, color=["#2ecc71", "#95a5a6", "#3498db", "#9b59b6", "#e67e22"])
    ax.set_xticks(range(len(names)))
    ax.set_xticklabels(names, rotation=20, ha="right", fontsize=8)
    ax.set_ylabel("ns per runEngine() call")
    ax.set_title("Incremental Evaluation Benchmarks")
    for bar, val in zip(bars, vals):
        ax.text(bar.get_x() + bar.get_width() / 2, bar.get_height(),
                f"{val:.1f}", ha="center", va="bottom", fontsize=7)
    fig.tight_layout()
    fig.savefig(os.path.join(RESULTS_DIR, "incremental_benchmarks.png"), dpi=150)
    print(f"  Saved incremental_benchmarks.png")


def plot_compare_results(results):
    cmp_r = [r for r in results if r.get("category") == "Compare"]
    if not cmp_r:
        return
    fig, ax = plt.subplots(figsize=(8, 5))
    names = [r.get("name", "") for r in cmp_r]
    vals = [r.get("ns_per_op", 0) for r in cmp_r]
    colors = ["#e74c3c" if "tree_walk" in r.get("name", "") else "#27ae60"
              for r in cmp_r]
    bars = ax.bar(range(len(names)), vals, color=colors)
    ax.set_xticks(range(len(names)))
    ax.set_xticklabels([n.replace("cmp_", "") for n in names], rotation=20, ha="right", fontsize=8)
    ax.set_ylabel("ns per evaluation")
    ax.set_title("Bytecode VM vs Tree-Walk Comparison")
    from matplotlib.patches import Patch
    legend_elements = [Patch(facecolor="#e74c3c", label="Tree-walk"),
                       Patch(facecolor="#27ae60", label="Bytecode VM")]
    ax.legend(handles=legend_elements)
    for bar, val in zip(bars, vals):
        ax.text(bar.get_x() + bar.get_width() / 2, bar.get_height(),
                f"{val:.1f}", ha="center", va="bottom", fontsize=7)
    fig.tight_layout()
    fig.savefig(os.path.join(RESULTS_DIR, "compare_benchmarks.png"), dpi=150)
    print(f"  Saved compare_benchmarks.png")


def main():
    results = load_results()

    print("Vela Benchmark Results")
    print(f"  {len(results)} benchmarks recorded\n")

    table_output(results)

    if HAS_MPL:
        os.makedirs(RESULTS_DIR, exist_ok=True)
        print(f"\nGenerating plots in {RESULTS_DIR}/ ...")
        plot_vm_results(results)
        plot_engine_results(results)
        plot_incremental_results(results)
        plot_compare_results(results)
        print("Done.")
    else:
        print("\nInstall matplotlib for PNG charts: pip install matplotlib numpy")


if __name__ == "__main__":
    main()
