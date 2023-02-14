"""
	is_inverter(pm, i::Int, nw::Int=nw_id_default)

Check to see if gen is inverter model
"""
function is_inverter(pm::_PM.AbstractPowerModel, i::Int, nw::Int=nw_id_default)
    gen = _PM.ref(pm, nw, :gen, i)

    if !haskey(gen, "inverter")
        return false
    end

    return gen["inverter"] == 1
end


"""
	is_pq_inverter(pm, i::Int, nw::Int=nw_id_default)

Checks to see if inverter is operating in pq mode
"""
function is_pq_inverter(pm::_PM.AbstractPowerModel, i::Int, nw::Int=nw_id_default)
    gen = _PM.ref(pm, nw, :gen, i)

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


"""
	is_v_inverter(pm, i::Int, nw::Int=nw_id_default)

Checks to see if inverter is operating in V mode
"""
function is_v_inverter(pm::_PM.AbstractPowerModel, i::Int, nw::Int=nw_id_default)
    gen = _PM.ref(pm, nw, :gen, i)

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


"""
	constraint_bus_fault_current(pm::_PM.AbstractIVRModel, i::Int; nw::Int=nw_id_default)

constraint for the fault current at the fault_bus
"""
function constraint_bus_fault_current(pm::_PM.AbstractIVRModel, i::Int; nw::Int=nw_id_default)
    constraint_bus_fault_current(pm, nw, i, _PM.ref(pm, nw, :fault, i, "fault_bus"), _PM.ref(pm, nw, :fault, i, "gf"))
end


"""
	constraint_mc_gen_power_setpoint_imag(pm::_PMD.AbstractUnbalancedPowerModel, i::Int; nw::Int=nw_id_default, kwargs...)

generator reactive power setpoint constraint
"""
function constraint_mc_gen_power_setpoint_imag(pm::_PMD.AbstractUnbalancedPowerModel, i::Int; nw::Int=nw_id_default)
    qg_set = _PMD.ref(pm, nw, :gen, i, "qg")
    constraint_mc_gen_power_setpoint_imag(pm, nw, i, qg_set)
end

"""
	constraint_gen_voltage_drop(pm::_PM.AbstractPowerModel; nw::Int=nw_id_default)

Constraint that sets the terminal voltage basd on the internal voltage and the stator impedence
"""
function constraint_gen_voltage_drop(pm::_PM.AbstractPowerModel; nw::Int=nw_id_default)
    for (k, gen) in _PM.ref(pm, nw, :gen)
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

        vm = _PM.ref(pm, :bus, bus_id, "vm")
        va = _PM.ref(pm, :bus, bus_id, "va")
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


"""
	constraint_pq_inverter(pm::_PM.AbstractPowerModel; nw::Int=nw_id_default)

Constraints for fault current contribution of inverter in grid-following mode with pq set points
"""
function constraint_pq_inverter(pm::_PM.AbstractPowerModel; nw::Int=nw_id_default)
    for (k, gen) in _PM.ref(pm, nw, :gen)
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


"""
	constraint_i_inverter(pm::_PM.AbstractPowerModel; nw::Int=nw_id_default)

Constraints for fault current contribution of inverter in grid-following mode assuming that the inverter current regulating loop operates slowly
"""
function constraint_i_inverter(pm::_PM.AbstractPowerModel; nw::Int=nw_id_default)
    for (k, gen) in _PM.ref(pm, nw, :gen)
        i = gen["index"]

        if !is_pq_inverter(pm, i, nw)
            continue
        end

        bus_id = gen["gen_bus"]
        bus = _PM.ref(pm, nw, :bus, bus_id)

        r = gen["zr"]
        pg = gen["pg"]
        qg = gen["qg"]

        cm = abs(gen["pg"] + 1im * gen["qg"]) / bus["vm"]

        constraint_i_inverter_vs(pm, nw, i, bus_id, r, pg, qg, cm)
    end
end


