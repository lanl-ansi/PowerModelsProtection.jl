"generator reactive power setpoint constraint"
function constraint_mc_gen_power_setpoint_imag(pm::_PM.AbstractPowerModel, n::Int, i, qg)
    qg_var = var(pm, n, :qg, i)
    JuMP.@constraint(pm.model, qg_var .== qg)
end

"States that the bus voltage is equal to the internal voltage minus voltage drop across subtransient impedance"
function constraint_gen_voltage_drop(pm::_PM.AbstractIVRModel, n::Int, i, bus_id, r, x, vgr, vgi)
    vr_to = var(pm, n, :vr, bus_id)
    vi_to = var(pm, n, :vi, bus_id)

    crg =  var(pm, n, :crg, i)
    cig =  var(pm, n, :cig, i)

    JuMP.@constraint(pm.model, vr_to == vgr - r * crg + x * cig)
    JuMP.@constraint(pm.model, vi_to == vgi - r * cig - x * crg)
end


"Calculates the fault current at a bus"
function constraint_fault_current(pm::_PM.AbstractPowerModel; nw::Int=pm.cnw)
    bus = ref(pm, nw, :active_fault, "bus_i")
    g = ref(pm, nw, :active_fault, "gf")
    vr = var(pm, nw, :vr, bus)
    vi = var(pm, nw, :vi, bus)

    var(pm, nw)[:cfr] = JuMP.@variable(pm.model,
        [bus], base_name = "$(nw)_cfr",
        start = 0
    )
    var(pm, nw)[:cfi] = JuMP.@variable(pm.model,
        [bus], base_name = "$(nw)_cfi",
        start = 0
    )

    cr = var(pm, nw, :cfr, bus)
    ci = var(pm, nw, :cfi, bus)
    JuMP.@constraint(pm.model, g * vr == cr)
    JuMP.@constraint(pm.model, g * vi == ci)
end


"Calculates the current balance at the non-faulted buses"
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
                                - sum(gs for gs in values(bus_gs)) * vr + sum(bs for bs in values(bus_bs)) * vi
                                )
    JuMP.@NLconstraint(pm.model, sum(ci[a] for a in bus_arcs)
                                ==
                                sum(cig[g] for g in bus_gens)
                                - sum(gs for gs in values(bus_gs)) * vi - sum(bs for bs in values(bus_bs)) * vr
                                )
end


"Calculates the current balance at the faulted bus"
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
                                - sum(gs for gs in values(bus_gs)) * vr + sum(bs for bs in values(bus_bs)) * vi
                                - cfr
                                )
    JuMP.@NLconstraint(pm.model, sum(ci[a] for a in bus_arcs)
                                ==
                                sum(cig[g] for g in bus_gens)
                                - sum(gs for gs in values(bus_gs)) * vi - sum(bs for bs in values(bus_bs)) * vr
                                - cfi
                                )
end


"Constraint that sets the terminal voltage basd on the internal voltage and the stator impedence"
function constraint_mc_gen_voltage_drop(pm::_PM.AbstractIVRModel, n::Int, i, bus_id, r, x, vgr, vgi, terminals)
    vr_to = var(pm, n, :vr, bus_id)
    vi_to = var(pm, n, :vi, bus_id)

    crg =  var(pm, n, :crg_bus, i)
    cig =  var(pm, n, :cig_bus, i)

    Memento.info(_LOGGER, "Adding drop for generator $i on bus $bus_id with xdp = $x")

    for c in terminals
        JuMP.@constraint(pm.model, vr_to[c] == vgr[c] - r[c] * crg[c] + x[c] * cig[c])
        JuMP.@constraint(pm.model, vi_to[c] == vgi[c] - r[c] * cig[c] - x[c] * crg[c])
        # JuMP.@constraint(pm.model, vr_to[c] == vgr[c])
        # JuMP.@constraint(pm.model, vi_to[c] == vgi[c])
    end
end


"Calculates the current at the faulted bus for multiconductor"
function constraint_mc_fault_current(pm::_PM.AbstractPowerModel; nw::Int=pm.cnw)

    bus = ref(pm, nw, :active_fault, "bus_i")
    terminals = ref(pm, nw, :bus, bus, "terminals")
    Gf = ref(pm, nw, :active_fault, "Gf")

    vr = var(pm, nw, :vr, bus)
    vi = var(pm, nw, :vi, bus)

    var(pm, nw)[:cfr] = JuMP.@variable(pm.model,
        [c in terminals], base_name = "$(nw)_cfr",
        start = 0
    )

    var(pm, nw)[:cfi] = JuMP.@variable(pm.model,
        [c in terminals], base_name = "$(nw)_cfi",
        start = 0
    )

    cr = var(pm, nw, :cfr)
    ci = var(pm, nw, :cfi)

    for c in terminals
        JuMP.@constraint(pm.model, cr[c] == sum(Gf[c,d] * vr[d] for d in terminals))
        JuMP.@constraint(pm.model, ci[c] == sum(Gf[c,d] * vi[d] for d in terminals))
    end
