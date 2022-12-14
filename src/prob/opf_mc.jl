"""
    solve_mc_opf(case::Dict{String,<:Any}, solver; kwargs...)

Function to solve a multiconductor (distribution) optimal power flow given a data set `case` and optimization `solver`

`kwargs` can be any valid keyword argument for PowerModelsDistribution's `solve_mc_model`
"""
function solve_mc_opf(data::Dict{String,<:Any}, solver; kwargs...)
    solution = _PMD.solve_mc_model(
        data,
        _PMD.IVRUPowerModel,
        solver,
        build_mc_opf;
        eng2math_extensions=[_eng2math_storage!, _eng2math_solar!],
        eng2math_passthrough=_pmp_eng2math_passthrough,
        make_pu_extensions=[_rebase_pu_gen_dynamics!, _rebase_pu_solar!, _rebase_pu_storage!],
        # map_math2eng_extensions=Dict{String,Function}("_map_math2eng_fault!"=>_map_math2eng_fault!),
        # make_si_extensions=[make_fault_si!],
        dimensionalize_math_extensions=_pmp_dimensionalize_math_extensions,
        ref_extensions=[ref_add_mc_solar!, ref_add_grid_forming_bus!, ref_add_mc_storage!],
        # solution_processors=[solution_fs!],
        kwargs...
    )
    return solution
end


"""
    solve_mc_opf(file::String, solver; kwargs...)

Given a `file`, parses the file, and runs the optimal power flow.
"""
function solve_mc_opf(file::String, solver; kwargs...)
    return solve_mc_opf(parse_file(file), solver; kwargs...)
end


"""
	build_mc_fault_study(pm::_PMD.AbstractUnbalancedPowerModel)

Builds a multiconductor (distribution) fault study optimization problem
"""
function build_mc_opf(pm::_PMD.AbstractUnbalancedIVRModel)
    pm.ref[:it][:pmd][:nw][0][:load] = Dict{Int, Any}()
    # @debug "$(keys(pm.ref[:it][:pmd][:nw][0]))"
    # @debug "$(keys(pm.ref[:it][:pmd][:nw][0][:gen]))"
    @debug "$(pm.ref[:it][:pmd][:nw][0][:solar_gfli])"
    @debug "$(pm.ref[:it][:pmd][:nw][0][:solar_gfmi])"
    @debug "$(keys(_PMD.ref(pm, 0, :bus_conns_storage)))"

    # @debug "$(pm.ref[:it][:pmd][:nw][0][:storage_gfmi])"
    # # @debug "$(pm.ref[:it][:pmd][:nw][0][:storage])"
    # @debug "$(pm.ref[:it][:pmd][:nw][0][:gen][5])"
    # @debug "$("\n\n")"
    # @debug "$(pm.ref[:it][:pmd][:nw][0][:gen][17])"
    # @debug "$("\n\n")"
    # @debug "$(pm.ref[:it][:pmd][:nw][0][:gen][13])"
    # @debug "$("\n\n")"
    # @debug "$((pm.ref[:it][:pmd][:nw][0][:ref_buses]))"


    @debug "optimal power flow"
    _PMD.variable_mc_bus_voltage(pm; bounded=false)
    _PMD.variable_mc_switch_current(pm)
    _PMD.variable_mc_branch_current(pm)
    _PMD.variable_mc_transformer_current(pm)
    _PMD.variable_mc_generator_current(pm)
    # _PMD.variable_mc_load_current(pm)
    variable_mc_storage_current(pm)

    # variable_mc_pq_inverter(pm)
    # variable_mc_grid_formimg_inverter(pm)
    # variable_mc_storage_grid_forming_inverter(pm)

    @debug "$(keys(_PMD.ref(pm, 0, :ref_buses)))"
    for (i,bus) in _PMD.ref(pm, :ref_buses)
        @assert bus["bus_type"] == 3
        if i != 48 && i != 28
            _PMD.constraint_mc_theta_ref(pm, i)
            # constraint_mc_voltage_magnitude_bounds(pm,i)
        end
    end

    for id in _PMD.ids(pm, :gen)
        _PMD.constraint_mc_generator_power(pm, id)
        constraint_mc_opf_generator_constant_power(pm, id)
        # constraint_mc_generator_voltage_drop(pm, id)
        constraint_mc_opf_generator_pq_constant_inverter(pm, id)
        constraint_mc_opf_generator_grid_forming_inverter(pm, id)
    end


    for id in _PMD.ids(pm, :load)
        # _PMD.constraint_mc_load_power(pm, id)
    end

    for (i,bus) in _PMD.ref(pm, :bus)
        constraint_mc_current_balance(pm, i)

    end

    for i in _PMD.ids(pm, :branch)
        _PMD.constraint_mc_current_from(pm, i)
        _PMD.constraint_mc_current_to(pm, i)
        _PMD.constraint_mc_bus_voltage_drop(pm, i)
        _PMD.constraint_mc_voltage_angle_difference(pm, i)
    end

    for i in _PMD.ids(pm, :switch)
        _PMD.constraint_mc_switch_state(pm, i)
    end

    for i in _PMD.ids(pm, :transformer)
        _PMD.constraint_mc_transformer_power(pm, i)
    end

    # @debug "Adding constraints for grid-following inverters"
    # for i in _PMD.ids(pm, :solar_gfli)
    #     @debug "$(pppppp)"
    #     @debug "Adding constraints for grid-following inverter $i"
    #     constraint_mc_pq_inverter(pm, i)
    # end

    # @debug "Adding constraints for grid-forming inverters"
    # for i in _PMD.ids(pm, :solar_gfmi)
    #     @debug "$(oooo)"
    #     @debug "Adding constraints for grid-forming inverter $i"
    #     # constraint_mc_grid_forming_inverter(pm, i)
    #     constraint_mc_grid_forming_inverter_virtual_impedance(pm, i)
    # end
    @debug "$("storage___________________________________")"
    @debug "Adding constraints for grid-forming storage inverters"
    for i in _PMD.ids(pm, :storage)
        @debug "Adding constraints for grid-forming inverter $i"
        constraint_opf_mc_storage_grid_forming_inverter_virtual_impedance(pm, i)
    end
end
