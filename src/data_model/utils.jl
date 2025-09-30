
"mod (becuase of three phase transformer) of PMD's helper function to map non integer conductor ids into integers"
function _map_conductor_ids!(data_math::Dict{String,<:Any})
    if all(typeof(c) <: Int for c in data_math["conductor_ids"])
        cnd_map = Dict{Any,Int}(c => c for c in data_math["conductor_ids"])
    else
        cnd_map = Dict{Any,Int}(c => idx for (idx, c) in enumerate(data_math["conductor_ids"]))
    end

    data_math["conductor_ids"] = Vector{Int}([cnd_map[c] for c in data_math["conductor_ids"]])

    # TODO make more robus with f_connections and t_connections as vectors
    for type in ["branch", "switch", "transformer"]
        if haskey(data_math, type)
            for (_, obj) in data_math[type]
                obj["f_connections"] = Vector{Int}([cnd_map[c] for c in obj["f_connections"]])
                if haskey(obj, "sm_nom") && length(obj["sm_nom"]) > 2
                    t_connections_org = deepcopy(obj["t_connections"])
                    obj["t_connections"] = Vector{Vector{Int}}()
                    for t_connections in t_connections_org
                        push!(obj["t_connections"], Vector{Int}([cnd_map[c] for c in t_connections]))
                    end
                else
                    obj["t_connections"] = Vector{Int}([cnd_map[c] for c in obj["t_connections"]])
                end
            end
        end
    end

    for type in ["load", "shunt", "gen", "storage"]
        if haskey(data_math, type)
            for (_, obj) in data_math[type]
                obj["connections"] = Vector{Int}([cnd_map[c] for c in obj["connections"]])
            end
        end
    end

    for (_, bus) in data_math["bus"]
        bus["terminals"] = Vector{Int}([cnd_map[t] for t in bus["terminals"]])
    end
end


function _convert_sparse_matrix(m::Dict{Tuple,Complex{Float64}})
    rows = zeros(Int64, length(m))
    columns = zeros(Int64, length(m))
    values = zeros(Complex{Float64}, length(m))
    indx = 1
    for ((i, j), val) in m
        rows[indx] = i
        columns[indx] = j
        values[indx] = val
        indx += 1
    end
    return SparseArrays.sparse(rows, columns, values)
end


function _add_phases!(data)
    phases = 0
    if haskey(data, "connections")
        phases = length(f_connections)
    end
    data["phases"] = phases
end


" checks if delta-gwye transformer is connected to gen "
function check_gen_transformer(data)
    nothing
end


function calculate_currents(gen, v, data)
    transformer = data["transformer"][gen["transformer_id"]]
    f_bus = transformer["f_bus"]
    t_bus = transformer["t_bus"]
    y = transformer["p_matrix"]
    n = size(y)[1]
    _v = zeros(Complex{Float64}, n, 1)
    for (i, j) in enumerate(transformer["f_connections"])
        if haskey(data["admittance_map"], (f_bus, j)) 
            _v[i, 1] = v[data["admittance_map"][(f_bus, j)], 1]
        else
             _v[i, 1] = 0.0 + 0.0im
        end
    end
    for (i, j) in enumerate(transformer["t_connections"])
        if haskey(data["admittance_map"], (t_bus, j))
            _v[i+length(transformer["t_connections"]), 1] = v[data["admittance_map"][(t_bus, j)], 1]
        else
            _v[i+length(transformer["t_connections"]), 1] = 0.0 + 0.0im
        end
    end
    _i = y * _v 
    i_012 = inv(PowerModelsProtection._A)*_i[1:3,1] 
    v_012 = inv(PowerModelsProtection._A)*_v[1:3,1]
    return _i[1:3,1], i_012, _v[1:3,1], v_012
end


