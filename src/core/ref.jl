
function ref_add_fault!(pm::_PMs.AbstractPowerModel)
    pm.ref[:active_fault] = pm.data["active_fault"]
    Gf = zeros(3,3)
    if pm.data["active_fault"]["type"] == "lg"
        i = pm.data["active_fault"]["phases"][1]
        Gf[i,i] = pm.data["active_fault"]["gf"]
    end
    pm.ref[:active_fault]["GF"] = Gf
    # Dict{String,Any}("phases"=>[1],"GF"=>[0.1 0.0 0.0; 0.0 0.0 0.0; 0.0 0.0 0.0],"gf"=>0.1,"type"=>"lg","bus_i"=>3)
end
