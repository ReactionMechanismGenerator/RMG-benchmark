#!/bin/bash

# Define the target date (YYYY-MM-DD format)
CUTOFF_DATE="2026-06-08"

# Define your target channels and packages here
CHANNELS=("rmg" "conda-forge")
PACKAGES=("cairo" "cairocffi" "ffmpeg >= 7" "xlrd" "xlwt" "h5py >=3.10" "graphviz >=12" "markupsafe" "psutil" "ncurses" "suitesparse" "pyopenssl >24" "coolprop" "cantera >=3.0" "mopac" "cclib >=1.6.3,<1.9" "openbabel >= 3" "rdkit >=2024" "pysidt-rmg >=1.2" "setuptools >=70,<80" "coverage" "cython >=3.0,<3.1" "scikit-learn >=1.3" "scipy >=1.13" "numpy >=1.24,<2" "pydot" "jinja2" "jupyter" "pip" "pymongo" "pyparsing" "pyyaml" "networkx" "pytest" "pytest-cov" "pytest-check" "pyutilib" "matplotlib >=3.5" "mpmath" "pandas >=2" "gprof2dot" "numdifftools" "quantities !=0.16.0,!=0.16.1" "pydas >=1.0.3" "pydqed >=1.0.3" "symmetry")

echo "Searching for latest package versions as of $CUTOFF_DATE..."
echo "---------------------------------------------------------------------------------"
printf "%-15s | %-12s | %s\n" "CHANNEL" "PACKAGE" "LATEST RESOLVED FILE"
echo "---------------------------------------------------------------------------------"

for package in "${PACKAGES[@]}"; do
    for channel in "${CHANNELS[@]}"; do
        
        # Fetch the conda package metadata, routing stderr to null to hide fetch errors
        output=$(conda search --info "${channel}::${package}" 2>/dev/null)
        
        # Check if the package was found on the channel at all
        if [ -z "$output" ]; then
            printf "%-15s | %-12s | %s\n" "$channel" "$package" "Error: Package/Channel not found"
            continue
        fi

        # Parse the output blocks with awk
        result=$(echo "$output" | awk -v target="$CUTOFF_DATE" '
        /^file name[ \t]+:/ { 
            # The file name line contains the package name, version, and build string
            filename = $NF 
        }
        /^timestamp[ \t]+:/ {
            # Iterate through the fields to find the YYYY-MM-DD date string
            for(i=1; i<=NF; i++) {
                if ($i ~ /^[0-9]{4}-[0-9]{2}-[0-9]{2}$/) {
                    pkg_date = $i
                    
                    # If the timestamp is on or before our cutoff date, save it.
                    # Because conda output is sorted, the last one we find that 
                    # passes this check will be the most up-to-date version.
                    if (pkg_date <= target) {
                        best_file = filename
                        best_date = pkg_date
                        found = 1
                    }
                    break
                }
            }
        }
        END {
            # Output the final matched result for this package
            if (found) {
                print best_file " (Published: " best_date ")"
            } else {
                print "No versions published before " target
            }
        }')

        printf "%-15s | %-12s | %s\n" "$channel" "$package" "$result"
        
    done
done
echo "---------------------------------------------------------------------------------"
