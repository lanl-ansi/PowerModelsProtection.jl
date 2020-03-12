
function solution_fs!(pm::_PMs.AbstractPowerModel, sol::Dict{String,Any})
    sol["fault"] = _PMs.ref(pm, pm.cnw, :active_fault) #Dict{String,Any}("name" => "2","phases" => [2],"type" => "lg","bus_i" => 3,"Gf" => [0.0 0.0 0.0; 0.0 99999.99999999999 0.0; 0.0 0.0 0.0])
    sol["fault"]["currents"] = Dict{String, Any}()
    add_branch_currents!(pm, sol)
    add_tansformer_currents!(pm, sol)
    println(sol["fault"])
    println("##########################################################################")
end

function add_tansformer_currents!(pm::_PMs.AbstractPowerModel, sol::Dict{String,Any})
    s_base = sol["baseMVA"] * 1000
    for (l,i,j) in _PMs.ref(pm, pm.cnw, :arcs_from_trans)
        v_base = _PMs.ref(pm, pm.cnw, :bus, i)["base_kv"]
        i_base = sqrt(3) * s_base/ v_base
        trans = _PMs.ref(pm, pm.cnw, :bus, j)["name"]
        name = string(_PMs.ref(pm, pm.cnw, :bus, i)["name"], ">>", trans) 
        sol["fault"]["currents"][name] = [abs(JuMP.value(_PMs.var(pm, pm.cnw, :crt, (l,i,j))[c]) + JuMP.value(_PMs.var(pm, pm.cnw, :cit, (l,i,j))[c]) * im ) * i_base for c in 1:3]
    end
end

function add_branch_currents!(pm::_PMs.AbstractPowerModel, sol::Dict{String,Any})
    s_base = sol["baseMVA"] * 1000
    for (index, branch) in _PMs.ref(pm, pm.cnw, :branch)
        if occursin("line.", branch["source_id"])
            v_base = _PMs.ref(pm, pm.cnw, :bus, branch["t_bus"])["base_kv"]
            i_base = sqrt(3) * s_base/ v_base
            bus_i = string(index)
            name = branch["name"]
            sol["fault"]["currents"][name] = [abs(sol["branch"][bus_i]["csr_fr"][c] + sol["branch"][bus_i]["csi_fr"][c] *im) * i_base for c in 1:3]
        end
    end
end

