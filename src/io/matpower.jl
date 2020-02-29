function parse_matpower(io::IO; validate=true)::Dict
    pm_data = _PMs.parse_matpower(io, validate=validate)

    # if haskey(pm_data, "fault")
    #     println(pm_data["fault"])
    # else
    #     # add all buses with default impedance
    # end

    if haskey(pm_data, "gensub")
        for (i,gen) in pm_data["gensub"]
            pm_data["gen"][i]["rs"] = gen["rs"]
            pm_data["gen"][i]["xs"] = gen["xs"]
        end
        delete!(pm_data, "gensub")
    else
        # default values need address pu values?
        for (i,gen) in pm_data["gensub"]
            pm_data["gen"][i]["rs"] = 0
            pm_data["gen"][i]["xs"] = .1
        end
    end
end




#     num_scenarios = pm_data["num_scenarios"]
#     num_time_periods = pm_data["num_time_periods"]

#     pm_data["scenario"] = Dict{Int, Dict{String,Any}}()
#     for s = 1:num_scenarios
#         pm_data["scenario"][s] = Dict{String,Any}()
#     end

#     pm_data["time_period"] = Dict{Int, Dict{String,Any}}()
#     for t = 1:num_time_periods
#         pm_data["time_period"][t] = Dict{String,Any}()
#     end

#     if haskey(pm_data, "scenario_feasible_data")
#         for (index,data) in pm_data["scenario_feasible_data"]
#             s        = data["scenario_i"]
#             feasible = data["preprocess_feasible"]
#             pm_data["scenario"][s]["preprocess_feasible"] = feasible
#         end
#     end
    
#     global_keys = Set{String}(["num_scenarios", "num_time_periods", "epsilon", "time_period_bus_data", "scenario_bus_data", "scenario_load_data", "scenario", "scenario_feasible_data", "time_period", "critical_bus_data"])
#     mn_data = _PMs.replicate(pm_data, num_scenarios*num_time_periods; global_keys=global_keys)

#     nw_map = Dict{Tuple{Int64,Int64}, Int64}()
#     index = 1
#     for scenario = 1:num_scenarios
#         for time_period = 1:num_time_periods
#             nw_map[(scenario,time_period)] = index
#             index = index + 1
#         end
#     end
#     mn_data["nw_map"] = nw_map

#     # get bus criticality data
#     if haskey(pm_data, "critical_bus_data")
#         for (index,data) in pm_data["critical_bus_data"]
#             s           = data["scenario"]
#             i           = data["bus_i"]
#             t           = data["time_period"]
#             is_critical = data["is_critical"]
#             n           = nw_map[(s,t)]
#             mn_data["nw"][string(n)]["bus"][string(i)]["is_critical"] = is_critical
#         end
#     end


#     # get time period specific data for buses
#     for (index,data) in pm_data["time_period_bus_data"]
#         bus_i = data["bus_i"]
#         time_period = data["time_period"]

#         for (key, value) in data
#             if key == "bus_i" || key == "time_period" || key == "index"
#                 continue
#             end

#             for i = 1:num_scenarios
#                 mn_data["nw"][string(nw_map[(i,time_period)])]["bus"][string(bus_i)][key] = value
#             end
#         end
#     end
#     delete!(mn_data, "time_period_bus_data")

#     # get time period and scenario specific data for buses
#     for (index,data) in pm_data["scenario_bus_data"]
#         bus_i       = data["bus_i"]
#         time_period = data["time_period"]
#         scenario    = data["scenario"]

#         for (key, value) in data
#             if key == "bus_i" || key == "time_period" || key == "scenario" || key == "index"
#                 continue
#             end
#             mn_data["nw"][string(nw_map[(scenario,time_period)])]["bus"][string(bus_i)][key] = value
#         end
#     end
#     delete!(mn_data, "scenario_bus_data")

#     bus_to_load = Dict()
#     for (idx,load) in pm_data["load"]
#        bus_to_load[load["load_bus"]] = idx
#     end

#     # get time period and scenario specific data for loads
#     for (index,data) in pm_data["scenario_load_data"]
#         bus_i       = data["bus_i"]
#         time_period = data["time_period"]
#         scenario    = data["scenario"]

#         for (key, value) in data
#             if key == "load_i" || key == "time_period" || key == "scenario" || key == "index"
#                 continue
#             end
#             # oddness about load numbering scheme, so we map from the bus back to the load here
#             load_i = bus_to_load[bus_i]
#             mn_data["nw"][string(nw_map[(scenario,time_period)])]["load"][string(load_i)][key] = value
#         end
#     end
#     delete!(mn_data, "scenario_load_data")

#     if (validate)
#         for (n,nw) in mn_data["nw"]
#             _PMs.correct_network_data!(nw)
#             _PMs.propagate_topology_status!(nw)
#         end
#     end

#     mn_data["per_unit"] = true

#     if haskey(pm_data, "study")
#         mn_data["study"] = zeros(Int64, 0)
#         for (n, bus) in pm_data["study"]
#             append!(mn_data["study"], bus["bus_i"])
#             for nw in keys(mn_data["nw"])
#                 mn_data["nw"][nw]["bus"][string(bus["bus_i"])]["bus_type"] == 4 ? mn_data["nw"][nw]["bus"][string(bus["bus_i"])]["bus_type"] = 1 : nothing
#             end
#         end
#     end

#     return mn_data
# end