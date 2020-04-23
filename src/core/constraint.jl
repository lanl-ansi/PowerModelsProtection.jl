"states that the bus voltage is equal to the internal voltage minus voltage drop across subtransient impedance"
function constraint_gen_voltage_drop(pm::_PM.AbstractIVRModel, n::Int, i, bus_id, r, x, vgr, vgi)
    vr_to = var(pm, n, :vr, bus_id)
    vi_to = var(pm, n, :vi, bus_id)

    crg =  var(pm, n, :crg, i)
    cig =  var(pm, n, :cig, i)

    JuMP.@constraint(pm.model, vr_to == vgr - r * crg + x * cig)
    JuMP.@constraint(pm.model, vi_to == vgi - r * cig - x * crg)
end


""
function constraint_pq_inverter(pm::_PM.AbstractIVRModel, n::Int, i, bus_id, pg0, qg0, cmax)
    vr = var(pm, n, :vr, bus_id)
    vi = var(pm, n, :vi, bus_id)

    crg =  var(pm, n, :crg, i)
    cig =  var(pm, n, :cig, i)

    kg = var(pm, n, :kg, i) # generator loading
    
    JuMP.@NLconstraint(pm.model, kg*pg0 == vr*crg - vi*cig)
    JuMP.@NLconstraint(pm.model, kg*qg0 == vi*crg + vr*cig)
    #JuMP.@NLconstraint(pm.model, cmax^2 >= crg^2 + cig^2) 
    JuMP.@NLconstraint(pm.model, cmax^2 >= crg^2 + cig^2) 
end

"McCormick relaxation of inverter in PQ mode"
function constraint_pq_inverter_mccormick(pm::_PM.AbstractIVRModel, n::Int, i, bus_id, pg, qg)
    vrg = var(pm, n, :vr, bus_id)
    vig = var(pm, n, :vi, bus_id)

    crg =  var(pm, n, :crg, i)
    cig =  var(pm, n, :cig, i)

    pg1 =  var(pm, n, :pg1, i)
    pg2 =  var(pm, n, :pg2, i)
    qg1 =  var(pm, n, :qg1, i)
    qg2 =  var(pm, n, :qg2, i)

    InfrastructureModels.relaxation_product(pm.model, vrg, crg, pg1)
    InfrastructureModels.relaxation_product(pm.model, vig, cig, pg2)
    InfrastructureModels.relaxation_product(pm.model, vrg, cig, qg1)
    InfrastructureModels.relaxation_product(pm.model, vig, crg, qg2)
    JuMP.@constraint(pm.model, kg*pg == pg1 - pg2)
    JuMP.@constraint(pm.model, kg*qg == qg1 + qg2)
end



""
function constraint_fault_current(pm::_PM.AbstractPowerModel; nw::Int=pm.cnw)
    bus = ref(pm, nw, :active_fault, "bus_i")
    g = ref(pm, nw, :active_fault, "gf")
    vr = var(pm, nw, :vr, bus)
    vi = var(pm, nw, :vi, bus)

    var(pm, nw)[:cfr] = JuMP.@variable(pm.model,
        [bus], base_name="$(nw)_cfr",
        start = 0
    )
    var(pm, nw)[:cfi] = JuMP.@variable(pm.model,
        [bus], base_name="$(nw)_cfi",
        start = 0
    )

    cr = var(pm, nw, :cfr, bus)
    ci = var(pm, nw, :cfi, bus)
    JuMP.@constraint(pm.model, g * vr == cr)
    JuMP.@constraint(pm.model, g * vi == ci)
end


