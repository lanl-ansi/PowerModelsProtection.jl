# states that the bus voltage is equal to the internal voltage minus voltage drop across subtransient impedance
function constraint_gen_voltage_drop(pm::_PMs.AbstractIVRModel, n::Int, i, bus_id, r, x, vgr, vgi)
    vr_to = _PMs.var(pm, n, :vr, bus_id)
    vi_to = _PMs.var(pm, n, :vi, bus_id)

    crg =  _PMs.var(pm, n, :crg, i)
    cig =  _PMs.var(pm, n, :cig, i)    

    JuMP.@constraint(pm.model, vr_to == vgr - r * crg + x * cig)
    JuMP.@constraint(pm.model, vi_to == vgi - r * cig - x * crg)
end

# function constraint_gen_fault_voltage_drop(pm, nw, i, bus_id, r, x, vgr, vgi)
#     fault_bus = 1
#     z = 0.000001
#     vr = var(pm, nw, :vr, fault_bus)
#     vi = var(pm, nw, :vi, fault_bus)
#     var(pm, nw)[:cfr] = JuMP.@variable(pm.model,
#         [fault_bus], base_name="$(nw)_cfr",
#         start = 0
#     )
#     var(pm, nw)[:cfi] = JuMP.@variable(pm.model,
#         [fault_bus], base_name="$(nw)_cfi",
#         start = 0
#     )
#     cr = var(pm, nw, :cfr, fault_bus)
#     ci = var(pm, nw, :cfi, fault_bus)
#     JuMP.@constraint(pm.model, vr == cr * z)
#     JuMP.@constraint(pm.model, vi == ci * z)
# end