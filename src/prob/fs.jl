
""
function run_fault_study(data::Dict{String,Any}, solver; kwargs...)
    check_pf!(data, solver)
    solution = Dict{String, Any}()
    for (i,fault) in data["fault"]
        data["active_fault"] = fault
        result = _PMs.run_model(data, _PMs.IVRPowerModel, solver, build_fault_study; ref_extensions=[ref_add_fault!], kwargs...)
        println(result)
    end
    println(ll)
    return solution
end

""
function run_fault_study(file::String, solver; kwargs...)
    return run_fault_study(parse_file(file), solver; kwargs...)
end
""

function build_fault_study(pm::_PMs.AbstractPowerModel)
    _PMs.variable_voltage(pm, bounded = false)
    variable_branch_current(pm, bounded = false)
    _PMs.variable_gen(pm, bounded = false)

    constraint_gen_voltage_drop(pm)
    constraint_fault_current(pm)

    for (i,bus) in _PMs.ref(pm, :bus)
        constraint_current_balance(pm, i)
    end

    for i in _PMs.ids(pm, :branch)
        _PMs.constraint_current_from(pm, i)
        _PMs.constraint_current_to(pm, i)
        _PMs.constraint_voltage_drop(pm, i)
    end
end

