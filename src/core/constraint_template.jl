"Check to see if gen is inverter model"
function is_inverter(pm, i, nw)
    gen = ref(pm, nw, :gen, i)

    if !haskey(gen, "inverter")
        return false
    end

    return gen["inverter"] == 1
end


"Checks to see if inverter is operating in pq mode"
function is_pq_inverter(pm, i, nw)
    gen = ref(pm, nw, :gen, i)

    if !haskey(gen, "inverter")
        return false
    end

    if gen["inverter"] == 0
        return false
    end

    if !haskey(gen, "inverter_mode")
    	return false
    end

    return gen["inverter_mode"] == "pq"
end


"Checks to see if inverter is operating in V mode"
function is_v_inverter(pm, i, nw)
    gen = ref(pm, nw, :gen, i)

    if !haskey(gen, "inverter")
        return false
    end

    if gen["inverter"] == 0
        return false
    end

    if !haskey(gen, "inverter_mode")
    	return false
    end

    return gen["inverter_mode"] == "v"
end

"generator reactive power setpoint constraint"
function constraint_mc_gen_power_setpoint_imag(pm::_PM.AbstractPowerModel, i::Int; nw::Int=pm.cnw, kwargs...)
    qg_set = ref(pm, nw, :gen, i)["qg"]
    constraint_mc_gen_power_setpoint_imag(pm, nw, i, qg_set)
end

"Constraint that sets the terminal voltage basd on the internal voltage and the stator impedence"
function constraint_gen_voltage_drop(pm::_PM.AbstractPowerModel; nw::Int=pm.cnw)
    for (k, gen) in ref(pm, nw, :gen)
        i = gen["index"]

        if is_inverter(pm, i, nw)
            continue
        end

        bus_id = gen["gen_bus"]

        r = gen["zr"]
        x = gen["zx"]
        z = r + 1im * x

        p = gen["pg"]
        q = gen["qg"]
        s = p + 1im * q

        vm = ref(pm, :bus, bus_id, "vm")
        va = ref(pm, :bus, bus_id, "va")
        v = vm * exp(1im * va)

        vr = real(v)
        vi = imag(v)
        @debug "vr = $vr, vi = $vi"

        c = conj(s / v)
        vg = v + z * c # add an option here to disable pre-computed voltage drop
        vgr = real(vg)
        vgi = imag(vg)
        @debug "Compensated vg: vgr = $vgr, vgi = $vgi"


        constraint_gen_voltage_drop(pm, nw, i, bus_id, r, x, vgr, vgi)
    end
end


"Constraints for fault current contribution of inverter in grid-following mode with pq set points"
function constraint_pq_inverter(pm::_PM.AbstractPowerModel; nw::Int=pm.cnw)
    for (k, gen) in ref(pm, nw, :gen)
        i = gen["index"]

        if !is_pq_inverter(pm, i, nw)
            continue
        end

        bus_id = gen["gen_bus"]

        r = gen["zr"]
        pg = gen["pg"]
        qg = gen["qg"]

        smax = abs(max(abs(gen["pmax"]), abs(gen["pmin"])) + max(abs(gen["qmax"]), abs(gen["qmin"])) * 1im)
        cmax = 1.1 * smax

        # constraint_pq_inverter(pm, nw, i, bus_id, pg, qg, cmax)
        constraint_unity_pf_inverter(pm, nw, i, bus_id, pg, qg, cmax)
    end
end


"Constraints for fault current contribution of inverter in grid-following mode assuming that the inverter current regulating loop operates slowly"
function constraint_i_inverter(pm::_PM.AbstractPowerModel; nw::Int=pm.cnw)
    for (k, gen) in ref(pm, nw, :gen)
        i = gen["index"]

        if !is_pq_inverter(pm, i, nw)
            continue
        end

            bus_id = gen["gen_bus"]
        bus = ref(pm, nw, :bus, bus_id)

        r = gen["zr"]
        pg = gen["pg"]
        qg = gen["qg"]

        cm = abs(gen["pg"] + 1im * gen["qg"]) / bus["vm"]

        constraint_i_inverter_vs(pm, nw, i, bus_id, r, pg, qg, cm)
    end
end


