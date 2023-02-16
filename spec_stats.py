import os
import sys
from collections import defaultdict
import matplotlib.pyplot as plt
import numpy as np
import argparse
from matplotlib.ticker import FuncFormatter, FixedLocator
from matplotlib.transforms import Affine2D

#prefix = "sfi-spectre-spec/result/"

#result_codes = {}
#times = defaultdict(list)
nameset = set()


def median(lst):
    n = len(lst)
    s = sorted(lst)
    return (sum(s[n//2-1:n//2+1])/2.0, s[n//2])[n % 2] if n else None

def geomean(lst):
    # Geomean is conceptually:
    #   product of all terms in the list, take nth root
    # This can overflow, so it is better to compute it as:
    #   log all terms in the list, arithmetic mean, un-log
    # which is equivalent
    lst = np.array(lst)
    return np.exp(np.mean(np.log(1.0*lst)))  # 1.0* and np.log implicitly lift to lists elementwise

def load_data(input_path):
    with open(input_path, 'r') as f:
        data = f.read()
        lines = data.split('\n')
    return lines

def get_lock_num(result_path, spec2017=False,speclocknum=None):
    if speclocknum:
        return int(speclocknum)
    if spec2017:
        path = result_path + "/lock.CPU2017"
    else:
        path = result_path + "/lock.CPU2006"
    with open(path, 'r') as f:
        data = f.read().strip()
    return int(data)

#spec.cpu2006.results.462_libquantum.base.000.reported_time: 502.749075
# spec.cpu2006.ext: wasm_lucet
def summarise(input_path, spec2017=False):
    times = {}
    mitigation_name = ""
    lines = load_data(input_path)
    results_label = ("spec.cpu2006.results" if not spec2017 else "spec.cpu2017.results")
    ext_label = ("spec.cpu2006.ext" if not spec2017 else "spec.cpu2017.label")
    for line in lines:
        if results_label in line:
            if ".valid" in line:
                name = line.split('.')[3]
                result_code = line.split()[-1]
                nameset.add(name)
            if ".reported_time" in line:
                name = line.split('.')[3]
                success_code = line.split()[-1]
                print(success_code)
                try:
                    times[name] = float(success_code)
                except:
                    print("Error parsing line: " + line + ". Fragment: " + success_code)
                    times[name] = 1
        if ext_label in line:
                mitigation_name = line.split()[1]

    return (mitigation_name,times)

def all_times_to_vals(all_times):
    vals = []
    #print(all_times)
    for d in all_times.values():
        l = sorted(list(d.items()),key=lambda x: x[0])
        ll = [v for (k,v) in l]
        vals.append(ll)
    return vals


def make_graph(all_times, output_path, use_percent=False):
    print("Making graph! all_times = " )
    for name, times in all_times.items():
        print(name, times)
    fig = plt.figure(figsize=(6.1,3))
    num_mitigations = len(all_times)
    num_benches = len(next(iter(all_times.values()))) # get any element
    mitigations = list(all_times.keys())
    width = (1.0 / ( (num_mitigations) + 1))        # the width of the bars

    ax = fig.add_subplot(111)

    plt.rcParams['pdf.fonttype'] = 42 # true type font
    # plt.rcParams['font.family'] = 'serif'
    # plt.rcParams['font.serif'] = ['Times New Roman'] + plt.rcParams['font.serif']
    plt.rcParams['font.size'] = '11'

    vals = all_times_to_vals(all_times)

    ind = np.arange(num_benches)
    labels = tuple(sorted(list(next(iter(all_times.values())).keys())))
    print(labels)
    print(vals)

    # https://colorbrewer2.org/#type=diverging&scheme=Spectral&n=5
    colors = ['#FFFFBF', '#D7191C', '#2B83BA', '#FDAE61', '#ABDDA4', ]

    rects = []
    for idx,val in enumerate(vals):
      rects.append(ax.bar(ind + width*idx, val, width, bottom=0, color=colors[idx], edgecolor="black"))


    #ax.set_xlabel('Spec2006 Benchmarks')
    if use_percent:
        ax.set_ylabel('Norm. runtime')
    else:
        ax.set_ylabel('Relative execution time')
    ax.set_xticks(ind+width)
    plt.xticks(rotation=45, ha='right', rotation_mode='anchor')
    for lbl in ax.xaxis.get_majorticklabels():
        lbl.set_transform(lbl.get_transform() + Affine2D().translate(-2, 0))

    plt.axhline(y=1.0, color='black', linestyle='dashed')
    # plt.ylim(ymin=.9)
    # if not use_percent:
    plt.ylim(ymin=0)

    if use_percent:
        ax.yaxis.set_major_formatter(FuncFormatter(lambda y, _: '{:.0%}'.format(y)))
        # ax.yaxis.set_major_locator(FixedLocator(np.arange(-.5,10,.5)))
    else:
        ax.yaxis.set_major_formatter(FuncFormatter(lambda y, _: '{:.2f}×'.format(y)))
        ax.yaxis.set_major_locator(FixedLocator(list([0, 0.25, 0.50, 0.75, 1, 1.25, 1.5])))

    ax.set_xticklabels(labels)
    if use_percent:
        ax.legend( tuple(rects), all_times.keys(), frameon=True, ncol=3, loc='upper center', prop={'size':10.5}, bbox_to_anchor=(0.5,1.05))
    else:
        ax.legend( tuple(rects), all_times.keys(), frameon=False, ncol=1, loc=(0.7, .79))
    #fig.subplots_adjust(bottom=0.25)
    plt.subplots_adjust(top = 1, bottom = 0, right = 1, left = 0,
            hspace = 0, wspace = 0)
    plt.margins(0,0)

    if os.path.exists(output_path + ".stats"):
        os.remove(output_path + ".stats")

    with open(output_path + ".stats", "a+") as myfile:
        myfile.write(f"Benchmarks: {labels}\n")

    for i in range(num_mitigations):
        result_geomean = geomean(vals[i])
        result_median = median(vals[i])
        result_min = min(vals[i])
        result_max = max(vals[i])
        with open(output_path + ".stats", "a+") as myfile:
            myfile.write(f"{mitigations[i]} geomean = {result_geomean} {mitigations[i]} median = {result_median} min = {result_min} max = {result_max} raw_values = {[p*100 for p in vals[i]]}\n")

    plt.tight_layout()
    plt.ylim([0,1.80])
    plt.savefig(output_path + ".pdf", format="pdf", bbox_inches="tight", pad_inches=0)


def get_merged_summary(result_path, n):
    int_input_path = f"{result_path}/CINT2006.{str(n).zfill(3)}.ref.rsf"
    name1,int_times = summarise(int_input_path)

    times = {}
    times.update(int_times)

    fp_input_path  = f"{result_path}/CFP2006.{str(n).zfill(3)}.ref.rsf"
    name2 = ""
    if os.path.exists(fp_input_path):
        name2,fp_times  = summarise(fp_input_path)
        times.update(fp_times)
    assert( (not (name1 != "" and name2 == "")) and (name1 == name2) or (name1 == "") or (name2 == ""))
    #print(name1, name2)
    return name1,times


def get_merged_summary_spec2017(result_path, n):
    intspeed_input_path = f"{result_path}/CPU2017.{str(n).zfill(3)}.intspeed.refspeed.rsf"
    fpspeed_input_path = f"{result_path}/CPU2017.{str(n).zfill(3)}.fpspeed.refspeed.rsf"
    fprate_input_path = f"{result_path}/CPU2017.{str(n).zfill(3)}.fprate.refrate.rsf"
    name1,intspeed_times = summarise(intspeed_input_path, spec2017=True)
    name2,fpspeed_times = summarise(fpspeed_input_path, spec2017=True)
    name3,fprate_times = summarise(fprate_input_path, spec2017=True)
    times = {}
    times.update(intspeed_times)
    times.update(fpspeed_times)
    times.update(fprate_times)
    assert(name1 == name2)
    assert(name2 == name3)
    return name1,times

def normalize_times(times):
    normalized_times = defaultdict(dict)
    if "Stock" in times:
        base_times = times["Stock"]
    elif "wasm_lucet" in times:
        base_times = times["wasm_lucet"]
    elif "hfi_wasm2c_guardpages" in times:
        base_times = times["hfi_wasm2c_guardpages"]
    elif "hfi_wasm2c_guardpagespure" in times:
        base_times = times["hfi_wasm2c_guardpagespure"]
    else:
        raise Exception("Could not find baseline times to normalize against. Expected either 'Stock' or 'wasm_lucet'. Got " + str(times.keys()))

    for bench in base_times:
        base_time = base_times[bench]
        for mitigation in times:
            try:
                curr_time = times[mitigation][bench]
            except:
                print("Error getting time for: " + mitigation + ", " + bench)
                curr_time = 1
            normalized_times[mitigation][bench] = curr_time / base_time

    return dict(normalized_times)

# "spec.cpu2006.results.464_h264ref.base.000.valid:"
def run(result_path, n, output_path,speclocknum=None):
    lock_num = get_lock_num(result_path,speclocknum=speclocknum)
    all_times = {}
    for idx in range(n):
        name,times = get_merged_summary(result_path, lock_num - n + idx + 1)
        print(name, times)
        all_times[name] = times

    normalized_times = normalize_times(all_times)

    #{mitigation name -> {}}      --- here is where we cut
    make_graph(normalized_times, output_path)


def run_w_filter(result_path, bench_filter, n, use_percent, spec2017=False, extra_spec2017_path=None, extra_spec2017_n=None,speclocknum=None):
    all_times = {}
    lock_num = get_lock_num(result_path, spec2017=spec2017,speclocknum=speclocknum)
    if spec2017:
        for idx in range(n):
            name,times = get_merged_summary_spec2017(result_path, lock_num - n + idx + 1)
            print(name, times)
            all_times[name] = times
        normalized_times = normalize_times(all_times)
        print("Normalized Spec2017 Times: ")
        for name,times in normalized_times.items():
            print(name, times)
        # Do graphing here
        for partitioned_times, output_path in bench_filter.partition_benches(normalized_times):
            make_graph(partitioned_times, output_path, use_percent=use_percent)
        return
    else:
        for idx in range(n):
            name,times = get_merged_summary(result_path, lock_num - n + idx + 1)
            print(name, times)
            all_times[name] = times

        normalized_times = normalize_times(all_times)

        # If we're using a merged run
        if extra_spec2017_path != None:
            assert(extra_spec2017_n != None)
            all_times_extra = {}
            loc_num_extra = lock_num = get_lock_num(extra_spec2017_path, spec2017=True,speclocknum=speclocknum)
            for idx in range(extra_spec2017_n):
                name,times = get_merged_summary_spec2017(extra_spec2017_path, lock_num - extra_spec2017_n + idx + 1)
                all_times_extra[name] = times
            normalized_times_extra = normalize_times(all_times_extra)
            #normalized_times.update(normalized_times_extra)
            for name,extra_times in normalized_times_extra.items():
                print(name, extra_times, normalized_times[name])
                if name in normalized_times:
                    times = normalized_times[name]
                    times.update(extra_times)
                    normalized_times[name] = times
                else:
                    normalized_times[name] = extra_times


        print("Normalized times:")
        for name, times in normalized_times.items():
            print(name, times)
        #{mitigation name -> {}}      --- here is where we cut
        for partitioned_times, output_path in bench_filter.partition_benches(normalized_times):
            make_graph(partitioned_times, output_path,  use_percent=use_percent)


class BenchAlias(object):
        """docstring for BenchAlias"""
        def __init__(self, arg):
            name,aliased_as = arg.split(":")
            self.name = name
            self.aliased_as = aliased_as

        def __repr__(self):
            return self.__str__()

        def __str__(self):
            return f"{self.name} -> {self.aliased_as}"

def parse_bench_filter(s):
    d = {}
    benchsets = s.split(";")
    for benchset in benchsets:
        out_path,alias_list = benchset.split("=")
        parsed_aliases = [BenchAlias(alias) for alias in alias_list.split(",")]
        d[out_path] = parsed_aliases

    return d
'''
def get_geomean_times(d):
    print(d)
    d_geomean = defaultdict(list)
    for times in d.values():
        for name,t in times.items():
            d_geomean[name].append(t)

    geomeans = {}
    for name,times in d_geomean.items():
        geomeans[name] = geomean(times)

    return geomeans
'''

class BenchFilter(object):
        """docstring for BenchFilter"""
        def __init__(self, s):
                self.filter = parse_bench_filter(s)

        def get_total_mitigation_num(self):
            n = 0
            for bencheset in self.filter.values():
                n += len(bencheset)
            return n

        # normalized times = {mitigation_name -> {bench_name -> time}}
        # bench_aliases = [(name, alias)]
        # result = {mitigation_name (aliased) -> {bench_name -> time}}
        def partition_one(self, normalized_times, bench_aliases):
            d = {}
            for alias in bench_aliases:
                times = normalized_times[alias.name]
                #print("<><><><><><><><><>",alias, geomean(list(times.values())))
                times["Geomean"] = geomean(list(times.values()))
                d[alias.aliased_as] = times
            #d["Geomean"] = get_geomean_times(d)
            return d

        def partition_benches(self, normalized_times):
            for output_path, bench_aliases in self.filter.items():
                partitioned_benches = self.partition_one(normalized_times, bench_aliases)
                print("=========>", partitioned_benches, output_path)
                yield partitioned_benches, output_path

        def __str__(self):
            return str(self.filter)

def main():
    parser = argparse.ArgumentParser(description='Graph Spec Results')
    parser.add_argument('-i', dest='input_path', help='input directory (should be a spec results directory)')
    parser.add_argument('--extraSpec2017Path', dest='extra_spec2017_path', default=None, help='extra input directory (should be a spec2017 results directory)')
    parser.add_argument("--extraSpec2017n", dest="extra_spec2017_n", default=None, type=int)
    parser.add_argument('--usePercent', dest='usePercent', default=False, action='store_true')
    parser.add_argument('--spec2017', dest='spec2017', default=False, action='store_true')
    parser.add_argument("--filter", dest="filter", type=BenchFilter)
    parser.add_argument("-n", dest="n", type=int)
    parser.add_argument("--speclocknum", dest="speclocknum", default=None, type=int)
    args = parser.parse_args()

    with open(args.input_path + '/spec_results.cmd', 'w') as f:
        f.write("Command: " + str(sys.argv))

    run_w_filter(args.input_path, args.filter, args.n, use_percent=args.usePercent, spec2017=args.spec2017, extra_spec2017_path=args.extra_spec2017_path, extra_spec2017_n=args.extra_spec2017_n,speclocknum=args.speclocknum)


if __name__ == '__main__':
    main()
