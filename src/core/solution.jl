"Output the solution"
function solution_fs!(pm::_PM.AbstractPowerModel, sol::Dict{String,Any})
    # TODO create an output format
end


""
function add_fault_solution!(sol::Dict{String,Any}, data::Dict{String,Any})
    sol["fault"] = Dict{String,Any}()
    sol["fault"]["currents"] = Dict{String,Any}()
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
