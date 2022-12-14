"""
	constraint_mc_gen_power_setpoint_imag(pm::_PMD.AbstractUnbalancedPowerModel, n::Int, i, qg)

generator reactive power setpoint constraint
"""
function constraint_mc_gen_power_setpoint_imag(pm::_PMD.AbstractUnbalancedPowerModel, n::Int, i, qg)
    qg_var = _PMD.var(pm, n, :qg, i)
    JuMP.@constraint(pm.model, qg_var .== qg)
end


"""
	constraint_gen_voltage_drop(pm::_PM.AbstractIVRModel, n::Int, i::Int, bus_id, r, x, vgr, vgi)

States that the bus voltage is equal to the internal voltage minus voltage drop across subtransient impedance
"""
function constraint_gen_voltage_drop(pm::_PM.AbstractIVRModel, n::Int, i::Int, bus_id, r, x, vgr, vgi)
    vr_to = _PM.var(pm, n, :vr, bus_id)
    vi_to = _PM.var(pm, n, :vi, bus_id)

    crg =  _PM.var(pm, n, :crg, i)
    cig =  _PM.var(pm, n, :cig, i)

    JuMP.@constraint(pm.model, vr_to == vgr - r * crg + x * cig)
    JuMP.@constraint(pm.model, vi_to == vgi - r * cig - x * crg)
end


"""
	constraint_bus_fault_current(pm::_PM.AbstractIVRModel, nw::Int, i::Int, fault_bus::Int, g::Real)

Calculates the fault current at a bus
"""
function constraint_bus_fault_current(pm::_PM.AbstractIVRModel, nw::Int, i::Int, fault_bus::Int, g::Real)
    vr = _PM.var(pm, nw, :vr, fault_bus)
    vi = _PM.var(pm, nw, :vi, fault_bus)

    cr = _PM.var(pm, nw, :cfr, i)
    ci = _PM.var(pm, nw, :cfi, i)

    JuMP.@constraint(pm.model, g * vr == cr)
    JuMP.@constraint(pm.model, g * vi == ci)
end


"""
	constraint_current_balance(pm::_PM.AbstractIVRModel, n::Int, i::Int, bus_arcs, bus_gens, bus_gs, bus_bs)

Calculates the current balance at the non-faulted buses
"""
function constraint_current_balance(pm::_PM.AbstractIVRModel, n::Int, i::Int, bus_arcs, bus_gens, bus_gs, bus_bs)
    vr = _PM.var(pm, n, :vr, i)
    vi = _PM.var(pm, n, :vi, i)

    cr =  _PM.var(pm, n, :cr)
    ci =  _PM.var(pm, n, :ci)

    crg =  _PM.var(pm, n, :crg)
    cig =  _PM.var(pm, n, :cig)

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


"""
	constraint_fault_current_balance(pm::_PM.AbstractIVRModel, n::Int, i::Int, bus_arcs, bus_gens, bus_gs, bus_bs)

Calculates the current balance at the faulted bus
"""
function constraint_fault_current_balance(pm::_PM.AbstractIVRModel, n::Int, i::Int, bus_arcs, bus_gens, bus_gs, bus_bs)
    vr = _PM.var(pm, n, :vr, i)
    vi = _PM.var(pm, n, :vi, i)

    cr =  _PM.var(pm, n, :cr)
    ci =  _PM.var(pm, n, :ci)

    crg =  _PM.var(pm, n, :crg)
    cig =  _PM.var(pm, n, :cig)

    cfr = _PM.var(pm, n, :cfr_bus, i)
    cfi = _PM.var(pm, n, :cfi_bus, i)

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


"""
"""
function constraint_mc_pf_generator_constant_power(pm::_PMD.AbstractUnbalancedIVRModel, n::Int, i::Int, bus_id::Int, kw, kvar, connections)
    pg = _PMD.var(pm, n, :pg, i)
    qg = _PMD.var(pm, n, :qg, i)

    for c in connections
        JuMP.@NLconstraint(pm.model, pg[c] == kw[c])
        JuMP.@NLconstraint(pm.model, kvar[c] == qg[c])
    end
end