""
function constraint_current_balance(pm::_PM.AbstractIVRModel, n::Int, i, bus_arcs, bus_gens, bus_gs, bus_bs)
    vr = var(pm, n, :vr, i)
    vi = var(pm, n, :vi, i)

    cr =  var(pm, n, :cr)
    ci =  var(pm, n, :ci)

    crg =  var(pm, n, :crg)
    cig =  var(pm, n, :cig)

    JuMP.@NLconstraint(pm.model, sum(cr[a] for a in bus_arcs)
                                ==
                                sum(crg[g] for g in bus_gens)
                                - sum(gs for gs in values(bus_gs))*vr + sum(bs for bs in values(bus_bs))*vi
                                )
    JuMP.@NLconstraint(pm.model, sum(ci[a] for a in bus_arcs)
                                ==
                                sum(cig[g] for g in bus_gens)
                                - sum(gs for gs in values(bus_gs))*vi - sum(bs for bs in values(bus_bs))*vr
                                )
end


""
function constraint_fault_current_balance(pm::_PM.AbstractIVRModel, n::Int, i, bus_arcs, bus_gens, bus_gs, bus_bs, bus)
    vr = var(pm, n, :vr, i)
    vi = var(pm, n, :vi, i)

    cr =  var(pm, n, :cr)
    ci =  var(pm, n, :ci)

    crg =  var(pm, n, :crg)
    cig =  var(pm, n, :cig)

    cfr = var(pm, n, :cfr, bus)
    cfi = var(pm, n, :cfi, bus)

    JuMP.@NLconstraint(pm.model, sum(cr[a] for a in bus_arcs)
                                ==
                                sum(crg[g] for g in bus_gens)
                                - sum(gs for gs in values(bus_gs))*vr + sum(bs for bs in values(bus_bs))*vi
                                - cfr
                                )
    JuMP.@NLconstraint(pm.model, sum(ci[a] for a in bus_arcs)
                                ==
                                sum(cig[g] for g in bus_gens)
                                - sum(gs for gs in values(bus_gs))*vi - sum(bs for bs in values(bus_bs))*vr
                                - cfi
                                )
end


""
function constraint_mc_gen_voltage_drop(pm::_PM.AbstractIVRModel, n::Int, i, bus_id, r, x, vgr, vgi)
    vr_to = var(pm, n, :vr, bus_id)
    vi_to = var(pm, n, :vi, bus_id)

    crg =  var(pm, n, :crg, i)
    cig =  var(pm, n, :cig, i)

    for c in _PM.conductor_ids(pm; nw=n)
        JuMP.@constraint(pm.model, vr_to[c] == vgr[c] - r[c]*crg[c] + x[c]*cig[c])
        JuMP.@constraint(pm.model, vi_to[c] == vgi[c] - r[c]*cig[c] - x[c]*crg[c])
    end
end


""
function constraint_mc_fault_current(pm::_PM.AbstractPowerModel; nw::Int=pm.cnw)
    bus = ref(pm, nw, :active_fault, "bus_i")
    Gf = ref(pm, nw, :active_fault, "Gf")

    vr = var(pm, nw, :vr, bus)
    vi = var(pm, nw, :vi, bus)

    var(pm, nw)[:cfr] = JuMP.@variable(pm.model,
        [c in _PM.conductor_ids(pm; nw=nw)], base_name="$(nw)_cfr",
        start = 0
    )

    var(pm, nw)[:cfi] = JuMP.@variable(pm.model,
        [c in _PM.conductor_ids(pm; nw=nw)], base_name="$(nw)_cfi",
        start = 0
    )

    cr = var(pm, nw, :cfr)
    ci = var(pm, nw, :cfi)

    cnds = _PM.conductor_ids(pm; nw=nw)

    for c in _PM.conductor_ids(pm; nw=nw)
        JuMP.@constraint(pm.model, cr[c] == sum(Gf[c,d]*vr[d] for d in cnds))
        JuMP.@constraint(pm.model, ci[c] == sum(Gf[c,d]*vi[d] for d in cnds))
    end
end


