# states that the bus voltage is equal to the internal voltage minus voltage drop across subtransient impedance
function constraint_gen_voltage_drop(pm::_PMs.AbstractIVRModel, n::Int, i, bus_id, r, x, vgr, vgi)
    vr_to = _PMs.var(pm, n, :vr, bus_id)
    vi_to = _PMs.var(pm, n, :vi, bus_id)

    crg =  _PMs.var(pm, n, :crg, i)
    cig =  _PMs.var(pm, n, :cig, i)    

    JuMP.@constraint(pm.model, vr_to == vgr - r * crg + x * cig)
    JuMP.@constraint(pm.model, vi_to == vgi - r * cig - x * crg)
end

function constraint_fault_current(pm::_PMs.AbstractPowerModel; nw::Int=pm.cnw)
    bus = _PMs.ref(pm, nw, :active_fault, "bus")
    z = _PMs.ref(pm, nw, :active_fault, "gf")
    vr = _PMs.var(pm, nw, :vr, bus)
    vi = _PMs.var(pm, nw, :vi, bus)

    _PMs.var(pm, nw)[:cfr] = JuMP.@variable(pm.model,
        [bus], base_name="$(nw)_cfr",
        start = 0
    )
    _PMs.var(pm, nw)[:cfi] = JuMP.@variable(pm.model,
        [bus], base_name="$(nw)_cfi",
        start = 0
    )

    cr = _PMs.var(pm, nw, :cfr, bus)
    ci = _PMs.var(pm, nw, :cfi, bus)
    JuMP.@constraint(pm.model, vr == cr * z)
    JuMP.@constraint(pm.model, vi == ci * z)
end

function constraint_current_balance(pm::_PMs.AbstractIVRModel, n::Int, i, bus_arcs, bus_gens, bus_gs, bus_bs)
    vr = _PMs.var(pm, n, :vr, i)
    vi = _PMs.var(pm, n, :vi, i)

    cr =  _PMs.var(pm, n, :cr)
    ci =  _PMs.var(pm, n, :ci)

    crg =  _PMs.var(pm, n, :crg)
    cig =  _PMs.var(pm, n, :cig)    

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

function constraint_fault_current_balance(pm::_PMs.AbstractIVRModel, n::Int, i, bus_arcs, bus_gens, bus_gs, bus_bs, bus)
    vr = _PMs.var(pm, n, :vr, i)
    vi = _PMs.var(pm, n, :vi, i)

    cr =  _PMs.var(pm, n, :cr)
    ci =  _PMs.var(pm, n, :ci)

    crg =  _PMs.var(pm, n, :crg)
    cig =  _PMs.var(pm, n, :cig) 
    
    cfr = _PMs.var(pm, n, :cfr, bus)
    cfi = _PMs.var(pm, n, :cfi, bus)

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

function constraint_mc_gen_voltage_drop(pm::_PMs.AbstractIVRModel, n::Int, i, bus_id, r, x, vgr, vgi)
    vr_to = _PMs.var(pm, n, :vr, bus_id)
    vi_to = _PMs.var(pm, n, :vi, bus_id)

    crg =  _PMs.var(pm, n, :crg, i)
    cig =  _PMs.var(pm, n, :cig, i)    

    for c in _PMs.conductor_ids(pm; nw=n)
        JuMP.@constraint(pm.model, vr_to[c] == vgr[c] - r[c]*crg[c] + x[c]*cig[c])
        JuMP.@constraint(pm.model, vi_to[c] == vgi[c] - r[c]*cig[c] - x[c]*crg[c])
    end
end

function constraint_mc_fault_current(pm::_PMs.AbstractPowerModel; nw::Int=pm.cnw)
    bus = _PMs.ref(pm, nw, :active_fault, "bus_i")
    z = _PMs.ref(pm, nw, :active_fault, "Gf")
    vr = _PMs.var(pm, nw, :vr, bus)
    vi = _PMs.var(pm, nw, :vi, bus)

    _PMs.var(pm, nw)[:cfr] = JuMP.@variable(pm.model,
        [c in _PMs.conductor_ids(pm; nw=nw)], base_name="$(nw)_cfr",
        start = 0
    )

    _PMs.var(pm, nw)[:cfi] = JuMP.@variable(pm.model,
        [c in _PMs.conductor_ids(pm; nw=nw)], base_name="$(nw)_cfi",
        start = 0
    )

    cr = _PMs.var(pm, nw, :cfr, bus)
    ci = _PMs.var(pm, nw, :cfi, bus)
    # Gf[c,d]*vi[d] for d in cnds
    for c in _PMs.conductor_ids(pm; nw=nw)
        JuMP.@constraint(pm.model, vr[c] == cr[c] * .1)
        JuMP.@constraint(pm.model, vi[c] == ci[c] * .1)
    end
