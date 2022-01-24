
"Entry point for running the optimal power-water flow problem."
function solve_mc_opf_fault_study(data_mn, solver; kwargs...)
    solution = _PMD.solve_mc_model(
        data_mn,
        _PMD.IVRUPowerModel,
        solver,
        build_mc_opf_sc;
        eng2math_extensions=[_eng2math_fault!],
        eng2math_passthrough=_pmp_eng2math_passthrough,
        make_pu_extensions=[_rebase_pu_fault!, _rebase_pu_gen_dynamics!],
        map_math2eng_extensions=Dict{String,Function}("_map_math2eng_fault!"=>_map_math2eng_fault!),
        make_si_extensions=[make_fault_si!],
        dimensionalize_math_extensions=_pmp_dimensionalize_math_extensions,
        ref_extensions=[ref_add_mc_fault!, ref_add_mc_solar!, ref_add_grid_forming_bus!, ref_add_mc_storage!],
        solution_processors=[solution_fs!],
        multinetwork=true,
    )
return solution
end

function solve_mc_opf_fault_study(file::String, solver; kwargs...)
    data = parse_file(file)
    data_mn = _PMD.make_multinetwork(data)
    return solve_mc_opf_fault_study(data_mn, solver; kwargs...)
end

function build_mc_opf_sc(pm::_PMD.AbstractUnbalancedPowerModel)

    for (n, network) in _PMD.nws(pm)
        if n != 0
            build_mc_fault_study(pm, n) 
            variable_mc_generator_power(pm, n)
            for id in _PMD.ids(pm, n, :gen)
                constraint_mc_gen_power_setpoint_real(pm, id, nw=n)
            end
        end
    end

    _PMD.build_mc_opf(pm)

    for (n, network) in _PMD.nws(pm)
        if n != 0
            for id in _PMD.ids(pm, n, :gen)
                constraint_mc_gen_voltage_drop(pm, id, nw=n)
            end
        end
    end
end


function build_mc_fault_study(pm::_PMD.AbstractUnbalancedPowerModel, n::Int)
    @debug "Building fault study"
    _PMD.variable_mc_bus_voltage(pm, bounded=false, nw=n)
    _PMD.variable_mc_switch_current(pm, bounded=false, nw=n)
    _PMD.variable_mc_branch_current(pm, bounded=false, nw=n)
    _PMD.variable_mc_transformer_current(pm, bounded=false, nw=n)
    _PMD.variable_mc_generator_current(pm, bounded=false, nw=n)

    variable_mc_storage_current(pm, bounded=false, nw=n)
    variable_mc_bus_fault_current(pm, nw=n)
    variable_mc_pq_inverter(pm, nw=n)
    variable_mc_grid_formimg_inverter(pm, nw=n)
    variable_mc_storage_grid_forming_inverter(pm, nw=n)
    
    for (i,bus) in _PMD.ref(pm, n, :ref_buses)
        @assert bus["bus_type"] == 3
        _PMD.constraint_mc_theta_ref(pm, i, nw=n)
        _PMD.constraint_mc_voltage_magnitude_only(pm, i, nw=n)
    end

    for id in _PMD.ids(pm, n, :gen)
        _PMD.constraint_mc_generator_power(pm, id; bounded=false, nw=n)
    end

    # TODO add back in the generator voltage drop with inverters in model
    @debug "Adding constraints for synchronous generators"

    for i in _PMD.ids(pm, n, :fault)
        constraint_mc_bus_fault_current(pm, i, nw=n)
        expression_mc_bus_fault_sequence_current(pm, i, nw=n)
    end

    for (i,bus) in _PMD.ref(pm, n, :bus)
        constraint_mc_current_balance(pm, i, nw=n)
    end

    for i in _PMD.ids(pm, n, :branch)
        _PMD.constraint_mc_current_from(pm, i, nw=n)
        _PMD.constraint_mc_current_to(pm, i, nw=n)
        _PMD.constraint_mc_bus_voltage_drop(pm, i, nw=n)
        expression_mc_branch_fault_sequence_current(pm, i, nw=n)
    end

    for i in _PMD.ids(pm, n, :switch)
        _PMD.constraint_mc_switch_state(pm, i, nw=n)
        expression_mc_switch_fault_sequence_current(pm, i, nw=n)
    end

    for i in _PMD.ids(pm, n, :transformer)
        _PMD.constraint_mc_transformer_power(pm, i, nw=n)
    end

    @debug "Adding constraints for grid-following inverters"
    for i in _PMD.ids(pm, n, :solar_gfli)
        @debug "Adding constraints for grid-following inverter $i"
        constraint_mc_pq_inverter(pm, i, nw=n)
    end

    @debug "Adding constraints for grid-forming inverters"
    for i in _PMD.ids(pm, n, :solar_gfmi)
        @debug "Adding constraints for grid-forming inverter $i"
        # constraint_mc_grid_forming_inverter(pm, i)
        constraint_mc_grid_forming_inverter_virtual_impedance(pm, i, nw=n)
    end

    @debug "Adding constraints for grid-forming storage inverters"
    for i in _PMD.ids(pm, n, :storage)
        @debug "Adding constraints for grid-forming inverter $i"
        constraint_mc_storage_grid_forming_inverter(pm, i, nw=n)
    end
end


