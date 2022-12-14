"""
    solve_mc_fault_study(case::Dict{String,<:Any}, solver; kwargs...)

Function to solve a multiconductor (distribution) fault study given a data set `case` and optimization `solver`

`kwargs` can be any valid keyword argument for PowerModelsDistribution's `solve_mc_model`
"""
function solve_mc_fault_study(case::Dict{String,<:Any}, solver; kwargs...)
    data = deepcopy(case)

    # TODO can this be moved?
    check_microgrid!(data)

    islands = _PMD.identify_islands(data)
    solar_deactivate = []
    storage_deactivate = []
    for island in islands
        for (key,fault) in get(data, "fault", Dict())
            if !(data["fault"][key]["bus"] in island)
                for (i,solar) in data["solar"]
                    if solar["bus"] in island
                        push!(solar_deactivate, i)
                    end
                end
                for (i,storage) in get(data, "storage", Dict())
                    if storage["bus"] in island
                        push!(storage_deactivate, i)
                    end
                end
            end
        end
    end
    for name in solar_deactivate
        delete!(data["solar"], name)
    end
    for name in storage_deactivate
        delete!(data["storage"], name)
    end

    solution = _PMD.solve_mc_model(
        data,
        _PMD.IVRUPowerModel,
        solver,
        build_mc_fault_study;
        eng2math_extensions=[_eng2math_fault!, _eng2math_storage!, _eng2math_solar!],
        eng2math_passthrough=_pmp_eng2math_passthrough,
        make_pu_extensions=[_rebase_pu_fault!, _rebase_pu_gen_dynamics!, _rebase_pu_solar!, _rebase_pu_storage!],
        map_math2eng_extensions=Dict{String,Function}("_map_math2eng_fault!"=>_map_math2eng_fault!),
        make_si_extensions=[make_fault_si!],
        dimensionalize_math_extensions=_pmp_dimensionalize_math_extensions,
        ref_extensions=[ref_add_mc_fault!, ref_add_mc_solar!, ref_add_grid_forming_bus!, ref_add_mc_storage!],
        solution_processors=[solution_fs!],
        kwargs...
    )

    return solution
end


"""
    solve_mc_fault_study(file::String, solver; kwargs...)

Given a `file`, parses the file, and runs the fault study.
"""
function solve_mc_fault_study(file::String, solver; kwargs...)
    return solve_mc_fault_study(parse_file(file), solver; kwargs...)
end


"""
    solve_mc_fault_study(case::Dict{String,<:Any}, fault_studies::Dict{String,<:Any}, solver; kwargs...)

Solves a series of fault studies given by `fault_studies`, e.g., built from [`build_mc_fault_study`](@ref build_mc_fault_study).
"""
function solve_mc_fault_study(case::Dict{String,<:Any}, fault_studies::Dict{String,<:Any}, solver; kwargs...)
    results = deepcopy(fault_studies)

    for (bus, fault_types) in fault_studies
        for (fault_type, faults) in fault_types
            for (fault_id, fault) in faults
                data = deepcopy(case)
                data["fault"] = Dict{String,Any}(fault_id => fault)
                _result = solve_mc_fault_study(data, solver; kwargs...)

                results[bus][fault_type][fault_id] = _result
            end
        end
    end
    return results
end


"""
	build_mc_fault_study(pm::_PMD.AbstractUnbalancedPowerModel)

Builds a multiconductor (distribution) fault study optimization problem
"""
function build_mc_fault_study(pm::_PMD.AbstractUnbalancedPowerModel)
    @debug "Building fault study"
    _PMD.variable_mc_bus_voltage(pm, bounded=false)
    _PMD.variable_mc_switch_current(pm, bounded=false)
    _PMD.variable_mc_branch_current(pm, bounded=false)
    _PMD.variable_mc_transformer_current(pm, bounded=false)
    _PMD.variable_mc_generator_current(pm, bounded=false)

    variable_mc_storage_current(pm; bounded=false)
    variable_mc_bus_fault_current(pm)
    variable_mc_solar_power(pm)

    for id in _PMD.ids(pm, :gen)
        _PMD.constraint_mc_generator_power(pm, id; bounded=false)
        constraint_mc_fs_generator_constant_power(pm, id)
        # constraint_mc_generator_voltage_drop(pm, id)
        constraint_mc_fs_generator_pq_constant_inverter(pm, id)
        constraint_mc_fs_generator_grid_forming_inverter(pm, id)
        constraint_mc_fs_generator_grid_following_inverter(pm, id)
    end

    for i in _PMD.ids(pm, :fault)
        constraint_mc_bus_fault_current(pm, i)
        expression_mc_bus_fault_sequence_current(pm, i)
    end

    for (i,bus) in _PMD.ref(pm, :bus)
        constraint_mc_current_balance(pm, i)
    end

    for i in _PMD.ids(pm, :branch)
        _PMD.constraint_mc_current_from(pm, i)
        _PMD.constraint_mc_current_to(pm, i)
        _PMD.constraint_mc_bus_voltage_drop(pm, i)
        expression_mc_branch_fault_sequence_current(pm, i)
    end

    for i in _PMD.ids(pm, :switch)
        _PMD.constraint_mc_switch_state(pm, i)
        expression_mc_switch_fault_sequence_current(pm,i)
    end

    for i in _PMD.ids(pm, :transformer)
        _PMD.constraint_mc_transformer_power(pm, i)
    end

    @debug "Adding constraints for storage inverters"
    for i in _PMD.ids(pm, :storage)
        @debug "Adding constraints for inverter $i"
        constraint_mc_fs_storage_grid_forming_inverter(pm, i)
    end

    objective_mc_max_inverter_power(pm)
end
