
function run_mc_fault_study(data::Dict{String,Any}, solver; kwargs...)
    check_pf!(data, solver)
    solution = Dict{String, Any}()
    for (i,fault) in data["fault"]
        data["active_fault"] = fault
        result = _PMs.run_model(data, _PMs.IVRPowerModel, solver, build_mc_fault_study; multiconductor=true, ref_extensions=[_PMD.ref_add_arcs_trans!, ref_add_fault!], kwargs...)
        println(result)
    end
    return solution
end

""
function run_mc_fault_study(file::String, solver; kwargs...)
    return run_mc_fault_study(parse_file(file), solver; kwargs...)
end
""

function build_mc_fault_study(pm::_PMs.AbstractPowerModel)
    _PMD.variable_mc_voltage(pm, bounded = false)
    variable_mc_branch_current(pm, bounded = false)
    variable_mc_transformer_current(pm, bounded = false)
    _PMD.variable_mc_generation(pm, bounded = false) 

    for id in _PMs.ids(pm, :gen)
        _PMD.constraint_mc_generation(pm, id)
    end

    constraint_mc_gen_voltage_drop(pm)

    constraint_mc_fault_current(pm)

    for (i,bus) in _PMs.ref(pm, :bus)
        constraint_mc_current_balance(pm, i)  
    end      

    for i in _PMs.ids(pm, :branch)
        _PMD.constraint_mc_current_from(pm, i)
        _PMD.constraint_mc_current_to(pm, i)
        _PMD.constraint_mc_voltage_drop(pm, i)
    end

    for i in _PMs.ids(pm, :transformer)
        _PMD.constraint_mc_trans(pm, i)
    end
end