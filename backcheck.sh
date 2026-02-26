#!/bin/bash

# Define the target date (YYYY-MM-DD format)
CUTOFF_DATE="2019-07-23"

# Define your target channels and packages here
CHANNELS=("defaults" "rmg" "rdkit" "cantera" "anaconda")
PACKAGES=("cairo" "cairocffi" "cantera >=2.3.0" "coolprop" "coverage" "cython >=0.25.2" "dde" "ffmpeg" "gprof2dot" "graphviz" "jinja2" "jupyter" "lpsolve55" "markupsafe" "matplotlib >=1.5" "mock" "mopac" "mpmath" "muq" "networkx" "nose" "numpy >=1.10.0" "openbabel" "psutil" "pydas >=1.0.1" "pydot ==1.2.2" "pydot-ng" "pydqed >=1.0.0" "pygpu" "pymongo" "pyparsing" "pyrdl" "pyyaml" "quantities" "rdkit >=2018" "scikit-learn" "scipy" "symmetry" "textgenrnn" "xlwt")

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