end

function constraint_mc_current_balance(pm::_PMs.AbstractIVRModel, n::Int, i, bus_arcs, bus_arcs_sw, bus_arcs_trans, bus_gens, bus_gs, bus_bs)
    vr = _PMs.var(pm, n, :vr, i)
    vi = _PMs.var(pm, n, :vi, i)

    # TODO: add storage back with inverter fault model
    cr    = get(_PMs.var(pm, n),    :cr, Dict()); _PMs._check_var_keys(cr, bus_arcs, "real current", "branch")
    ci    = get(_PMs.var(pm, n),    :ci, Dict()); _PMs._check_var_keys(ci, bus_arcs, "imaginary current", "branch")
    crg   = get(_PMs.var(pm, n),   :crg_bus, Dict()); _PMs._check_var_keys(crg, bus_gens, "real current", "generator")
    cig   = get(_PMs.var(pm, n),   :cig_bus, Dict()); _PMs._check_var_keys(cig, bus_gens, "imaginary current", "generator")
    crsw  = get(_PMs.var(pm, n),  :crsw, Dict()); _PMs._check_var_keys(crsw, bus_arcs_sw, "real current", "switch")
    cisw  = get(_PMs.var(pm, n),  :cisw, Dict()); _PMs._check_var_keys(cisw, bus_arcs_sw, "imaginary current", "switch")
    crt   = get(_PMs.var(pm, n),   :crt, Dict()); _PMs._check_var_keys(crt, bus_arcs_trans, "real current", "transformer")
    cit   = get(_PMs.var(pm, n),   :cit, Dict()); _PMs._check_var_keys(cit, bus_arcs_trans, "imaginary current", "transformer")

    cnds = _PMs.conductor_ids(pm; nw=n)
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
                                    )
        JuMP.@NLconstraint(pm.model, sum(ci[a][c] for a in bus_arcs)
                                    + sum(cisw[a_sw][c] for a_sw in bus_arcs_sw)
                                    + sum(cit[a_trans][c] for a_trans in bus_arcs_trans)
                                    ==
                                    sum(cig[g][c]        for g in bus_gens)
                                    - sum( Gt[c,d]*vi[d] + Bt[c,d]*vr[d] for d in cnds) # shunts
                                    )
    end
end

function constraint_mc_fault_current_balance(pm::_PMs.AbstractIVRModel, n::Int, i, bus_arcs, bus_arcs_sw, bus_arcs_trans, bus_gens, bus_gs, bus_bs, bus)
    vr = _PMs.var(pm, n, :vr, i)
    vi = _PMs.var(pm, n, :vi, i)

    # TODO: add storage back with inverter fault model
    cr    = get(_PMs.var(pm, n),    :cr, Dict()); _PMs._check_var_keys(cr, bus_arcs, "real current", "branch")
    ci    = get(_PMs.var(pm, n),    :ci, Dict()); _PMs._check_var_keys(ci, bus_arcs, "imaginary current", "branch")
    crg   = get(_PMs.var(pm, n),   :crg_bus, Dict()); _PMs._check_var_keys(crg, bus_gens, "real current", "generator")
    cig   = get(_PMs.var(pm, n),   :cig_bus, Dict()); _PMs._check_var_keys(cig, bus_gens, "imaginary current", "generator")
    crsw  = get(_PMs.var(pm, n),  :crsw, Dict()); _PMs._check_var_keys(crsw, bus_arcs_sw, "real current", "switch")
    cisw  = get(_PMs.var(pm, n),  :cisw, Dict()); _PMs._check_var_keys(cisw, bus_arcs_sw, "imaginary current", "switch")
    crt   = get(_PMs.var(pm, n),   :crt, Dict()); _PMs._check_var_keys(crt, bus_arcs_trans, "real current", "transformer")
    cit   = get(_PMs.var(pm, n),   :cit, Dict()); _PMs._check_var_keys(cit, bus_arcs_trans, "imaginary current", "transformer")

    cnds = _PMs.conductor_ids(pm; nw=n)
    ncnds = length(cnds)

    Gt = isempty(bus_bs) ? fill(0.0, ncnds, ncnds) : sum(values(bus_gs))  
    Bt = isempty(bus_bs) ? fill(0.0, ncnds, ncnds) : sum(values(bus_bs))

    cfr = _PMs.var(pm, n, :cfr, bus)
    cfi = _PMs.var(pm, n, :cfi, bus)

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
