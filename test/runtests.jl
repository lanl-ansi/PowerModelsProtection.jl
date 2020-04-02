using Pkg
Pkg.activate("../julia_venv")
include("../src/PowerModelsProtection.jl")
const FS = PowerModelsProtection

import Memento

# import InfrastructureModels
import PowerModels
import PowerModelsDistribution

const PMD = PowerModelsDistribution
const PMs = PowerModels

# Suppress warnings during testing.
const TESTLOG = Memento.getlogger(PowerModels)
Memento.setlevel!(TESTLOG, "error")

import JuMP
import Ipopt
# import Cbc
# import Juniper
# import SCS

import JSON

using Test
using LinearAlgebra


ipopt_solver = JuMP.with_optimizer(Ipopt.Optimizer, tol=1e-6, print_level=0)
# cbc_solver = JuMP.with_optimizer(Cbc.Optimizer, logLevel=0)
# scs_solver = JuMP.with_optimizer(SCS.Optimizer, max_iters=20000, eps=1e-5, alpha=0.4, verbose=0)
# juniper_solver = JuMP.with_optimizer(Juniper.Optimizer, nl_solver=JuMP.with_optimizer(Ipopt.Optimizer, tol=1e-4, print_level=0), mip_solver=cbc_solver, log_levels=[])

@testset "PowerModelsProtection" begin

    include("fs.jl") 
    include("fsmc.jl")
end