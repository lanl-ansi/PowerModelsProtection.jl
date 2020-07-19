""
function run_mc_fault_study(data::Dict{String,<:Any}, solver; kwargs...)
    # check_pf!(data, solver)
    add_mc_fault_data!(data)
    solution = Dict{String, Any}()
    faults = deepcopy(data["fault"])
    delete!(data, "fault")
    for (i,bus) in faults
        solution[i] = Dict{String,Any}()
        for (j,type) in bus
            solution[i][j] = Dict{Int64,Any}()
            for (f,fault) in type
                data["active_fault"] = fault
                solution[i][j][f] = run_mc_model(data, _PM.IVRPowerModel, solver, build_mc_fault_study; ref_extensions=[ref_add_fault!, ref_add_solar!], kwargs...)
            end
        end
    end
    return solution
end


""
function run_mc_fault_study(file::String, solver; kwargs...)
    return run_mc_fault_study(parse_file(file; import_all = true), solver; kwargs...)
end


""
function build_mc_fault_study(pm::_PM.AbstractPowerModel)
    _PMD.variable_mc_bus_voltage(pm, bounded=false)
    variable_mc_branch_current(pm, bounded=false)
    variable_mc_transformer_current(pm, bounded=false)
    variable_mc_generation(pm, bounded=false) 
  
    # variable_mc_pq_inverter(pm)
    variable_mc_grid_formimg_inverter(pm)

    for (i,bus) in ref(pm, :ref_buses)
        @assert bus["bus_type"] == 3
        # constraint_mc_ref_bus_voltage(pm, i)
        constraint_mc_voltage_magnitude_only(pm, i)
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
        _PMD.constraint_mc_bus_voltage_drop(pm, i)
    end

    for i in ids(pm, :transformer)
        _PMD.constraint_mc_transformer_power(pm, i)
    end

    for i in ids(pm, :solar)
        # constraint_mc_pq_inverter(pm, i)
        constraint_mc_grid_forming_inverter(pm, i)
    end

end
