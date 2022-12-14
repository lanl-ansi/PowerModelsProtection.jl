

using PowerModelsProtection

import PowerModels
import PowerModelsDistribution

import Ipopt

const PMD = PowerModelsDistribution
const PM = PowerModels

PowerModels.silence()
PowerModelsDistribution.silence!()

ipopt_solver = optimizer_with_attributes(Ipopt.Optimizer, "tol"=>1e-6, "print_level"=>0)

# data = parse_file("../test/data/dist/case3_balanced_pv.dss")
# add_fault!(data, "1", "lg", "loadbus", [1, 4], 0.005)
# # add_fault!(data, "1", "3p", "loadbus", [1,2,3], .0005)
# sol = solve_mc_fault_study(data, ipopt_solver)


data = parse_file("../test/data/dist/case3_balanced_pv_grid_forming.dss")
data["solar"]["pv1"]["grid_forming"] = true
data["line"]["ohline"]["status"] = DISABLED

add_fault!(data, "1", "lg", "loadbus", [1, 4], 0.005)
sol = solve_mc_fault_study(data, ipopt_solver)
