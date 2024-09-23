"""
	solve_mc_pf(data::Dict{String,<:Any}, solver; kwargs...)

Run Power Flow Problem with Solar
"""
function solve_mc_pf(data::Dict{String,<:Any}, solver; kwargs...)
    solution = _PMD.solve_mc_model(
        data,
        _PMD.IVRUPowerModel,
        solver,
        build_mc_pf;
        eng2math_passthrough=_pmp_eng2math_passthrough,
        make_pu_extensions=[_rebase_pu_gen_dynamics!],
        dimensionalize_math_extensions=_pmp_dimensionalize_math_extensions,
        ref_extensions=[ref_add_mc_solar!, ref_add_grid_forming_bus!],
        kwargs...
    )

    return solution
end


"""
	solve_mc_pf(file::String, solver; kwargs...)

Run Power Flow Problem with Solar
"""
function solve_mc_pf(file::String, solver; kwargs...)
    return solve_mc_pf(parse_file(file), solver; kwargs...)
end


"""
	build_mc_pf(pm::_PMD.AbstractUnbalancedPowerModel)

Constructor for Power Flow Problem with Solar
"""
function build_mc_pf(pm::_PMD.AbstractUnbalancedPowerModel)
    _PMD.variable_mc_bus_voltage(pm, bounded=false)
    _PMD.variable_mc_branch_current(pm, bounded=false)
    _PMD.variable_mc_transformer_current(pm, bounded=false)
    _PMD.variable_mc_generator_current(pm, bounded=false)
    _PMD.variable_mc_load_current(pm, bounded=false)

    variable_mc_pq_inverter(pm)
    variable_mc_grid_formimg_inverter(pm)

    for (i, bus) in _PMD.ref(pm, :ref_buses)
        @assert bus["bus_type"] == 3
        _PMD.constraint_mc_theta_ref(pm, i)
        _PMD.constraint_mc_voltage_magnitude_only(pm, i)
    end

    for id in _PMD.ids(pm, :gen)
        _PMD.constraint_mc_generator_power(pm, id)
    end

    for id in _PMD.ids(pm, :load)
        _PMD.constraint_mc_load_power(pm, id)
    end

    for (i, bus) in _PMD.ref(pm, :bus)
        _PMD.constraint_mc_current_balance(pm, i)

        # PV Bus Constraints
        if length(_PMD.ref(pm, :bus_gens, i)) > 0 && !(i in _PMD.ids(pm, :ref_buses))
            # this assumes inactive generators are filtered out of bus_gens
            @assert bus["bus_type"] == 2
            if !(i in _PMD.ids(pm, :solar_gfli))
                _PMD.constraint_mc_voltage_magnitude_only(pm, i)
                if !(i in _PMD.ids(pm, :solar_gfmi))
                    for j in _PMD.ref(pm, :bus_gens, i)
                        _PMD.constraint_mc_gen_power_setpoint_real(pm, j)
                    end
                end
            end
        end

    end

    for i in _PMD.ids(pm, :branch)
        _PMD.constraint_mc_current_from(pm, i)
        _PMD.constraint_mc_current_to(pm, i)
        _PMD.constraint_mc_bus_voltage_drop(pm, i)
    end

    for i in _PMD.ids(pm, :transformer)
        _PMD.constraint_mc_transformer_power(pm, i)
    end

    for i in _PMD.ids(pm, :solar_gfli)
        constraint_mc_pq_inverter(pm, i)
    end

    for i in _PMD.ids(pm, :solar_gfmi)
        constraint_mc_grid_forming_inverter_impedance(pm, i)
        # constraint_mc_grid_forming_inverter(pm, i)
    end
end


"""
	solve_mc_dg_pf(data::Dict{String,<:Any}, solver; kwargs...)

Run Power Flow Problem with DG
"""
function solve_mc_dg_pf(data::Dict{String,<:Any}, solver; kwargs...)
    return _PMD.solve_mc_model(data, _PMD.ACPUPowerModel, solver, build_mc_dg_pf; kwargs...)
end

"""
	solve_mc_dg_pf(file::String, solver; kwargs...)

Run Power Flow Problem with DG
"""
function solve_mc_dg_pf(file::String, solver; kwargs...)
    return solve_mc_dg_pf(parse_file(file; import_all=true), solver; kwargs...)
end