"""
	constraint_v_inverter(pm::_PM.AbstractPowerModel; nw::Int=nw_id_default)

Constraints for fault current contribution of inverter in grid-forming mode
"""
function constraint_v_inverter(pm::_PM.AbstractPowerModel; nw::Int=nw_id_default)
    for (k, gen) in _PM.ref(pm, nw, :gen)
        i = gen["index"]

        if !is_v_inverter(pm, i, nw)
            continue
        end

        bus_id = gen["gen_bus"]
        bus = _PM.ref(pm, nw, :bus, bus_id)

        vm = _PM.ref(pm, :bus, bus_id, "vm")
        va = _PM.ref(pm, :bus, bus_id, "va")

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


"""
	constraint_current_balance(pm::_PM.AbstractPowerModel, i::Int; nw::Int=nw_id_default)

Constraint to calculate the fault current at a bus and the current at other buses
"""
function constraint_current_balance(pm::_PM.AbstractPowerModel, i::Int; nw::Int=nw_id_default)
    bus_arcs = _PM.ref(pm, nw, :bus_arcs, i)
    bus_gens = _PM.ref(pm, nw, :bus_gens, i)
    bus_shunts = _PM.ref(pm, nw, :bus_shunts, i)

    bus_gs = Dict(k => _PM.ref(pm, nw, :shunt, k, "gs") for k in bus_shunts)
    bus_bs = Dict(k => _PM.ref(pm, nw, :shunt, k, "bs") for k in bus_shunts)

    if i in _PM.ids(pm, nw, :fault_buses)
        constraint_fault_current_balance(pm, nw, i, bus_arcs, bus_gens, bus_gs, bus_bs)
    else
        constraint_current_balance(pm, nw, i, bus_arcs, bus_gens, bus_gs, bus_bs)
    end
end


"""
"""
function constraint_mc_pf_generator_constant_power(pm::_PMD.AbstractUnbalancedPowerModel, i::Int; nw::Int=nw_id_default)
    gen =  _PMD.ref(pm, nw, :gen, i)
    if haskey(gen, "gen_model") && gen["gen_model"] == 1
        connections = gen["connections"]
        bus_id = gen["gen_bus"]
        kw = gen["pg"]
        kvar = gen["qg"]
        constraint_mc_pf_generator_constant_power(pm, nw, i, bus_id, kw, kvar, connections)
    end
end


"""
"""
function constraint_mc_opf_generator_constant_power(pm::_PMD.AbstractUnbalancedPowerModel, i::Int; nw::Int=nw_id_default)
    gen =  _PMD.ref(pm, nw, :gen, i)
    if haskey(gen, "gen_model") && gen["gen_model"] == 1
        connections = gen["connections"]
        bus_id = gen["gen_bus"]
        pf_ratio = tan(acos(gen["pf"]))
        constraint_mc_opf_generator_constant_power(pm, nw, i, bus_id, connections, pf_ratio)
    end
end


"""
"""
function constraint_mc_fs_generator_constant_power(pm::_PMD.AbstractUnbalancedIVRModel, i::Int; nw::Int=nw_id_default)
    gen =  _PMD.ref(pm, nw, :gen, i)
    if haskey(gen, "gen_model") && gen["gen_model"] == 1
        connections = gen["connections"]
        bus_id = gen["gen_bus"]
        kw = gen["pg"]
        kvar = gen["qg"]
        vr = real.([1, exp.(-2im/3), exp.(2im/3)])
        vi = imag.([1, exp.(-2im/3), exp.(2im/3)])
        s = conj.(kw + kvar .* 1im)
        v = vr.^2 + vi.^2
        z = 1 ./ s ./ 4
        constraint_mc_fs_generator_constant_power(pm, nw, i, bus_id, vr, vi, z, connections)
    end
end



