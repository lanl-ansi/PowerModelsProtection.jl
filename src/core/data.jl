
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
    get_active_phases!(data)
    if !haskey(data, "fault")
        add_fault_study!(data)
    else
        add_fault!(data)
    end
    delete!(data, "bus_phases")
end

function add_fault!(data::Dict{String,Any})
    hold = deepcopy(data["fault"])
    data["fault"] = Dict{String, Any}()
    for (k, fault) in hold
        for (i, bus) in data["bus"]
            if bus["name"] == fault["bus"]
                !haskey(data["fault"], i) ? data["fault"][i] = Dict{String, Any}() : nothing
                if fault["type"] == "lg"
                    add_lg_fault!(data, bus, i, fault["phases"], fault["gr"])
                elseif fault["type"] == "ll"
                    add_ll_fault!(data, bus, i, fault["phases"], fault["gr"])
                elseif fault["type"] == "3p"
                    add_3p_fault!(data, bus, i, fault["phases"], fault["gr"])
                elseif fault["type"] == "3pg"
                    add_3pg_fault!(data, bus, i, fault["phases"], fault["gr"], fault["pr"])
                end
            end
        end
    end
end

function add_fault_study!(data::Dict{String,Any})
    data["fault"] = Dict{String, Any}()
    get_fault_buses!(data)
    println(data["fault_buses"])
    for (i, bus) in data["bus"]
        if i in data["fault_buses"]
            data["fault"][i] = Dict{String, Any}()
            add_lg_fault!(data, bus, i)
            add_ll_fault!(data, bus, i)
            add_3p_fault!(data, bus, i)
        end
    end
    delete!(data, "fault_buses")
end

function add_lg_fault!(data::Dict{String,Any}, bus::Dict{String,Any}, i::String, phases, resistance)
    gf = max(1/resistance, 1e-6)
    ncnd = 3
    !haskey(data["fault"][i], "lg") ? data["fault"][i]["lg"] = Dict{Int, Any}() : nothing
    length(keys(data["fault"][i]["lg"])) > 0 ? index = length(keys(data["fault"][i]["lg"])) + 1 : index = 1
    c = phases[1]
    Gf = zeros(ncnd, ncnd)
    Gf[c,c] = gf
    data["fault"][i]["lg"][index] = Dict("bus_i" => bus["bus_i"], "type" => "lg", "Gf"=> Gf, "phases" => [c], "name" => bus["name"])
end

function add_ll_fault!(data::Dict{String,Any}, bus::Dict{String,Any}, i::String, phases, phase_resistance)
    gf = max(1/phase_resistance, 1e-6)
    ncnd = 3
    !haskey(data["fault"][i], "ll") ? data["fault"][i]["ll"] = Dict{Int, Any}() : nothing
    length(keys(data["fault"][i]["ll"])) > 0 ? index = length(keys(data["fault"][i]["ll"])) + 1 : index = 1
    j = phases[1]
    k = phases[2]
    Gf = zeros(3, 3)
    Gf[j,j] = gf
    Gf[j,k] = -gf
    Gf[k,k] = gf
    Gf[k,j] = -gf
    data["fault"][i]["ll"][index] = Dict("bus_i" => bus["bus_i"], "type" => "ll", "Gf"=> Gf, "phases" => [j, k])
end

function add_3p_fault!(data::Dict{String,Any}, bus::Dict{String,Any}, i::String, phases, phase_resistance)
    gf = max(1/phase_resistance, 1e-6)
    data["fault"][i]["3p"] = Dict{Int, Any}()
    ncnd = length(data["bus_phases"][bus["bus_i"]])
    if ncnd == 3
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
        data["fault"][i]["3p"][1] = Dict("bus_i" => bus["bus_i"], "type" => "3p", "Gf"=> Gf, "phases" => [1,2,3])
    end
end

function add_llg_fault!(data::Dict{String,Any}, bus::Dict{String,Any}, i::String, phases, resistance=0.0001, phase_resistance=0.0001)
    gp = max(1/phase_resistance, 1e-6)
    gf = max(1/resistance, 1e-6)
    gtot = 2 * gp + gf
    gpp = gp * gp/gtot
    gpg = gp * gf/gtot
    data["fault"][i]["3pg"] = Dict{Int, Any}()
    ncnd = length(data["bus_phases"][bus["bus_i"]])
    if ncnd == 3
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
        data["fault"][i]["3pg"][1] = Dict("bus_i" => bus["bus_i"], "type" => "3pg", "Gf"=> Gf, "phases" => [1,2,3])
    end
end


function add_3pg_fault!(data::Dict{String,Any}, bus::Dict{String,Any}, i::String, phases, resistance=0.0001, phase_resistance=0.0001)
    gp = max(1/phase_resistance, 1e-6)
    gf = max(1/resistance, 1e-6)
    gtot = 3 * gp + gf
    gpp = gp * gp/gtot
    gpg = gp * gf/gtot
    data["fault"][i]["3pg"] = Dict{Int, Any}()
    ncnd = length(data["bus_phases"][bus["bus_i"]])
    if ncnd == 3
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
        data["fault"][i]["3pg"][1] = Dict("bus_i" => bus["bus_i"], "type" => "3pg", "Gf"=> Gf, "phases" => [1,2,3])
    end
end

function add_lg_fault!(data::Dict{String,Any}, bus::Dict{String,Any}, i::String; resistance=0.0001)
    gf = max(1/resistance, 1e-6)
    ncnd = 3
    data["fault"][i]["lg"] = Dict{Int, Any}()
    index = 1
    for c in data["bus_phases"][bus["bus_i"]]
        Gf = zeros(ncnd, ncnd)
        Gf[c,c] = gf
        data["fault"][i]["lg"][index] = Dict("bus_i" => bus["bus_i"], "type" => "lg", "Gf"=> Gf, "phases" => [c])
        index += 1
    end
end

function add_ll_fault!(data::Dict{String,Any}, bus::Dict{String,Any}, i::String; phase_resistance=0.0001)
    gf = max(1/phase_resistance, 1e-6)
    data["fault"][i]["ll"] = Dict{Int, Any}()
    ncnd = length(data["bus_phases"][bus["bus_i"]])
    index = 1
    for j = 1:ncnd 
        for k = j+1:ncnd
            Gf = zeros(3, 3)
            Gf[j,j] = gf
            Gf[j,k] = -gf
            Gf[k,k] = gf
            Gf[k,j] = -gf
            data["fault"][i]["ll"][index] = Dict("bus_i" => bus["bus_i"], "type" => "ll", "Gf"=> Gf, "phases" => [j, k])
            index += 1
        end
    end
end

function add_3p_fault!(data::Dict{String,Any}, bus::Dict{String,Any}, i::String; phase_resistance=0.0001)
    gf = max(1/phase_resistance, 1e-6)
    data["fault"][i]["3p"] = Dict{Int, Any}()
    ncnd = length(data["bus_phases"][bus["bus_i"]])
    if ncnd == 3
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
        data["fault"][i]["3p"][1] = Dict("bus_i" => bus["bus_i"], "type" => "3p", "Gf"=> Gf, "phases" => [1,2,3])
    end
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

function get_fault_buses!(data::Dict{String,Any})
    hold = []
    for (i, bus) in data["bus"]
        if !haskey(bus, "source_id")
            push!(hold, i)
        end
    end
    data["fault_buses"] = hold
end

