"""
	solution_fs!(pm::_PMD.AbstractUnbalancedIVRModel, sol::Dict{String,<:Any})

adds additional variable transformations for fault study solutions of distribution networks
"""
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

"calculates relay and fuse operation times and adds them to solution dictionary"
function solution_protection!(pm::_PMD.AbstractUnbalancedIVRModel, sol::Dict{String,<:Any})
    _PMD.apply_pmd!(_solution_protection!, pm.ref, sol; apply_to_subnetworks=true)
end


"calculates relay and fuse operation times and adds them to solution dictionary"
function _solution_protection!(ref::Dict{Symbol,Any},sol::Dict{String,<:Any})
    if haskey(ref,:relay)
        pu = [ref[:settings]["sbase_default"]]
        push!(pu,ref[:settings]["power_scale_factor"])
        push!(pu,ref[:settings]["voltage_scale_factor"])
        tripped_relays = Dict{String,Any}()
        for (id,obj) in get(ref,:relay,Dict())
            trip = false
            element_enum = obj["element_enum"]
            Iabc = _get_current_math(ref,sol,element_enum,id,pu)
            _relay_operation(obj,Iabc)
            if haskey(obj,"phase")
                for phase=1:length(obj["phase"])
                    if obj["phase"]["$phase"]["state"] == "open"
                        trip = true
                    end
                end
            else
                if obj["state"] == "open"
                    trip = true
                end
            end
            if trip
                tripped_relays["$id"] = obj
            end
        end
        if !isempty(tripped_relays)
            sol["relay"] = tripped_relays
        end
    end

    if haskey(ref, :fuse)
        pu = [ref[:settings]["sbase_default"]]
        push!(pu,ref[:settings]["power_scale_factor"])
        push!(pu,ref[:settings]["voltage_scale_factor"])
        blown_fuses = Dict{String,Any}()
        for (id, obj) in get(ref, :fuse, Dict())
            blown = false
            element_enum = obj["element_enum"]
            Iabc = _get_current_math(ref,sol,element_enum,id,pu)
            for phase=1:length(obj["phase"])
                if haskey(obj, "min_melt_curve_enum")
                    current_vec = ref[:curve][obj["min_melt_curve_enum"]]["curve_mat"][1,:]
                    time_vec = ref[:curve][obj["min_melt_curve_enum"]]["curve_mat"][2,:]
                else
                    current_vec = obj["min_melt_curve"][1,:]
                    time_vec = obj["min_melt_curve"][2,:]
                end
                (time_min, op_min) = _interpolate_time(current_vec, time_vec, Iabc[phase])
                if op_min
                    blown = true
                    if haskey(obj, "max_clear_curve_enum")
                        current_vec = ref[:curve][obj["max_clear_curve_enum"]]["curve_mat"][1,:]
                        time_vec = ref[:curve][obj["max_clear_curve_enum"]]["curve_mat"][2,:]
                    else
                        current_vec = obj["max_clear_curve"][1,:]
                        time_vec = obj["max_clear_curve"][2,:]
                    end
                    (time_max, op_max) = _interpolate_time(current_vec,time_vec,Iabc[phase])
                    if op_max
                        obj["phase"]["$phase"]["state"] = "open"
                        obj["phase"]["$phase"]["op_times"] = "Min. melt: $time_min. Max. clear: $time_max."
                    else
                        obj["phase"]["$phase"]["state"] = "open"
                        obj["phase"]["$phase"]["op_times"] = "Min. melt: $time_min."
                    end
                end
            end
            if blown
                blown_fuses["$id"] = obj
            end
        end
        if !isempty(blown_fuses)
            sol["fuse"] = blown_fuses
        end
    end
end
