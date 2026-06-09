git clone git@github.com:ReactionMechanismGenerator/RMG-Py.git
cd RMG-Py
git checkout 643259b56e75c91107caef674aab35761bd9a03d
cd ..

# patch out the automatic multiprocessing code which doesn't work on our particular hardware
sed -i 's/psutil\.virtual_memory().free/psutil.virtual_memory().available/' RMG-Py/rmgpy/rmg/main.py

git clone git@github.com:ReactionMechanismGenerator/RMG-database.git
cd RMG-database
git checkout 0c2e564d4414a6dba92d2a08abb69e3d1ed10494
cd ..

conda env create -f env.yml
conda activate rmg_400_env
conda env export > env_linux_locked.yml

cd RMG-Py
make
cd ..
