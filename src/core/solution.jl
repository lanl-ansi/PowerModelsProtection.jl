
"expand solution to three phases to keep phase info in solution"
function expand_phases(fault_current_r, fault_current_i, terminals)
    real_currents = [0.0 0.0 0.0]
    imag_currents = [0.0 0.0 0.0]
    for phase in terminals
        real_currents[phase] = fault_current_r[phase]
        imag_currents[phase] = fault_current_i[phase]
    end
    return real_currents, imag_currents
end


"Output the solution"
function solution_fs!(pm::_PMD.AbstractUnbalancedPowerModel, sol::Dict{String,Any})
    # TODO create an output format
    if haskey(pm.var[:it][_PMD.pmd_it_sym][:nw][0], :cfr)
        cfr = JuMP.value.(pm.var[:it][_PMD.pmd_it_sym][:nw][0][:cfr])
        cfi = JuMP.value.(pm.var[:it][_PMD.pmd_it_sym][:nw][0][:cfi])
        sol["fault_current"] = Dict("cfr" => cfr, "cfi" => cfi)
    end
end


""
function add_fault_solution!(sol::Dict{String,Any}, data::Dict{String,Any})
    sol["fault"] = Dict{String,Any}()
    sol["fault"]["currents"] = Dict{String,Any}()
    bus = data["bus"][string(data["active_fault"]["bus_i"])]
    cfr_expand, cfi_expand = expand_phases(sol["fault_current"]["cfr"], sol["fault_current"]["cfi"], bus["terminals"])
    cfr = [(data["settings"]["sbase"] * data["settings"]["power_scale_factor"] / 1e6) * 1000 / bus["vbase"] * cfr_expand[c] for c in 1:3]
    cfi = [(data["settings"]["sbase"] * data["settings"]["power_scale_factor"] / 1e6) * 1000 / bus["vbase"] * cfi_expand[c] for c in 1:3]
    sol["fault"]["bus"] = Dict("bus_i" => data["active_fault"]["bus_i"], "current" => [sqrt(cfr[c]^2 + cfi[c]^2) for c in 1:3])
    for (name, line) in sol["line"]
        for (i, branch) in data["branch"]
            if branch["name"] == name
                csr_fr = [0.0 0.0 0.0]
                csi_fr = [0.0 0.0 0.0]
                sol["fault"]["currents"][name] = [0.0 0.0 0.0]
                for (indx, c) in enumerate(branch["f_connections"])
                    csr_fr[c] = (data["settings"]["sbase"] * data["settings"]["power_scale_factor"] / 1e6) * 1000 / branch["vbase"] * line["csr_fr"][indx]
                    csi_fr[c] = (data["settings"]["sbase"] * data["settings"]["power_scale_factor"] / 1e6) * 1000 / branch["vbase"] * line["csi_fr"][indx]
                    sol["fault"]["currents"][name][c] = abs(csr_fr[c] + csi_fr[c] * im)
                end
            end
        end
    end
end