"""
"""
function constraint_mc_opf_generator_constant_power(pm::_PMD.AbstractUnbalancedIVRModel, n::Int, i::Int, bus_id::Int, connections, pf_ratio)
    pg =  _PMD.var(pm, n, :pg)
    qg =  _PMD.var(pm, n, :qg)

    for c in connections
        JuMP.@NLconstraint(pm.model, pf_ratio*pg[c] >= qg[c])
        JuMP.@NLconstraint(pm.model, -pf_ratio*pg[c] <= qg[c])
    end
end


"""
"""
function constraint_mc_fs_generator_constant_power(pm::_PMD.AbstractUnbalancedIVRModel, n::Int, i::Int, bus_id::Int, vr0::Vector{<:Real}, vi0::Vector{<:Real}, z::Vector{<:Complex}, connections::Vector{Int})
    vr =  _PMD.var(pm, n, :vr, bus_id)
    vi =  _PMD.var(pm, n, :vi, bus_id)

    crg =  _PMD.var(pm, n, :crg, i)
    cig =  _PMD.var(pm, n, :cig, i)

    zr = real.(z)
    zi = imag.(z)

    for (idx,c) in enumerate(connections)
        JuMP.@NLconstraint(pm.model, vr0[idx] - crg[c]*zr[c] + cig[c]*zi[c] == vr[c])
        JuMP.@NLconstraint(pm.model, vi0[idx] - cig[c]*zr[c] - crg[c]*zi[c] == vi[c])
    end
end


"""
	constraint_mc_gen_voltage_drop(pm::_PMD.AbstractUnbalancedIVRModel, n::Int, i::Int, bus_id::Int, r, x, vgr, vgi, terminals)

Constraint that sets the terminal voltage basd on the internal voltage and the stator impedence
"""
function constraint_mc_gen_voltage_drop(pm::_PMD.AbstractUnbalancedIVRModel, n::Int, i::Int, bus_id::Int, r, x, vgr, vgi, terminals)
    vr_to = _PMD.var(pm, n, :vr, bus_id)
    vi_to = _PMD.var(pm, n, :vi, bus_id)

    crg =  _PMD.var(pm, n, :crg_bus, i)
    cig =  _PMD.var(pm, n, :cig_bus, i)

    @debug "Adding drop for generator $i on bus $bus_id with xdp = $x"

    for c in terminals
        JuMP.@constraint(pm.model, vr_to[c] == vgr[c] - r[c] * crg[c] + x[c] * cig[c])
        JuMP.@constraint(pm.model, vi_to[c] == vgi[c] - r[c] * cig[c] - x[c] * crg[c])
        # JuMP.@constraint(pm.model, vr_to[c] == vgr[c])
        # JuMP.@constraint(pm.model, vi_to[c] == vgi[c])
    end
end


"""
	constraint_mc_bus_fault_current(pm::_PMD.AbstractUnbalancedPowerModel, nw::Int, i::Int, bus::Int, connections::Vector{Int}, Gf::Matrix{<:Real}, Bf::Matrix{<:Real})

Calculates the current at the faulted bus for multiconductor
"""
function constraint_mc_bus_fault_current(pm::_PMD.AbstractUnbalancedPowerModel, nw::Int, i::Int, bus::Int, connections::Vector{Int}, Gf::Matrix{<:Real}, Bf::Matrix{<:Real})
    vr = _PMD.var(pm, nw, :vr, bus)
    vi = _PMD.var(pm, nw, :vi, bus)

    cr = _PMD.var(pm, nw, :cfr, i)
    ci = _PMD.var(pm, nw, :cfi, i)

    for (idx, fc) in enumerate(connections)
        JuMP.@constraint(pm.model, cr[fc] == sum(Gf[idx,jdx] * vr[tc] for (jdx,tc) in enumerate(connections)))
        JuMP.@constraint(pm.model, ci[fc] == sum(Gf[idx,jdx] * vi[tc] for (jdx,tc) in enumerate(connections)))
    end
end