end


function constraint_mc_current_balance(pm::_PM.AbstractIVRModel, nw::Int, i::Int, terminals::Vector{Int}, grounded::Vector{Bool}, bus_arcs::Vector{Tuple{Tuple{Int,Int,Int},Vector{Int}}}, bus_arcs_sw::Vector{Tuple{Tuple{Int,Int,Int},Vector{Int}}}, bus_arcs_trans::Vector{Tuple{Tuple{Int,Int,Int},Vector{Int}}}, bus_gens::Vector{Tuple{Int,Vector{Int}}}, bus_storage::Vector{Tuple{Int,Vector{Int}}}, bus_shunts::Vector{Tuple{Int,Vector{Int}}})
    vr = var(pm, nw, :vr, i)
    vi = var(pm, nw, :vi, i)

    cr    = get(var(pm, nw),    :cr, Dict()); _PM._check_var_keys(cr, bus_arcs, "real current", "branch")
    ci    = get(var(pm, nw),    :ci, Dict()); _PM._check_var_keys(ci, bus_arcs, "imaginary current", "branch")
    crg   = get(var(pm, nw),   :crg_bus, Dict()); _PM._check_var_keys(crg, bus_gens, "real current", "generator")
    cig   = get(var(pm, nw),   :cig_bus, Dict()); _PM._check_var_keys(cig, bus_gens, "imaginary current", "generator")
    crs   = get(var(pm, nw),   :crs, Dict()); _PM._check_var_keys(crs, bus_storage, "real currentr", "storage")
    cis   = get(var(pm, nw),   :cis, Dict()); _PM._check_var_keys(cis, bus_storage, "imaginary current", "storage")
    crsw  = get(var(pm, nw),  :crsw, Dict()); _PM._check_var_keys(crsw, bus_arcs_sw, "real current", "switch")
    cisw  = get(var(pm, nw),  :cisw, Dict()); _PM._check_var_keys(cisw, bus_arcs_sw, "imaginary current", "switch")
    crt   = get(var(pm, nw),   :crt, Dict()); _PM._check_var_keys(crt, bus_arcs_trans, "real current", "transformer")
    cit   = get(var(pm, nw),   :cit, Dict()); _PM._check_var_keys(cit, bus_arcs_trans, "imaginary current", "transformer")

    Gt, Bt = _PMD._build_bus_shunt_matrices(pm, nw, terminals, bus_shunts)

    ungrounded_terminals = [(idx,t) for (idx,t) in enumerate(terminals) if !grounded[idx]]

    for (idx, t) in ungrounded_terminals
        JuMP.@NLconstraint(pm.model,  sum(cr[a][t] for (a, conns) in bus_arcs if t in conns)
                                    + sum(crsw[a_sw][t] for (a_sw, conns) in bus_arcs_sw if t in conns)
                                    + sum(crt[a_trans][t] for (a_trans, conns) in bus_arcs_trans if t in conns)
                                    ==
                                      sum(crg[g][t]         for (g, conns) in bus_gens if t in conns)
                                    - sum(crs[s][t]         for (s, conns) in bus_storage if t in conns)
                                    - sum( Gt[idx,jdx]*vr[u] -Bt[idx,jdx]*vi[u] for (jdx,u) in ungrounded_terminals) # shunts
                                    )
        JuMP.@NLconstraint(pm.model,  sum(ci[a][t] for (a, conns) in bus_arcs if t in conns)
                                    + sum(cisw[a_sw][t] for (a_sw, conns) in bus_arcs_sw if t in conns)
                                    + sum(cit[a_trans][t] for (a_trans, conns) in bus_arcs_trans if t in conns)
                                    ==
                                      sum(cig[g][t]         for (g, conns) in bus_gens if t in conns)
                                    - sum(cis[s][t]         for (s, conns) in bus_storage if t in conns)
                                    - sum( Gt[idx,jdx]*vi[u] +Bt[idx,jdx]*vr[u] for (jdx,u) in ungrounded_terminals) # shunts
                                    )
    end
end