"Constraints for fault current contribution of inverter in grid-forming mode"
function constraint_v_inverter(pm::_PM.AbstractPowerModel; nw::Int=pm.cnw)
    for (k, gen) in ref(pm, nw, :gen)
        i = gen["index"]

        if !is_v_inverter(pm, i, nw)
            continue
        end

        bus_id = gen["gen_bus"]
        bus = ref(pm, nw, :bus, bus_id)

        vm = ref(pm, :bus, bus_id, "vm")
        va = ref(pm, :bus, bus_id, "va")

        vgr = vm * cos(va)
        vgi = vm * sin(va)

        r = gen["zr"]
        x = gen["zx"]

        pg = gen["pg"]
        qg = gen["qg"]

        smax = abs(max(abs(gen["pmax"]), abs(gen["pmin"])) + max(abs(gen["qmax"]), abs(gen["qmin"])) * 1im)
        cmax = 1.1 * smax

        constraint_v_inverter(pm, nw, i, bus_id, r, x, vgr, vgi, cmax)
    end
end


"Constraint to calculate the fault current at a bus and the current at other buses"
function constraint_current_balance(pm::_PM.AbstractPowerModel, i::Int; nw::Int=pm.cnw)
    bus = ref(pm, nw, :bus, i)["bus_i"]
    bus_arcs = ref(pm, nw, :bus_arcs, i)
    bus_gens = ref(pm, nw, :bus_gens, i)
    bus_shunts = ref(pm, nw, :bus_shunts, i)

    bus_gs = Dict(k => ref(pm, nw, :shunt, k, "gs") for k in bus_shunts)
    bus_bs = Dict(k => ref(pm, nw, :shunt, k, "bs") for k in bus_shunts)

    if bus != ref(pm, nw, :active_fault, "bus_i")
        constraint_current_balance(pm, nw, i, bus_arcs, bus_gens, bus_gs, bus_bs)
    else
        constraint_fault_current_balance(pm, nw, i, bus_arcs, bus_gens, bus_gs, bus_bs, bus)
    end
end


"Constraint that sets the terminal voltage basd on the internal voltage and the stator impedence for multiconductor"
function constraint_mc_gen_voltage_drop(pm::_PM.AbstractPowerModel; nw::Int=pm.cnw)
    for (k, gen) in ref(pm, nw, :gen)

        if k in ids(pm, :solar_gfli)
            Memento.info(_LOGGER, "Skipping gen $k in gen constraints")
            continue
        end

        if !("zr" in keys(gen))
            Memento.info(_LOGGER, "Skipping gen $k in gen constraints")
            continue
        end

        if gen["source_id"] == "_virtual_gen.vsource.source"
            Memento.info(_LOGGER, "Skipping gen $k in gen constraints")
            continue
        end

        Memento.info(_LOGGER, "Adding voltage drop constraint for generator $k")

        i = gen["index"]
        bus_id = gen["gen_bus"]

        r = gen["zr"]
        x = gen["zx"]

        # only 3 phase generation is supported
        terminals = length(gen["connections"])
        if terminals == 3
            vm = [1, 1, 1]
            va = [0, -2*pi/3, 2*pi/3]

            if "vm" in keys(ref(pm, :bus, bus_id))
                vm = ref(pm, :bus, bus_id, "vm")
            else
                Memento.warn(_LOGGER, "vm not specified for bus $bus_id, assuming 1")
            end

            if "va" in keys(ref(pm, :bus, bus_id))
                va = ref(pm, :bus, bus_id, "va")
            else
                Memento.warn(_LOGGER, "va not specified for bus $bus_id, assuming 0")
            end

            mva = 100
            kva = 1e3*mva
            sb = 1e6*mva

            kv = 4.16
            vb = 1000*kv

            pg = gen["pg"]
            qg = gen["qg"]
            sg = pg + 1im*qg

            vr = [vm[i] * cos(va[i]) for i in 1:3]
            vi = [vm[i] * sin(va[i]) for i in 1:3]

            v = vr + 1im*vi
            cg = [conj(sg[i]/v[i]) for i in 1:3]
            z = r + 1im*x
            vg = [v[i] + (z[i]*cg[i]) for i in 1:3]

            vgr = real(vg)
            vgi = imag(vg)

            @debug "Generator terminal voltage from pre-fault powerflow" abs.(v[1])

            @debug "Generator pre-fault power (kVA)" kva*sg[1]

            ssi = sb*sg[1]
            vsi = vb*v[1]/sqrt(3)
            isi = ssi/vsi

            @debug "Generator pre-fault current (A)" abs(isi)
            @debug "Calculated generator internal voltage" abs.(vg[1])

            constraint_mc_gen_voltage_drop(pm, nw, i, bus_id, r, x, vr, vi, terminals)
        end
    end
