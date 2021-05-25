function expression_mc_branch_fault_sequence_current(pm::_PMD.AbstractUnbalancedIVRModel, i::Int; nw::Int=nw_id_default, report::Bool=true)
    branch = _PMD.ref(pm, nw, :branch, i)

    f_connections = branch["f_connections"]

    csr = [c in f_connections ? _PMD.var(pm, nw, :csr, i)[c] : 0.0 for c in 1:3]
    csi = [c in f_connections ? _PMD.var(pm, nw, :csi, i)[c] : 0.0 for c in 1:3]

    cm = [JuMP.@NLexpression(pm.model, sqrt(csr[c]^2 + csi[c]^2)) for c in 1:3]
    ca = [JuMP.@NLexpression(pm.model, atan(csi[c] / csr[c])) for c in 1:3]

    cf0 = JuMP.@NLexpression(pm.model, sqrt(((1/3)*sum(csr[c] for c in 1:3))^2+((1/3)*sum(csi[c] for c in 1:3))^2))
    cf1 = JuMP.@NLexpression(pm.model, sqrt(((1/3)*(csr[1]+cm[2]*cos( 2*pi/3+ca[2])+cm[3]*cos(-2*pi/3+ca[3])))^2+((1/3)*(csi[1]+cm[2]*sin( 2*pi/3+ca[2])+cm[3]*sin(-2*pi/3+ca[3])))^2))
    cf2 = JuMP.@NLexpression(pm.model, sqrt(((1/3)*(csr[1]+cm[2]*cos(-2*pi/3+ca[2])+cm[3]*cos( 2*pi/3+ca[3])))^2+((1/3)*(csi[1]+cm[2]*sin(-2*pi/3+ca[2])+cm[3]*sin( 2*pi/3+ca[3])))^2))

    if report
        _PMD.sol(pm, nw, :branch, i)[:cf0] = cf0
        _PMD.sol(pm, nw, :branch, i)[:cf1] = cf1
        _PMD.sol(pm, nw, :branch, i)[:cf2] = cf2
    end
end