"Calculates the current balance at the faulted bus for multiconductor"
function constraint_mc_fault_current_balance(pm::_PM.AbstractIVRModel, nw::Int, i::Int, terminals::Vector{Int}, grounded::Vector{Bool}, bus_arcs::Vector{Tuple{Tuple{Int,Int,Int},Vector{Int}}}, bus_arcs_sw::Vector{Tuple{Tuple{Int,Int,Int},Vector{Int}}}, bus_arcs_trans::Vector{Tuple{Tuple{Int,Int,Int},Vector{Int}}}, bus_gens::Vector{Tuple{Int,Vector{Int}}}, bus_storage::Vector{Tuple{Int,Vector{Int}}}, bus_shunts::Vector{Tuple{Int,Vector{Int}}})
    vr = var(pm, nw, :vr, i)
    vi = var(pm, nw, :vi, i)

    cr    = get(var(pm, nw),    :cr, Dict()); _PM._check_var_keys(cr, bus_arcs, "real current", "branch")
    ci    = get(var(pm, nw),    :ci, Dict()); _PM._check_var_keys(ci, bus_arcs, "imaginary current", "branch")
    crg   = get(var(pm, nw),   :crg_bus, Dict()); _PM._check_var_keys(crg, bus_gens, "real current", "generator")
    cig   = get(var(pm, nw),   :cig_bus, Dict()); _PM._check_var_keys(cig, bus_gens, "imaginary current", "generator")
    crs   = get(var(pm, nw),   :crs, Dict()); _PM._check_var_keys(crs, bus_storage, "real currentr", "storage")
    cis   = get(var(pm, nw),   :cis, Dict()); _PM._check_var_keys(cis, bus_storage, "imaginary current", "storage")
    crsw  = get(var(pm, nw),  :crsw, Dict()); _PM._check_var_keys(crsw, bus_arcs_sw, "real current", "switch")
    cisw  = get(var(pm, nw),  :cisw, Dict()); _PM._check_var_keys(cisw, bus_arcs_sw, "imaginary current", "switch")
    crt   = get(var(pm, nw),   :crt, Dict()); _PM._check_var_keys(crt, bus_arcs_trans, "real current", "transformer")
    cit   = get(var(pm, nw),   :cit, Dict()); _PM._check_var_keys(cit, bus_arcs_trans, "imaginary current", "transformer")

    cfr = var(pm, nw, :cfr)
    cfi = var(pm, nw, :cfi)

    Gt, Bt = _PMD._build_bus_shunt_matrices(pm, nw, terminals, bus_shunts)

    ungrounded_terminals = [(idx,t) for (idx,t) in enumerate(terminals) if !grounded[idx]]

    for (idx, t) in ungrounded_terminals
        JuMP.@NLconstraint(pm.model,  sum(cr[a][t] for (a, conns) in bus_arcs if t in conns)
                                    + sum(crsw[a_sw][t] for (a_sw, conns) in bus_arcs_sw if t in conns)
                                    + sum(crt[a_trans][t] for (a_trans, conns) in bus_arcs_trans if t in conns)
                                    ==
                                      sum(crg[g][t]         for (g, conns) in bus_gens if t in conns)
                                    - sum(crs[s][t]         for (s, conns) in bus_storage if t in conns)
                                    - sum( Gt[idx,jdx]*vr[u] -Bt[idx,jdx]*vi[u] for (jdx,u) in ungrounded_terminals) # shunts
                                    - cfr[t] # faults
                                    )
        JuMP.@NLconstraint(pm.model,  sum(ci[a][t] for (a, conns) in bus_arcs if t in conns)
                                    + sum(cisw[a_sw][t] for (a_sw, conns) in bus_arcs_sw if t in conns)
                                    + sum(cit[a_trans][t] for (a_trans, conns) in bus_arcs_trans if t in conns)
                                    ==
                                      sum(cig[g][t]         for (g, conns) in bus_gens if t in conns)
                                    - sum(cis[s][t]         for (s, conns) in bus_storage if t in conns)
                                    - sum( Gt[idx,jdx]*vi[u] +Bt[idx,jdx]*vr[u] for (jdx,u) in ungrounded_terminals) # shunts
                                    - cfi[t] # faults
                                    )
    end
end


"Calculates the current at a wye connected gen with no power constraints"
function constraint_mc_generation_wye(pm::_PM.IVRPowerModel, nw::Int, id::Int, bus_id::Int,connections::Vector{Int}; report::Bool=true, bounded::Bool=true)
    crg = var(pm, nw, :crg, id)
    cig = var(pm, nw, :cig, id)

    var(pm, nw, :crg_bus)[id] = crg
    var(pm, nw, :cig_bus)[id] = cig

    if report
        sol(pm, nw, :gen, id)[:crg_bus] = var(pm, nw, :crg_bus, id)
        sol(pm, nw, :gen, id)[:cig_bus] = var(pm, nw, :crg_bus, id)
    end
end


