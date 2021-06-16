
function get_phase_base_order(faulted_phases::Vector{Int})
    if length(faulted_phases) == 1
        phase_base = faulted_phases[1]
    elseif length(faulted_phases) == 2
        for phase = 1:3
            phase in faulted_phases ? nothing : phase_base = phase
        end
    else
        phase_base = 1
    end
    phase_base_order = [phase_base;0;0]
    for phase = 2:3
        phase_base += 1
        phase_base == 4 ? phase_base = 1 : nothing
        phase_base_order[phase] = phase_base
    end
    return phase_base_order
end


function expression_mc_branch_fault_sequence_current(pm::_PMD.AbstractUnbalancedIVRModel, i::Int; nw::Int=nw_id_default, report::Bool=true)
    branch = _PMD.ref(pm, nw, :branch, i)

    f_connections = branch["f_connections"]
    t_connections = branch["t_connections"]
    
    if length(f_connections) == 3 && length(t_connections) == 3

        f_bus = branch["f_bus"]
        t_bus = branch["t_bus"]
        f_idx = (i, f_bus, t_bus)
        t_idx = (i, t_bus, f_bus)

        cr_fr =  [_PMD.var(pm, nw, :cr, f_idx)[c] for c in f_connections]
        ci_fr =  [_PMD.var(pm, nw, :ci, f_idx)[c] for c in f_connections]
        cr_to =  [_PMD.var(pm, nw, :cr, t_idx)[c] for c in t_connections]
        ci_to =  [_PMD.var(pm, nw, :ci, t_idx)[c] for c in t_connections]

        
        faulted_phases = _PMD.ref(pm, nw, :fault, 1)["connections"]
        phase_base_order = get_phase_base_order(faulted_phases)

        alpha = exp(1im*2/3*pi)
        a = 1/3*[1 1 1; 1 alpha alpha^2; 1 alpha^2 alpha] 
        ar = real(a)
        ai = imag(a)

        cf0r_fr = JuMP.@expression(pm.model, sum(ar[1,c] * cr_fr[phase_base_order[c]] for c in f_connections))
        cf0i_fr = JuMP.@expression(pm.model, sum(ai[1,c] * ci_fr[phase_base_order[c]] for c in f_connections))
        cf0r_to = JuMP.@expression(pm.model, sum(ar[1,c] * cr_to[phase_base_order[c]] for c in t_connections))
        cf0i_to = JuMP.@expression(pm.model, sum(ai[1,c] * ci_to[phase_base_order[c]] for c in t_connections))

        cf1r_fr = JuMP.@expression(pm.model, sum(ar[2,c] * cr_fr[phase_base_order[c]] - ai[2,c] * ci_fr[phase_base_order[c]] for c in f_connections))
        cf1i_fr = JuMP.@expression(pm.model, sum(ar[2,c] * ci_fr[phase_base_order[c]] + ai[2,c] * cr_fr[phase_base_order[c]] for c in f_connections))
        cf1r_to = JuMP.@expression(pm.model, sum(ar[2,c] * cr_to[phase_base_order[c]] - ai[2,c] * ci_to[phase_base_order[c]] for c in t_connections))
        cf1i_to = JuMP.@expression(pm.model, sum(ar[2,c] * ci_to[phase_base_order[c]] + ai[2,c] * cr_to[phase_base_order[c]] for c in t_connections))
     
        cf2r_fr = JuMP.@expression(pm.model, sum(ar[3,c] * cr_fr[phase_base_order[c]] - ai[3,c] * ci_fr[phase_base_order[c]] for c in f_connections))
        cf2i_fr = JuMP.@expression(pm.model, sum(ar[3,c] * ci_fr[phase_base_order[c]] + ai[3,c] * cr_fr[phase_base_order[c]] for c in f_connections))
        cf2r_to = JuMP.@expression(pm.model, sum(ar[3,c] * cr_to[phase_base_order[c]] - ai[3,c] * ci_to[phase_base_order[c]] for c in t_connections))
        cf2i_to = JuMP.@expression(pm.model, sum(ar[3,c] * ci_to[phase_base_order[c]] + ai[3,c] * cr_to[phase_base_order[c]] for c in t_connections))

        if report
            _PMD.sol(pm, nw, :branch, i)[:cf0r_fr] = cf0r_fr
            _PMD.sol(pm, nw, :branch, i)[:cf0i_fr] = cf0i_fr
            _PMD.sol(pm, nw, :branch, i)[:cf1r_fr] = cf1r_fr
            _PMD.sol(pm, nw, :branch, i)[:cf1i_fr] = cf1i_fr
            _PMD.sol(pm, nw, :branch, i)[:cf2r_fr] = cf2r_fr
            _PMD.sol(pm, nw, :branch, i)[:cf2i_fr] = cf2i_fr
            _PMD.sol(pm, nw, :branch, i)[:cf0r_to] = cf0r_to
            _PMD.sol(pm, nw, :branch, i)[:cf0i_to] = cf0i_to
            _PMD.sol(pm, nw, :branch, i)[:cf1r_to] = cf1r_to
            _PMD.sol(pm, nw, :branch, i)[:cf1i_to] = cf1i_to
            _PMD.sol(pm, nw, :branch, i)[:cf2r_to] = cf2r_to
            _PMD.sol(pm, nw, :branch, i)[:cf2i_to] = cf2i_to
        end
    end
