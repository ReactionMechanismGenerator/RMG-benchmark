git clone git@github.com:ReactionMechanismGenerator/RMG-Py.git
cd RMG-Py
git checkout af0ef48bda472c4689605015ac0adda102425aae
cd ..

# patch out the automatic multiprocessing code which doesn't work on our particular hardware
sed -i 's/psutil\.virtual_memory().free/psutil.virtual_memory().available/' RMG-Py/rmgpy/rmg/main.py

git clone git@github.com:ReactionMechanismGenerator/RMG-database.git
cd RMG-database
git checkout d52ebabb3478377660dd4c25c938844549d9ec42
cd ..

conda env create -f env.yml
conda activate rmg_241_env
conda env export > env_linux_locked.yml

cd RMG-Py
make
cd ..
