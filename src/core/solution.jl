"adds additional variable transformations for fault study solutions of distribution networks"
function solution_fs!(pm::_PMD.AbstractUnbalancedIVRModel, sol::Dict{String,<:Any})
    _PMD.apply_pmd!(_solution_fs!, sol; apply_to_subnetworks=true)
end


"adds additional variable transformations for fault study solutions of distribution networks"
function _solution_fs!(sol::Dict{String,<:Any})
    if haskey(sol, "branch")
        for (_,branch) in sol["branch"]
            if haskey(branch, "csr_fr") && haskey(branch, "csi_fr")
                branch["fault_current"] = sqrt.(branch["csr_fr"].^2 + branch["csi_fr"].^2)
            end
        end
    end

    if haskey(sol, "fault")
        for (_,fault) in sol["fault"]
            if haskey(fault, "cfr") && haskey(fault, "cfi")
                fault["fault_current"] = sqrt.(fault["cfr"].^2 + fault["cfi"].^2)
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
                bus["fault_current"] = sqrt.(bus["cfr_bus"].^2 + bus["cfi_bus"].^2)
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
            if haskey(branch, "csr_fr") && haskey(branch, "csi_fr")
                branch["fault_current"] = sqrt.(branch["csr_fr"].^2 + branch["csi_fr"].^2)
            end
        end
    end

    if haskey(sol, "fault")
        for (_,fault) in sol["fault"]
            if haskey(fault, "cfr") && haskey(fault, "cfi")
                fault["fault_current"] = sqrt.(fault["cfr"].^2 + fault["cfi"].^2)
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
                bus["fault_current"] = sqrt(bus["cfr_bus"]^2 + bus["cfi_bus"]^2)
            end
        end
    end
end

