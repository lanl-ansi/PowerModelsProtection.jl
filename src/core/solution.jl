
function solution_fs!(pm::_PMs.AbstractPowerModel, sol::Dict{String,Any})
    # println(pm.data["branch"])
    currents = ["cr_fr", "ci_fr", "csr_fr", "csi_fr", "cr_to", "ci_to"]
    s_base = sol["baseMVA"] * 1000
    for (i, branch) in pm.data["branch"]
        if branch["t_bus"] == 9
        i_base = sqrt(3) * s_base/ pm.data["bus"]["9"]["base_kv"] 
        for key in currents 
            sol["branch"][i][key] = sol["branch"][i][key] * i_base
        end
        println(sol["branch"][i])
    end
    end
    sol["active_fault"] = pm.ref[:active_fault]
    println(sol)
    println(here)
end