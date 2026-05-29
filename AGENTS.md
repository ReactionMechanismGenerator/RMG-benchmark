# RMG-benchmark

Benchmark harness comparing RMG-Py versions 2.4.1 (Python 2.7), 3.0.0 (Python 3.7), and 3.3.0+c2d1cee (Python 3.11).

## Setup

Each version subdirectory (`2.4.1/`, `3.0.0/`, `3.3.0+c2d1cee/`) has its own `install.sh` that:
1. Clones RMG-Py at a pinned commit
2. Patches `rmgpy/rmg/main.py`: replaces `psutil.virtual_memory().free` with `.available`
3. Clones RMG-database at a pinned commit
4. Creates a conda env from `env.yml` (env names: `rmg_241_env`, `rmg_300_env`, `rmg_3.3.0+c2d1cee_env`)
5. Runs `make` inside RMG-Py

Run `bash install.sh` inside each version directory. Cloned repos (`RMG-Py/`, `RMG-database/`) are gitignored.

## Running Benchmarks

From repo root: `bash test.sh`

This runs every benchmark case (heptane, diesel, propane, octane) across all 3 versions and process counts (1, 2, 4, 8), writing a timestamped `rmgpy_output_<timestamp>/` directory with a `results.csv` (execution time, peak RSS, RAM pressure per run).

Each run invokes: `python <version>/RMG-Py/rmg.py --maxproc N --output-directory <dir> <version>/<case>.py`

## Analyzing Results

1. Parse RMG logs: `bash parse_results.sh` from inside a `rmgpy_output_*` directory. Produces `benchmark_summary.csv` with per-iteration species/reaction counts.
2. Plotting: `results.ipynb` reads `benchmark_summary.csv` and `results.csv` for throughput and memory plots. Uses a `rmgb` conda kernel.

## Key Details

- 2.4.1 requires Python 2.7 (`conda-forge::python >=2.7,<3`); the `free` channel is needed for some deps
- No build, test, or lint tooling — this is a benchmark harness, not application code
- Benchmark input files (`.py`) are RMG input scripts, not test files