end


function expression_mc_bus_fault_sequence_current(pm::_PMD.AbstractUnbalancedIVRModel, i::Int; nw::Int=nw_id_default, report::Bool=true)
    fault = _PMD.ref(pm, nw, :fault, i)
    bus = _PMD.ref(pm, nw, :bus, fault["fault_bus"])

    terminals = bus["terminals"]
    connections = fault["connections"]
    
    if length(terminals) == 3

        cr = _PMD.var(pm, nw, :cfr, i)
        ci = _PMD.var(pm, nw, :cfi, i)

        faulted_phases = _PMD.ref(pm, nw, :fault, 1)["connections"]
        phase_base_order = get_phase_base_order(faulted_phases)

        alpha = exp(1im*2/3*pi)
        a = 1/3*[1 1 1; 1 alpha alpha^2; 1 alpha^2 alpha] 
        ar = real(a)
        ai = imag(a)

        if length(cr) == 3
            cf0r = JuMP.@expression(pm.model, sum(ar[1,c] * cr[phase_base_order[c]] for c in terminals))
            cf0i = JuMP.@expression(pm.model, sum(ai[1,c] * ci[phase_base_order[c]] for c in terminals))

            cf1r = JuMP.@expression(pm.model, sum(ar[2,c] * cr[phase_base_order[c]] - ai[2,c] * ci[phase_base_order[c]] for c in terminals))
            cf1i = JuMP.@expression(pm.model, sum(ar[2,c] * ci[phase_base_order[c]] + ai[2,c] * cr[phase_base_order[c]] for c in terminals))
     
            cf2r = JuMP.@expression(pm.model, sum(ar[3,c] * cr[phase_base_order[c]] - ai[3,c] * ci[phase_base_order[c]] for c in terminals))
            cf2i = JuMP.@expression(pm.model, sum(ar[3,c] * ci[phase_base_order[c]] + ai[3,c] * cr[phase_base_order[c]] for c in terminals))

        elseif length(cr) == 2
            cf0r = JuMP.@expression(pm.model, sum(ar[1,c] * cr[phase_base_order[c]] for c in 2:3))
            cf0i = JuMP.@expression(pm.model, sum(ai[1,c] * ci[phase_base_order[c]] for c in 2:3))

            cf1r = JuMP.@expression(pm.model, sum(ar[2,c] * cr[phase_base_order[c]] - ai[2,c] * ci[phase_base_order[c]] for c in 2:3))
            cf1i = JuMP.@expression(pm.model, sum(ar[2,c] * ci[phase_base_order[c]] + ai[2,c] * cr[phase_base_order[c]] for c in 2:3))
     
            cf2r = JuMP.@expression(pm.model, sum(ar[3,c] * cr[phase_base_order[c]] - ai[3,c] * ci[phase_base_order[c]] for c in 2:3))
            cf2i = JuMP.@expression(pm.model, sum(ar[3,c] * ci[phase_base_order[c]] + ai[3,c] * cr[phase_base_order[c]] for c in 2:3))

        else
            cf0r = JuMP.@expression(pm.model, ar[1,1] * cr[phase_base_order[1]])
            cf0i = JuMP.@expression(pm.model, ai[1,1] * ci[phase_base_order[1]])

            cf1r = JuMP.@expression(pm.model, ar[2,1] * cr[phase_base_order[1]] - ai[2,1] * ci[phase_base_order[1]])
            cf1i = JuMP.@expression(pm.model, ar[2,1] * ci[phase_base_order[1]] + ai[2,1] * cr[phase_base_order[1]])
     
            cf2r = JuMP.@expression(pm.model, ar[3,1] * cr[phase_base_order[1]] - ai[3,1] * ci[phase_base_order[1]])
            cf2i = JuMP.@expression(pm.model, ar[3,1] * ci[phase_base_order[1]] + ai[3,1] * cr[phase_base_order[1]])
        end

        if report
            _PMD.sol(pm, nw, :fault, i)[:cf0r] = cf0r
            _PMD.sol(pm, nw, :fault, i)[:cf0i] = cf0i
            _PMD.sol(pm, nw, :fault, i)[:cf1r] = cf1r
            _PMD.sol(pm, nw, :fault, i)[:cf1i] = cf1i
            _PMD.sol(pm, nw, :fault, i)[:cf2r] = cf2r
            _PMD.sol(pm, nw, :fault, i)[:cf2i] = cf2i
        end
    end
