""
function objective_max_inverter_power(pm::_PM.AbstractIVRModel; report::Bool=true)
	v_buses = Set(gen["gen_bus"] for (i,gen) in nw_ref[:gen] if gen["v_mode"] == 1)
	pq_buses = Set(gen["gen_bus"] for (i,gen) in nw_ref[:gen] if gen["pq_mode"] == 1)

    return JuMP.@objective(pm.model, Min,
        sum(
        	    sum(  
        	  		  (var(pm, n, :vr, i) - bus["vm"]*cos(bus["va"]))^2 
        	  		+ (var(pm, n, :vi, i) - bus["vm"]*sin(bus["va"]))^2 
        	  	for (i,bus) in nw_ref[:bus] if i in v_buses)
            - sum(  var(pm, n, :kg, i) for (i,gen) in nw_ref[:gen] if i in pq_buses) 
        for (n, nw_ref) in nws(pm))
    )
end
