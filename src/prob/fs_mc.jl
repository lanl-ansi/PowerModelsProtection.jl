"Runs the mc fault study"
function solve_mc_fault_study(case::Dict{String,<:Any}, solver; kwargs...)
    data = deepcopy(case)
    # check_pf!(data, solver)
    check_microgrid!(data)
    add_mc_fault_data!(data)
    solution = Dict{String, Any}()
    faults = deepcopy(data["fault"])
    delete!(data, "fault")
    for (i,bus) in faults
        solution[i] = Dict{String,Any}()
        for (j,type) in bus
            solution[i][j] = Dict{String,Any}()
            for (f,fault) in type
                data["active_fault"] = fault
                @debug "Running short circuit"
                solution[i][j]["$f"] = run_mc_model(data, _PMD.IVRUPowerModel, solver, build_mc_fault_study; ref_extensions=[ref_add_mc_fault!, ref_add_gen_dynamics!, ref_add_solar!], kwargs...)
            end
        end
    end
    return solution
end


"Call to run fs on file"
function solve_mc_fault_study(file::String, solver; kwargs...)
    return solve_mc_fault_study(parse_file(file), solver; kwargs...)
end


"Build mc fault study"
function build_mc_fault_study(pm::_PMD.AbstractUnbalancedPowerModel)
    @debug "Building fault study"
    _PMD.variable_mc_bus_voltage(pm, bounded=false)
    _PMD.variable_mc_switch_current(pm, bounded=false)
    _PMD.variable_mc_branch_current(pm, bounded=false)
    _PMD.variable_mc_transformer_current(pm, bounded=false)
    _PMD.variable_mc_generator_current(pm, bounded=false)

    variable_mc_pq_inverter(pm)
    variable_mc_grid_formimg_inverter(pm)

    for (i,bus) in _PMD.ref(pm, :ref_buses)
        @assert bus["bus_type"] == 3
        _PMD.constraint_mc_theta_ref(pm, i)
        _PMD.constraint_mc_voltage_magnitude_only(pm, i)
    end

    for id in _PMD.ids(pm, :gen)
        _PMD.constraint_mc_generator_power(pm, id; bounded=false)
    end

    # TODO add back in the generator voltage drop with inverters in model
    @debug "Adding constraints for synchronous generators"
    constraint_mc_gen_voltage_drop(pm)

    constraint_mc_fault_current(pm)

    for (i,bus) in _PMD.ref(pm, :bus)
        constraint_mc_current_balance(pm, i)
    end

    for i in _PMD.ids(pm, :branch)
        _PMD.constraint_mc_current_from(pm, i)
        _PMD.constraint_mc_current_to(pm, i)
        _PMD.constraint_mc_bus_voltage_drop(pm, i)
    end

    for i in _PMD.ids(pm, :switch)
        _PMD.constraint_mc_switch_state(pm, i)
    end

    for i in _PMD.ids(pm, :transformer)
        _PMD.constraint_mc_transformer_power(pm, i)
    end

    @debug "Adding constraints for grid-following inverters"
    for i in _PMD.ids(pm, :solar_gfli)
        @debug "Adding constraints for grid-following inverter $i"
        constraint_mc_pq_inverter(pm, i)
    end

    @debug "Adding constraints for grid-forming inverters"
    for i in _PMD.ids(pm, :solar_gfmi)
        @debug "Adding constraints for grid-forming inverter $i"
        # constraint_mc_grid_forming_inverter(pm, i)
        constraint_mc_grid_forming_inverter_virtual_impedance(pm, i)
    end
end
