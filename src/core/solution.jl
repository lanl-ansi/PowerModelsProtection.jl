""
function solution_fs!(pm::_PMD.AbstractUnbalancedIVRModel, sol::Dict{String,<:Any})
    _PMD.apply_pmd!(_solution_fs!, sol; apply_to_subnetworks=true)
end


"Output the solution"
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
end
