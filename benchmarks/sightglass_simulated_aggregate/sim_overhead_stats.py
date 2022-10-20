# calculate the mean squared error of hfiemulate wrt hfi
import os
from statistics import mean, geometric_mean

sim_folder = os.path.dirname(os.path.realpath(__file__))
os.chdir(sim_folder)

hfi_res = []
emu_res = []
for datafile in sorted(os.listdir()):
    if 'results' in datafile:
        continue
    with open(datafile, 'r') as f:
        if 'emulate' in datafile:
            emu_res.append(int(f.read()))
        elif 'hfi' in datafile:
            hfi_res.append(int(f.read()))

n = len(emu_res)
print("Max % overhead:",100*(max([emu_res[i]/hfi_res[i] for i in range(n)])- 1))
print("Avg % overhead:",100*(mean([emu_res[i]/hfi_res[i] for i in range(n)])- 1))
print("Geomean % overhead:",100*(geometric_mean([emu_res[i]/hfi_res[i] for i in range(n)])-1))

