"Constraints for fault current contribution of inverter in grid-following mode with pseudo-binary for current-limiting"
function constraint_unity_pf_inverter_disjunctive(pm::_PM.AbstractIVRModel, nw, i, bus_id, pg, qg, cmax)
    vr = var(pm, nw, :vr, bus_id)
    vi = var(pm, nw, :vi, bus_id)

    crg =  var(pm, nw, :crg, i)
    cig =  var(pm, nw, :cig, i)

    b = var(pm, nw, :c_limit, i)
    p_int = var(pm, nw, :p_int, i)
    q_int = var(pm, nw, :q_int, i) 
    
    JuMP.@NLconstraint(pm.model, crg^2 + cig^2 >= cmax^2 * b)
    JuMP.@NLconstraint(pm.model, crg^2 + cig^2 <= cmax^2)
    JuMP.@NLconstraint(pm.model, p_int * (1 - b) == 0.0)
    JuMP.@constraint(pm.model, q_int <= 0.00001)

    # Power Factor
    JuMP.@NLconstraint(pm.model, pg == vr*crg + vi*cig + b*p_int)
    JuMP.@NLconstraint(pm.model, 0 == vi*crg - vr*cig)
    JuMP.@NLconstraint(pm.model, cmax^2 >= crg^2 + cig^2) 
end

"Constraints for fault current contribution of inverter in grid-following mode with a real voltage drop to handle low-zero terminal voltages"
function constraint_pf_inverter_vs(pm::_PM.AbstractIVRModel, n::Int, i, bus_id, vs, pg, qg, cmax)
    vr = var(pm, n, :vr, bus_id)
    vi = var(pm, n, :vi, bus_id)

    crg =  var(pm, n, :crg, i)
    cig =  var(pm, n, :cig, i)

    kg = var(pm, n, :kg, i) # generator loading, varies between 0 and 1
    
    # this is equivalent to having a real voltage drop vs in series with the inverter
    JuMP.@NLconstraint(pm.model, kg*pg == vr*crg + vi*cig + vs*crg)
    JuMP.@NLconstraint(pm.model, kg*qg == vi*crg - vr*cig - vs*cig)
    JuMP.@NLconstraint(pm.model, cmax^2 >= crg^2 + cig^2) 
end

"Constraints for fault current contribution of inverter in grid-following mode operating at unity power factor"
function constraint_unity_pf_inverter(pm::_PM.AbstractIVRModel, n::Int, i, bus_id, pg, qg, cmax)
    vr = var(pm, n, :vr, bus_id)
    vi = var(pm, n, :vi, bus_id)

    crg =  var(pm, n, :crg, i)
    cig =  var(pm, n, :cig, i)

    kg = var(pm, n, :kg, i) # generator loading, varies between 0 and 1
    
    # I think this can be generalized to arbitrary power factors by multiplying k with alpha + j*beta
    # JuMP.@NLconstraint(pm.model, vr == kg*crg)
    # JuMP.@NLconstraint(pm.model, vi == kg*cig)
    _IM.relaxation_product(pm.model, kg, crg, vr)    
    _IM.relaxation_product(pm.model, kg, cig, vi)
    println("Limiting max current for gen $i at $bus_id to $cmax")
    JuMP.@NLconstraint(pm.model, cmax^2 >= crg^2 + cig^2) 
end

