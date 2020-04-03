using PowerModelsProtection
const FS = PowerModelsProtection

import Memento

import PowerModels
import PowerModelsDistribution

const PMD = PowerModelsDistribution
const PM = PowerModels

# Suppress warnings during testing.
const TESTLOG = Memento.getlogger(PowerModels)
Memento.setlevel!(TESTLOG, "error")

import JuMP
import Ipopt

import JSON

using Test
using LinearAlgebra

ipopt_solver = JuMP.with_optimizer(Ipopt.Optimizer, tol=1e-6, print_level=0)

@testset "PowerModelsProtection" begin
    include("fs.jl")
    include("fsmc.jl")
end
