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