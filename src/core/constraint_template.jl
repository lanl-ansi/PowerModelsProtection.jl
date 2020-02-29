
function constraint_gen_voltage_drop(pm::_PMs.AbstractPowerModel; nw::Int=pm.cnw)
    deg2rad = pi/180
    for (k,gen) in _PMs.ref(pm, nw, :gen)
        i = gen["index"]
        bus_id = gen["gen_bus"]

        r = gen["rg"] 
        x = gen["xg"]
        
        vm = _PMs.ref(pm, :bus, bus_id, "vm") 
        va = _PMs.ref(pm, :bus, bus_id, "va")
    
        vgr = vm * cos(va * deg2rad)
        vgi = vm * sin(va * deg2rad)   

        constraint_gen_voltage_drop(pm, nw, i, bus_id, r, x, vgr, vgi)
    end
end
