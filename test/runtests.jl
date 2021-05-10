using PowerModelsProtection

import PowerModels
import PowerModelsDistribution

const PMD = PowerModelsDistribution
const PM = PowerModels

PowerModels.silence()
PowerModelsDistribution.silence!()

import Ipopt

import JSON

using Test
# using LinearAlgebra

ipopt_solver = optimizer_with_attributes(Ipopt.Optimizer, "tol"=>1e-6, "print_level"=>0)

@testset "PowerModelsProtection" begin
    include("common.jl")
    include("fs.jl")
    include("fs_mc.jl")
    include("pf_mc.jl")
end
