
function constraint_gen_voltage_drop(pm::_PMs.AbstractPowerModel; nw::Int=pm.cnw)
    deg2rad = pi/180
    for (k,gen) in _PMs.ref(pm, nw, :gen)
        i = gen["index"]
        bus_id = gen["gen_bus"]

        r = gen["rs"] 
        x = gen["xs"]
        
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
    
    if bus != _PMs.ref(pm, nw, :active_fault, "bus") 
        constraint_current_balance(pm, nw, i, bus_arcs, bus_gens, bus_gs, bus_bs)
    else
        constraint_fault_current_balance(pm, nw, i, bus_arcs, bus_gens, bus_gs, bus_bs, bus)
    end

end