end



function expression_mc_switch_fault_sequence_current(pm::_PMD.AbstractUnbalancedIVRModel, i::Int; nw::Int=nw_id_default, report::Bool=true)
    switch = _PMD.ref(pm, nw, :switch, i)

    f_connections = switch["f_connections"]
    t_connections = switch["t_connections"]
    
    if length(f_connections) == 3 && length(t_connections) == 3

        f_bus = switch["f_bus"]
        t_bus = switch["t_bus"]
        f_idx = (i, f_bus, t_bus)
        t_idx = (i, t_bus, f_bus)

        cr_fr =  [_PMD.var(pm, nw, :crsw, f_idx)[c] for c in f_connections]
        ci_fr =  [_PMD.var(pm, nw, :cisw, f_idx)[c] for c in f_connections]
        cr_to =  [_PMD.var(pm, nw, :crsw, t_idx)[c] for c in t_connections]
        ci_to =  [_PMD.var(pm, nw, :cisw, t_idx)[c] for c in t_connections]
        
        faulted_phases = _PMD.ref(pm, nw, :fault, 1)["connections"]
        phase_base_order = get_phase_base_order(faulted_phases)

        alpha = exp(1im*2/3*pi)
        a = 1/3*[1 1 1; 1 alpha alpha^2; 1 alpha^2 alpha] 
        ar = real(a)
        ai = imag(a)

        cf0r_fr = JuMP.@expression(pm.model, sum(ar[1,c] * cr_fr[phase_base_order[c]] for c in f_connections))
        cf0i_fr = JuMP.@expression(pm.model, sum(ai[1,c] * ci_fr[phase_base_order[c]] for c in f_connections))
        cf0r_to = JuMP.@expression(pm.model, sum(ar[1,c] * cr_to[phase_base_order[c]] for c in t_connections))
        cf0i_to = JuMP.@expression(pm.model, sum(ai[1,c] * ci_to[phase_base_order[c]] for c in t_connections))

        cf1r_fr = JuMP.@expression(pm.model, sum(ar[2,c] * cr_fr[phase_base_order[c]] - ai[2,c] * ci_fr[phase_base_order[c]] for c in f_connections))
        cf1i_fr = JuMP.@expression(pm.model, sum(ar[2,c] * ci_fr[phase_base_order[c]] + ai[2,c] * cr_fr[phase_base_order[c]] for c in f_connections))
        cf1r_to = JuMP.@expression(pm.model, sum(ar[2,c] * cr_to[phase_base_order[c]] - ai[2,c] * ci_to[phase_base_order[c]] for c in t_connections))
        cf1i_to = JuMP.@expression(pm.model, sum(ar[2,c] * ci_to[phase_base_order[c]] + ai[2,c] * cr_to[phase_base_order[c]] for c in t_connections))
     
        cf2r_fr = JuMP.@expression(pm.model, sum(ar[3,c] * cr_fr[phase_base_order[c]] - ai[3,c] * ci_fr[phase_base_order[c]] for c in f_connections))
        cf2i_fr = JuMP.@expression(pm.model, sum(ar[3,c] * ci_fr[phase_base_order[c]] + ai[3,c] * cr_fr[phase_base_order[c]] for c in f_connections))
        cf2r_to = JuMP.@expression(pm.model, sum(ar[3,c] * cr_to[phase_base_order[c]] - ai[3,c] * ci_to[phase_base_order[c]] for c in t_connections))
        cf2i_to = JuMP.@expression(pm.model, sum(ar[3,c] * ci_to[phase_base_order[c]] + ai[3,c] * cr_to[phase_base_order[c]] for c in t_connections))

        if report
            _PMD.sol(pm, nw, :switch, i)[:cf0r_fr] = cf0r_fr
            _PMD.sol(pm, nw, :switch, i)[:cf0i_fr] = cf0i_fr
            _PMD.sol(pm, nw, :switch, i)[:cf1r_fr] = cf1r_fr
            _PMD.sol(pm, nw, :switch, i)[:cf1i_fr] = cf1i_fr
            _PMD.sol(pm, nw, :switch, i)[:cf2r_fr] = cf2r_fr
            _PMD.sol(pm, nw, :switch, i)[:cf2i_fr] = cf2i_fr
            _PMD.sol(pm, nw, :switch, i)[:cf0r_to] = cf0r_to
            _PMD.sol(pm, nw, :switch, i)[:cf0i_to] = cf0i_to
            _PMD.sol(pm, nw, :switch, i)[:cf1r_to] = cf1r_to
            _PMD.sol(pm, nw, :switch, i)[:cf1i_to] = cf1i_to
            _PMD.sol(pm, nw, :switch, i)[:cf2r_to] = cf2r_to
            _PMD.sol(pm, nw, :switch, i)[:cf2i_to] = cf2i_to
        end
    end
end