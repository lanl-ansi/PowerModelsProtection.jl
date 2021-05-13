"Check to see if pf should be solved"
function check_pf!(data::Dict{String,Any}, solver)
    if haskey(data, "pf")
        if data["pf"] == "true"
            add_pf_data!(data, solver)
        end
    else
        add_pf_data!(data, solver)
    end
end


"Adds the result from pf based on model type"
function add_pf_data!(data::Dict{String,Any}, solver)
    if haskey(data, "method") && data["method"] in ["PMD", "solar-pf"]
        @debug "Adding PF results to network"
        result = solve_mc_pf(data, solver)
        add_mc_pf_data!(data, result)
    elseif haskey(data, "method") && data["method"] == "dg-pf"
        @debug "Adding PF results to network"
        result = solve_mc_dg_pf(data, solver)
        add_pf_data!(data, result)
    elseif haskey(data, "method") && data["method"] in ["PMs", "pf"]
        @debug "Adding PF results to network"
        result = _PM.run_pf(data, _PM.ACPPowerModel, solver)
        add_pf_data!(data, result)
    elseif haskey(data, "method") && data["method"] == "opf"
        @debug "Adding OPF results to network"
        result = _PM.run_opf(data, _PM.ACPPowerModel, solver)
        add_pf_data!(data, result)
    else
        @debug "Not performing pre-fault power flow"
    end
    @debug "Done adding results to network"

end


"Adds the result from pf"
function add_pf_data!(data::Dict{String,Any}, result::Dict{String,Any})
    if result["primal_status"] == FEASIBLE_POINT
        for (i, bus) in result["solution"]["bus"]
            data["bus"][i]["vm"] = bus["vm"]
            data["bus"][i]["va"] = bus["va"]
            @debug "Adding powerflow solution to bus $i"
            # @debug "Adding powerflow solution to bus $i"
        end
        for (i, gen) in result["solution"]["gen"]
            data["gen"][i]["pg"] = gen["pg"]
            data["gen"][i]["qg"] = gen["qg"]
            @debug "Adding powerflow solution to gen $i"
            # @debug "Adding powerflow solution to bus $i"
        end
    else
        @debug "The model power flow returned infeasible"
    end
end


"Add the result from pf returning in the engineer model format"
function add_mc_pf_data!(data::Dict{String,Any}, result::Dict{String,Any})
    if result["primal_status"] == FEASIBLE_POINT
        for (i, bus) in result["solution"]["bus"]
            bus_index = string(data["bus_lookup"][i])
            data["bus"][bus_index]["vr"] = bus["vr"]
            data["bus"][bus_index]["vi"] = bus["vi"]
        end
    else
        @warn "The model power flow returned infeasible"
    end
end


""
function add_fault_data!(data::Dict{String,Any})
    if haskey(data, "fault")
        add_fault!(data)
    else
        add_fault_study!(data)
    end
end


"Add single fault data to model"
function add_fault!(data::Dict{String,Any})
    hold = deepcopy(data["fault"])
    data["fault"] = Dict{String,Any}()
    for (k, fault) in hold
        for (i, bus) in data["bus"]
            if bus["index"] == fault["bus"]
                add_fault!(data, bus, i, fault["r"])
            end
        end
    end
end


"Add study fault data to model"
function add_fault_study!(data::Dict{String,Any})
    data["fault"] = Dict{String,Any}()
    for (i, bus) in data["bus"]
        data["fault"][i] = Dict{String,Any}()
        add_fault!(data, bus, i, 0.0001)
    end
end


"Add single fault data to model for study"
function add_fault!(data::Dict{String,Any}, bus::Dict{String,Any}, i::String, resistance=0.0001)
    gf = max(1 / resistance, 1e-6)
    haskey(data["fault"], i) || (data["fault"][i] = Dict{Int,Any}())
    index = length(keys(data["fault"][i])) + 1
    data["fault"][i][index] = Dict("bus_i" => bus["bus_i"], "gf" => gf)
end


"Add all fault type data to model for study for multiconductor"
function build_mc_fault_studies(data::Dict{String,<:Any}; resistance::Real=0.01, phase_resistance::Real=0.01)::Dict{String,Any}
    fault_studies = Dict{String,Any}()
    vsource_buses = Set([vsource["bus"] for (_,vsource) in get(data, "voltage_source", Dict())])
    for (id, line) in get(data, "line", Dict())
        if !(line["f_bus"] in vsource_buses)
            for fault_type in ["lg", "ll", "llg", "3p", "3pg"]
                connections = []
                if fault_type == "lg"
                    for (fc, tc) in zip(line["f_connections"], line["t_connections"])
                        push!(connections, (Int[fc], Int[tc]))
                    end
                elseif fault_type == "ll" || fault_type == "llg"
                    if length(line["f_connections"]) >= 2
                        for i in 1:(mod(length(line["f_connections"]), 2)+rem(length(line["f_connections"]), 2))
                            push!(connections, (line["f_connections"][i:i+1], line["t_connections"][i:i+1]))
                        end
                    end
                elseif fault_type == "3p" || fault_type == "3pg"
                    if length(line["f_connections"]) == 3
                        push!(connections, (line["f_connections"], line["t_connections"]))
                    end
                end

                for (i, (f_connections, t_connections)) in enumerate(connections)
                    fault = create_fault(fault_type, line["f_bus"], line["t_bus"], f_connections, t_connections, resistance, phase_resistance)
                    fault["name"] = "$(id)_$(fault_type)_$(i)"
                    fault_studies[fault["name"]] = fault
                end
            end
        end
    end
    return fault_studies
end


"Creates a list of buses in the model to fault for study"
function get_mc_fault_buses(data::Dict{String,Any})
    hold = []
    vsource_buses = Set([vsource["bus"] for (_,vsource) in get(data, "voltage_source", Dict())])

    for (id,_) in get(data, "bus", Dict())
        if !(id in vsource_buses)
            push!(hold, id)
        end
    end
    hold
end


"Checks for a microgrid and deactivates infinite bus"
function check_microgrid!(data::Dict{String,Any})
    if haskey(data, "microgrid")
        if data["microgrid"]
            index_bus = 0
            index_gen = 0
            bus_i = 0
            for (index, bus) in data["bus"]
                if bus["bus_type"] == 3
                    bus_i = bus["bus_i"]
                    index_bus = index
                end
            end
            for (index, gen) in data["gen"]
                gen["gen_bus"] == bus_i ? index_gen = index : nothing
            end
            delete!(data["bus"], index_bus)
            delete!(data["gen"], index_gen)
        end
    end
end