end

"Constraints for fault current contribution of multiconductor inverter in grid-following mode"
function constraint_mc_pq_inverter(pm::_PM.AbstractPowerModel, i::Int; nw::Int=pm.cnw)
    index = pm.ref[:nw][nw][:solar_gfli][i]
    gen = pm.ref[:nw][nw][:gen][i]

    cmax = gen["i_max"]
    if gen["solar_max"] < gen["kva"] * gen["pf"]
        pmax = gen["solar_max"]
    else
        pmax = gen["kva"] * gen["pf"]
    end
    constraint_mc_pq_inverter(pm, nw, i, index, pmax, 0.0, cmax)
end


"Constraints for fault current contribution of multiconductor inverter in grid-forming mode"
function constraint_mc_grid_forming_inverter(pm::_PM.AbstractPowerModel, i::Int; nw::Int=pm.cnw)
    Memento.info(_LOGGER, "Adding grid-forming inverter constraint without impedance")
    index = pm.ref[:nw][nw][:solar_gfmi][i]
    gen = pm.ref[:nw][nw][:gen][index]
    bus_i = gen["gen_bus"]
    bus = pm.ref[:nw][nw][:bus][bus_i]

    if !haskey(bus, "vm") && !haskey(bus, "va")
        bus["vm"] = [1 for c in _PM.conductor_ids(pm; nw=nw)]
        bus["va"] = [0, -2*pi/3, 2*pi/3]
    end

    cmax = gen["i_max"]
    vrstar = [bus["vm"][c] * cos(bus["va"][c]) for c in _PM.conductor_ids(pm; nw=nw)]
    vistar = [bus["vm"][c] * sin(bus["va"][c]) for c in _PM.conductor_ids(pm; nw=nw)]

    # push into pmax on import and erase this
    if gen["solar_max"] < gen["kva"]
        pmax = gen["solar_max"]
    else
        pmax = gen["kva"]
    end

    constraint_grid_forming_inverter(pm, nw, index, i, vrstar, vistar, pmax, cmax)
end


"Constraints for fault current contribution of multiconductor inverter in grid-forming mode with power matching"
function constraint_mc_grid_forming_inverter_impedance(pm::_PM.AbstractPowerModel, i::Int; nw::Int=pm.cnw)
    index = pm.ref[:nw][nw][:solar_gfmi][i]
    gen = pm.ref[:nw][nw][:gen][index]
    bus_i = gen["gen_bus"]
    bus = pm.ref[:nw][nw][:bus][bus_i]

    if !haskey(bus, "vm") && !haskey(bus, "va")
        bus["vm"] = [1 for c in _PM.conductor_ids(pm; nw=nw)]
        bus["va"] = [0, -2*pi/3, 2*pi/3]
    end

    cmax = gen["i_max"]
    vrstar = [bus["vm"][c] * cos(bus["va"][c]) for c in _PM.conductor_ids(pm; nw=nw)]
    vistar = [bus["vm"][c] * sin(bus["va"][c]) for c in _PM.conductor_ids(pm; nw=nw)]

    # push into pmax on import and erase this
    if gen["solar_max"] < gen["kva"]
        pmax = gen["solar_max"]
    else
        pmax = gen["kva"]
    end

    r = 0.1*ones(3)
    x = [0, 0, 0]

    if "r" in keys(gen)
        r = gen["zr"]
    end

    if "x" in keys(gen)
        x = gen["zx"]
    end

    constraint_grid_formimg_inverter_impedance(pm, nw, index, i, vrstar, vistar, r, x, pmax, cmax)
end