"copy/mod for pmp helper function to map non integer conductor ids into integers"
function _pmp_map_conductor_ids!(data_math::Dict{String,<:Any})
    if all(typeof(c) <: Int for c in data_math["conductor_ids"])
        cnd_map = Dict{Any,Int}(c => c for c in data_math["conductor_ids"])
    else
        cnd_map = Dict{Any,Int}(c => idx for (idx, c) in enumerate(data_math["conductor_ids"]))
    end

    data_math["conductor_ids"] = Vector{Int}([cnd_map[c] for c in data_math["conductor_ids"]])

    for type in ["branch", "switch"]
        if haskey(data_math, type)
            for (_,obj) in data_math[type]
                obj["f_connections"] = Vector{Int}([cnd_map[c] for c in obj["f_connections"]])
                obj["t_connections"] = Vector{Int}([cnd_map[c] for c in obj["t_connections"]])
            end
        end
    end

    for type in ["transformer"]
        if haskey(data_math, type)
            for (_,obj) in data_math[type]
                if length(obj["f_connections"]) == 3 || length(obj["f_connections"]) == 2
                    obj["phases"] = 3
                else
                    obj["phases"] = 1
                end
            end
        end
    end

    for type in ["load", "shunt", "gen", "storage"]
        if haskey(data_math, type)
            for (_,obj) in data_math[type]
                obj["connections"] = Vector{Int}([cnd_map[c] for c in obj["connections"]])
            end
        end
    end

    for (_,bus) in data_math["bus"]
        bus["terminals"] = Vector{Int}([cnd_map[t] for t in bus["terminals"]])
    end
end


function build_graph(data, componenet_list)
    indx = 0
    nodes = Dict{String, Int}()
    reverse_nodes = Dict{Int, String}()
    for (i, bus) in data["bus"]
        indx += 1
        nodes[i] = indx
        reverse_nodes[indx] = i
    end
    g = Graphs.SimpleGraph(indx)
    for (i, component) in enumerate(componenet_list)
        for (i, edge) in data[component]
            if haskey(edge, "status")
                edge["status"] == 1 ? Graphs.add_edge!(g, nodes["$(edge["f_bus"])"], nodes["$(edge["t_bus"])"]) : nothing
            elseif haskey(edge, "br_status")
                edge["br_status"] == 1 ? Graphs.add_edge!(g, nodes["$(edge["f_bus"])"], nodes["$(edge["t_bus"])"]) : nothing
            else
                println("$(component) is missing status")
            end
        end
    end
    # for (i, switch) in data["switch"]
    #     Graphs.add_edge!(g, nodes["$(switch["f_bus"])"], nodes["$(switch["t_bus"])"])
    # end
    return g, nodes, reverse_nodes
end


