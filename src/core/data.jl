
""
function check_pf!(data::Dict{String,Any}, solver)
    if haskey(data, "pf")
        if data["pf"] == "true"
            add_pf_data!(data, solver)
        end
    else
        add_pf_data!(data, solver)
    end
end


""
function add_pf_data!(data::Dict{String,Any}, solver)
    if haskey(data, "method") && (data["method"] == "PMD")
        println("Running MC PF")
        result = _PMD.run_mc_pf(data, _PM.ACPPowerModel, solver)
        println(result["solution"]["bus"])
        println("Adding PF results to data")
        add_mc_pf_data!(data, result)
    else
        if haskey(data, "method") && (data["method"] == "PMs")
            result = _PMD.run_pf(data, _PM.ACPPowerModel, solver)
            add_pf_data!(data, result)
        end
    end
end


""
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

function add_mc_pf_data!(data::Dict{String,Any}, result::Dict{String,Any})
    # need to work on 
    # if result["primal_status"] == MOI.FEASIBLE_POINT
    #     for (i, bus) in result["solution"]["bus"]
    #         data["bus"][i]["vm"] = bus["vm"]
    #         data["bus"][i]["va"] = bus["va"]
    #     end
    # else
    #     Memento.info(_LOGGER, "The model power flow returned infeasible")
    # end
end

""
function add_fault_data!(data::Dict{String,Any})
    if haskey(data, "fault")
        add_fault!(data)
    else
        add_fault_study!(data)
    end
end


""
function add_fault!(data::Dict{String,Any})
    hold = deepcopy(data["fault"])
    data["fault"] = Dict{String, Any}()
    for (k, fault) in hold
        for (i, bus) in data["bus"]
            if bus["index"] == fault["bus"]
                add_fault!(data, bus, i, fault["r"])
            end
        end
    end
end


""
function add_fault_study!(data::Dict{String,Any})
    data["fault"] = Dict{String, Any}()
    get_active_phases!(data)
    get_fault_buses!(data)
    for (i, bus) in data["bus"]
        if i in data["fault_buses"]
            data["fault"][i] = Dict{String, Any}()
            add_fault!(data, bus, i, 0.0001)
        end
    end
    delete!(data, "fault_buses")
end


""
function add_fault!(data::Dict{String,Any}, bus::Dict{String,Any}, i::String, resistance=0.0001)
    gf = max(1/resistance, 1e-6)
    haskey(data["fault"], i) || (data["fault"][i] = Dict{Int, Any}())
    index = length(keys(data["fault"][i])) + 1
    data["fault"][i][index] = Dict("bus_i" => bus["bus_i"], "gf"=> gf)
end


""
function add_mc_fault_data!(data::Dict{String,Any})
    if haskey(data, "fault")
        add_mc_fault!(data)
    else
        add_mc_fault_study!(data)
    end
end


""
function add_mc_fault!(data::Dict{String,Any})
    hold = deepcopy(data["fault"])
    data["fault"] = Dict{String, Any}()
    for (k, fault) in hold
        i = fault["bus"]
        haskey(data["fault"], i) || (data["fault"][i] = Dict{String, Any}())
        if fault["type"] == "lg"
            add_lg_fault!(data, i, fault["phases"], fault["gr"])
        elseif fault["type"] == "ll"
            add_ll_fault!(data, i, fault["phases"], fault["gr"])
        elseif fault["type"] == "llg"
            add_llg_fault!(data, i, fault["phases"], fault["gr"], fault["pr"])
        elseif fault["type"] == "3p"
            add_3p_fault!(data, i, fault["phases"], fault["gr"])
        elseif fault["type"] == "3pg"
            add_3pg_fault!(data, i, fault["phases"], fault["gr"], fault["pr"])
        end
    end
end



""
function add_mc_fault_study!(data::Dict{String,Any})
    data["fault"] = Dict{String, Any}()
    get_fault_buses!(data) 
    for i in data["fault_buses"]
        bus = data["bus_lookup"][i]
        data["fault"][i] = Dict{String, Any}()
        add_lg_fault_study!(data, bus, i)
        add_ll_fault_study!(data, bus, i)
        add_llg_fault_study!(data, bus, i)
        add_3p_fault_study!(data, bus, i)
        add_3pg_fault_study!(data, bus, i)
    end
    delete!(data, "fault_buses")
end


""
function add_lg_fault!(data::Dict{String,Any}, i::String, phases, resistance)
    bus = data["bus_lookup"][i]
    b = string(bus)
    s_base = data["baseMVA"] 
    v_base = data["bus"][b]["vbase"]/sqrt(3)
    z_base = v_base^2 / s_base
    r = resistance/z_base
    gf = max(1/r, 1e-6)
    ncnd = 3
    haskey(data["fault"][i], "lg") || (data["fault"][i]["lg"] = Dict{Int, Any}())
    index = length(keys(data["fault"][i]["lg"])) + 1
    c = phases[1]
    Gf = zeros(ncnd, ncnd)
    Gf[c,c] = gf
    data["fault"][i]["lg"][index] = Dict("bus_i" => bus, "type" => "lg", "Gf"=> Gf, "phases" => [c])
