
using PowerModelsProtection

import PowerModels
import PowerModelsDistribution

import Ipopt

const PMD = PowerModelsDistribution
const PM = PowerModels

PowerModels.silence()
PowerModelsDistribution.silence!()

ipopt_solver = optimizer_with_attributes(Ipopt.Optimizer, "tol"=>1e-6, "print_level"=>0)

data = parse_file("../test/data/dist/case3_unbalanced.dss")
fault_studies = build_mc_fault_study(data)
sol = solve_mc_fault_study(data, fault_studies, ipopt_solver)


# keys(sol["primary"]["lg"]["1"]["solution"]["fault"]["1"]["cf"])