"""
	constraint_mc_gen_voltage_drop(pm::_PMD.AbstractUnbalancedPowerModel; nw::Int=nw_id_default)

Constraint that sets the terminal voltage basd on the internal voltage and the stator impedence for multiconductor
"""
function constraint_mc_gen_voltage_drop(pm::_PMD.AbstractUnbalancedPowerModel, i::Int; nw::Int=nw_id_default)
    gen =  _PMD.ref(pm, nw, :gen, i)
    if haskey(gen, "gen_model")
        if gen["gen_model"] == 3
            bus_id = gen["gen_bus"]
            bus = _PMD.ref(pm, nw, :bus, bus_id)
            terminals = gen["connections"]
            if haskey(bus, "vr")
                vr = bus["vr"]
                vi = bus["vi"]
            else
                @warn "No power flow solution found for bus $bus_id, assuming 1"
                v = [1 1*exp(-1im*pi/3) 1*exp(1im*pi/3)]
                vr = real.(v)
                vi = imag.(v)
            end
            rp = gen["rp"]
            xdp = gen["xdp"]
            terminals = gen["connections"]

            constraint_mc_gen_voltage_drop(pm, nw, i, bus_id, rp, xdp, vr, vi, terminals)
        end
    end
end


"""
	constraint_mc_generator_pq_constant_inverter(pm::_PMD.AbstractUnbalancedIVRModel; nw::Int=nw_id_default)

Constraint that sets the gen to output constant power
"""
function constraint_mc_opf_generator_pq_constant_inverter(pm::_PMD.AbstractUnbalancedIVRModel, i::Int; nw::Int=nw_id_default)
    gen = _PMD.ref(pm, nw, :gen, i)
    if haskey(gen, "gen_model") && gen["gen_model"] == 7 && !(i in _PMD.ref(pm, nw, :solar_gfli)) && !(i in _PMD.ref(pm, nw, :solar_gfmi))
        connections = gen["connections"]
        bus_id = gen["gen_bus"]
        constraint_mc_opf_generator_pq_constant_inverter(pm, nw, i, bus_id, connections)
    end
end


"""
"""
function constraint_mc_fs_generator_pq_constant_inverter(pm::_PMD.AbstractUnbalancedIVRModel, i::Int; nw::Int=nw_id_default)
    gen = _PMD.ref(pm, nw, :gen, i)
    if haskey(gen, "gen_model") && gen["gen_model"] == 7 && !(i in _PMD.ref(pm, nw, :solar_gfli)) && !(i in _PMD.ref(pm, nw, :solar_gfmi))
        connections = gen["connections"]
        bus_id = gen["gen_bus"]
    end
end


"""
"""
function constraint_mc_opf_generator_grid_forming_inverter(pm::_PMD.AbstractUnbalancedIVRModel, i::Int; nw::Int=nw_id_default)
    gen = _PMD.ref(pm, nw, :gen, i)
    if haskey(gen, "gen_model") && gen["gen_model"] == 7 && i in _PMD.ref(pm, nw, :solar_gfmi)
        constraint_mc_opf_generator_pq_constant_inverter(pm, nw, i, gen["gen_bus"], gen["connections"])
    end
end


"""
"""
function constraint_mc_fs_generator_grid_forming_inverter(pm::_PMD.AbstractUnbalancedIVRModel, i::Int; nw::Int=nw_id_default)
    gen = _PMD.ref(pm, nw, :gen, i)
    if haskey(gen, "gen_model") && gen["gen_model"] == 7 && i in _PMD.ref(pm, nw, :solar_gfmi)
        connections = gen["connections"]
        bus_id = gen["gen_bus"]
        pg = gen["pg"]
        imax = gen["imax"]
        # constraint_mc_fs_generator_grid_forming_inverter(pm, nw, i, bus_id, pg, imax, connections)
    end
end


"""
"""
function constraint_mc_fs_generator_grid_following_inverter(pm::_PMD.AbstractUnbalancedIVRModel, i::Int; nw::Int=nw_id_default)
    gen = _PMD.ref(pm, nw, :gen, i)
    if haskey(gen, "gen_model") && gen["gen_model"] == 7 && i in _PMD.ref(pm, nw, :solar_gfli)
        connections = gen["connections"]
        bus_id = gen["gen_bus"]
        pg = gen["pg"]
        # imax = gen["pg"] ./ 0.90
        imax = gen["imax"]
        constraint_mc_fs_generator_grid_following_inverter(pm, nw, i, bus_id, pg, imax, connections)
    end
end