end


""
function add_ll_fault!(data::Dict{String,Any}, i::String, phases, phase_resistance)
    bus = data["bus_lookup"][i]
    b = string(bus)
    s_base = data["baseMVA"] 
    v_base = data["bus"][b]["vbase"]/sqrt(3)
    z_base = v_base^2 / s_base
    r = phase_resistance/z_base
    gf = max(1/r, 1e-6)
    ncnd = 3
    haskey(data["fault"][i], "ll") || (data["fault"][i]["ll"] = Dict{Int, Any}())
    index = length(keys(data["fault"][i]["ll"])) + 1
    j = phases[1]
    k = phases[2]
    Gf = zeros(3, 3)
    Gf[j,j] = gf
    Gf[j,k] = -gf
    Gf[k,k] = gf
    Gf[k,j] = -gf
    data["fault"][i]["ll"][index] = Dict("bus_i" => bus, "type" => "ll", "Gf"=> Gf, "phases" => [j, k])
end


""
function add_3p_fault!(data::Dict{String,Any}, i::String, phases, phase_resistance)
    bus = data["bus_lookup"][i]
    b = string(bus)
    s_base = data["baseMVA"] 
    v_base = data["bus"][b]["vbase"]/sqrt(3)
    z_base = v_base^2 / s_base
    r = phase_resistance/z_base
    gf = max(1/r, 1e-6)
    data["fault"][i]["3p"] = Dict{Int, Any}()
    ncnd = length(data["bus"][b]["terminals"])  # should add a better check for phases 
    if ncnd >= 3
        Gf = zeros(3, 3)
        for j = 1:3
            for k = 1:3
                if j != k
                    Gf[j,k] = -gf
                else
                    Gf[j,k] = 2*gf
                end
            end
        end
        data["fault"][i]["3p"][1] = Dict("bus_i" => bus, "type" => "3p", "Gf"=> Gf, "phases" => [1,2,3])
    end
end


""
function add_llg_fault!(data::Dict{String,Any}, i::String, phases, resistance=0.0001, phase_resistance=0.0001)
    bus = data["bus_lookup"][i]
    b = string(bus)
    s_base = data["baseMVA"] 
    v_base = data["bus"][b]["vbase"]/sqrt(3)
    z_base = v_base^2 / s_base
    r = resistance/z_base
    p_r = phase_resistance/z_base
    gp = max(1/p_r, 1e-6)
    gf = max(1/r, 1e-6)
    gtot = 2 * gp + gf
    gpp = gp * gp/gtot
    gpg = gp * gf/gtot
    data["fault"][i]["llg"] = Dict{Int, Any}()
    j = phases[1]
    k = phases[2]
    Gf = zeros(3, 3)
    Gf[j,j] = gpp + gpg
    Gf[j,k] = -gpp
    Gf[k,k] = gpp + gpg
    Gf[k,j] = -gpp
    data["fault"][i]["llg"][1] = Dict("bus_i" => bus, "type" => "llg", "Gf"=> Gf, "phases" => [j, k])
end


""
function add_3pg_fault!(data::Dict{String,Any}, i::String, phases, resistance=0.0001, phase_resistance=0.0001)
    bus = data["bus_lookup"][i]
    b = string(bus)
    s_base = data["baseMVA"] 
    v_base = data["bus"][b]["vbase"]/sqrt(3)
    z_base = v_base^2 / s_base
    r = resistance/z_base
    p_r = phase_resistance/z_base
    gp = max(1/p_r, 1e-6)
    gf = max(1/r, 1e-6)
    gtot = 3 * gp + gf
    gpp = gp * gp/gtot
    gpg = gp * gf/gtot
    data["fault"][i]["3pg"] = Dict{Int, Any}()
    ncnd = length(data["bus"][b]["terminals"])
    if ncnd >= 3
        Gf = zeros(3, 3)
        for j = 1:3
            for k = 1:3
                if j != k
                    Gf[j,k] = -gpp
                else
                    Gf[j,k] = 2*gpp + gpg
                end
            end
        end
        data["fault"][i]["3pg"][1] = Dict("bus_i" => bus, "type" => "3pg", "Gf"=> Gf, "phases" => [1,2,3])
    end
end


""
function add_lg_fault_study!(data::Dict{String,Any}, bus::Int, i; resistance=0.01)
    b = string(bus)
    s_base = data["baseMVA"] 
    v_base = data["bus"][b]["vbase"]/sqrt(3)
    z_base = v_base^2 / s_base
    r = resistance/z_base
    gf = max(1/r, 1e-6)
    ncnd = 3
    data["fault"][i]["lg"] = Dict{Int, Any}()
    index = 1
    for c in data["bus"][b]["terminals"]
        if c != 4
            Gf = zeros(ncnd, ncnd)
            Gf[c,c] = gf
            data["fault"][i]["lg"][index] = Dict("bus_i" => bus, "type" => "lg", "Gf"=> Gf, "phases" => [c])
            index += 1
        end
    end
