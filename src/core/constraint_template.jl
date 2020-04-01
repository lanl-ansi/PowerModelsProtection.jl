function constraint_gen_voltage_drop(pm::_PMs.AbstractPowerModel; nw::Int=pm.cnw)
    deg2rad = pi/180
    for (k,gen) in _PMs.ref(pm, nw, :gen)
        i = gen["index"]
        bus_id = gen["gen_bus"]

        r = gen["zr"] 
        x = gen["zx"]
        
        vm = _PMs.ref(pm, :bus, bus_id, "vm") 
        va = _PMs.ref(pm, :bus, bus_id, "va")
    
        vgr = vm * cos(va * deg2rad)
        vgi = vm * sin(va * deg2rad)   

        constraint_gen_voltage_drop(pm, nw, i, bus_id, r, x, vgr, vgi)
    end
end

function constraint_current_balance(pm::_PMs.AbstractPowerModel, i::Int; nw::Int=pm.cnw)
    bus = _PMs.ref(pm, nw, :bus, i)["bus_i"]
    bus_arcs = _PMs.ref(pm, nw, :bus_arcs, i)
    bus_gens = _PMs.ref(pm, nw, :bus_gens, i)
    bus_shunts = _PMs.ref(pm, nw, :bus_shunts, i)
            
    bus_gs = Dict(k => _PMs.ref(pm, nw, :shunt, k, "gs") for k in bus_shunts)
    bus_bs = Dict(k => _PMs.ref(pm, nw, :shunt, k, "bs") for k in bus_shunts)
    
    if bus != _PMs.ref(pm, nw, :active_fault, "bus_i") 
        # debug(_LOGGER, "Calling current_balance on bus $i")
        println("Calling current_balance on bus $i")

        constraint_current_balance(pm, nw, i, bus_arcs, bus_gens, bus_gs, bus_bs)
    else
        # debug(_LOGGER, "Calling fault current_balance on bus $i")
        println("Calling fault_current_balance on bus $i")
        constraint_fault_current_balance(pm, nw, i, bus_arcs, bus_gens, bus_gs, bus_bs, bus)
    end
end

function constraint_mc_gen_voltage_drop(pm::_PMs.AbstractPowerModel; nw::Int=pm.cnw)
    for (k,gen) in _PMs.ref(pm, nw, :gen)
        i = gen["index"]
        bus_id = gen["gen_bus"]

        r = gen["zr"] 
        x = gen["zx"]

        vm = _PMs.ref(pm, :bus, bus_id, "vm") 
        va = _PMs.ref(pm, :bus, bus_id, "va")

        vgr = [vm[i] * cos(va[i]) for i in 1:3]
        vgi = [vm[i] * sin(va[i]) for i in 1:3]

        constraint_mc_gen_voltage_drop(pm, nw, i, bus_id, r, x, vgr, vgi)
    end
end

function constraint_mc_current_balance(pm::_PMs.AbstractPowerModel, i::Int; nw::Int=pm.cnw)
    bus = _PMs.ref(pm, nw, :bus, i)["bus_i"]
    bus_arcs = _PMs.ref(pm, nw, :bus_arcs, i)
    bus_arcs_sw = _PMs.ref(pm, nw, :bus_arcs_sw, i)
    bus_arcs_trans = _PMs.ref(pm, nw, :bus_arcs_trans, i)
    bus_gens = _PMs.ref(pm, nw, :bus_gens, i)
    bus_shunts = _PMs.ref(pm, nw, :bus_shunts, i) 

    bus_gs = Dict(k => _PMs.ref(pm, nw, :shunt, k, "gs") for k in bus_shunts)
    bus_bs = Dict(k => _PMs.ref(pm, nw, :shunt, k, "bs") for k in bus_shunts)

    if bus != _PMs.ref(pm, nw, :active_fault, "bus_i")
        constraint_mc_current_balance(pm, nw, i, bus_arcs, bus_arcs_sw, bus_arcs_trans, bus_gens, bus_gs, bus_bs)
    else
        constraint_mc_fault_current_balance(pm, nw, i, bus_arcs, bus_arcs_sw, bus_arcs_trans, bus_gens, bus_gs, bus_bs, bus)
    end
    
end

function constraint_mc_generation(pm::_PMs.AbstractPowerModel, id::Int; nw::Int=pm.cnw, report::Bool=true, bounded::Bool=true)
    generator = _PMs.ref(pm, nw, :gen, id)
    bus = _PMs.ref(pm, nw, :bus, generator["gen_bus"])

    if generator["conn"]=="wye"
        constraint_mc_generation_wye(pm, nw, id, bus["index"]; report=report, bounded=bounded)
    else
        constraint_mc_generation_delta(pm, nw, id, bus["index"]; report=report, bounded=bounded)
    end
end

function constraint_mc_ref_bus_voltage(pm::_PMs.AbstractIVRModel, i::Int; nw::Int=pm.cnw)
    vm = _PMs.ref(pm, :bus, i, "vm") 
    va = _PMs.ref(pm, :bus, i, "va")
    
    vr = [vm[i] * cos(va[i]) for i in 1:3]
    vi = [vm[i] * sin(va[i]) for i in 1:3]

    constraint_mc_ref_bus_voltage(pm, nw, i, vr, vi)
end