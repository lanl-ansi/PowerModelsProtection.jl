"adds additional variable transformations for fault study solutions of distribution networks"
function solution_fs!(pm::_PMD.AbstractUnbalancedIVRModel, sol::Dict{String,<:Any})
    _PMD.apply_pmd!(_solution_fs!, sol; apply_to_subnetworks=true)
end


"adds additional variable transformations for fault study solutions of distribution networks"
function _solution_fs!(sol::Dict{String,<:Any})
	a = exp(2im*pi/3)
	Ai = [1 1 1; 1 a a^2; 1 a^2 a]/3	
	
    if haskey(sol, "branch")
        for (_,branch) in sol["branch"]
            if haskey(branch, "csr_fr") && haskey(branch, "csi_fr")
                branch["fault_current"] = sqrt.(branch["csr_fr"].^2 + branch["csi_fr"].^2)
                if length(branch["csr_fr"]) == 3
					Iabc = branch["csr_fr"] + 1im*branch["csi_fr"]
					I012 = Ai*Iabc
                    branch["zero_sequence_current"] = I012[1]
					branch["positive_sequence_current"] = I012[2]
					branch["negative_sequence_current"] = I012[3]
					
                    branch["zero_sequence_current_mag"] = abs(I012[1])
					branch["positive_sequence_current_mag"] = abs(I012[2])
					branch["negative_sequence_current_mag"] = abs(I012[3])
                end
            end
        end
    end

    if haskey(sol, "switch")
        for (_,switch) in sol["switch"]
            if haskey(switch, "csrsw_fr") && haskey(switch, "csisw_fr")
                switch["fault_current"] = sqrt.(switch["csrsw_fr"].^2 + switch["csisw_fr"].^2)
                if length(switch["csrsw_fr"]) == 3
					Iabc = switch["csrsw_fr"] + 1im*switch["csisw_fr"]
					I012 = Ai*Iabc
                    switch["zero_sequence_current_real"] = real(I012[1])
					switch["positive_sequence_current_real"] = real(I012[2])
					switch["negative_sequence_current_real"] = real(I012[3])

                    switch["zero_sequence_current_imag"] = imag(I012[1])
					switch["positive_sequence_current_imag"] = imag(I012[2])
					switch["negative_sequence_current_imag"] = imag(I012[3])

                    switch["zero_sequence_current_mag"] = abs(I012[1])
					switch["positive_sequence_current_mag"] = abs(I012[2])
					switch["negative_sequence_current_mag"] = abs(I012[3])
                end
            end
        end
    end

    if haskey(sol, "fault")
        for (_,fault) in sol["fault"]
            if haskey(fault, "cfr") && haskey(fault, "cfi")
                fault["fault_current"] = sqrt.(fault["cfr"].^2 + fault["cfi"].^2)
                if length(fault["cfr"]) == 3
					Iabc = fault["cfr"] + 1im*fault["cfi"]
					I012 = Ai*Iabc
                    fault["zero_sequence_current"] = I012[1]
					fault["positive_sequence_current"] = I012[2]
					fault["negative_sequence_current"] = I012[3]
					
                    fault["zero_sequence_current_mag"] = abs(I012[1])
					fault["positive_sequence_current_mag"] = abs(I012[2])
					fault["negative_sequence_current_mag"] = abs(I012[3])					
                end
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
                if length(bus["cfr_bus"]) == 3
					Iabc = bus["cfr_bus"] + 1im*bus["cfi_bus"]
					I012 = Ai*Iabc
                    bus["zero_sequence_current"] = I012[1]
					bus["positive_sequence_current"] = I012[2]
					bus["negative_sequence_current"] = I012[3]
					
                    bus["zero_sequence_current_mag"] = abs(I012[1])
					bus["positive_sequence_current_mag"] = abs(I012[2])
					bus["negative_sequence_current_mag"] = abs(I012[3])					
                end
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

