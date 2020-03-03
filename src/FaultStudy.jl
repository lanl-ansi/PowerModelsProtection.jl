module FaultStudy
    
    import JuMP
    import Memento

    import InfrastructureModels
    import PowerModels
    import PowerModelsDistribution
    import MathOptInterface

    const _PMs = PowerModels
    const _PMD = PowerModelsDistribution
    const MOI = MathOptInterface

    function __init__()
        global _LOGGER = Memento.getlogger(PowerModels)
    end

    # include("core/ref.jl")
    include("core/variable.jl")
    include("core/constraint_template.jl")
    include("core/constraint.jl")
    include("core/data.jl")
    include("core/ref.jl")

    include("io/common.jl")
    include("io/matpower.jl")
    include("io/opendss.jl")

    include("prob/fs.jl")
    include("prob/fs_mc.jl")
    #include("prob/pf.jl")

    include("core/export.jl")  # must be last include to properly export functions
end 