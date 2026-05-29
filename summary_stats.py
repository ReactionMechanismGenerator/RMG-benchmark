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
                    "peak_rss_mib": int(r["peak_rss_mib"]),
                    "peak_ram_pressure_mib": int(r["peak_ram_pressure_mib"]),
                }
            )
    return rows


def aggregate(summary_rows, results_rows):
    """
    For each (version, benchmark, nproc) group:
      - peak_throughput: max throughput across iterations
      - avg_memory_mb: mean memory_mb across iterations
      - peak_rss_mib: from results.csv (overall process RSS, not per-iteration)
      - peak_ram_pressure_mib: from results.csv
      - total_wall_time_s: from results.csv
    """
    from collections import defaultdict

    groups = defaultdict(lambda: {"throughputs": [], "memories": [], "total_objects": []})

    for row in summary_rows:
        key = (row["version"], row["benchmark"], row["nproc"])
        groups[key]["throughputs"].append(row["throughput"])
        groups[key]["memories"].append(row["memory_mb"])
        groups[key]["total_objects"].append(row["total_objects"])

    # Enrich with per-run metrics from results.csv
    for row in results_rows:
        key = (row["version"], row["case"], row["processes"])
        groups[key]["peak_rss_mib"] = row["peak_rss_mib"]
        groups[key]["peak_ram_pressure_mib"] = row["peak_ram_pressure_mib"]

    out = []
    for (version, benchmark, nproc), data in sorted(groups.items()):
        if nproc != 1:
            continue
        if not data["throughputs"]:
            continue
        out.append(
            {
                "version": version,
                "benchmark": benchmark,
                "peak_throughput": max(data["throughputs"]),
                "avg_memory_mb": sum(data["memories"]) / len(data["memories"]),
                "max_total_objects": max(data["total_objects"]),
                "peak_rss_mib": data.get("peak_rss_mib", 0),
                "peak_ram_pressure_mib": data.get("peak_ram_pressure_mib", 0),
            }
        )
    return out


def print_table(rows):
    """Print a pivoted markdown table: versions as rows, benchmarks as multi-level columns."""
    metrics = ["peak_throughput", "mem_per_obj"]
    metric_labels = {
        "peak_throughput": "Peak Throughput",
        "mem_per_obj": "Avg Memory/Obj",
    }

    benchmarks = sorted({r["benchmark"] for r in rows})
    versions = sorted({r["version"] for r in rows})

    # Build lookup: (version, benchmark) -> metrics
    data = {}
    for r in rows:
        r["mem_per_obj"] = (
            r["peak_rss_mib"] / r["max_total_objects"]
            if r["max_total_objects"]
            else 0
        )
        data[(r["version"], r["benchmark"])] = r

    num_cols = 1 + len(benchmarks) * len(metrics)

    # Top-level header: benchmark names repeated per sub-col for alignment
    header_cells = ["Version"]
    for bm in benchmarks:
        header_cells.extend([bm] * len(metrics))
    print("| " + " | ".join(header_cells) + " |")

    # Alignment row
    align_cells = ["left"] + (["center"] * (num_cols - 1))
    print("| " + " | ".join(f":---:" if a == "center" else ":---" for a in align_cells) + " |")

    # Sub-header row: metric names
    sub_cells = [""]
    for bm in benchmarks:
        sub_cells.extend([metric_labels[m] for m in metrics])
    print("| " + " | ".join(sub_cells) + " |")

    # Data rows
    for v in versions:
        cells = [v]
        for bm in benchmarks:
            row = data.get((v, bm))
            if row:
                for m in metrics:
                    val = row[m]
                    if m == "peak_throughput":
                        cells.append(f"{val:.2f}")
                    elif m == "mem_per_obj":
                        cells.append(f"{val:.4f}")
                    else:
                        cells.append(str(val))
            else:
                cells.extend(["—"] * len(metrics))
        print("| " + " | ".join(cells) + " |")


def write_csv(rows, path):
    """Write results to CSV."""
    fieldnames = [
        "version",
        "benchmark",
        "peak_throughput",
        "avg_memory_mb",
        "max_total_objects",
        "peak_rss_mib",
        "peak_ram_pressure_mib",
        "mem_per_obj",
    ]
    with open(path, "w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)


if __name__ == "__main__":
    if len(sys.argv) > 1:
        output_dir = Path(sys.argv[1])
    else:
        # Find the most recent rmgpy_output_* directory
        candidates = sorted(Path(".").glob("rmgpy_output_*"))
        if not candidates:
            print("Error: no rmgpy_output_* directory found. Run test.sh first.")
            sys.exit(1)
        output_dir = candidates[-1]

    summary_path = output_dir / "benchmark_summary.csv"
    results_path = output_dir / "results.csv"

    if not summary_path.exists():
        print(
            f"Error: {summary_path} not found.\n"
            f"Run 'bash parse_results.sh' inside {output_dir}/ first."
        )
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
