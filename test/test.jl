

# using PowerModelsProtection

# import PowerModels
# import PowerModelsDistribution

# import Ipopt

# const PMD = PowerModelsDistribution
# const PM = PowerModels

# PowerModels.silence()
# PowerModelsDistribution.silence!()

# ipopt_solver = optimizer_with_attributes(Ipopt.Optimizer, "tol"=>1e-6, "print_level"=>0)


# t = @elapsed begin
#     data = parse_file("Z:/git/github/PMP_Data/123Bus/IEEE123Master.dss")
#     # data = parse_file("../test/data/dist/13Bus/IEEE13Nodeckt.dss")
#     model = PowerModelsProtection.instantiate_mc_admittance_model(data;loading=false) 
#     fault_study = PowerModelsProtection.compute_mc_pf(model)   
# end
# println(t)

# data = parse_file("../test/data/dist/ut_trans_2w_dy_lag.dss")
# data = parse_file("../test/data/dist/trans_3w_center_tap.dss")
# data = parse_file("Z:/git/github/PMP_solver_admittance/test/data/dist/123Bus/IEEE123Master.dss")
# model =  PowerModelsProtection.instantiate_mc_admittance_model(data;loading=true) 
# result = PowerModelsProtection.compute_mc_pf(model)
# result = PowerModelsProtection.solve_mc_fault_study(model)


# data = parse_file("../test/data/dist/ut_trans_2w_dy_lead.dss")
# data = parse_file("../test/data/dist/case3_gen_wye.dss")
# model = PowerModelsProtection.instantiate_mc_admittance_model(data) 
# sol = PowerModelsProtection.compute_mc_pf(model)


using PowerModelsProtection

import PowerModels
import PowerModelsDistribution

import Ipopt

using Printf

const PMD = PowerModelsDistribution

PowerModelsDistribution.silence!()

ipopt_solver = optimizer_with_attributes(Ipopt.Optimizer, "tol"=>1e-6, "print_level"=>0)

data = parse_file("../test/data/dist/gfmi_test.dss")


data["solar"]["pv1"]["fault_standard"] = {
    "model" => IEEE2800,
    "k" => 2,
}

data_math = transform_admittance_data_model(data)