"""
	constraint_mc_pq_inverter(pm::_PMD.AbstractUnbalancedPowerModel, i::Int; nw::Int=nw_id_default)

Constraints for fault current contribution of multiconductor inverter in grid-following mode
"""
function constraint_mc_generator_pq_inverter(pm::_PMD.AbstractUnbalancedPowerModel, i::Int; nw::Int=nw_id_default)
    index = _PMD.ref(pm, nw, :solar_gfli, i)
    gen = _PMD.ref(pm, nw, :gen, i)
    imax = gen["imax"]
    pg = gen["pg"] # need to make sure pg is based on irrand pmpp
    qg = gen["qg"]
    qmax = gen["qmax"]
    qmin = gen["qmin"]
    connections = gen["connections"]
    constraint_mc_pq_inverter(pm, nw, i, index, pg, qg, qmax, qmin, imax, connections)
end


"""
	constraint_mc_grid_forming_inverter(pm::_PMD.AbstractUnbalancedPowerModel, i::Int; nw::Int=nw_id_default)

Constraints for fault current contribution of multiconductor inverter in grid-forming mode
"""
function constraint_mc_grid_forming_inverter(pm::_PMD.AbstractUnbalancedPowerModel, i::Int; nw::Int=nw_id_default)
    @debug "Adding grid-forming inverter constraint without impedance"
    index = _PMD.ref(pm, nw, :solar_gfmi, i)
    gen = _PMD.ref(pm, nw, :gen, index)
    bus_i = gen["gen_bus"]
    bus = _PMD.ref(pm, nw, :bus, bus_i)

    if !haskey(bus, "vm") && !haskey(bus, "va")
        bus["vm"] = [1 for c in bus["terminals"]]
        bus["va"] = [0, -2*pi/3, 2*pi/3]
    end

    cmax = gen["imax"]
    vrstar = [bus["vm"][c] * cos(bus["va"][c]) for c in bus["terminals"]]
    vistar = [bus["vm"][c] * sin(bus["va"][c]) for c in bus["terminals"]]

    # push into pmax on import and erase this
    if gen["solar_max"] < gen["kva"]
        pmax = gen["solar_max"]
    else
        pmax = gen["kva"]
    end

    constraint_grid_forming_inverter(pm, nw, index, i, vrstar, vistar, pmax, cmax)
end


"""
	constraint_mc_grid_forming_inverter_impedance(pm::_PMD.AbstractUnbalancedPowerModel, i::Int; nw::Int=nw_id_default)

Constraints for fault current contribution of multiconductor inverter in grid-forming mode with power matching
"""
function constraint_mc_grid_forming_inverter_impedance(pm::_PMD.AbstractUnbalancedPowerModel, i::Int; nw::Int=nw_id_default)
    index = _PMD.ref(pm, nw, :solar_gfmi, i)
    gen = _PMD.ref(pm, nw, :gen, index)
    bus_i = gen["gen_bus"]
    bus = _PMD.ref(pm, nw, :bus, bus_i)

    if !haskey(bus, "vm") && !haskey(bus, "va")
        bus["vm"] = [1 for c in bus["terminals"]]
        bus["va"] = [0, -2*pi/3, 2*pi/3]
    end

    cmax = gen["imax"]
    vrstar = [bus["vm"][c] * cos(bus["va"][c]) for c in bus["terminals"]]
    vistar = [bus["vm"][c] * sin(bus["va"][c]) for c in bus["terminals"]]

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


