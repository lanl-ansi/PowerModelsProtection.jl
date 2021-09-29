using PowerModelsProtection, Ipopt, JuMP, Printf, LightGraphs

netfile = "dist/case3_dg_islanded.dss"
netfile = "dist/case3_balanced_pv_2_gridforming.dss"
netfile = "dist/case3_unbalanced_switch.dss"
# netfile = "dist/ieee123/IEEE123Master_No_Regs.dss"
net = PowerModelsProtection.parse_file(netfile)

# net["multinetwork"] = false
# solver = JuMP.with_optimizer(Ipopt.Optimizer)
# # Simulate the fault

busid = Dict(enumerate(keys(net["bus"])))
busnum = Dict([k => i for (i,k) in enumerate(keys(net["bus"]))])
g = SimpleGraph(length(busnum))

if "line" in keys(net)
    for (_, x) in net["line"]
        add_edge!(g, busnum[x["f_bus"]], busnum[x["t_bus"]])
    end
end

# vsource_busids = Set([vsource["bus"] for (_,vsource) in get(net, "voltage_source", Dict())])
# fault_busids = Set()

# for (i,d) in enumerate(degree(g))
#     if d == 1 && !(busid[i] in vsource_busids)
#         push!(fault_busids, busid[i])
#     end
# end

# if "generator" in keys(net)
#     for (_,g) in net["generator"]
#         push!(fault_busids, g["bus"])
#     end
# end

# if "solar" in keys(net)
#     for (_,g) in net["solar"]
#         push!(fault_busids, g["bus"])
#     end
# end

# if "transformer" in keys(net)
#     for (_, x) in net["transformer"]
#         push!(fault_busids, busnum[x["bus"][1]])
#         push!(fault_busids, busnum[x["bus"][2]])
#     end
# end

# if "switch" in keys(net)
#     for (_, x) in net["switch"]
#         push!(fault_busids, x["f_bus"])
#         push!(fault_busids, x["t_bus"])
#     end
# end


# resistance = 0.01
# phase_resistance = 0.01
# fault_studies = Dict{String,Any}()

# for id in fault_busids
#     bus = net["bus"][id]

#     if id in vsource_busids
#         continue
#     end

#     fault_studies[id] = Dict{String,Any}(
#         "lg" => Dict{String,Any}(),
#         "ll" => Dict{String,Any}(),
#         "llg" => Dict{String,Any}(),
#         "3p" => Dict{String,Any}(),
#         "3pg" => Dict{String,Any}(),
#     )

#     i = 1
#     for t in bus["terminals"]
#         ground_terminal = !isempty(bus["grounded"]) ? bus["grounded"][end] : 4
#         if !(t in bus["grounded"])
#             fault_studies[id]["lg"]["$i"] = add_fault!(Dict{String,Any}(), "1", "lg", id, [t, ground_terminal], resistance)
#             i += 1
#         end
#     end

#     i = 1
#     for t in bus["terminals"]
#         ground_terminal = !isempty(bus["grounded"]) ? bus["grounded"][end] : 4
#         if !(t in bus["grounded"])
#             for u in bus["terminals"]
#                 if !(u in bus["grounded"]) && t != u && t < u
#                     fault_studies[id]["ll"]["$i"] = add_fault!(Dict{String,Any}(), "1", "ll", id, [t, u], phase_resistance)
#                     fault_studies[id]["llg"]["$i"] = add_fault!(Dict{String,Any}(), "1", "llg", id, [t, u, ground_terminal], resistance, phase_resistance)
#                     i += 1
#                 end
#             end
#         end
#     end

#     if length(bus["terminals"]) >= 3
#         fault_studies[id]["3p"]["1"] = add_fault!(Dict{String,Any}(), "1", "3p", id, bus["terminals"][1:3], phase_resistance)
#         if length(bus["terminals"]) >= 4
#             fault_studies[id]["3pg"]["1"] = add_fault!(Dict{String,Any}(), "1", "3pg", id, bus["terminals"][1:4], resistance, phase_resistance)
#         else
#             fault_studies[id]["3pg"]["1"] = add_fault!(Dict{String,Any}(), "1", "3pg", id, [bus["terminals"][1:3]; 4], resistance, phase_resistance)
#         end
#     end
# end


# # PowerModelsProtection.add_fault!(net, "1", "lg", "loadbus", [1, 4], 0.005)
# # results = PowerModelsProtection.solve_mc_fault_study(net, solver)

# # # Print out the fault currents
# # Iabc = results["solution"]["line"]["ohline"]["fault_current"]
# # @printf("Fault current: %0.3f A\n", Iabc[1])