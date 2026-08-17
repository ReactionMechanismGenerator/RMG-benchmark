#!/usr/bin/env python3
"""
Calculate peak throughput and average memory consumption per version/benchmark.

Inputs:
  benchmark_summary.csv  — per-iteration species/reaction counts + exec time + memory
  results.csv            — per-run execution time, peak RSS, RAM pressure

Output:
  summary_table.csv      — one row per version/benchmark/nproc combination
  Console table
"""

import csv
import sys
from pathlib import Path
import numpy as np

def parse_exec_time(time_str):
    """Parse dd:hh:mm:ss or hh:mm:ss into total seconds."""
    parts = list(map(int, time_str.strip().split(":")))
    if len(parts) == 4:
        d, h, m, s = parts
        return d * 86400 + h * 3600 + m * 60 + s
    elif len(parts) == 3:
        h, m, s = parts
        return h * 3600 + m * 60 + s
    return 0

def load_benchmark_summary(path):
    """Load benchmark_summary.csv, compute per-iteration throughput."""
    rows = []
    with open(path, newline="") as f:
        for r in csv.DictReader(f):
            total_objects = (
                int(r["core_species"] or 0)
                + int(r["core_reactions"] or 0)
                + int(r["edge_species"] or 0)
                + int(r["edge_reactions"] or 0)
            )
            total_seconds = parse_exec_time(r["exec_time_dd_hh_mm_ss"])
            throughput = total_objects / total_seconds if total_seconds else 0
            rows.append(
                {
                    "version": r["version"],
                    "benchmark": r["benchmark"],
                    "nproc": int(r["nproc"]),
                    "run": int(r["run"]),
                    "iteration": int(r["iteration"]),
                    "total_objects": total_objects,
                    "total_seconds": total_seconds,
                    "throughput": throughput,
                    "memory_mb": float(r["memory_mb"]) if r["memory_mb"] else 0.0,
                }
            )
    return rows

def load_results(path):
    """Load results.csv (per-run metrics from test.sh)."""
    rows = []
    with open(path, newline="") as f:
        for r in csv.DictReader(f):
            rows.append(
                {
                    "version": r["version"],
                    "case": r["case"],
                    "processes": int(r["processes"]),
                    "run": int(r["run"]),
                    "peak_rss_mib": int(r["peak_rss_mib"]),
                    "peak_ram_pressure_mib": int(r["peak_ram_pressure_mib"]),
                }
            )
    return rows

def aggregate(summary_rows, results_rows):
    """
    Groups metrics over repetitions to calculate uncertainty (mean, median, std, IQR).
    """
    from collections import defaultdict
    
    # Store data by explicit run
    runs = defaultdict(lambda: {"throughputs": [], "memories": [], "total_objects": [], "peak_rss_mib": 0})

    for row in summary_rows:
        key = (row["version"], row["benchmark"], row["nproc"], row["run"])
        runs[key]["throughputs"].append(row["throughput"])
        runs[key]["memories"].append(row["memory_mb"])
        runs[key]["total_objects"].append(row["total_objects"])

    for row in results_rows:
        key = (row["version"], row["case"], row["processes"], row["run"])
        runs[key]["peak_rss_mib"] = row["peak_rss_mib"]
        runs[key]["peak_ram_pressure_mib"] = row["peak_ram_pressure_mib"]

    # Calculate statistics across runs for the same parameter set
    groups = defaultdict(lambda: {"peak_throughputs": [], "avg_memories": [], "peak_rss_mibs": [], "max_total_objects": []})
    for (version, benchmark, nproc, run), data in runs.items():
        group_key = (version, benchmark, nproc)
        groups[group_key]["peak_throughputs"].append(max(data["throughputs"]) if data["throughputs"] else 0)
        groups[group_key]["avg_memories"].append(sum(data["memories"])/len(data["memories"]) if data["memories"] else 0)
        groups[group_key]["peak_rss_mibs"].append(data["peak_rss_mib"])
        groups[group_key]["max_total_objects"].append(max(data["total_objects"]) if data["total_objects"] else 0)

    out = []
    for (version, benchmark, nproc), data in sorted(groups.items()):
        if nproc != 1:
            continue
        if not data["peak_throughputs"]:
            continue
            
        pts = data["peak_throughputs"]
        rss = data["peak_rss_mibs"]
        
        out.append({
            "version": version,
            "benchmark": benchmark,
            "max_total_objects": int(np.median(data["max_total_objects"])),
            # Peak Throughput Dispersion
            "throughput_mean": np.mean(pts),
            "throughput_median": np.median(pts),
            "throughput_std": np.std(pts),
            "throughput_iqr": np.percentile(pts, 75) - np.percentile(pts, 25),
            # RSS Memory Dispersion
            "rss_mean": np.mean(rss),
            "rss_median": np.median(rss),
            "rss_std": np.std(rss),
            "rss_iqr": np.percentile(rss, 75) - np.percentile(rss, 25),
        })
        
    return out

