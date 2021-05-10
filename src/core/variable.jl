"Copies from PowerModels and PowerModelsDistribution without power vars"
function variable_branch_current(pm::_PM.AbstractIVRModel; nw::Int=nw_id_default, bounded::Bool=true, report::Bool=true, kwargs...)
    _PM.variable_branch_current_real(pm, nw=nw, bounded=bounded, report=report; kwargs...)
    _PM.variable_branch_current_imaginary(pm, nw=nw, bounded=bounded, report=report; kwargs...)

    _PM.variable_branch_series_current_real(pm, nw=nw, bounded=bounded, report=report; kwargs...)
    _PM.variable_branch_series_current_imaginary(pm, nw=nw, bounded=bounded, report=report; kwargs...)
end


""
function variable_gen(pm::_PM.AbstractIVRModel; nw::Int=nw_id_default, bounded::Bool=true, report::Bool=true, kwargs...)
    _PM.variable_gen_current_real(pm, nw=nw, bounded=bounded, report=report; kwargs...)
    _PM.variable_gen_current_imaginary(pm, nw=nw, bounded=bounded, report=report; kwargs...)
    variable_gen_loading(pm, nw=nw, bounded=bounded, report=report; kwargs...)


    # store active and reactive power expressions for use in objective + post processing
    pg = Dict()
    qg = Dict()

    for (i, gen) in _PM.ref(pm, nw, :gen)
        busid = gen["gen_bus"]
        smax = abs(max(abs(gen["pmax"]), abs(gen["pmin"])) + max(abs(gen["qmax"]), abs(gen["qmin"])) * 1im)
        cmax = 1.1 * smax

        vr = _PM.var(pm, nw, :vr, busid)
        vi = _PM.var(pm, nw, :vi, busid)
        crg = _PM.var(pm, nw, :crg, i)
        cig = _PM.var(pm, nw, :cig, i)

        if gen["inverter"] == 1 && gen["inverter_mode"] == "pq"
            JuMP.set_lower_bound(crg, -cmax)
            JuMP.set_upper_bound(crg, cmax)
            JuMP.set_lower_bound(cig, -cmax)
            JuMP.set_upper_bound(cig, cmax)
        end

        pg[i] = JuMP.@NLexpression(pm.model, vr * crg  + vi * cig)
        qg[i] = JuMP.@NLexpression(pm.model, vi * crg  - vr * cig)
    end

    _PM.var(pm, nw)[:pg] = pg
    _PM.var(pm, nw)[:qg] = qg
    report && _IM.sol_component_value(pm, _PM.pm_it_sym, nw, :gen, :pg, _PM.ids(pm, nw, :gen), pg)
    report && _IM.sol_component_value(pm, _PM.pm_it_sym, nw, :gen, :qg, _PM.ids(pm, nw, :gen), qg)

    if bounded
        for (i, gen) in _PM.ref(pm, nw, :gen)
            _PM.constraint_gen_active_bounds(pm, i, nw=nw)
            _PM.constraint_gen_reactive_bounds(pm, i, nw=nw)
        end
    end
end


"variable: `pg[j]` for `j` in `gen`"
function variable_gen_loading(pm::_PM.AbstractIVRModel; nw::Int=nw_id_default, bounded::Bool=true, report::Bool=true)
    kg = _PM.var(pm, nw)[:kg] = JuMP.@variable(pm.model,
        [i in _PM.ids(pm, nw, :gen)], base_name = "$(nw)_kg",
        start = _PM.comp_start_value(_PM.ref(pm, nw, :gen, i), "kg_start")
    )

    for (i, gen) in _PM.ref(pm, nw, :gen)
        kmax = max(1.1 / gen["pg"], 2)
        JuMP.set_lower_bound(kg[i], 0)
        JuMP.set_upper_bound(kg[i], kmax)
    end

    report && _IM.sol_component_value(pm, _PM.pm_it_sym, nw, :gen, :kg, _PM.ids(pm, nw, :gen), kg)
end


""
function variable_mc_branch_current(pm::_PMD.AbstractUnbalancedIVRModel; nw::Int=nw_id_default, bounded::Bool=true, report::Bool=true, kwargs...)
    _PMD.variable_mc_branch_current_real(pm, nw=nw, bounded=bounded, report=report; kwargs...)
    _PMD.variable_mc_branch_current_imaginary(pm, nw=nw, bounded=bounded, report=report; kwargs...)

    _PMD.variable_mc_branch_current_series_real(pm, nw=nw, bounded=bounded, report=report; kwargs...)
    _PMD.variable_mc_branch_current_series_imaginary(pm, nw=nw, bounded=bounded, report=report; kwargs...)
end


""
function variable_mc_transformer_current(pm::_PMD.AbstractUnbalancedIVRModel; nw::Int=nw_id_default, bounded::Bool=true, report::Bool=true, kwargs...)
    _PMD.variable_mc_transformer_current_real(pm, nw=nw, bounded=bounded, report=report; kwargs...)
    _PMD.variable_mc_transformer_current_imaginary(pm, nw=nw, bounded=bounded, report=report; kwargs...)
end