"""
	build_mc_dg_pf(pm::_PMD.AbstractUnbalancedPowerModel)

Constructor for Power Flow Problem with DG
"""
function build_mc_dg_pf(pm::_PMD.AbstractUnbalancedPowerModel)
    _PMD.variable_mc_bus_voltage(pm; bounded=false)
    _PMD.variable_mc_branch_power(pm; bounded=false)
    # _PMD.variable_mc_branch_current(pm; bounded=false)
    _PMD.variable_mc_transformer_power(pm; bounded=false)
    # _PMD.variable_mc_transformer_current(pm; bounded=false)
    _PMD.variable_mc_generator_current(pm; bounded=false)
    _PMD.variable_mc_load_current(pm; bounded=false)
    # _PMD.variable_mc_storage_power(pm; bounded=false)

    _PMD.constraint_mc_model_voltage(pm)

    for (i, bus) in _PMD.ref(pm, :ref_buses)
        @assert bus["bus_type"] == 3

        _PMD.constraint_mc_theta_ref(pm, i)
        _PMD.constraint_mc_voltage_magnitude_only(pm, i)
    end

    # gens should be constrained before KCL, or Pd/Qd undefined
    for id in _PMD.ids(pm, :gen)
        _PMD.constraint_mc_generator_power(pm, id)
    end

    # loads should be constrained before KCL, or Pd/Qd undefined
    for id in _PMD.ids(pm, :load)
        _PMD.constraint_mc_load_power(pm, id)
    end

    for (i, bus) in _PMD.ref(pm, :bus)
        _PMD.constraint_mc_current_balance(pm, i)
        # _PMD.constraint_mc_load_current_balance(pm, i)


        # PV Bus Constraints
        if length(_PMD.ref(pm, :bus_gens, i)) > 0 && !(i in _PMD.ids(pm, :ref_buses))
            # this assumes inactive generators are filtered out of bus_gens

            for j in _PMD.ref(pm, :bus_gens, i)
                _PMD.constraint_mc_gen_power_setpoint_real(pm, j)
                constraint_mc_gen_power_setpoint_imag(pm, j)
            end
        end
    end

    # for i in ids(pm, :storage)
    #     _PM.constraint_storage_state(pm, i)
    #     _PM.constraint_storage_complementarity_nl(pm, i)
    #     _PMD.constraint_mc_storage_losses(pm, i)
    #     _PMD.constraint_mc_storage_thermal_limit(pm, i)
    # end

    for i in _PMD.ids(pm, :branch)
        _PMD.constraint_mc_ohms_yt_from(pm, i)
        _PMD.constraint_mc_ohms_yt_to(pm, i)
        # _PMD.constraint_mc_current_from(pm, i)
        # _PMD.constraint_mc_current_to(pm, i)
        # _PMD.constraint_mc_bus_voltage_drop(pm, i)
    end

    for i in _PMD.ids(pm, :transformer)
        _PMD.constraint_mc_transformer_power(pm, i)
    end
end


function compute_mc_pf(model::AdmittanceModel)
    y = model.y
    i = model.i
    v = model.v
    delta_i_control = model.delta_i_control
    delta_i = model.delta_i
    max_it = 2
    it_pf = 0
    _i = i + delta_i_control + delta_i
    _v = deepcopy(v)
    last_v = deepcopy(v)
    while it_pf != max_it
        _v = y \ _i
        if maximum((abs.(_v - last_v))) < 0.0001
            break
        else
            _delta_i_control = update_mc_delta_current_control_vector(model, _v)
            it_control = 0
            _i = i + _delta_i_control + delta_i
            while it_control != max_it
                __v = y \ _i
                if maximum((abs.(__v - _v))) < 0.0001
                    _v = __v
                    break
                else
                    _delta_i_control = update_mc_delta_current_control_vector(model, __v)
                    _i = i + _delta_i_control + delta_i
                    _v = __v
                    it_control += 1
                end
            end
            delta_i = update_mc_delta_current_vector(model, _v)
            _i = i + _delta_i_control + delta_i
            last_v = _v
            it_pf += 1
        end
    end
    return solution_mc_pf(_v, it_pf, maximum((abs.(_v - last_v))), i + delta_i_control + delta_i, model)
end


function compute_mc_pf(y, model::AdmittanceModel)
    y = _SP.sparse(y)
    i = model.i
    v = model.v
    delta_i_control = model.delta_i_control
    delta_i = model.delta_i
    max_it = 10
    it_pf = 0
    _i = i + delta_i_control + delta_i
    _v = deepcopy(v)
    last_v = deepcopy(v)
    while it_pf != max_it
        _v = y \ _i
        if maximum((abs.(_v - last_v))) < 0.0001
            break
        else
            _delta_i_control = update_mc_delta_current_control_vector(model, _v)
            it_control = 0
            _i = i + _delta_i_control + delta_i
            while it_control != max_it
                __v = y \ _i
                if maximum((abs.(__v - _v))) < 0.0001
                    _v = __v
                    break
                else
                    _delta_i_control = update_mc_delta_current_control_vector(model, __v)
                    _i = i + _delta_i_control + delta_i
                    _v = __v
                    it_control += 1
                end
            end
            delta_i = update_mc_delta_current_vector(model, _v)
            _i = i + _delta_i_control + delta_i
            last_v = _v
            it_pf += 1
        end
    end
    return _v
end