def print_table(rows):
    """Print a pivoted markdown table with representative dispersion statistics."""
    metrics = ["peak_throughput", "mem_per_obj"]
    metric_labels = {
        "peak_throughput": "Peak Throughput\n(Median ±SD, IQR)",
        "mem_per_obj": "Avg Mem/Obj\n(Median ±SD, IQR)",
    }

    benchmarks = sorted({r["benchmark"] for r in rows})
    versions = sorted({r["version"] for r in rows})

    data = {}
    for r in rows:
        data[(r["version"], r["benchmark"])] = r

    num_cols = 1 + len(benchmarks) * len(metrics)

    header_cells = ["Version"]
    for bm in benchmarks:
        header_cells.extend([bm] * len(metrics))
    print("| " + " | ".join(header_cells) + " |")

    align_cells = ["left"] + (["center"] * (num_cols - 1))
    print("| " + " | ".join(f":---:" if a == "center" else ":---" for a in align_cells) + " |")

    sub_cells = [""]
    for bm in benchmarks:
        sub_cells.extend([metric_labels[m] for m in metrics])
    print("| " + " | ".join(sub_cells) + " |")

    for v in versions:
        cells = [v]
        for bm in benchmarks:
            row = data.get((v, bm))
            if row:
                for m in metrics:
                    if m == "peak_throughput":
                        cells.append(f"{row['throughput_median']:.2f} (±{row['throughput_std']:.2f}, {row['throughput_iqr']:.2f})")
                    elif m == "mem_per_obj":
                        mem_obj_med = row["rss_median"] / row["max_total_objects"] if row["max_total_objects"] else 0
                        mem_obj_std = row["rss_std"] / row["max_total_objects"] if row["max_total_objects"] else 0
                        mem_obj_iqr = row["rss_iqr"] / row["max_total_objects"] if row["max_total_objects"] else 0
                        cells.append(f"{mem_obj_med:.4f} (±{mem_obj_std:.4f}, {mem_obj_iqr:.4f})")
            else:
                cells.extend(["—"] * len(metrics))
        print("| " + " | ".join(cells) + " |")

def write_csv(rows, path):
    fieldnames = [
        "version", "benchmark", "max_total_objects", 
        "throughput_mean", "throughput_median", "throughput_std", "throughput_iqr",
        "rss_mean", "rss_median", "rss_std", "rss_iqr"
    ]
    with open(path, "w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)

if __name__ == "__main__":
    if len(sys.argv) > 1:
        output_dir = Path(sys.argv[1])
    else:
        candidates = sorted(Path(".").glob("rmgpy_output_*"))
        if not candidates:
            print("Error: no rmgpy_output_* directory found. Run test.sh first.")
            sys.exit(1)
        output_dir = candidates[-1]

    summary_path = output_dir / "benchmark_summary.csv"
    results_path = output_dir / "results.csv"

    if not summary_path.exists():
        print(f"Error: {summary_path} not found.\nRun 'bash parse_results.sh' inside {output_dir}/ first.")
        sys.exit(1)
    if not results_path.exists():
        print(f"Error: {results_path} not found. Run test.sh first.")
        sys.exit(1)

    summary_rows = load_benchmark_summary(summary_path)
    results_rows = load_results(results_path)

    aggregated = aggregate(summary_rows, results_rows)

    print_table(aggregated)

    out_csv = output_dir / "summary_table.csv"
    write_csv(aggregated, out_csv)
    print(f"\nWrote {out_csv}")