"""
	constraint_mc_fault_current_balance(pm::_PMD.AbstractUnbalancedIVRModel, nw::Int, i::Int, fault::Int, terminals::Vector{Int}, grounded::Vector{Bool}, bus_arcs::Vector{Tuple{Tuple{Int,Int,Int},Vector{Int}}}, bus_arcs_sw::Vector{Tuple{Tuple{Int,Int,Int},Vector{Int}}}, bus_arcs_trans::Vector{Tuple{Tuple{Int,Int,Int},Vector{Int}}}, bus_gens::Vector{Tuple{Int,Vector{Int}}}, bus_storage::Vector{Tuple{Int,Vector{Int}}}, bus_shunts::Vector{Tuple{Int,Vector{Int}}})

Calculates the current balance at the faulted bus for multiconductor
"""
function constraint_mc_fault_current_balance(pm::_PMD.AbstractUnbalancedIVRModel, nw::Int, i::Int, fault::Int, terminals::Vector{Int}, grounded::Vector{Bool}, bus_arcs::Vector{Tuple{Tuple{Int,Int,Int},Vector{Int}}}, bus_arcs_sw::Vector{Tuple{Tuple{Int,Int,Int},Vector{Int}}}, bus_arcs_trans::Vector{Tuple{Tuple{Int,Int,Int},Vector{Int}}}, bus_gens::Vector{Tuple{Int,Vector{Int}}}, bus_storage::Vector{Tuple{Int,Vector{Int}}}, bus_shunts::Vector{Tuple{Int,Vector{Int}}})
    vr = _PMD.var(pm, nw, :vr, i)
    vi = _PMD.var(pm, nw, :vi, i)

    cr    = get(_PMD.var(pm, nw),    :cr, Dict()); _PMD._check_var_keys(cr, bus_arcs, "real current", "branch")
    ci    = get(_PMD.var(pm, nw),    :ci, Dict()); _PMD._check_var_keys(ci, bus_arcs, "imaginary current", "branch")
    crg   = get(_PMD.var(pm, nw),   :crg_bus, Dict()); _PMD._check_var_keys(crg, bus_gens, "real current", "generator")
    cig   = get(_PMD.var(pm, nw),   :cig_bus, Dict()); _PMD._check_var_keys(cig, bus_gens, "imaginary current", "generator")
    crs   = get(_PMD.var(pm, nw),   :crs, Dict()); _PMD._check_var_keys(crs, bus_storage, "real currentr", "storage")
    cis   = get(_PMD.var(pm, nw),   :cis, Dict()); _PMD._check_var_keys(cis, bus_storage, "imaginary current", "storage")
    crsw  = get(_PMD.var(pm, nw),  :crsw, Dict()); _PMD._check_var_keys(crsw, bus_arcs_sw, "real current", "switch")
    cisw  = get(_PMD.var(pm, nw),  :cisw, Dict()); _PMD._check_var_keys(cisw, bus_arcs_sw, "imaginary current", "switch")
    crt   = get(_PMD.var(pm, nw),   :crt, Dict()); _PMD._check_var_keys(crt, bus_arcs_trans, "real current", "transformer")
    cit   = get(_PMD.var(pm, nw),   :cit, Dict()); _PMD._check_var_keys(cit, bus_arcs_trans, "imaginary current", "transformer")

    cfr = _PMD.var(pm, nw, :cfr, fault)
    cfi = _PMD.var(pm, nw, :cfi, fault)

    fault_conns = _PMD.ref(pm, nw, :fault, fault, "connections")

    Gt, Bt = _PMD._build_bus_shunt_matrices(pm, nw, terminals, bus_shunts)

    ungrounded_terminals = [(idx,t) for (idx,t) in enumerate(terminals) if !grounded[idx]]

    for (idx, t) in ungrounded_terminals
        if t in fault_conns
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
        else
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
end