"Constraints for fault current contribution of inverter in grid-following mode operating at arbitrary power factor"
function constraint_pq_inverter(pm::_PM.AbstractIVRModel, n::Int, i, bus_id, pg, qg, cmax)
    vr = var(pm, n, :vr, bus_id)
    vi = var(pm, n, :vi, bus_id)

    crg =  var(pm, n, :crg, i)
    cig =  var(pm, n, :cig, i)

    sg = complex(pg, qg) # complex power
    ag = abs(sg) # apparent power
    ug = sg/ag # normalized power

    alpha = real(ug)
    beta = imag(ug)

    println("alpha + j*beta = $alpha + j$beta")
    
    kg = var(pm, n, :kg, i) # generator loading, varies between 0 and 1

    # scaled real & imag current
    scrg =  var(pm, n, :scrg, i)
    scig =  var(pm, n, :scig, i)

    # inverter current scaled by a real amount
    _IM.relaxation_product(pm.model, kg, crg, scrg)
    _IM.relaxation_product(pm.model, kg, cig, scig)
    JuMP.@constraint(pm.model, vr == alpha*scrg - beta*scig)
    JuMP.@constraint(pm.model, vi == alpha*scig + beta*scrg)
    
    println("Limiting max current for pq inverter $i at $bus_id to $cmax")
    JuMP.@NLconstraint(pm.model, cmax^2 >= crg^2 + cig^2) 
end

"Constraints for fault current contribution of inverter in grid-following mode operating at unity power factor with a series resistance to handle low-zero terminal voltages"
function constraint_unity_pf_inverter_rs(pm::_PM.AbstractIVRModel, n::Int, i, bus_id, r, pg, qg, cm)
    vr = var(pm, n, :vr, bus_id)
    vi = var(pm, n, :vi, bus_id)

    crg =  var(pm, n, :crg, i)
    cig =  var(pm, n, :cig, i)

    kg = var(pm, n, :kg, i) # generator loading, varies between 0 and 1
    
    # this is equivalent to having a resistance in series with the inverter
    JuMP.@NLconstraint(pm.model, kg*pg == vr*crg + vi*cig + r*crg^2 + r*cig^2)
    # JuMP.@NLconstraint(pm.model, 0.01 >= vi*crg - vr*cig)
    # JuMP.@NLconstraint(pm.model, -0.01 <= vi*crg - vr*cig)
    JuMP.@NLconstraint(pm.model, cm^2 >= crg^2 + cig^2) 
end

"Constraints for fault current contribution of inverter in grid-following mode assuming that the inverter current regulating loop operates slowly"
function constraint_i_inverter_vs(pm::_PM.AbstractIVRModel, n::Int, i, bus_id, vs, pg, qg, cm)
    vr = var(pm, n, :vr, bus_id)
    vi = var(pm, n, :vi, bus_id)

    crg =  var(pm, n, :crg, i)
    cig =  var(pm, n, :cig, i)

    kg = var(pm, n, :kg, i) # generator loading, varies between 0 and 1
    
    # this is equivalent to having a resistance in series with the inverter
    JuMP.@NLconstraint(pm.model, kg*pg == vr*crg + vi*cig + vs*crg)
    JuMP.@NLconstraint(pm.model, kg*qg == vi*crg - vr*cig - vs*cig)
    JuMP.@NLconstraint(pm.model, cm^2 == crg^2 + cig^2) 
end

"Constraints for fault current contribution of inverter in grid-forming mode"
function constraint_v_inverter(pm::_PM.AbstractIVRModel, n::Int, i, bus_id, r, x, vgr, vgi, cmax)
    vr_to = var(pm, n, :vr, bus_id)
    vi_to = var(pm, n, :vi, bus_id)

    crg =  var(pm, n, :crg, i)
    cig =  var(pm, n, :cig, i)
    
    # add a voltage drop so we don't need to worry about infeasibility near a short s
    # JuMP.@constraint(pm.model, vr_to == vgr - r * crg + x * cig)
    # JuMP.@constraint(pm.model, vi_to == vgi - r * cig - x * crg)

    JuMP.@NLconstraint(pm.model, cmax^2 >= crg^2 + cig^2) 
end