function add_voltages_through_graph!(data)
    g, nodes, reverse_nodes = build_graph(data, ["branch", "switch"])
    connections = Graphs.connected_components(g)
    vbase = Dict{Int, Any}()
    for (i, transformer) in data["transformer"]
        for (j, connection) in enumerate(connections)
            if nodes["$(transformer["f_bus"])"] in connection
                if j in keys(vbase)
                    if vbase[j]["phases"] == transformer["phases"]
                        if vbase[j]["voltage"] != transformer["tm_nom"][1]
                            vbase[j]["voltage"] = max(vbase[j]["voltage"], transformer["tm_nom"][1])
                        end
                    else
                        if vbase[j]["phases"] <= transformer["phases"]
                            vbase[j]["voltage"] = transformer["tm_nom"][1]
                            vbase[j]["phases"] = transformer["phases"]
                        end
                    end
                else
                    vbase[j] = Dict{String, Any}(
                        "voltage" => transformer["tm_nom"][1],
                        "phases" => transformer["phases"]
                    )
                end
            elseif nodes["$(transformer["t_bus"])"] in connection
                if j in keys(vbase)
                    if vbase[j]["phases"] == transformer["phases"]
                        if vbase[j]["voltage"] != transformer["tm_nom"][2]
                            vbase[j]["voltage"] = max(vbase[j]["voltage"], transformer["tm_nom"][2])
                        end
                    else
                        if vbase[j]["phases"] <= transformer["phases"]
                            vbase[j]["voltage"] = transformer["tm_nom"][2]
                            vbase[j]["phases"] = transformer["phases"]
                        end
                    end
                else
                    vbase[j] = Dict{String, Any}(
                        "voltage" => transformer["tm_nom"][2],
                        "phases" => transformer["phases"]
                    )
                end
            end
        end
    end
    for (i, gen) in data["gen"]
        for (j, connection) in enumerate(connections)
            if nodes["$(gen["gen_bus"])"] in connection
                if j in keys(vbase)
                    if vbase[j]["phases"] == length(gen["vg"])
                        if length(gen["vg"]) == 3
                            if vbase[j]["voltage"] != gen["vg"][1] * sqrt(3)
                                vbase[j]["voltage"] = max(vbase[j]["voltage"], gen["vg"][1] * sqrt(3))
                            end
                        else
                            if vbase[j]["voltage"] != gen["vg"][1]
                                vbase[j]["voltage"] = max(vbase[j]["voltage"], gen["vg"][1])
                            end
                        end
                    else
                        if vbase[j]["phases"] <= length(gen["vg"])
                            vbase[j]["voltage"] = length(gen["vg"]) == 3 ? gen["vg"][1]*sqrt(3) : gen["vg"]
                            vbase[j]["phases"] = length(gen["vg"])
                        end
                    end
                else
                    vbase[j] = Dict{String, Any}(
                        "voltage" => length(gen["vg"]) == 3 ? gen["vg"][1]*sqrt(3) : gen["vg"],
                        "phases" => length(gen["vg"])
                    )
                end
            end
        end
    end
    for (j, connection) in enumerate(connections)
        for node in connection
            data["bus"][reverse_nodes[node]]["vbase"] = vbase[j]["voltage"]
        end
    end
    
end


function add_solar_imax!(data, multiplier)
    for (i, gen) in data["gen"]
        if gen["model_type"] == "pv_systems"
            i_rated = (gen["pmax"][1] * data["settings"]["voltage_scale_factor"]) / (gen["vbase"] * data["settings"]["power_scale_factor"])
            gen["i_max"] = fill(i_rated*multiplier, length(gen["pmax"]))
            gen["vminpu"] = 1/multiplier
        end
    end
end


function ckeck_connectivity(data)
    g, nodes, reverse_nodes = build_graph(data, ["branch", "switch", "transformer"])
    connections = Graphs.connected_components(g)
    if length(connections) > 1
        println("network contains disconnected componets")
    else
        println("network is connected")
    end
end


function remove_based_transformer_graph(data)
    new_data = deepcopy(data)
    g, nodes, reverse_nodes = build_graph(data, ["branch", "switch"])
    sub = ""
    for (i, gen) in data["gen"]
        if gen["model_type"] == "energy_source"
            sub = "$(gen["gen_bus"])"
        end
    end
    network = []
    connections = Graphs.connected_components(g)
    for (i, connection) in enumerate(connections)
        if nodes[sub] in connection
            network = connection
        end
    end
    branch_types = ["transformer", "branch", "switch"]
    for branch_type in branch_types
        for (i, branch) in data[branch_type]
            if !(nodes["$(branch["t_bus"])"] in network && nodes["$(branch["f_bus"])"] in network)
                delete!(new_data[branch_type], i)
            end
        end
    end
    component_types = ["load", "gen"]
    for componet_type in component_types
        for (i, component) in data[componet_type] 
            bus = component["$(componet_type)_bus"]
            if !(nodes["$(bus)"] in network)
                delete!(new_data[componet_type], i)
            end
        end
    end

    for (i, bus) in data["bus"]
        if !(nodes["$(bus["bus_i"])"] in network)
            delete!(new_data["bus"], i)
        end
    end
    return new_data
end


