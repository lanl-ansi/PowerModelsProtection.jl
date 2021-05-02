""
function v_gen_buses(nw_ref)
	v_gen_bus_ids = Set(gen["gen_bus"] for (i, gen) in nw_ref[:gen] if gen["inverter_mode"] == "v")
    return [(i, bus) for (i, bus) in nw_ref[:bus] if i in v_gen_bus_ids]
end


""
function pq_gens(nw_ref)
	return [(i, gen) for (i, gen) in nw_ref[:gen] if gen["inverter_mode"] == "pq"]
end


""
function objective_min_inverter_voltage_regulation(pm::_PMD.AbstractUnbalancedIVRModel; report::Bool=true)
    return JuMP.@objective(pm.model, Min,
        sum(
            sum(
                (var(pm, n, :vr, i) - bus["vm"] * cos(bus["va"]))^2
                + (var(pm, n, :vi, i) - bus["vm"] * sin(bus["va"]))^2
                for (i, bus) in v_gen_buses(nw_ref)
            ) for (n, nw_ref) in nws(pm)
        )
    )
end


"Tries to maximize the power from an inverter"
function objective_max_inverter_power(pm::_PMD.AbstractUnbalancedIVRModel; report::Bool=true)
    return JuMP.@objective(pm.model, Min,
        sum(
            - sum(var(pm, n, :crg, i)^2 - var(pm, n, :cig, i)^2 for (i, gen) in pq_gens(nw_ref))
        for (n, nw_ref) in nws(pm))
    )
end


"Tries to minimize the power from an inverter"
function objective_min_inverter_error(pm::_PMD.AbstractUnbalancedIVRModel; report::Bool=true)
    return JuMP.@objective(pm.model, Min,
        sum(
            sum(
                (var(pm, n, :vr, i) - bus["vm"] * cos(bus["va"]))^2
                + (var(pm, n, :vi, i) - bus["vm"] * sin(bus["va"]))^2
                for (i, bus) in v_gen_buses(nw_ref))
            - sum(var(pm, n, :crg, i)^2 - var(pm, n, :cig, i)^2 for (i, gen) in pq_gens(nw_ref))
        for (n, nw_ref) in nws(pm))
    )
end
