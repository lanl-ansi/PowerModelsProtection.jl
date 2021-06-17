"adds additional variable transformations for fault study solutions of distribution networks"
function solution_fs!(pm::_PMD.AbstractUnbalancedIVRModel, sol::Dict{String,<:Any})
    _PMD.apply_pmd!(_solution_fs!, sol; apply_to_subnetworks=true)
end


"adds additional variable transformations for fault study solutions of distribution networks"
function _solution_fs!(sol::Dict{String,<:Any})

    if haskey(sol, "branch")
        for (_,branch) in sol["branch"]
            if haskey(branch, "cr_fr") && haskey(branch, "ci_fr")
                branch["cf_fr"] = sqrt.(branch["cr_fr"].^2 + branch["ci_fr"].^2)
            end
            if haskey(branch, "cr_to") && haskey(branch, "ci_to")
                branch["cf_to"] = sqrt.(branch["cr_to"].^2 + branch["ci_to"].^2)
            end
        end
    end

    if haskey(sol, "switch")
        for (_,switch) in sol["switch"]
            if haskey(switch, "crsw_fr") && haskey(switch, "cisw_fr")
                switch["cf_fr"] = sqrt.(switch["crsw_fr"].^2 + switch["cisw_fr"].^2)
            end
            if haskey(switch, "crsw_to") && haskey(switch, "cisw_to")
                switch["cf_to"] = sqrt.(switch["crsw_to"].^2 + switch["cisw_to"].^2)
            end
        end
    end

    if haskey(sol, "fault")
        for (_,fault) in sol["fault"]
            if haskey(fault, "cfr") && haskey(fault, "cfi")
                fault["cf"] = sqrt.(fault["cfr"].^2 + fault["cfi"].^2)
            end
        end
    end

    if haskey(sol, "bus")
        for (_,bus) in sol["bus"]
            if haskey(bus, "vr")  && haskey(bus, "vi")
                bus["vm"] = sqrt.(bus["vr"].^2 + bus["vi"].^2)
                bus["va"] = atan.(bus["vi"], bus["vr"])
            end

            if haskey(bus, "cfr_bus") && haskey(bus, "cfi_bus")
                bus["cf_bus"] = sqrt.(bus["cfr_bus"].^2 + bus["cfi_bus"].^2)
            end
        end
    end
end


"adds additional variable transformations for fault study solutions of transmission networks"
function solution_fs!(pm::_PM.AbstractIVRModel, sol::Dict{String,<:Any})
    _PM.apply_pm!(_solution_pm_fs!, sol; apply_to_subnetworks=true)
end


"adds additional variable transformations for fault study solutions of transmission networks"
function _solution_pm_fs!(sol::Dict{String,<:Any})
    if haskey(sol, "branch")
        for (_,branch) in sol["branch"]
            if haskey(branch, "cr_fr") && haskey(branch, "ci_fr")
                branch["cf_fr"] = sqrt.(branch["csr_fr"].^2 + branch["csi_fr"].^2)
            end
            if haskey(branch, "cr_to") && haskey(branch, "ci_to")
                branch["cf_to"] = sqrt.(branch["cr_to"].^2 + branch["ci_to"].^2)
            end
        end
    end

    if haskey(sol, "switch")
        for (_,switch) in sol["switch"]
            if haskey(switch, "cr_fr") && haskey(switch, "ci_fr")
                switch["cf_fr"] = sqrt.(switch["cr_fr"].^2 + switch["ci_fr"].^2)
            end
            if haskey(switch, "cr_to") && haskey(switch, "ci_to")
                switch["cf_to"] = sqrt.(switch["cr_to"].^2 + switch["ci_to"].^2)
            end
        end
    end

    if haskey(sol, "fault")
        for (_,fault) in sol["fault"]
            if haskey(fault, "cfr") && haskey(fault, "cfi")
                fault["cf_bus"] = sqrt.(fault["cfr"].^2 + fault["cfi"].^2)
            end
        end
    end

    if haskey(sol, "bus")
        for (_,bus) in sol["bus"]
            if haskey(bus, "vr")  && haskey(bus, "vi")
                bus["vm"] = sqrt(bus["vr"]^2 + bus["vi"]^2)
                bus["va"] = atan(bus["vi"], bus["vr"])
            end

            if haskey(bus, "cfr_bus") && haskey(bus, "cfi_bus")
                bus["cf"] = sqrt(bus["cfr_bus"]^2 + bus["cfi_bus"]^2)
            end
        end
    end
end

