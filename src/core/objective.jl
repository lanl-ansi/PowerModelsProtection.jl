""
function objective_max_inverter_power(pm::_PM.AbstractIVRModel; report::Bool=true)
    return JuMP.@objective(pm.model, Max,
        sum(
            sum(  var(pm, n, :kg, i) for (i,gen) in nw_ref[:gen] ) 
        for (n, nw_ref) in nws(pm))
    )
end
