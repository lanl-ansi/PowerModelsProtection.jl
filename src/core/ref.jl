""
function ref_add_fault!(pm::_PM.AbstractPowerModel)
    pm.ref[:active_fault] = pm.data["active_fault"]
end
