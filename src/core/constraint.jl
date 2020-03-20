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
    g = _PMs.ref(pm, nw, :active_fault, "gf")
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
    JuMP.@constraint(pm.model, g * vr == cr)
    JuMP.@constraint(pm.model, g * vi == ci)
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
    Gf = _PMs.ref(pm, nw, :active_fault, "Gf")

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

    cr = _PMs.var(pm, nw, :cfr)
    ci = _PMs.var(pm, nw, :cfi)

    cnds = _PMs.conductor_ids(pm; nw=nw)

    for c in _PMs.conductor_ids(pm; nw=nw)
        JuMP.@constraint(pm.model, cr[c] == sum(Gf[c,d]*vr[d] for d in cnds))
        JuMP.@constraint(pm.model, ci[c] == sum(Gf[c,d]*vi[d] for d in cnds))
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

    cfr = _PMs.var(pm, n, :cfr)
    cfi = _PMs.var(pm, n, :cfi)

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


function constraint_mc_generation_wye(pm::_PMs.IVRPowerModel, nw::Int, id::Int, bus_id::Int; report::Bool=true, bounded::Bool=true)
    vr = _PMs.var(pm, nw, :vr, bus_id)
    vi = _PMs.var(pm, nw, :vi, bus_id)
    crg = _PMs.var(pm, nw, :crg, id)
    cig = _PMs.var(pm, nw, :cig, id)

    nph = 3

    _PMs.var(pm, nw, :crg_bus)[id] = crg
    _PMs.var(pm, nw, :cig_bus)[id] = cig

    if report
        _PMs.sol(pm, nw, :gen, id)[:crg_bus] = _PMs.var(pm, nw, :crg_bus, id)
        _PMs.sol(pm, nw, :gen, id)[:cig_bus] = _PMs.var(pm, nw, :crg_bus, id)
    end
end


""
function constraint_mc_generation_delta(pm::_PMs.IVRPowerModel, nw::Int, id::Int, bus_id::Int; report::Bool=true, bounded::Bool=true)
    vr = _PMs.var(pm, nw, :vr, bus_id)
    vi = _PMs.var(pm, nw, :vi, bus_id)
    crg = _PMs.var(pm, nw, :crg, id)
    cig = _PMs.var(pm, nw, :cig, id)

    nph = 3
    prev = Dict(i=>(i+nph-2)%nph+1 for i in 1:nph)
    next = Dict(i=>i%nph+1 for i in 1:nph)

    vrg = JuMP.@NLexpression(pm.model, [i in 1:nph], vr[i]-vr[next[i]])
    vig = JuMP.@NLexpression(pm.model, [i in 1:nph], vi[i]-vi[next[i]])

    crg_bus = JuMP.@NLexpression(pm.model, [i in 1:nph], crg[i]-crg[prev[i]])
    cig_bus = JuMP.@NLexpression(pm.model, [i in 1:nph], cig[i]-cig[prev[i]])

    _PMs.var(pm, nw, :crg_bus)[id] = crg_bus
    _PMs.var(pm, nw, :cig_bus)[id] = cig_bus

    if report
        _PMs.sol(pm, nw, :gen, id)[:crg_bus] = crg_bus
        _PMs.sol(pm, nw, :gen, id)[:cig_bus] = cig_bus
    end
end

function constraint_mc_ref_bus_voltage(pm::_PMs.AbstractIVRModel, n::Int, i, vr0, vi0)
    vr = _PMs.var(pm, n, :vr, i)
    vi = _PMs.var(pm, n, :vi, i)

    cnds = _PMs.conductor_ids(pm; nw=n)
    ncnds = length(cnds)

    for c in cnds
        JuMP.@constraint(pm.model, vr[c] == vr0[c])
        JuMP.@constraint(pm.model, vi[c] == vi0[c])
    end
end