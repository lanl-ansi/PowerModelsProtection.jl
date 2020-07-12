"copies from PowerModels and PowerModelsDistribution without power vars"
function variable_branch_current(pm::_PM.AbstractIVRModel; nw::Int=pm.cnw, bounded::Bool=true, report::Bool=true, kwargs...)
    _PM.variable_branch_current_real(pm, nw=nw, bounded=bounded, report=report; kwargs...)
    _PM.variable_branch_current_imaginary(pm, nw=nw, bounded=bounded, report=report; kwargs...)

    _PM.variable_branch_series_current_real(pm, nw=nw, bounded=bounded, report=report; kwargs...)
    _PM.variable_branch_series_current_imaginary(pm, nw=nw, bounded=bounded, report=report; kwargs...)
end


""
function variable_gen(pm::_PM.AbstractIVRModel; nw::Int=pm.cnw, bounded::Bool=true, report::Bool=true, kwargs...)
    _PM.variable_gen_current_real(pm, nw=nw, bounded=bounded, report=report; kwargs...)
    _PM.variable_gen_current_imaginary(pm, nw=nw, bounded=bounded, report=report; kwargs...)
    variable_gen_loading(pm, nw=nw, report=report; kwargs...)


    # store active and reactive power expressions for use in objective + post processing
    pg = Dict()
    qg = Dict()

    for (i,gen) in ref(pm, nw, :gen)
        busid = gen["gen_bus"]
        vr = var(pm, nw, :vr, busid)
        vi = var(pm, nw, :vi, busid)
        crg = var(pm, nw, :crg, i)
        cig = var(pm, nw, :cig, i)
        pg[i] = JuMP.@NLexpression(pm.model, vr*crg  + vi*cig)
        qg[i] = JuMP.@NLexpression(pm.model, vi*crg  - vr*cig)
    end

    var(pm, nw)[:pg] = pg
    var(pm, nw)[:qg] = qg
    report && _PM.sol_component_value(pm, nw, :gen, :pg, ids(pm, nw, :gen), pg)
    report && _PM.sol_component_value(pm, nw, :gen, :qg, ids(pm, nw, :gen), qg)

    if bounded
        for (i,gen) in ref(pm, nw, :gen)
            _PM.constraint_gen_active_power_limits(pm, i, nw=nw)
            _PM.constraint_gen_reactive_power_limits(pm, i, nw=nw)
        end
    end
end


"variable: `pg[j]` for `j` in `gen`"
function variable_gen_loading(pm::_PM.AbstractIVRModel; nw::Int=pm.cnw, bounded::Bool=true, report::Bool=true)
    kg = var(pm, nw)[:kg] = JuMP.@variable(pm.model,
        [i in ids(pm, nw, :gen)], base_name="$(nw)_kg",
        start = _PM.comp_start_value(ref(pm, nw, :gen, i), "kg_start")
    )

    for (i, gen) in ref(pm, nw, :gen)
        JuMP.set_lower_bound(kg[i], 0)
        JuMP.set_upper_bound(kg[i], 1)
    end

    report && _PM.sol_component_value(pm, nw, :gen, :kg, ids(pm, nw, :gen), kg)
end


""
function variable_mc_branch_current(pm::_PM.AbstractIVRModel; nw::Int=pm.cnw, bounded::Bool=true, report::Bool=true, kwargs...)
    _PMD.variable_mc_branch_current_real(pm, nw=nw, bounded=bounded, report=report; kwargs...)
    _PMD.variable_mc_branch_current_imaginary(pm, nw=nw, bounded=bounded, report=report; kwargs...)

    _PMD.variable_mc_branch_current_series_real(pm, nw=nw, bounded=bounded, report=report; kwargs...)
    _PMD.variable_mc_branch_current_series_imaginary(pm, nw=nw, bounded=bounded, report=report; kwargs...)
end


""
function variable_mc_transformer_current(pm::_PM.AbstractIVRModel; nw::Int=pm.cnw, bounded::Bool=true, report::Bool=true, kwargs...)
    _PMD.variable_mc_transformer_current_real(pm, nw=nw, bounded=bounded, report=report; kwargs...)
    _PMD.variable_mc_transformer_current_imaginary(pm, nw=nw, bounded=bounded, report=report; kwargs...)