"Constraints for fault current contribution of multiconductor inverter in grid-forming mode with power matching"
function constraint_mc_grid_forming_inverter_virtual_impedance(pm::_PM.AbstractPowerModel, i::Int; nw::Int=pm.cnw)
    index = pm.ref[:nw][nw][:solar_gfmi][i]
    gen = pm.ref[:nw][nw][:gen][i]
    bus_i = gen["gen_bus"]
    bus = pm.ref[:nw][nw][:bus][bus_i]
    terminals = bus["terminals"]
    bus["bus_type"] == 5 ? ang = true : ang = false

    if !haskey(bus, "vm") && !haskey(bus, "va")
        vm = [.995 for c in bus["terminals"]]
        va = [0 -2*pi/3 2*pi/3]
    else
        vm = bus["vm"]
        va = bus["va"]
    end

    vm = [.995 for c in terminals]
    va = [0 -2*pi/3 2*pi/3]

    cmax = gen["i_max"]
    vr = [vm[c] * cos(va[c]) for c in terminals]
    vi = [vm[c] * sin(va[c]) for c in terminals]

    # push into pmax on import and erase this
    if gen["solar_max"] < gen["kva"]
        pmax = gen["solar_max"]
    else
        pmax = gen["kva"]
    end

    smax = gen["kva"]

    constraint_mc_grid_formimg_inverter_virtual_impedance(pm, nw, i, index, vr, vi, pmax, cmax, smax, ang, terminals)
end


"Constraint to calculate the fault current at a bus and the current at other buses for multiconductor"
function constraint_mc_current_balance(pm::_PM.AbstractPowerModel, i::Int; nw::Int=pm.cnw)
    bus = ref(pm, nw, :bus, i)
    bus_arcs = ref(pm, nw, :bus_arcs_conns_branch, i)
    bus_arcs_sw = ref(pm, nw, :bus_arcs_conns_switch, i)
    bus_arcs_trans = ref(pm, nw, :bus_arcs_conns_transformer, i)
    bus_gens = ref(pm, nw, :bus_conns_gen, i)
    bus_storage = ref(pm, nw, :bus_conns_storage, i)
    bus_shunts = ref(pm, nw, :bus_conns_shunt, i)


    if bus["bus_i"] != ref(pm, nw, :active_fault, "bus_i")
        constraint_mc_current_balance(pm, nw, i, bus["terminals"], bus["grounded"], bus_arcs, bus_arcs_sw, bus_arcs_trans, bus_gens, bus_storage, bus_shunts)
    else
        constraint_mc_fault_current_balance(pm, nw, i, bus["terminals"], bus["grounded"], bus_arcs, bus_arcs_sw, bus_arcs_trans, bus_gens, bus_storage, bus_shunts)
    end
end


""
function constraint_mc_current_balance_pf(pm::_PM.AbstractPowerModel, i::Int; nw::Int=pm.cnw)
    bus = ref(pm, nw, :bus, i)["bus_i"]
    bus_arcs = ref(pm, nw, :bus_arcs, i)
    bus_arcs_sw = ref(pm, nw, :bus_arcs_sw, i)
    bus_arcs_trans = ref(pm, nw, :bus_arcs_trans, i)
    bus_gens = ref(pm, nw, :bus_gens, i)
    bus_shunts = ref(pm, nw, :bus_shunts, i)

    bus_gs = Dict(k => ref(pm, nw, :shunt, k, "gs") for k in bus_shunts)
    bus_bs = Dict(k => ref(pm, nw, :shunt, k, "bs") for k in bus_shunts)

    constraint_mc_current_balance(pm, nw, i, bus_arcs, bus_arcs_sw, bus_arcs_trans, bus_gens, bus_gs, bus_bs)
end


"Constraint on the current from gen based on connection"
function constraint_mc_generation(pm::_PM.AbstractPowerModel, id::Int; nw::Int=pm.cnw, report::Bool=true, bounded::Bool=true)
    generator = ref(pm, nw, :gen, id)
    bus = ref(pm, nw, :bus, generator["gen_bus"])

    if get(generator, "configuration", _PMD.WYE) == _PMD.WYE
        constraint_mc_generation_wye(pm, nw, id, bus["index"], generator["connections"]; report=report, bounded=bounded)
    else
        constraint_mc_generation_delta(pm, nw, id, bus["index"], generator["connections"]; report=report, bounded=bounded)
    end
end


"Constarint to set the ref bus voltage"
function constraint_mc_ref_bus_voltage(pm::_PM.AbstractIVRModel, i::Int; nw::Int=pm.cnw)
    terminals = ref(pm, nw, :bus, i)["terminals"]
    vm = ref(pm, :bus, i, "vm")
    va = ref(pm, :bus, i, "va")

    vr = [vm[i] * cos(va[i]) for i in terminals]
    vi = [vm[i] * sin(va[i]) for i in terminals]

    constraint_mc_ref_bus_voltage(pm, nw, i, vr, vi, terminals)
