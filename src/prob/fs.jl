
""
function run_fault_study(data::Dict{String,Any}, solver; kwargs...)
    check_pf!(data, solver)
    add_fault_data!(data)
    solution = Dict{String, Any}()
    for (i,bus) in data["fault"]
        solution[i] = Dict{Int64, Any}()
        for (f,fault) in bus
            data["active_fault"] = fault
            solution[i][f] = _PM.run_model(data, _PM.IVRPowerModel, solver, build_fault_study; ref_extensions=[ref_add_fault!], kwargs...)
        end
    end
    return solution
end


""
function run_fault_study(file::String, solver; kwargs...)
    return run_fault_study(parse_file(file), solver; kwargs...)
end


""
function build_fault_study(pm::_PM.AbstractPowerModel)
    _PM.variable_voltage(pm, bounded = false)
    variable_branch_current(pm, bounded = false)
    variable_gen(pm, bounded = false)

    objective_max_inverter_power(pm)

    constraint_gen_voltage_drop(pm)
    constraint_pq_inverter(pm)

    constraint_fault_current(pm)

    for (i,bus) in ref(pm, :bus)
        constraint_current_balance(pm, i)
    end

    for i in ids(pm, :branch)
        _PM.constraint_current_from(pm, i)
        _PM.constraint_current_to(pm, i)
        _PM.constraint_voltage_drop(pm, i)
    end
end
