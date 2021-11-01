"""
	v_gen_buses(nw_ref)

helper function to get gen buses where inverter_mode on the generator is 'v'
"""
function v_gen_buses(nw_ref)
	v_gen_bus_ids = Set(gen["gen_bus"] for (i, gen) in nw_ref[:gen] if gen["inverter_mode"] == "v")
    return [(i, bus) for (i, bus) in nw_ref[:bus] if i in v_gen_bus_ids]
end


"""
	pq_gens(nw_ref)

helper function to get gens where inverter_mode is 'pq'
"""
function pq_gens(nw_ref)
	return [(i, gen) for (i, gen) in nw_ref[:gen] if gen["inverter_mode"] == "pq"]
end


"""
    objective_min_inverter_voltage_regulation(pm::_PM.AbstractIVRModel)

Tries to minimize the voltage regulation on gen buses where inverter_mode is 'v' on the generator
"""
function objective_min_inverter_voltage_regulation(pm::_PM.AbstractIVRModel)
    return JuMP.@objective(pm.model, Min,
        sum(
            sum(
                (_PM.var(pm, n, :vr, i) - bus["vm"] * cos(bus["va"]))^2
                + (_PM.var(pm, n, :vi, i) - bus["vm"] * sin(bus["va"]))^2
                for (i, bus) in v_gen_buses(nw_ref)
            ) for (n, nw_ref) in _PM.nws(pm)
        )
    )
end


"""
    objective_max_inverter_power(pm::_PM.AbstractIVRModel)

Tries to maximize the power from an inverter
"""
function objective_max_inverter_power(pm::_PM.AbstractIVRModel)
    return JuMP.@objective(pm.model, Min,
        sum(
            - sum(_PM.var(pm, n, :crg, i)^2 - _PM.var(pm, n, :cig, i)^2 for (i, gen) in pq_gens(nw_ref))
        for (n, nw_ref) in _PM.nws(pm))
    )
end


"""
    objective_min_inverter_error(pm::_PM.AbstractIVRModel)

Tries to minimize the power from an inverter
"""
function objective_min_inverter_error(pm::_PM.AbstractIVRModel)
    return JuMP.@objective(pm.model, Min,
        sum(
            sum(
                (_PM.var(pm, n, :vr, i) - bus["vm"] * cos(bus["va"]))^2
                + (_PM.var(pm, n, :vi, i) - bus["vm"] * sin(bus["va"]))^2
                for (i, bus) in v_gen_buses(nw_ref))
            - sum(_PM.var(pm, n, :crg, i)^2 - _PM.var(pm, n, :cig, i)^2 for (i, gen) in pq_gens(nw_ref))
        for (n, nw_ref) in _PM.nws(pm))
    )
end
