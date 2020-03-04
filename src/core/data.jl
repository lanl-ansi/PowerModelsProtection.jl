
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
    data["fault"] = Dict{String, Any}()
    # for (i, bus) in data["bus"]
    #     data["fault"][i] = Dict{String, Any}()
    #     data["fault"][i]["ll"] = Dict("gp"=> .01, "phases" => [1, 2])
    #     data["fault"][i]["lg"] = Dict("gf"=> .1, "phases" => [1])
    # end
    data["fault"]["1"] = Dict("bus_i" => 3, "type" => "lg", "gf"=> .1, "phases" => [1])
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