"Calculates the current at a delta connected gen with no power constraints"
function constraint_mc_generation_delta(pm::_PM.IVRPowerModel, nw::Int, id::Int, bus_id::Int, connections::Vector{Int}; report::Bool=true, bounded::Bool=true)
    vr = var(pm, nw, :vr, bus_id)
    vi = var(pm, nw, :vi, bus_id)
    crg = var(pm, nw, :crg, id)
    cig = var(pm, nw, :cig, id)

    nph = length(connections)

    prev = Dict(c=>connections[(idx+nph-2)%nph+1] for (idx,c) in enumerate(connections))
    next = Dict(c=>connections[idx%nph+1] for (idx,c) in enumerate(connections))

    vrg = Dict()
    vig = Dict()
    for c in connections
        vrg[c] = JuMP.@NLexpression(pm.model, vr[c]-vr[next[c]])
        vig[c] = JuMP.@NLexpression(pm.model, vi[c]-vi[next[c]])
    end

    crg_bus = Vector{JuMP.NonlinearExpression}([])
    cig_bus = Vector{JuMP.NonlinearExpression}([])
    for c in connections
        push!(crg_bus, JuMP.@NLexpression(pm.model, crg[c]-crg[prev[c]]))
        push!(cig_bus, JuMP.@NLexpression(pm.model, cig[c]-cig[prev[c]]))
    end

    crg_bus = JuMP.@NLexpression(pm.model, [i in 1:nph], crg[i] - crg[prev[i]])
    cig_bus = JuMP.@NLexpression(pm.model, [i in 1:nph], cig[i] - cig[prev[i]])

    var(pm, nw, :crg_bus)[id] = JuMP.Containers.DenseAxisArray(crg_bus, connections)
    var(pm, nw, :cig_bus)[id] = JuMP.Containers.DenseAxisArray(cig_bus, connections)

    if report
        sol(pm, nw, :gen, id)[:crg_bus] = JuMP.Containers.DenseAxisArray(crg_bus, connections)
        sol(pm, nw, :gen, id)[:cig_bus] = JuMP.Containers.DenseAxisArray(cig_bus, connections)
    end
end




"Constraint to set the ref bus voltage"
function constraint_mc_ref_bus_voltage(pm::_PM.AbstractIVRModel, n::Int, i, vr0, vi0, terminals)
    Memento.info(_LOGGER, "Setting voltage for reference bus $i")
    vr = var(pm, n, :vr, i)
    vi = var(pm, n, :vi, i)

    for c in terminals
        JuMP.@constraint(pm.model, vr[c] == vr0[c])
        JuMP.@constraint(pm.model, vi[c] == vi0[c])
    end
end


"Constarint to set the ref bus voltage magnitude only"
function constraint_mc_voltage_magnitude_only(pm::_PM.AbstractIVRModel, n::Int, i, vm)
    vr = var(pm, n, :vr, i)
    vi = var(pm, n, :vi, i)

    for c in _PM.conductor_ids(pm; nw=n)
        JuMP.@NLconstraint(pm.model, vr[c]^2 + vi[c]^2 == vm[c]^2)
    end
end


"Constarint to set the ref bus voltage angle only"
function constraint_mc_theta_ref(pm::_PM.AbstractIVRModel, n::Int, i, vr0, vi0)
    vr = var(pm, n, :vr, i)
    vi = var(pm, n, :vi, i)

    for c in _PM.conductor_ids(pm; nw=n)
        JuMP.@constraint(pm.model, vr[c] * vi0[c] == vi[c] * vr0[c])
        JuMP.@constraint(pm.model, vr[c] * vr0[c] >= 0.0)
        JuMP.@constraint(pm.model, vi[c] * vi0[c] >= 0.0)
    end
end


function constraint_mc_switch_state_closed(pm::_PM.AbstractIVRModel, nw::Int, f_bus::Int, t_bus::Int, f_idx::Tuple{Int,Int,Int}, f_connections::Vector{Int}, t_connections::Vector{Int}, z)
    vr_fr = var(pm, nw, :vr, f_bus)
    vr_to = var(pm, nw, :vr, t_bus)

    vi_fr = var(pm, nw, :vi, f_bus)
    vi_to = var(pm, nw, :vi, t_bus)

    crsw = var(pm, nw, :crsw, f_idx)
    cisw = var(pm, nw, :cisw, f_idx)

    zr = real(z)
    zi = imag(z)

    for (idx,(fc,tc)) in enumerate(zip(f_connections, t_connections))
        JuMP.@constraint(pm.model, vr_fr[fc] - crsw[fc]*zr + cisw[fc]*zi == vr_to[tc])
        JuMP.@constraint(pm.model, vi_fr[fc] - cisw[fc]*zr - crsw[fc]*zi == vi_to[tc])
    end
end