function remove_delta_transformer_graph(data)
    new_data = deepcopy(data)
    indx = 0
    nodes = Dict{String, Int}()
    reverse_nodes = Dict{Int, String}()
    for (i, bus) in data["bus"]
        indx += 1
        nodes[i] = indx
        reverse_nodes[indx] = i
    end
    sub = ""
    for (i, gen) in data["gen"]
        if gen["model_type"] == "energy_source"
            sub = "$(gen["gen_bus"])"
        end
    end
    g = Graphs.SimpleGraph(indx)
    componenet_list = ["branch", "switch"]
    for (i, component) in enumerate(componenet_list)
        for (i, edge) in data[component]
            Graphs.add_edge!(g, nodes["$(edge["f_bus"])"], nodes["$(edge["t_bus"])"])
        end
    end
    for (i, transformer) in data["transformer"]
        if !(_PMD.DELTA in transformer["configuration"])
            Graphs.add_edge!(g, nodes["$(transformer["f_bus"])"], nodes["$(transformer["t_bus"])"])
        end
    end
    network = []
    connections = Graphs.connected_components(g)
    for (i, connection) in enumerate(connections)
        if nodes[sub] in connection
            network = connection
        end
    end
    branch_types = ["transformer", "branch", "switch"]
    for branch_type in branch_types
        for (i, branch) in data[branch_type]
            if !(nodes["$(branch["t_bus"])"] in network && nodes["$(branch["f_bus"])"] in network)
                delete!(new_data[branch_type], i)
            end
        end
    end
    component_types = ["load", "gen"]
    for componet_type in component_types
        for (i, component) in data[componet_type] 
            bus = component["$(componet_type)_bus"]
            if !(nodes["$(bus)"] in network)
                delete!(new_data[componet_type], i)
            end
        end
    end

    for (i, bus) in data["bus"]
        if !(nodes["$(bus["bus_i"])"] in network)
            delete!(new_data["bus"], i)
        end
    end
    return new_data
end


function remove_inactive_transformer_graph(data)
    new_data = deepcopy(data)
    indx = 0
    nodes = Dict{String, Int}()
    reverse_nodes = Dict{Int, String}()
    for (i, bus) in data["bus"]
        indx += 1
        nodes[i] = indx
        reverse_nodes[indx] = i
    end
    sub = ""
    for (i, gen) in data["gen"]
        if gen["model_type"] == "energy_source"
            sub = "$(gen["gen_bus"])"
        end
    end
    for (i, gen) in data["storage"]
        sub = "$(gen["storage_bus"])"
    end
    g = Graphs.SimpleGraph(indx)
    componenet_list = ["branch", "switch"]
    for (i, component) in enumerate(componenet_list)
        for (i, edge) in data[component]
            Graphs.add_edge!(g, nodes["$(edge["f_bus"])"], nodes["$(edge["t_bus"])"])
        end
    end
    for (i, transformer) in data["transformer"]
        if transformer["status"] == 1
            Graphs.add_edge!(g, nodes["$(transformer["f_bus"])"], nodes["$(transformer["t_bus"])"])
        end
    end
    network = []
    connections = Graphs.connected_components(g)
    for (i, connection) in enumerate(connections)
        if nodes[sub] in connection
            network = connection
        end
    end
    branch_types = ["transformer", "branch", "switch"]
    for branch_type in branch_types
        for (i, branch) in data[branch_type]
            if !(nodes["$(branch["t_bus"])"] in network && nodes["$(branch["f_bus"])"] in network)
                delete!(new_data[branch_type], i)
            end
        end
    end
    component_types = ["load", "gen"]
    for componet_type in component_types
        for (i, component) in data[componet_type] 
            bus = component["$(componet_type)_bus"]
            if !(nodes["$(bus)"] in network)
                delete!(new_data[componet_type], i)
            end
        end
    end

    for (i, bus) in data["bus"]
        if !(nodes["$(bus["bus_i"])"] in network)
            delete!(new_data["bus"], i)
        end
    end
    return new_data
end


function storage_add_transformer_model!(data)
    for (i, storage) in data["storage"]
        for (_, transformer) in data["transformer"]
            if transformer["f_bus"] == storage["storage_bus"]
                storage["transformer"] = Dict{String,Any}(
                    "p_matrix" => transformer["p_matrix"],
                    "f_bus" => transformer["f_bus"],
                    "f_connections" => transformer["f_connections"],
                )
            end
        end
    end
end