""
function constraint_mc_current_balance(pm::_PM.AbstractIVRModel, n::Int, i, bus_arcs, bus_arcs_sw, bus_arcs_trans, bus_gens, bus_gs, bus_bs)
    vr = var(pm, n, :vr, i)
    vi = var(pm, n, :vi, i)

    # TODO: add storage back with inverter fault model
    cr    = get(var(pm, n),    :cr, Dict()); _PM._check_var_keys(cr, bus_arcs, "real current", "branch")
    ci    = get(var(pm, n),    :ci, Dict()); _PM._check_var_keys(ci, bus_arcs, "imaginary current", "branch")
    crg   = get(var(pm, n),   :crg_bus, Dict()); _PM._check_var_keys(crg, bus_gens, "real current", "generator")
    cig   = get(var(pm, n),   :cig_bus, Dict()); _PM._check_var_keys(cig, bus_gens, "imaginary current", "generator")
    crsw  = get(var(pm, n),  :crsw, Dict()); _PM._check_var_keys(crsw, bus_arcs_sw, "real current", "switch")
    cisw  = get(var(pm, n),  :cisw, Dict()); _PM._check_var_keys(cisw, bus_arcs_sw, "imaginary current", "switch")
    crt   = get(var(pm, n),   :crt, Dict()); _PM._check_var_keys(crt, bus_arcs_trans, "real current", "transformer")
    cit   = get(var(pm, n),   :cit, Dict()); _PM._check_var_keys(cit, bus_arcs_trans, "imaginary current", "transformer")

    cnds = _PM.conductor_ids(pm; nw=n)
    ncnds = length(cnds)

    Gt = isempty(bus_bs) ? fill(0.0, ncnds, ncnds) : sum(values(bus_gs))
    Bt = isempty(bus_bs) ? fill(0.0, ncnds, ncnds) : sum(values(bus_bs))

    for c in cnds
        JuMP.@NLconstraint(pm.model,  sum(cr[a][c] for a in bus_arcs)
                                    + sum(crsw[a_sw][c] for a_sw in bus_arcs_sw)
                                    + sum(crt[a_trans][c] for a_trans in bus_arcs_trans)
                                    ==
                                    sum(crg[g][c]        for g in bus_gens)
                                    - sum( Gt[c,d]*vr[d] - Bt[c,d]*vi[d] for d in cnds) # shunts
                                    - 0
                                    )
        JuMP.@NLconstraint(pm.model, sum(ci[a][c] for a in bus_arcs)
                                    + sum(cisw[a_sw][c] for a_sw in bus_arcs_sw)
                                    + sum(cit[a_trans][c] for a_trans in bus_arcs_trans)
                                    ==
                                    sum(cig[g][c]        for g in bus_gens)
                                    - sum( Gt[c,d]*vi[d] + Bt[c,d]*vr[d] for d in cnds) # shunts
                                    - 0
                                    )
    end
end


""
function constraint_mc_fault_current_balance(pm::_PM.AbstractIVRModel, n::Int, i, bus_arcs, bus_arcs_sw, bus_arcs_trans, bus_gens, bus_gs, bus_bs, bus)
    vr = var(pm, n, :vr, i)
    vi = var(pm, n, :vi, i)

    # TODO: add storage back with inverter fault model
    cr    = get(var(pm, n),    :cr, Dict()); _PM._check_var_keys(cr, bus_arcs, "real current", "branch")
    ci    = get(var(pm, n),    :ci, Dict()); _PM._check_var_keys(ci, bus_arcs, "imaginary current", "branch")
    crg   = get(var(pm, n),   :crg_bus, Dict()); _PM._check_var_keys(crg, bus_gens, "real current", "generator")
    cig   = get(var(pm, n),   :cig_bus, Dict()); _PM._check_var_keys(cig, bus_gens, "imaginary current", "generator")
    crsw  = get(var(pm, n),  :crsw, Dict()); _PM._check_var_keys(crsw, bus_arcs_sw, "real current", "switch")
    cisw  = get(var(pm, n),  :cisw, Dict()); _PM._check_var_keys(cisw, bus_arcs_sw, "imaginary current", "switch")
    crt   = get(var(pm, n),   :crt, Dict()); _PM._check_var_keys(crt, bus_arcs_trans, "real current", "transformer")
    cit   = get(var(pm, n),   :cit, Dict()); _PM._check_var_keys(cit, bus_arcs_trans, "imaginary current", "transformer")

    cnds = _PM.conductor_ids(pm; nw=n)
    ncnds = length(cnds)

    Gt = isempty(bus_bs) ? fill(0.0, ncnds, ncnds) : sum(values(bus_gs))
    Bt = isempty(bus_bs) ? fill(0.0, ncnds, ncnds) : sum(values(bus_bs))

    cfr = var(pm, n, :cfr)
    cfi = var(pm, n, :cfi)

    for c in cnds
        JuMP.@NLconstraint(pm.model,  sum(cr[a][c] for a in bus_arcs)
                                    + sum(crsw[a_sw][c] for a_sw in bus_arcs_sw)
                                    + sum(crt[a_trans][c] for a_trans in bus_arcs_trans)
                                    ==
                                    sum(crg[g][c]        for g in bus_gens)
                                    - sum( Gt[c,d]*vr[d] - Bt[c,d]*vi[d] for d in cnds) # shunts
                                    - cfr[c] # faults
                                    )
        JuMP.@NLconstraint(pm.model, sum(ci[a][c] for a in bus_arcs)
                                    + sum(cisw[a_sw][c] for a_sw in bus_arcs_sw)
                                    + sum(cit[a_trans][c] for a_trans in bus_arcs_trans)
                                    ==
                                    sum(cig[g][c]        for g in bus_gens)
                                    - sum( Gt[c,d]*vi[d] + Bt[c,d]*vr[d] for d in cnds) # shunts
                                    - cfi[c] # faults
                                    )
    end
