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
function build_fault_studies(data::Dict{String,<:Any}; default_fault_resistance::Real=0.0001)::Dict{String,Any}
    fault_studies = Dict{String,Any}()

    if haskey(data, "bus")
        for (i, bus) in data["bus"]
            fault_studies[i] = add_fault!(Dict{String,Any}(), parse(Int, i), bus["bus_i"], default_fault_resistance)
        end
    end

    return fault_studies
end


""
function  add_fault!(data::Dict{String,<:Any}, id::Int, bus_i::Int, resistance::Real)
    if !haskey(data, "fault")
        data["fault"] = Dict{String,Any}()
    end

    data["fault"]["$id"] = Dict{String,Any}(
        "fault_bus" => bus_i,
        "gf" => max(1 / resistance, 1e-6),
        "status" => 1,
        "index" => id,
    )
end


"Add all fault type data to model for study for multiconductor"
function build_mc_fault_studies(data::Dict{String,<:Any}; resistance::Real=0.01, phase_resistance::Real=0.01)::Dict{String,Any}
    # TODO better detection of neutral vs ground phases, ground is currently hardcoded as 4

    fault_studies = Dict{String,Any}()
    vsource_buses = Set([vsource["bus"] for (_,vsource) in get(data, "voltage_source", Dict())])

    for (id, bus) in get(data, "bus", Dict())
        if !(id in vsource_buses)
            fault_studies[id] = Dict{String,Any}(
                "lg" => Dict{String,Any}(),
                "ll" => Dict{String,Any}(),
                "llg" => Dict{String,Any}(),
                "3p" => Dict{String,Any}(),
                "3pg" => Dict{String,Any}(),
            )

            i = 1
            for t in bus["terminals"]
                ground_terminal = !isempty(bus["grounded"]) ? bus["grounded"][end] : 4
                if !(t in bus["grounded"])
                    fault_studies[id]["lg"]["$i"] = add_fault!(Dict{String,Any}(), "1", "lg", id, [t, ground_terminal], resistance)
                    for u in bus["terminals"]
                        if !(u in bus["grounded"]) && t != u
                            fault_studies[id]["ll"]["$i"] = add_fault!(Dict{String,Any}(), "1", "ll", id, [t, u], phase_resistance)
                            fault_studies[id]["llg"]["$i"] = add_fault!(Dict{String,Any}(), "1", "llg", id, [t, u, ground_terminal], resistance, phase_resistance)
                        end
                    end
                    i += 1
                end
            end

            if length(bus["terminals"]) >= 3
                fault_studies[id]["3p"]["1"] = add_fault!(Dict{String,Any}(), "1", "3p", id, bus["terminals"][1:3], phase_resistance)
                if length(bus["terminals"]) >= 4
                    fault_studies[id]["3pg"]["1"] = add_fault!(Dict{String,Any}(), "1", "3pg", id, bus["terminals"][1:4], resistance, phase_resistance)
                else
                    fault_studies[id]["3pg"]["1"] = add_fault!(Dict{String,Any}(), "1", "3pg", id, [bus["terminals"][1:3]; 4], resistance, phase_resistance)
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


""
function prepare_transmission_data!(
    data::Dict{String,<:Any};
    flat_start::Bool=false,
    neglect_line_charging::Bool=false,
    neglect_transformer::Bool=false,
    zero_gen_setpoints::Bool=false)

    flat_start && flat_start!(data)
    neglect_line_charging && neglect_line_charging!(data)
    neglect_transformer && neglect_transformer!(data)
    zero_gen_setpoints && zero_gen_setpoints!(data)
end


""
function flat_start!(data::Dict{String,<:Any})
    if haskey(data, "bus")
        for (_,b) in data["bus"]
            b["vm"] = 1
            b["va"] = 0
            b["vmax"] = 2
            b["vmin"] = 0
        end
    end
end


""
function neglect_line_charging!(data::Dict{String,<:Any})
    if haskey(data, "branch")
        for (_,br) in data["branch"]
            br["b_fr"] = 0
            br["b_to"] = 0
        end
    end
end


""
function neglect_transformer!(data::Dict{String,<:Any})
    if haskey(data, "branch")
        for (_,br) in data["branch"]
            br["tap"] = 1
            br["shift"] = 0
        end
    end
end


""
function zero_gen_setpoints!(data::Dict{String,<:Any})
    if haskey(data, "gen")
        for (_,g) in data["gen"]
            g["pg"] = 0
            g["qg"] = 0
        end
    end
end
