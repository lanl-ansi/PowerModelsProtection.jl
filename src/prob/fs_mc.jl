""
function run_mc_fault_study(data::Dict{String,<:Any}, solver; kwargs...)
    check_pf!(data, solver)
    add_mc_fault_data!(data)
    solution = Dict{String, Any}()
    for (i,bus) in data["fault"]
        name = data["bus"][i]["name"]
        solution[name] = Dict{String,Any}()
        for (j,type) in bus
            solution[name][j] = Dict{Int64,Any}()
            for (f,fault) in type
                data["active_fault"] = fault
                solution[name][j][f] = _PM.run_model(data, _PM.IVRPowerModel, solver, build_mc_fault_study; multiconductor=true, ref_extensions=[_PMD.ref_add_arcs_trans!, ref_add_fault!], solution_processors=[solution_fs!], kwargs...)
            end
        end
    end
    return solution
end


""
function run_mc_fault_study(file::String, solver; kwargs...)
    return run_mc_fault_study(parse_file(file), solver; kwargs...)
end


""
function build_mc_fault_study(pm::_PM.AbstractPowerModel)
    _PMD.variable_mc_voltage(pm, bounded=false)
    variable_mc_branch_current(pm, bounded=false)
    variable_mc_transformer_current(pm, bounded=false)
    variable_mc_generation(pm, bounded=false)

    for (i,bus) in ref(pm, :ref_buses)
        @assert bus["bus_type"] == 3
        constraint_mc_ref_bus_voltage(pm, i)
    end

    for id in ids(pm, :gen)
        constraint_mc_generation(pm, id)
    end

    # constraint_mc_gen_voltage_drop(pm)

    constraint_mc_fault_current(pm)

    for (i,bus) in ref(pm, :bus)
        constraint_mc_current_balance(pm, i)
    end

    for i in ids(pm, :branch)
        _PMD.constraint_mc_current_from(pm, i)
        _PMD.constraint_mc_current_to(pm, i)
        _PMD.constraint_mc_voltage_drop(pm, i)
    end

    for i in ids(pm, :transformer)
        _PMD.constraint_mc_trans(pm, i)
    end
end