end


""
function variable_mc_generation(pm::_PM.AbstractIVRModel; nw::Int=pm.cnw, bounded::Bool=true, report::Bool=true, kwargs...)
    _PMD.variable_mc_gen_current_setpoint_real(pm, nw=nw, bounded=bounded, report=report; kwargs...)
    _PMD.variable_mc_gen_current_setpoint_imaginary(pm, nw=nw, bounded=bounded, report=report; kwargs...)
    _PM.var(pm, nw)[:crg_bus] = Dict{Int, Any}()
    _PM.var(pm, nw)[:cig_bus] = Dict{Int, Any}()
    # _PM.var(pm, nw)[:pg] = Dict{Int, Any}()
    # _PM.var(pm, nw)[:qg] = Dict{Int, Any}()
end



function variable_mc_pq_inverter(pm::_PM.AbstractIVRModel; nw::Int=pm.cnw, bounded::Bool=true, kwargs...)
    p_int = var(pm, nw)[:p_int] = JuMP.@variable(pm.model,
        [i in ids(pm, nw, :solar)], base_name="$(nw)_p_int_$(i)",
        start = 0
    )
    for i in ids(pm, nw, :solar)
        index = pm.ref[:nw][nw][:solar][i]
        gen = pm.ref[:nw][nw][:gen][index]
        pmax = 0.0
        if gen["solar_max"] < gen["kva"] * gen["pf"]
            pmax = gen["solar_max"]
        else
            pmax = gen["kva"] * gen["pf"]
        end
        JuMP.set_lower_bound(p_int[i], 0.0)
        JuMP.set_upper_bound(p_int[i], pmax/3)
    end

    q_int = var(pm, nw)[:q_int] = JuMP.@variable(pm.model,
        [i in ids(pm, nw, :solar)], base_name="$(nw)_q_int_$(i)",
        start = 0
    )
    for i in ids(pm, nw, :solar)
        index = pm.ref[:nw][nw][:solar][i]
        gen = pm.ref[:nw][nw][:gen][index]
        pmax = 0.0
        if gen["solar_max"] < gen["kva"] * gen["pf"]
            pmax = gen["solar_max"]
        else
            pmax = gen["kva"] * gen["pf"]
        end
        JuMP.set_lower_bound(q_int[i], 0.0)
        JuMP.set_upper_bound(q_int[i], pmax/3)
    end

    crg_pos= var(pm, nw)[:crg_pos] = JuMP.@variable(pm.model,
        [i in ids(pm, nw, :solar)], base_name="$(nw)_crg_pos_$(i)",
        start = 0.0
    )
    cig_pos = var(pm, nw)[:cig_pos] = JuMP.@variable(pm.model,
        [i in ids(pm, nw, :solar)], base_name="$(nw)_cig_pos_$(i)",
        start = 0.0
    )  

    vrg_pos= var(pm, nw)[:vrg_pos] = JuMP.@variable(pm.model,
        [i in ids(pm, nw, :solar)], base_name="$(nw)_vrg_pos_$(i)",
        start = 0.0
    )
    vig_pos = var(pm, nw)[:vig_pos] = JuMP.@variable(pm.model,
        [i in ids(pm, nw, :solar)], base_name="$(nw)_vig_pos_$(i)",
        start = 0.0
    ) 

    crg_pos_max= var(pm, nw)[:crg_pos_max] = JuMP.@variable(pm.model,
        [i in ids(pm, nw, :solar)], base_name="$(nw)_crg_pos_max_$(i)",
        start = 0.0
    )
    cig_pos_max = var(pm, nw)[:cig_pos_max] = JuMP.@variable(pm.model,
        [i in ids(pm, nw, :solar)], base_name="$(nw)_cig_pos_max_$(i)",
        start = 0.0
    )

    z= var(pm, nw)[:z] = JuMP.@variable(pm.model,
        [i in ids(pm, nw, :solar)], base_name="$(nw)_z_$(i)",
        start = 0.0
    )
    for i in ids(pm, nw, :solar)
        JuMP.set_lower_bound(z[i], 0.0)
        JuMP.set_upper_bound(z[i], 1.0)
    end
end