""
function variable_mc_generation(pm::_PMD.AbstractUnbalancedIVRModel; nw::Int=nw_id_default, bounded::Bool=true, report::Bool=true, kwargs...)
    _PMD.variable_mc_generator_current_real(pm, nw=nw, bounded=bounded, report=report; kwargs...)
    _PMD.variable_mc_generator_current_imaginary(pm, nw=nw, bounded=bounded, report=report; kwargs...)
    _PMD.var(pm, nw)[:crg_bus] = Dict{Int,Any}()
    _PMD.var(pm, nw)[:cig_bus] = Dict{Int,Any}()

    # TODO need to test DER with power as decision variable
    # _PM.var(pm, nw)[:pg] = Dict{Int, Any}()
    # _PM.var(pm, nw)[:qg] = Dict{Int, Any}()
end


""
function pq_gen_ids(pm, nw)
    return [i for (i, gen) in _PM.ref(pm, nw, :gen) if gen["inverter_mode"] == "pq"]
end


""
function pq_gen_vals(pm, nw)
    return [gen for (i, gen) in _PM.ref(pm, nw, :gen) if gen["inverter_mode"] == "pq"]
end


""
function pq_gen_refs(pm, nw)
    return [(i, gen) for (i, gen) in _PM.ref(pm, nw, :gen) if gen["inverter_mode"] == "pq"]
end


""
function variable_pq_inverter(pm::_PM.AbstractIVRModel; nw::Int=nw_id_default, bounded::Bool=true, kwargs...)
    p_int = _PM.var(pm, nw)[:p_int] = JuMP.@variable(pm.model,
        [i in pq_gen_ids(pm, nw)], base_name = "$(nw)_p_int_$(i)",
        start = 0
    )

    for (i, gen) in pq_gen_refs(pm, nw)
        JuMP.set_lower_bound(p_int[i], 0.0)
        JuMP.set_upper_bound(p_int[i], gen["pmax"])
    end

    q_int = _PM.var(pm, nw)[:q_int] = JuMP.@variable(pm.model,
        [i in pq_gen_ids(pm, nw)], base_name = "$(nw)_q_int_$(i)",
        start = 0
    )

    for (i, gen) in pq_gen_refs(pm, nw)
        JuMP.set_lower_bound(q_int[i], gen["qmin"])
        JuMP.set_upper_bound(q_int[i], gen["qmax"])
    end


    crg_pos_max = _PM.var(pm, nw)[:crg_max] = JuMP.@variable(pm.model,
        [i in pq_gen_ids(pm, nw)], base_name = "$(nw)_crg_pos_max_$(i)",
        start = 0.0
    )
    cig_pos_max = _PM.var(pm, nw)[:cig_max] = JuMP.@variable(pm.model,
        [i in pq_gen_ids(pm, nw)], base_name = "$(nw)_cig_pos_max_$(i)",
        start = 0.0
    )

    z = _PM.var(pm, nw)[:z] = JuMP.@variable(pm.model,
        [i in pq_gen_ids(pm, nw)], base_name = "$(nw)_z_$(i)",
        start = 0.0
    )
    for i in pq_gen_ids(pm, nw)
        JuMP.set_lower_bound(z[i], 0.0)
        JuMP.set_upper_bound(z[i], 1.0)
    end
end


