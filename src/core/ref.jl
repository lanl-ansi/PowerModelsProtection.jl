
function ref_add_fault!(pm::_PMs.AbstractPowerModel)
    pm.ref[:active_fault] = pm.data["active_fault"]
end