# adding the complex multiplier to constraint_unity_pf_inverter should do the same thing as this
# with potentially better performance under low terminal voltages
"McCormick relaxation of constraints for fault current contribution of inverter in grid-following mode"
function constraint_pq_inverter_mccormick(pm::_PM.AbstractIVRModel, n::Int, i, bus_id, pg, qg, cmax)
    vrg = var(pm, n, :vr, bus_id)
    vig = var(pm, n, :vi, bus_id)

    crg =  var(pm, n, :crg, i)
    cig =  var(pm, n, :cig, i)

    pg1 =  var(pm, n, :pg1, i)
    pg2 =  var(pm, n, :pg2, i)
    qg1 =  var(pm, n, :qg1, i)
    qg2 =  var(pm, n, :qg2, i)

    _IM.relaxation_product(pm.model, vrg, crg, pg1)
    _IM.relaxation_product(pm.model, vig, cig, pg2)
    _IM.relaxation_product(pm.model, vrg, cig, qg1)
    _IM.relaxation_product(pm.model, vig, crg, qg2)
    JuMP.@constraint(pm.model, kg*pg == pg1 - pg2)
    JuMP.@constraint(pm.model, kg*qg == qg1 + qg2)
    JuMP.@NLconstraint(pm.model, cmax^2 >= crg^2 + cig^2) 
end


"Constraints for fault current contribution of multiconductor inverter in grid-following mode"
function constraint_mc_pq_inverter(pm::_PM.AbstractIVRModel, nw, i, bus_id, pg, qg, cmax)
    ar = -1/6
    ai = sqrt(3)/6
    a2r = -1/6
    a2i = -sqrt(3)/6

    vr = var(pm, nw, :vr, bus_id)
    vi = var(pm, nw, :vi, bus_id)

    crg =  var(pm, nw, :crg, i)
    cig =  var(pm, nw, :cig, i)

    p_int = var(pm, nw, :p_int, bus_id)
    q_int = var(pm, nw, :q_int, bus_id) 
    p_delta = var(pm, nw, :p_delta, bus_id)
    q_delta = var(pm, nw, :q_delta, bus_id)
    crg_pos= var(pm, nw, :crg_pos, bus_id)
    cig_pos = var(pm, nw, :cig_pos, bus_id)
    vrg_pos= var(pm, nw, :vrg_pos, bus_id)
    vig_pos = var(pm, nw, :vig_pos, bus_id)
    crg_pos_int = var(pm, nw, :crg_pos_int, bus_id)
    cig_pos_int = var(pm, nw, :cig_pos_int, bus_id)
    crg_pos_delta = var(pm, nw, :crg_pos_delta, bus_id)
    cig_pos_delta = var(pm, nw, :cig_pos_delta, bus_id)
    crg_pos_max = var(pm, nw, :crg_pos_max, bus_id)
    cig_pos_max = var(pm, nw, :cig_pos_max, bus_id)

    cnds = _PM.conductor_ids(pm; nw=nw)
    ncnds = length(cnds)   

    
    # Zero-Sequence
    JuMP.@constraint(pm.model, sum(crg[c] for c in cnds) == 0)
    JuMP.@constraint(pm.model, sum(cig[c] for c in cnds) == 0)

    # Negative-Sequence
    JuMP.@constraint(pm.model, .333*crg[1] + a2r*crg[2] - a2i*cig[2] + ar*crg[3] - ai*cig[3] == 0)
    JuMP.@constraint(pm.model, .333*cig[1] + a2r*cig[2] + a2i*crg[2] + ar*cig[3] + ai*crg[3] == 0)

    # Positive-Sequence
    JuMP.@constraint(pm.model, .333*crg[1] + ar*crg[2] - ai*cig[2] + a2r*crg[3] - a2i*cig[3] == crg_pos)
    JuMP.@constraint(pm.model, .333*cig[1] + ar*cig[2] + ai*crg[2] + a2r*cig[3] + a2i*crg[3] == cig_pos)
    JuMP.@constraint(pm.model, .333*vr[1] + ar*vr[2] - ai*vi[2] + a2r*vr[3] - a2i*vi[3] == vrg_pos)
    JuMP.@constraint(pm.model, .333*vi[1] + ar*vi[2] + ai*vr[2] + a2r*vi[3] + a2i*vr[3] == vig_pos)

    JuMP.@NLconstraint(pm.model, crg_pos^2 + cig_pos^2 <= crg_pos_max^2 + cig_pos_max^2)
    JuMP.@NLconstraint(pm.model, crg_pos * crg_pos_max >= 0.0)
    JuMP.@NLconstraint(pm.model, cig_pos * cig_pos_max >= 0.0)
    JuMP.@NLconstraint(pm.model, crg_pos^2 + cig_pos^2 <= crg_pos_int^2 + cig_pos_int^2)

    JuMP.@NLconstraint(pm.model, pg/3 == vrg_pos*crg_pos + vig_pos*cig_pos + p_int)
    JuMP.@NLconstraint(pm.model, 0.0 == vig_pos*crg_pos - vrg_pos*cig_pos + q_int)
    JuMP.@NLconstraint(pm.model, pg/3 == vrg_pos*crg_pos_int + vig_pos*cig_pos_int)
    JuMP.@NLconstraint(pm.model, 0.0 == vig_pos*crg_pos_int - vrg_pos*cig_pos_int)
    # Imax real and imaginary parts 
    JuMP.@NLconstraint(pm.model, 0.0 == crg_pos_max*cig_pos_int - cig_pos_max*crg_pos_int)
    JuMP.@NLconstraint(pm.model, crg_pos_max^2 + cig_pos_max^2 == cmax^2)
    JuMP.@NLconstraint(pm.model, crg_pos_max * crg_pos_int >= 0.0)
    JuMP.@NLconstraint(pm.model, cig_pos_max * cig_pos_int >= 0.0)

    JuMP.@NLconstraint(pm.model, p_int * p_delta >= 0.0)

    JuMP.@NLconstraint(pm.model, p_int == vrg_pos*crg_pos_int + vig_pos*cig_pos_int - vrg_pos*crg_pos - vig_pos*cig_pos)
    JuMP.@NLconstraint(pm.model, q_int == vig_pos*crg_pos_int - vrg_pos*cig_pos_int - vig_pos*crg_pos + vrg_pos*cig_pos)

    JuMP.@NLconstraint(pm.model, p_delta == vrg_pos*crg_pos + vig_pos*cig_pos - vrg_pos*crg_pos_max - vig_pos*cig_pos_max)
    JuMP.@NLconstraint(pm.model, q_delta == vig_pos*crg_pos - vrg_pos*cig_pos - vig_pos*crg_pos_max + vrg_pos*cig_pos_max)

