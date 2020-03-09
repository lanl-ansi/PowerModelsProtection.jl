
function check_pf!(data::Dict{String,Any}, solver)
    if haskey(data, "pf")
        if data["pf"] == "true" 
            add_pf_data!(data, solver)
        end
    else
        add_pf_data!(data, solver)
    end
end

function add_pf_data!(data::Dict{String,Any}, solver)
    if data["method"] == "PMs"
        result = _PMs.run_pf(data, _PMs.ACPPowerModel, solver)
        add_pf_data!(data, result)
    else
        result = _PMD.run_mc_pf(data, _PMs.ACPPowerModel, solver)
        add_pf_data!(data, result)
    end
end

function add_pf_data!(data::Dict{String,Any}, result::Dict{String,Any})
    if result["primal_status"] == MOI.FEASIBLE_POINT
        for (i, bus) in result["solution"]["bus"]
            data["bus"][i]["vm"] = bus["vm"]
            data["bus"][i]["va"] = bus["va"]
        end
    else
        Memento.info(_LOGGER, "The model power flow returned infeasible")
    end
end

function add_fault_data!(data::Dict{String,Any})
    if !haskey(data, "fault")
        add_fault_study!(data)
    end
    # data["fault"] = Dict{String, Any}()
    # gf = 1/.1
    # # for (i, bus) in data["bus"]
    # #     data["fault"][i] = Dict{String, Any}()
    # #     data["fault"][i]["ll"] = Dict("gp"=> .01, "phases" => [1, 2])
    # #     data["fault"][i]["lg"] = Dict("gf"=> .1, "phases" => [1])
    # # end
    # data["fault"]["1"] = Dict("bus_i" => 3, "type" => "lg", "gf"=> gf, "phases" => [1])
end

function add_fault_study!(data::Dict{String,Any})
    data["fault"] = Dict{String, Any}()
    get_active_phases!(data)
    for (i, bus) in data["bus"]
        if i == "9"
        data["fault"][i] = Dict{String, Any}()
        add_lg_fault!(data, bus, i)
        end
        # add_ll_fault!(data, bus, i)
        
    end
    println(data["fault"])
    delete!(data, "bus_phases")
end

function add_lg_fault!(data::Dict{String,Any}, bus::Dict{String,Any}, i::String; resistance=0.1)
    # for (i, bus) in data["bus"]
    #     println(i)
    #     println(bus)
    #     println("")
    # end
    gf = max(1/resistance, 1e-6)
    ncnd = 3
    data["fault"][i]["lg"] = Dict{Int, Any}()
    for c in data["bus_phases"][bus["bus_i"]]
        Gf = zeros(ncnd, ncnd)
        Gf[c,c] = gf
        data["fault"][i]["lg"][c] = Dict("bus_i" => bus["bus_i"], "type" => "lg", "Gf"=> Gf, "phases" => [c])
    end
end

function add_ll_fault!(data::Dict{String,Any}, bus::Dict{String,Any}, i::String; phase_resistance=0.01)
    f = max(1/phase_resistance, 1e-6)
    ncnd = length(data["bus_phases"][bus["bus_i"]])
    if ncnd > 1
        data["fault"][i]["ll"] = Dict{Int, Any}()
        println(ncnd)
    end
    # println(p)
    # g

    # data["fault"][i]["ll"] = Dict{Int, Any}()

    # for c = 1:ncnd
    #     Gf = zeros(ncnd, ncnd)
    #     Gf[c,c] = gf
    #     data["fault"][i]["lg"][c] = Dict("bus_i" => bus["bus_i"], "type" => "lg", "Gf"=> Gf, "phases" => [c])
    # end
end

function get_active_phases!(data::Dict{String,Any})
    bus = Dict{Int64, Any}()
    for (i, branch) in data["branch"]
        !haskey(bus, branch["t_bus"]) ? bus[branch["t_bus"]] = [] : nothing
        !haskey(bus, branch["f_bus"]) ? bus[branch["f_bus"]] = [] : nothing
        length(branch["active_phases"]) > length(bus[branch["t_bus"]]) ? bus[branch["t_bus"]] = branch["active_phases"] : nothing 
        length(branch["active_phases"]) > length(bus[branch["f_bus"]]) ? bus[branch["f_bus"]] = branch["active_phases"] : nothing 
    end
    for (i, transformer) in data["transformer"]
        !haskey(bus, transformer["t_bus"]) ? bus[transformer["t_bus"]] = [] : nothing
        !haskey(bus, transformer["f_bus"]) ? bus[transformer["f_bus"]] = [] : nothing
        length(transformer["active_phases"]) > length(bus[transformer["t_bus"]]) ? bus[transformer["t_bus"]] = transformer["active_phases"] : nothing 
        length(transformer["active_phases"]) > length(bus[transformer["f_bus"]]) ? bus[transformer["f_bus"]] = transformer["active_phases"] : nothing 
    end
    data["bus_phases"] = bus
end

# # create a convenience function add_fault or keyword options to run_mc_fault study
# function add_mc_fault!(net, busid; resistance=0.1, phase_resistance=0.01, type="three-phase", phases=[1, 2, 3])
#     if !("fault" in keys(net))
#         net["fault"] = Dict()
#     end

#     gf = max(1/resistance, 1e-6)
#     gp = max(1/phase_resistance, 1e-6)
#     Gf = zeros(3,3)

#     if lowercase(type) == "lg"
#         i = phases[1]

#         Gf[i,i] = gf
#     elseif lowercase(type) == "ll"
#         i = phases[1]
#         j = phases[2]

#         Gf[i,j] = gf
#         Gf[j,i] = gf
#     elseif lowercase(type) == "llg"
#         i = phases[1]
#         j = phases[2]        
#         # See https://en.wikipedia.org/wiki/Y-%CE%94_transform
#         # Section: Equations for the transformation from Y to Delta
#         gtot = 2*gp + gf

#         gpp = gp*gp/gtot 
#         gpg = gp*gf/gtot

#         G[i,j] = gpp
#         G[j,i] = gpp
#         G[i,i] = gpg
#         G[j,j] = gpg
#     elseif lowercase(type) == "3p" # three-phase ungrounded
#         # See http://faculty.citadel.edu/potisuk/elec202/notes/3phase1.pdf p. 12
#         gpp = gf/3

#         for i in 1:3
#             for j in 1:3
#                 if i != j
#                     G[i,j] = gpp
#                 end
#             end
#         end        
#     elseif lowercase(type) == "3pg" #