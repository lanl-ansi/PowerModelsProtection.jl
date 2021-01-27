"Output the solution"
function solution_fs!(pm::_PM.AbstractPowerModel, sol::Dict{String,Any})
    # TODO create an output format
    if haskey(pm.var[:nw][0], :cfr)
        cfr = JuMP.value.(pm.var[:nw][0][:cfr])
        cfi = JuMP.value.(pm.var[:nw][0][:cfi])
        sol["fault_current"] = Dict("cfr" => cfr, "cfi" => cfi)
    end
end


""
function add_fault_solution!(sol::Dict{String,Any}, data::Dict{String,Any})
    sol["fault"] = Dict{String,Any}()
    sol["fault"]["currents"] = Dict{String,Any}()
    bus = data["bus"][string(data["active_fault"]["bus_i"])]
    cfr = [data["baseMVA"] * 1000 / bus["vbase"] * sol["fault_current"]["cfr"][c] for c in 1:3]
    cfi = [data["baseMVA"] * 1000 / bus["vbase"] * sol["fault_current"]["cfi"][c] for c in 1:3]
    sol["fault"]["bus"] = Dict("bus_i" => data["active_fault"]["bus_i"], "current" => [sqrt(cfr[c]^2 + cfi[c]^2) for c in 1:3])
    for (name, line) in sol["line"]
        for (i, branch) in data["branch"]
            if branch["name"] == name
                csr_fr = [data["baseMVA"] * 1000 / branch["vbase"] * line["csr_fr"][c] for c in 1:3]
                csi_fr = [data["baseMVA"] * 1000 / branch["vbase"] * line["csi_fr"][c] for c in 1:3]
                sol["fault"]["currents"][name] = [abs(csr_fr[c] + csi_fr[c] * im) for c in 1:3]
            end
        end
    end
end