end



""
function constraint_mc_i_inverter(pm::_PM.AbstractIVRModel, n::Int, i, bus_id, pg, qg, cmax)
    ar = -1/2
    ai = sqrt(3)/2
    a2r = -1/2
    a2i = -sqrt(3)/2

    vr = var(pm, n, :vr, bus_id)
    vi = var(pm, n, :vi, bus_id)

    crg =  var(pm, n, :crg, i)
    cig =  var(pm, n, :cig, i)

    kg = var(pm, n, :kg, i) # generator loading

    cnds = _PMs.conductor_ids(pm; nw=n)
    ncnds = length(cnds)

    # Zero-Sequence
    JuMP.@constraint(pm.model, sum(crg[c] for c in cnds) == 0)
    JuMP.@constraint(pm.model, sum(cig[c] for c in cnds) == 0)

    # Negative-Sequence
    JuMP.@constraint(pm.model, crg[1] + a2r*crg[2] - a2i*cig[2] + ar*crg[3] - ai*cig[3] == 0)
    JuMP.@constraint(pm.model, cig[1] + a2r*cig[2] + a2i*crg[2] + ar*cig[3] + ai*crg[3] == 0)

    # Power Factor
    JuMP.@NLconstraint(pm.model, kg*pg == sum(vr[c]*crg[c] - vi[c]*cig[c] for c in cnds))
    JuMP.@NLconstraint(pm.model, kg*qg == sum(vi[c]*crg[c] + vr[c]*cig[c] for c in cnds))

    # Current limit
    for c in cnds
        JuMP.@NLconstraint(pm.model, cmax^2 == crg[c]^2 + cig[c]^2) 
    end
end