end


"Constarint to set the ref bus voltage magnitude only"
function constraint_mc_voltage_magnitude_only(pm::_PM.AbstractIVRModel, i::Int; nw::Int=pm.cnw)
    vm = ref(pm, :bus, i, "vm")
    constraint_mc_voltage_magnitude_only(pm, nw, i, vm)
end


function constraint_mc_switch_state(pm::_PM.AbstractPowerModel, i::Int; nw::Int=pm.cnw)
    switch = ref(pm, nw, :switch, i)
    f_bus = switch["f_bus"]
    t_bus = switch["t_bus"]
    z = switch["z"]

    f_idx = (i, f_bus, t_bus)

    if switch["state"] != 0
        constraint_mc_switch_state_closed(pm, nw, f_bus, t_bus, f_idx, switch["f_connections"], switch["t_connections"], z)
    else
        _PMD.constraint_mc_switch_state_open(pm, nw, f_idx)
    end
end


function constraint_mc_storage_grid_forming_inverter(pm::_PM.AbstractPowerModel, i::Int; nw::Int=pm.cnw)
    storage = pm.ref[:nw][nw][:storage][i]
    haskey(storage, "i_max") ? nothing : storage["i_max"] = 1.5*storage["dss"]["kva"] / (3 * 1000 * pm.ref[:nw][0][:baseMVA])
    connections = storage["connections"]
    bus_i = storage["storage_bus"]
    bus = pm.ref[:nw][nw][:bus][bus_i]
    bus["bus_type"] == 5 ? ang = true : ang = false
    vm = [1.00 for c in connections]
    va = [0 -2*pi/3 2*pi/3]
    cmax = storage["i_max"]
    vr = [vm[c] * cos(va[c]) for c in connections]
    vi = [vm[c] * sin(va[c]) for c in connections]
    pmax = storage["thermal_rating"]
    qmin = storage["qmin"]
    qmax = storage["qmax"]
    smax = storage["kva"]

    constraint_mc_storage_grid_formimg_inverter(pm, nw, i, bus_i, vr, vi, pmax, qmax, qmin, cmax, smax, ang, connections)
end

function constraint_pf_mc_storage_grid_forming_inverter(pm::_PM.AbstractPowerModel, i::Int; nw::Int=pm.cnw)
    storage = pm.ref[:nw][nw][:storage][i]
    haskey(storage, "i_max") ? nothing : storage["i_max"] = 1.5*storage["dss"]["kva"] / (3 * 1000 * pm.ref[:nw][0][:baseMVA])
    connections = storage["connections"]
    bus_i = storage["storage_bus"]
    bus = pm.ref[:nw][nw][:bus][bus_i]
    bus["bus_type"] == 5 ? ang = true : ang = false
    vm = [1.000 for c in connections]
    va = [0 -2*pi/3 2*pi/3]
    cmax = storage["i_max"]
    vr = [vm[c] * cos(va[c]) for c in connections]
    vi = [vm[c] * sin(va[c]) for c in connections]
    pmax = storage["thermal_rating"]
    qmin = storage["qmin"]
    qmax = storage["qmax"]
    smax = storage["kva"]
    energy = storage["energy"]
    energy_rating = storage["energy_rating"]

    constraint_pf_mc_storage_grid_formimg_inverter(pm, nw, i, bus_i, vr, vi, pmax, qmax, qmin, cmax, smax, energy, energy_rating, ang, connections)
end


"Constraints for fault current contribution of multiconductor inverter in grid-following mode"
function constraint_mc_pf_pq_inverter(pm::_PM.AbstractPowerModel, i::Int; nw::Int=pm.cnw)
    index = pm.ref[:nw][nw][:solar_gfli][i]
    gen = pm.ref[:nw][nw][:gen][i]
    connections = gen["connections"]
    cmax = gen["i_max"]
    if gen["solar_max"] < gen["kva"] * gen["pf"]
        pmax = gen["solar_max"]
    else
        pmax = gen["kva"] * gen["pf"]
    end
    smax = gen["kva"]
    constraint_mc_pf_pq_inverter(pm, nw, i, index, pmax, cmax, smax, connections)
end