end


""
function constraint_mc_generation_wye(pm::_PM.IVRPowerModel, nw::Int, id::Int, bus_id::Int; report::Bool=true, bounded::Bool=true)
    vr = var(pm, nw, :vr, bus_id)
    vi = var(pm, nw, :vi, bus_id)
    crg = var(pm, nw, :crg, id)
    cig = var(pm, nw, :cig, id)

    nph = 3

    var(pm, nw, :crg_bus)[id] = crg
    var(pm, nw, :cig_bus)[id] = cig

    if report
        sol(pm, nw, :gen, id)[:crg_bus] = var(pm, nw, :crg_bus, id)
        sol(pm, nw, :gen, id)[:cig_bus] = var(pm, nw, :crg_bus, id)
    end
end


""
function constraint_mc_generation_delta(pm::_PM.IVRPowerModel, nw::Int, id::Int, bus_id::Int; report::Bool=true, bounded::Bool=true)
    vr = var(pm, nw, :vr, bus_id)
    vi = var(pm, nw, :vi, bus_id)
    crg = var(pm, nw, :crg, id)
    cig = var(pm, nw, :cig, id)

    nph = 3
    prev = Dict(i=>(i+nph-2)%nph+1 for i in 1:nph)
    next = Dict(i=>i%nph+1 for i in 1:nph)

    vrg = JuMP.@NLexpression(pm.model, [i in 1:nph], vr[i]-vr[next[i]])
    vig = JuMP.@NLexpression(pm.model, [i in 1:nph], vi[i]-vi[next[i]])

    crg_bus = JuMP.@NLexpression(pm.model, [i in 1:nph], crg[i]-crg[prev[i]])
    cig_bus = JuMP.@NLexpression(pm.model, [i in 1:nph], cig[i]-cig[prev[i]])

    var(pm, nw, :crg_bus)[id] = crg_bus
    var(pm, nw, :cig_bus)[id] = cig_bus

    if report
        sol(pm, nw, :gen, id)[:crg_bus] = crg_bus
        sol(pm, nw, :gen, id)[:cig_bus] = cig_bus
    end
end


""
function constraint_mc_ref_bus_voltage(pm::_PM.AbstractIVRModel, n::Int, i, vr0, vi0)
    vr = var(pm, n, :vr, i)
    vi = var(pm, n, :vi, i)

    cnds = _PM.conductor_ids(pm; nw=n)
    ncnds = length(cnds)

    for c in cnds
        JuMP.@constraint(pm.model, vr[c] == vr0[c])
        JuMP.@constraint(pm.model, vi[c] == vi0[c])
    end
end
