git clone git@github.com:ReactionMechanismGenerator/RMG-Py.git
cd RMG-Py
git checkout 756c968b5a053f794a5a33dd9a292f602cb1e83a
cd ..

# patch out the automatic multiprocessing code which doesn't work on our particular hardware
sed -i 's/psutil\.virtual_memory().free/psutil.virtual_memory().available/' RMG-Py/rmgpy/rmg/main.py

git clone git@github.com:ReactionMechanismGenerator/RMG-database.git
cd RMG-database
git checkout 3b302c00c2a221cbc0a5f2b10234dd0d00fe2f19
cd ..

conda env create -f env.yml
conda activate rmg_300_env

cd RMG-Py
make
cd ..