"""
"""
function constraint_mc_opf_current_balance(pm::_PMD.AbstractUnbalancedIVRModel, nw::Int, i::Int, terminals::Vector{Int}, grounded::Vector{Bool}, bus_arcs::Vector{Tuple{Tuple{Int,Int,Int},Vector{Int}}}, bus_arcs_sw::Vector{Tuple{Tuple{Int,Int,Int},Vector{Int}}}, bus_arcs_trans::Vector{Tuple{Tuple{Int,Int,Int},Vector{Int}}}, bus_gens::Vector{Tuple{Int,Vector{Int}}}, bus_storage::Vector{Tuple{Int,Vector{Int}}}, bus_shunts::Vector{Tuple{Int,Vector{Int}}})
    vr = _PMD.var(pm, nw, :vr, i)
    vi = _PMD.var(pm, nw, :vi, i)

    cr    = get(_PMD.var(pm, nw),    :cr, Dict()); _PMD._check_var_keys(cr, bus_arcs, "real current", "branch")
    ci    = get(_PMD.var(pm, nw),    :ci, Dict()); _PMD._check_var_keys(ci, bus_arcs, "imaginary current", "branch")
    crg   = get(_PMD.var(pm, nw),   :crg_bus, Dict()); _PMD._check_var_keys(crg, bus_gens, "real current", "generator")
    cig   = get(_PMD.var(pm, nw),   :cig_bus, Dict()); _PMD._check_var_keys(cig, bus_gens, "imaginary current", "generator")
    crs   = get(_PMD.var(pm, nw),   :crs, Dict()); _PMD._check_var_keys(crs, bus_storage, "real currentr", "storage")
    cis   = get(_PMD.var(pm, nw),   :cis, Dict()); _PMD._check_var_keys(cis, bus_storage, "imaginary current", "storage")
    crsw  = get(_PMD.var(pm, nw),  :crsw, Dict()); _PMD._check_var_keys(crsw, bus_arcs_sw, "real current", "switch")
    cisw  = get(_PMD.var(pm, nw),  :cisw, Dict()); _PMD._check_var_keys(cisw, bus_arcs_sw, "imaginary current", "switch")
    crt   = get(_PMD.var(pm, nw),   :crt, Dict()); _PMD._check_var_keys(crt, bus_arcs_trans, "real current", "transformer")
    cit   = get(_PMD.var(pm, nw),   :cit, Dict()); _PMD._check_var_keys(cit, bus_arcs_trans, "imaginary current", "transformer")


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


"""
"""
function constraint_mc_switch_state_closed(pm::_PMD.AbstractUnbalancedIVRModel, nw::Int, f_bus::Int, t_bus::Int, f_idx, t_idx, f_connections::Vector{Int}, t_connections::Vector{Int})
    vr_fr = _PMD.var(pm, nw, :vr, f_bus)
    vr_to = _PMD.var(pm, nw, :vr, t_bus)

    vi_fr = _PMD.var(pm, nw, :vi, f_bus)
    vi_to = _PMD.var(pm, nw, :vi, t_bus)

    cr_fr = [_PMD.var(pm, nw, :crsw, f_idx)[c] for c in f_connections]
    ci_fr = [_PMD.var(pm, nw, :cisw, f_idx)[c] for c in f_connections]

    cr_to = [_PMD.var(pm, nw, :crsw, t_idx)[c] for c in t_connections]
    ci_to = [_PMD.var(pm, nw, :cisw, t_idx)[c] for c in t_connections]

    for (idx,(fc,tc)) in enumerate(zip(f_connections, t_connections))
        JuMP.@constraint(pm.model, vr_fr[fc] == vr_to[tc])
        JuMP.@constraint(pm.model, vi_fr[fc] == vi_to[tc])
        JuMP.@constraint(pm.model, cr_fr[fc] == cr_to[tc])
        JuMP.@constraint(pm.model, ci_fr[fc] == ci_to[tc])
    end
end


"""
"""
function constraint_mc_switch_state_open(pm::_PMD.AbstractUnbalancedIVRModel, nw::Int, f_idx::Tuple{Int,Int,Int})
    crsw = _PMD.var(pm, nw, :crsw, f_idx)
    cisw = _PMD.var(pm, nw, :cisw, f_idx)

    JuMP.@constraint(pm.model, crsw .== 0.0)
    JuMP.@constraint(pm.model, cisw .== 0.0)
end


"""
"""
function constraint_mc_voltage_magnitude_bounds(pm::_PMD.AbstractUnbalancedIVRModel, nw::Int, i::Int, vmin, vmax, terminals)
    vr = _PMD.var(pm, nw, :vr, i)
    vi = _PMD.var(pm, nw, :vi, i)
    for c in terminals
        JuMP.@NLconstraint(pm.model, vr[c]^2 + vi[c]^2 <= vmax[c]^2)
        JuMP.@NLconstraint(pm.model, vr[c]^2 + vi[c]^2 >= vmin[c]^2)
    end
end