"""
	constraint_mc_grid_forming_inverter_virtual_impedance(pm::_PMD.AbstractUnbalancedPowerModel, i::Int; nw::Int=nw_id_default)

Constraints for fault current contribution of multiconductor inverter in grid-forming mode with power matching
"""
function constraint_mc_grid_forming_inverter_virtual_impedance(pm::_PMD.AbstractUnbalancedPowerModel, i::Int; nw::Int=nw_id_default)
    index = _PMD.ref(pm, nw, :solar_gfmi, i)
    gen = _PMD.ref(pm, nw, :gen, i)
    bus_i = gen["gen_bus"]
    bus = _PMD.ref(pm, nw, :bus, bus_i)
    terminals = bus["terminals"]
    connections = gen["connections"]
    _PMD.ref(pm, nw, :grid_forming, bus_i) ? ang = true : ang = false

    if !haskey(bus, "vm") && !haskey(bus, "va")
        vm = [.995 for c in bus["terminals"]]
        va = [0 -2*pi/3 2*pi/3]
    else
        vm = bus["vm"]
        va = bus["va"]
    end

    vm = [.995 for c in terminals]
    va = [0 -2*pi/3 2*pi/3]

    vr = [vm[idx] * cos(va[idx]) for (idx,c) in enumerate(terminals)]
    vi = [vm[idx] * sin(va[idx]) for (idx,c) in enumerate(terminals)]

    pmax = gen["solar_max"]
    smax = gen["kva"]
    imax = gen["imax"]

    constraint_mc_grid_formimg_inverter_virtual_impedance(pm, nw, i, index, vr, vi, pmax, imax, smax, ang, connections)
end


"""
	constraint_mc_current_balance(pm::_PMD.AbstractUnbalancedPowerModel, i::Int; nw::Int=nw_id_default)

Constraint to calculate the fault current at a bus and the current at other buses for multiconductor
"""
function constraint_mc_current_balance(pm::_PMD.AbstractUnbalancedIVRModel, i::Int; nw::Int=nw_id_default)
    bus = _PMD.ref(pm, nw, :bus, i)
    bus_arcs = _PMD.ref(pm, nw, :bus_arcs_conns_branch, i)
    bus_arcs_sw = _PMD.ref(pm, nw, :bus_arcs_conns_switch, i)
    bus_arcs_trans = _PMD.ref(pm, nw, :bus_arcs_conns_transformer, i)
    bus_gens = _PMD.ref(pm, nw, :bus_conns_gen, i)
    bus_storage = _PMD.ref(pm, nw, :bus_conns_storage, i)
    bus_shunts = _PMD.ref(pm, nw, :bus_conns_shunt, i)

    # constraint_mc_opf_current_balance(pm, nw, i, bus["terminals"], bus["grounded"], bus_arcs, bus_arcs_sw, bus_arcs_trans, bus_gens, bus_storage, Tuple{Int,Vector{Int}}[], bus_shunts)

    if bus["bus_i"] in _PMD.ids(pm, nw, :fault_buses)
        constraint_mc_fault_current_balance(pm, nw, i, _PMD.ref(pm, nw, :fault_buses, bus["bus_i"]), bus["terminals"], bus["grounded"], bus_arcs, bus_arcs_sw, bus_arcs_trans, bus_gens, bus_storage, bus_shunts)
    else
        _PMD.constraint_mc_current_balance(pm, nw, i, bus["terminals"], bus["grounded"], bus_arcs, bus_arcs_sw, bus_arcs_trans, bus_gens, bus_storage, Tuple{Int,Vector{Int}}[], bus_shunts)
    end
end


"""
	constraint_mc_bus_fault_current(pm::_PMD.AbstractUnbalancedIVRModel, i::Int; nw::Int=nw_id_default)

Constraint for Kirchoff's current law on faulted buses
"""
function constraint_mc_bus_fault_current(pm::_PMD.AbstractUnbalancedIVRModel, i::Int; nw::Int=nw_id_default)
    bus = _PMD.ref(pm, nw, :fault, i, "fault_bus")
    connections = _PMD.ref(pm, nw, :fault, i, "connections")
    Gf = _PMD.ref(pm, nw, :fault, i, "g")
    Bf = _PMD.ref(pm, nw, :fault, i, "b")

    constraint_mc_bus_fault_current(pm, nw, i, bus, connections, Gf, Bf)
end


"""
	constraint_mc_storage_grid_forming_inverter(pm::_PMD.AbstractUnbalancedIVRModel, i::Int; nw::Int=nw_id_default)

Constraint for fault-current contribution battery energy storage inverters
"""
function constraint_mc_fs_storage_grid_forming_inverter(pm::_PMD.AbstractUnbalancedIVRModel, i::Int; nw::Int=nw_id_default)
    storage = _PMD.ref(pm, nw, :storage, i)
    if i in _PMD.ref(pm, nw, :storage_gfmi)
        connections = storage["connections"]
        imax = .9 ./ (storage["pmax"])
        bus_i = storage["storage_bus"]
        zmax = 1 ./ imax
        constraint_mc_fs_storage_grid_forming_inverter_virtual_impedance(pm, nw, i, bus_i, connections, zmax, imax)
    end