""
function variable_mc_pq_inverter(pm::_PMD.AbstractUnbalancedIVRModel; nw::Int=nw_id_default, bounded::Bool=true, kwargs...)
    p_int = _PMD.var(pm, nw)[:p_int] = JuMP.@variable(pm.model,
        [i in _PMD.ids(pm, nw, :solar_gfli)], base_name = "$(nw)_p_int_$(i)",
        start = 0
    )
    for i in _PMD.ids(pm, nw, :solar_gfli)
        gen = pm.ref[:it][_PMD.pmd_it_sym][:nw][nw][:gen][i]
        pmax = 0.0
        if gen["solar_max"] < gen["kva"] * gen["pf"]
            pmax = gen["solar_max"]
        else
            pmax = gen["kva"] * gen["pf"]
        end
        JuMP.set_lower_bound(p_int[i], 0.0)
        JuMP.set_upper_bound(p_int[i], pmax / 3)
    end

    q_int = _PMD.var(pm, nw)[:q_int] = JuMP.@variable(pm.model,
        [i in _PMD.ids(pm, nw, :solar_gfli)], base_name = "$(nw)_q_int_$(i)",
        start = 0
    )
    for i in _PMD.ids(pm, nw, :solar_gfli)
        gen = pm.ref[:it][_PMD.pmd_it_sym][:nw][nw][:gen][i]
        pmax = 0.0
        if gen["solar_max"] < gen["kva"] * gen["pf"]
            pmax = gen["solar_max"]
        else
            pmax = gen["kva"] * gen["pf"]
        end
        JuMP.set_lower_bound(q_int[i], 0.0)
        JuMP.set_upper_bound(q_int[i], pmax / 3)
    end

    crg_pos = _PMD.var(pm, nw)[:crg_pos] = JuMP.@variable(pm.model,
        [i in _PMD.ids(pm, nw, :solar_gfli)], base_name = "$(nw)_crg_pos_$(i)",
        start = 0.0
    )
    cig_pos = _PMD.var(pm, nw)[:cig_pos] = JuMP.@variable(pm.model,
        [i in _PMD.ids(pm,nw, :solar_gfli)], base_name = "$(nw)_cig_pos_$(i)",
        start = 0.0
    )

    vrg_pos = _PMD.var(pm, nw)[:vrg_pos] = JuMP.@variable(pm.model,
        [i in _PMD.ids(pm, nw, :solar_gfli)], base_name = "$(nw)_vrg_pos_$(i)",
        start = 0.0
    )
    vig_pos = _PMD.var(pm, nw)[:vig_pos] = JuMP.@variable(pm.model,
        [i in _PMD.ids(pm, nw, :solar_gfli)], base_name = "$(nw)_vig_pos_$(i)",
        start = 0.0
    )

    crg_pos_max = _PMD.var(pm, nw)[:crg_pos_max] = JuMP.@variable(pm.model,
        [i in _PMD.ids(pm, nw, :solar_gfli)], base_name = "$(nw)_crg_pos_max_$(i)",
        start = 0.0
    )
    cig_pos_max = _PMD.var(pm, nw)[:cig_pos_max] = JuMP.@variable(pm.model,
        [i in _PMD.ids(pm, nw, :solar_gfli)], base_name = "$(nw)_cig_pos_max_$(i)",
        start = 0.0
    )

    z = _PMD.var(pm, nw)[:z_gfli] = JuMP.@variable(pm.model,
        [i in _PMD.ids(pm, nw, :solar_gfli)], base_name = "$(nw)_z_gfli_$(i)",
        start = 0.0
    )

    for i in _PMD.ids(pm, nw, :solar_gfli)
        JuMP.set_lower_bound(z[i], 0.0)
        JuMP.set_upper_bound(z[i], 1.0)
    end
end


""
function variable_mc_grid_formimg_inverter(pm::_PMD.AbstractUnbalancedIVRModel; nw::Int=nw_id_default, bounded::Bool=true, kwargs...)
    terminals = Dict(gfmi => _PMD.ref(pm, nw, :bus, bus)["terminals"] for (gfmi,bus) in _PMD.ref(pm, nw, :solar_gfmi))

    # inverter setpoints for virtual impedance formulation
    # taking into account virtual impedance voltage drop
    _PMD.var(pm, nw)[:vrsp] = Dict(i => JuMP.@variable(pm.model,
               [c in terminals[i]], base_name = "$(nw)_vrsp_$(i)",
               start = 0.0,
        ) for i in _PMD.ids(pm, nw, :solar_gfmi)
    )

    _PMD.var(pm, nw)[:visp] = Dict(i => JuMP.@variable(pm.model,
    [c in terminals[i]], base_name = "$(nw)_visp_$(i)",
               start = 0.0,
        ) for i in _PMD.ids(pm, nw, :solar_gfmi)
    )

    _PMD.var(pm, nw)[:z] = Dict(i => JuMP.@variable(pm.model,
               [c in terminals[i]], base_name = "$(nw)_z_$(i)",
               start = 0.0,
               lower_bound = 0.0,
               upper_bound = 1.0
        ) for i in _PMD.ids(pm, nw, :solar_gfmi)
    )

    _PMD.var(pm, nw)[:z2] = Dict(i => JuMP.@variable(pm.model,
               [c in terminals[i]], base_name = "$(nw)_z2_$(i)",
               start = 0.0,
               lower_bound = 0.0,
               upper_bound = 1.0
        ) for i in _PMD.ids(pm, nw, :solar_gfmi)
    )

    _PMD.var(pm, nw)[:z3] = Dict(i => JuMP.@variable(pm.model,
               [c in terminals[i]], base_name = "$(nw)_z3_$(i)",
               start = 0.0,
               lower_bound = 0.0,
               upper_bound = 1.0
        ) for i in _PMD.ids(pm, nw, :solar_gfmi)
    )

    p = _PMD.var(pm, nw)[:p_solar] = JuMP.@variable(pm.model,
        [i in _PMD.ids(pm, nw, :solar_gfmi)], base_name = "$(nw)_p_solar_$(i)",
        start = 0
    )

    q = _PMD.var(pm, nw)[:q_solar] = JuMP.@variable(pm.model,
        [i in _PMD.ids(pm, nw, :solar_gfmi)], base_name = "$(nw)_q_solar_$(i)",
        start = 0
    )

    _PMD.var(pm, nw)[:rv] = Dict(i => JuMP.@variable(pm.model,
               [c in terminals[i]], base_name = "$(nw)_rv_$(i)",
               start = 0.0,
        ) for i in _PMD.ids(pm, nw, :solar_gfmi)
    )

    _PMD.var(pm, nw)[:xv] = Dict(i => JuMP.@variable(pm.model,
               [c in terminals[i]], base_name = "$(nw)_xv_$(i)",
               start = 0.0,
        ) for i in _PMD.ids(pm, nw, :solar_gfmi)
    )

end
