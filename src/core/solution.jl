
""
function solution_fs!(pm::_PM.AbstractPowerModel, sol::Dict{String,Any})
    # sol["fault"] = ref(pm, pm.cnw, :active_fault)
    # sol["fault"]["currents"] = Dict{String, Any}()
    # add_branch_currents!(pm, sol)
    # add_tansformer_currents!(pm, sol)
end


""
function add_tansformer_currents!(pm::_PM.AbstractPowerModel, sol::Dict{String,Any})
    s_base = sol["baseMVA"] * 1000
    for (l,i,j) in ref(pm, pm.cnw, :arcs_from_trans)
        v_base = ref(pm, pm.cnw, :bus, i)["vbase"]
        i_base = sqrt(3) * s_base/ v_base
        trans = ref(pm, pm.cnw, :bus, j)["name"]
        name = string(ref(pm, pm.cnw, :bus, i)["name"], ">>", trans)
        sol["fault"]["currents"][name] = [abs(JuMP.value(var(pm, pm.cnw, :crt, (l,i,j))[c]) + JuMP.value(var(pm, pm.cnw, :cit, (l,i,j))[c]) * im ) * i_base for c in 1:3]
    end
end


""
function add_branch_currents!(pm::_PM.AbstractPowerModel, sol::Dict{String,Any})
    s_base = sol["baseMVA"] * 1000
    for (index, branch) in ref(pm, pm.cnw, :branch)
        if occursin("line.", branch["source_id"])
            v_base = ref(pm, pm.cnw, :bus, branch["t_bus"])["vbase"]
            i_base = sqrt(3) * s_base/ v_base
            bus_i = string(index)
            name = branch["source_id"]
            sol["fault"]["currents"][name] = [abs(sol["branch"][bus_i]["csr_fr"][c] + sol["branch"][bus_i]["csi_fr"][c] *im) * i_base for c in 1:3]
        end
    end
end

function add_solution!(sol::Dict{String,Any}, data::Dict{String,Any})
    sol["fault"] = Dict{String,Any}()
    sol["fault"]["currents"] = Dict{String,Any}()
    for (name,line) in sol["line"]
        for (i, branch) in data["branch"]
            if branch["name"] == name
                csr_fr = [data["baseMVA"] * 1000/branch["vbase"] * line["csr_fr"][c] for c in 1:3]
                csi_fr = [data["baseMVA"] * 1000/branch["vbase"] * line["csi_fr"][c] for c in 1:3]
                sol["fault"]["currents"][name] = [abs(csr_fr[c] + csi_fr[c] *im) for c in 1:3]
            end
        end
    end
end
