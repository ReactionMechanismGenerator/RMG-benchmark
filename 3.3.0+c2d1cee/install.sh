git clone git@github.com:ReactionMechanismGenerator/RMG-Py.git
cd RMG-Py
git checkout c2d1cee02c4298312edd0d01c18125fa1735d865
cd ..

# patch out the automatic multiprocessing code which doesn't work on our particular hardware
sed -i 's/psutil\.virtual_memory().free/psutil.virtual_memory().available/' RMG-Py/rmgpy/rmg/main.py

git clone git@github.com:ReactionMechanismGenerator/RMG-database.git
cd RMG-database
git checkout 6bbe93aa278b21e18770f23dd57d23d37c94fbe2
cd ..

conda env create -f env.yml
conda activate rmg_3.3.0+c2d1cee_env

cd RMG-Py
make
cd ..