end


""
function add_ll_fault_study!(data::Dict{String,Any}, bus::Int, i; phase_resistance=0.01)
    b = string(bus)
    s_base = data["baseMVA"] 
    v_base = data["bus"][b]["vbase"]/sqrt(3)
    z_base = v_base^2 / s_base
    r = phase_resistance/z_base
    gf = max(1/r, 1e-6)
    data["fault"][i]["ll"] = Dict{Int, Any}()
    index = 1
    for j in data["bus"][b]["terminals"]
        if j != 4
            for k in data["bus"][b]["terminals"]
                if k != 4 && j < k 
                    Gf = zeros(3, 3)
                    Gf[j,j] = gf
                    Gf[j,k] = -gf
                    Gf[k,k] = gf
                    Gf[k,j] = -gf
                    data["fault"][i]["ll"][index] = Dict("bus_i" => bus, "type" => "ll", "Gf"=> Gf, "phases" => [j, k])
                    index += 1
                end
            end
        end
    end
end


""
function add_llg_fault_study!(data::Dict{String,Any}, bus::Int, i, resistance=0.01, phase_resistance=0.01)
    b = string(bus)
    s_base = data["baseMVA"] 
    v_base = data["bus"][b]["vbase"]/sqrt(3)
    z_base = v_base^2 / s_base
    r = resistance/z_base
    p_r = phase_resistance/z_base
    gp = max(1/p_r, 1e-6)
    gf = max(1/r, 1e-6)
    gtot = 2 * gp + gf
    gpp = gp * gp/gtot
    gpg = gp * gf/gtot
    data["fault"][i]["llg"] = Dict{Int, Any}()
    index = 1
    for j in data["bus"][b]["terminals"]
        if j != 4
            for k in data["bus"][b]["terminals"]
                if k != 4 && j < k
                    Gf = zeros(3, 3)
                    Gf[j,j] = gpp + gpg
                    Gf[j,k] = -gpp
                    Gf[k,k] = gpp + gpg
                    Gf[k,j] = -gpp
                    data["fault"][i]["llg"][1] = Dict("bus_i" => bus, "type" => "llg", "Gf"=> Gf, "phases" => [j, k])
                end
            end
        end
    end
end


""
function add_3p_fault_study!(data::Dict{String,Any}, bus::Int, i; phase_resistance=0.0001)
    b = string(bus)
    s_base = data["baseMVA"] 
    v_base = data["bus"][b]["vbase"]/sqrt(3)
    z_base = v_base^2 / s_base
    p_r = phase_resistance/z_base
    gf = max(1/p_r, 1e-6)
    data["fault"][i]["3p"] = Dict{Int, Any}()
    ncnd = length(data["bus"][b]["terminals"])
    if ncnd >= 3
        Gf = zeros(3, 3)
        for j = 1:3
            for k = 1:3
                if j != k
                    Gf[j,k] = -gf
                else
                    Gf[j,k] = 2*gf
                end
            end
        end
        data["fault"][i]["3p"][1] = Dict("bus_i" => bus, "type" => "3p", "Gf"=> Gf, "phases" => [1,2,3])
    end
end


""
function add_3pg_fault_study!(data::Dict{String,Any}, bus::Int, i, resistance=0.0001, phase_resistance=0.0001)
    b = string(bus)
    s_base = data["baseMVA"] 
    v_base = data["bus"][b]["vbase"]/sqrt(3)
    z_base = v_base^2 / s_base
    r = resistance/z_base
    p_r = phase_resistance/z_base
    gp = max(1/p_r, 1e-6)
    gf = max(1/r, 1e-6)
    gtot = 3 * gp + gf
    gpp = gp * gp/gtot
    gpg = gp * gf/gtot
    data["fault"][i]["3pg"] = Dict{Int, Any}()
    ncnd = length(data["bus"][b]["terminals"])
    if ncnd >= 3
        Gf = zeros(3, 3)
        for j = 1:3
            for k = 1:3
                if j != k
                    Gf[j,k] = -gpp
                else
                    Gf[j,k] = 2*gpp + gpg
                end
            end
        end
        data["fault"][i]["3pg"][1] = Dict("bus_i" => bus, "type" => "3pg", "Gf"=> Gf, "phases" => [1,2,3])
    end
end

function get_fault_buses!(data::Dict{String,Any})
    hold = []
    for i in keys(data["bus_lookup"])
        if !occursin("source", i)
            push!(hold, i)
        end
    end
    data["fault_buses"] = hold
end

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


# ""
# function is_pq_inverter(pm::_PM.AbstractPowerModel, i::Int; nw::Int=pm.cnw)
#     gen = ref(pm, nw, :gen, i)

#     if !haskey(gen, "inverter")
#         return false
#     end

#     if gen["inverter"] == 0
#         return false
#     end

#     bus_id = gen["gen_bus"]
#     bus = ref(pm, nw, :bus, bus_id)

#     if bus["bus_type"] == 1
#         return true
#     else
#         return false
#     end
# end
