# RMG-benchmark

Benchmarks for the RMG v4.0 paper, comparing it against historical versions of RMG.

## Installing

I have provided working installation files for Linux.
When I say working, I mean that you can run them _today_ and they actually resolve an environment that allows RMG-Py to run.
The environment files included in the original code don't work anymore because new versions of many of the dependencies have been released; the environment files don't forbid `conda` from installing these, so they often install incompatible packages.

These are the three versions which I have set up, each of which has its own subdirectory:

 - `2.4.1`: last Python 2 release, uses Python 2.7 ([RMG-Py commit is here on GitHub](https://github.com/ReactionMechanismGenerator/RMG-Py/tree/af0ef48bda472c4689605015ac0adda102425aae), [RMG-database is here](https://github.com/ReactionMechanismGenerator/RMG-database/tree/d52ebabb3478377660dd4c25c938844549d9ec42))
 - `3.0.0`: first Python 3 release, uses Python 3.7 ([commit is here on GitHub](https://github.com/ReactionMechanismGenerator/RMG-Py/tree/756c968b5a053f794a5a33dd9a292f602cb1e83a), [RMG-database is here](https://github.com/ReactionMechanismGenerator/RMG-database/tree/3b302c00c2a221cbc0a5f2b10234dd0d00fe2f19))
 - `4.0.0`: version described in the RMG-Py 4.0 manuscript; supports Python 3.9 through 3.11, this setup uses 3.11 ([commit is here on GitHub](https://github.com/ReactionMechanismGenerator/RMG-Py/tree/643259b56e75c91107caef674aab35761bd9a03d), [RMG-database is here](https://github.com/ReactionMechanismGenerator/RMG-database/tree/0c2e564d4414a6dba92d2a08abb69e3d1ed10494))

To actually run the install, just navigate to the corresponding subdirectory and run `install.sh`.

## Running

Within each version's subdirectory, there is a `test.sh` script that executes the tests, writing the results to both the terminal and a timestamped log file.
It will auto-magically run on all available CPUs.

## Results

Detailed results can be seen in `results.ipynb`, and summary results are generated using `summary_stats.py`.