end


"""
"""
function constraint_opf_mc_storage_grid_forming_inverter_virtual_impedance(pm::_PMD.AbstractUnbalancedIVRModel, i::Int; nw::Int=nw_id_default)
    storage = _PMD.ref(pm, nw, :storage, i)
    if i in _PMD.ref(pm, nw, :storage_gfmi)
        connections = storage["connections"]
        bus_i = storage["storage_bus"]
        pmin = storage["pmin"]
        pmax = storage["pmax"]
        qmin = storage["qmin"]
        qmax = storage["qmax"]
        constraint_opf_mc_storage_grid_forming_inverter_virtual_impedance(pm, nw, i, bus_i, pmin, pmax, qmin, qmax, connections)
    end
end


"""
	constraint_mc_gen_constant_power(pm::_PMD.AbstractUnbalancedPowerModel; nw::Int=nw_id_default)

Constraint that sets the gen to output constant power
"""
function constraint_mc_gen_constant_power(pm::_PMD.AbstractUnbalancedPowerModel, i::Int; nw::Int=nw_id_default)
    gen = _PMD.ref(pm, nw, :gen, i)
    if haskey(gen, "gen_model")
        if gen["gen_model"] == 1
            connections = gen["connections"]
            bus_id = gen["gen_bus"]
            kw = gen["pg"]
            kvar = gen["qg"]
            y_low = 1 ./conj.(.9^2 ./(kw .+ kvar.*1im))
            y_high = 1 ./conj.(1.1^2 ./(kw + kvar.*1im))
            constraint_mc_gen_constant_power(pm, nw, i, bus_id, kw, kvar, y_low, y_high, connections)
        end
    end
end


"""
	constraint_mc_gen_pq_constant_inverter(pm::_PMD.AbstractUnbalancedPowerModel; nw::Int=nw_id_default)

Constraint that sets the gen to output constant power
"""
function constraint_mc_gen_pq_constant_inverter(pm::_PMD.AbstractUnbalancedPowerModel, i::Int; nw::Int=nw_id_default)
    gen = _PMD.ref(pm, nw, :gen, i)
    if haskey(gen, "gen_model")
        if gen["gen_model"] == 7
            connections = gen["connections"]
            bus_id = gen["gen_bus"]
            kw = gen["pg"]
            kvar = gen["qg"]
            imax = abs.(conj.(kw + kvar*1im) ./ .9)
            qmax = gen["qmax"]
            qmin = gen["qmin"]
            constraint_mc_gen_pq_constant_inverter(pm, nw, i, bus_id, kw, kvar, imax, qmax, qmin, connections)
        end
    end
end


"""
"""
function constraint_mc_switch_state(pm::_PMD.AbstractUnbalancedPowerModel, i::Int; nw::Int=nw_id_default)::Nothing
    switch = _PMD.ref(pm, nw, :switch, i)
    f_bus = switch["f_bus"]
    t_bus = switch["t_bus"]

    f_idx = (i, f_bus, t_bus)
    t_idx = (i, t_bus, f_bus)

    if switch["state"] != 0
        constraint_mc_switch_state_closed(pm, nw, f_bus, t_bus, f_idx, t_idx, switch["f_connections"], switch["t_connections"])
    else
        constraint_mc_switch_state_open(pm, nw, f_idx)
    end
    nothing
end


"""
"""
function constraint_mc_voltage_magnitude_bounds(pm::_PMD.AbstractUnbalancedIVRModel, i::Int; nw::Int=nw_id_default)
    bus = _PMD.ref(pm, nw, :bus, i)
    vmax = _PMD.fill(1.05, length(bus["terminals"]))
    vmin = _PMD.fill(.8, length(bus["terminals"]))
    terminals = bus["terminals"]
    constraint_mc_voltage_magnitude_bounds(pm, nw, i, vmin, vmax, terminals)
end
