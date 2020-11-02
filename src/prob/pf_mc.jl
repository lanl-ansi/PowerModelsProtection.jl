
"Rm pf on the mc model"
function run_mc_pf(data::Dict{String,Any}, solver; kwargs...)
    solution = _PM.run_model(data, _PM.IVRPowerModel, solver, build_mc_pf; ref_extensions=[ref_add_fault!], kwargs...)
    return solution
end


"Run pf on file"
function run_fault_study(file::String, solver; kwargs...)
    return run_mc_pf(parse_file(file), solver; kwargs...)
end


"Build mc pf"
function build_mc_pf(pm::_PM.AbstractPowerModel)
    _PM.variable_bus_voltage(pm, bounded = true)
    variable_branch_current(pm, bounded = false)
    variable_gen(pm, bounded = false) # inverter currents are always bounded
    variable_pq_inverter(pm)

    has_pq_gens = false
    has_v_gens = false

    for (n, nw_ref) in nws(pm)
        for (i,gen) in nw_ref[:gen]
            if gen["inverter_mode"] == "pq"
                has_pq_gens = true
            end

            if gen["inverter_mode"] == "v"
                has_v_gens = true
            end
        end
    end

    if has_pq_gens && !has_v_gens
        objective_max_inverter_power(pm)
    elseif !has_pq_gens && has_v_gens
        objective_min_inverter_voltage_regulation(pm)
    elseif has_pq_gens && has_v_gens
        objective_min_inverter_error(pm)
    end

    constraint_gen_voltage_drop(pm)
    constraint_pq_inverter(pm)
    constraint_v_inverter(pm)

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
