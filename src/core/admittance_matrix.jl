
function build_mc_admittance_matrix(data::Dict{String,<:Any};loading=loading)
    n = add_mc_admittance_map!(data)
    admit_matrix = zeros(Complex{Float64}, n, n)
    current_matrix = zeros(Complex{Float64}, n, n)
    add_mc_voltage_source_p_matrix!(data, admit_matrix)
    add_mc_branch_p_matrix!(data, admit_matrix)
    add_mc_transformer_p_matrix!(data, admit_matrix)
    loading ? add_mc_load_p_matrix!(data, admit_matrix, current_matrix) : nothing 
    add_mc_shunt_p_matrix!(data, admit_matrix)
    # --> need to finish other devices 
    return admit_matrix, current_matrix
end

function add_mc_admittance_map!(data_math::Dict{String,<:Any})
    admittance_map = Dict{Tuple,Int}()
    admittance_type = Dict{Int,Any}()
    indx = 1
# TODO determine if bus is inactive
    for (_, bus) in data_math["bus"]
        id = bus["index"]
        for (i, t) in enumerate(bus["terminals"])
            if bus["bus_type"] != 4
                if !(bus["grounded"][i])
                    admittance_map[(id, t)] = indx
                    admittance_type[indx] = bus["bus_type"]
                    indx += 1
                end
            end
        end
    end

    data_math["admittance_map"] = admittance_map
    data_math["admittance_type"] = admittance_type
    return indx-1
end


function add_mc_voltage_source_p_matrix!(data::Dict{String,<:Any}, admit_matrix::Matrix{ComplexF64})
    for (_, gen) in data["gen"]
        bus = gen["gen_bus"]
        for (_i, i) in enumerate(gen["connections"])
            if haskey(data["admittance_map"], (bus, i))
                for (_j, j) in enumerate(gen["connections"])
                    if haskey(data["admittance_map"], (bus, j))
                        admit_matrix[data["admittance_map"][(bus, i)], data["admittance_map"][(bus, j)]] += gen["p_matrix"][_i,_j]
                    end
                end
            end
        end
    end
end


function add_mc_branch_p_matrix!(data::Dict{String,<:Any}, admit_matrix::Matrix{ComplexF64})
    for (indx, branch) in data["branch"]
        f_bus = branch["f_bus"]
        for (_i, i) in enumerate(branch["f_connections"])
            if haskey(data["admittance_map"], (f_bus, i))
                for (_j, j) in enumerate(branch["f_connections"])
                    if haskey(data["admittance_map"], (f_bus, j))
                        admit_matrix[data["admittance_map"][(f_bus, i)], data["admittance_map"][(f_bus, j)]] += branch["p_matrix"][_i,_j]
                    end
                end
                t_bus = branch["t_bus"]
                for (_j, j) in enumerate(branch["t_connections"])
                    if haskey(data["admittance_map"], (t_bus, j))
                        admit_matrix[data["admittance_map"][(f_bus, i)], data["admittance_map"][(t_bus, j)]] += branch["p_matrix"][_i,_j+length(branch["t_connections"])]
                    end
                end
            end
        end
        t_bus = branch["t_bus"]
        for (_i, i) in enumerate(branch["t_connections"])
            if haskey(data["admittance_map"], (t_bus, i))
                for (_j, j) in enumerate(branch["t_connections"])
                    if haskey(data["admittance_map"], (t_bus, j))
                        admit_matrix[data["admittance_map"][(t_bus, i)], data["admittance_map"][(t_bus, j)]] += branch["p_matrix"][_i+length(branch["t_connections"]),_j+length(branch["t_connections"])]
                    end
                end
                f_bus = branch["f_bus"]
                for (_j, j) in enumerate(branch["f_connections"])
                    if haskey(data["admittance_map"], (f_bus, j))
                        admit_matrix[data["admittance_map"][(t_bus, i)], data["admittance_map"][(f_bus, j)]] += branch["p_matrix"][_i+length(branch["f_connections"]),_j]
                    end
                end
            end
        end
    end
end


function add_mc_transformer_p_matrix!(data::Dict{String,<:Any}, admit_matrix::Matrix{ComplexF64})
    for (indx, transformer) in data["transformer"]
if typeof(transformer["t_bus"]) == Vector{Int}
            add_mc_3w_transformer_p_matrix!(transformer, data, admit_matrix)
        else
            add_mc_2w_transformer_p_matrix!(transformer, data, admit_matrix)
        end
    end
end


function add_mc_2w_transformer_p_matrix!(transformer::Dict{String,<:Any}, data::Dict{String,<:Any}, admit_matrix::Matrix{ComplexF64})
        f_bus = transformer["f_bus"]
        for (_i, i) in enumerate(transformer["f_connections"])
            if haskey(data["admittance_map"], (f_bus, i))
                for (_j, j) in enumerate(transformer["f_connections"])
                    if haskey(data["admittance_map"], (f_bus, j))
                        admit_matrix[data["admittance_map"][(f_bus, i)], data["admittance_map"][(f_bus, j)]] += transformer["p_matrix"][_i,_j]
                    end
                end
                t_bus = transformer["t_bus"]
                for (_j, j) in enumerate(transformer["t_connections"])
                    if haskey(data["admittance_map"], (t_bus, j))
                        if transformer["dss"]["phases"] == 3
                            admit_matrix[data["admittance_map"][(f_bus, i)], data["admittance_map"][(t_bus, j)]] += transformer["p_matrix"][_i,_j+4]
                        elseif transformer["dss"]["phases"] == 1
                            admit_matrix[data["admittance_map"][(f_bus, i)], data["admittance_map"][(t_bus, j)]] += transformer["p_matrix"][_i,_j+2]
                        end
                    end
                end
            end
        end
        t_bus = transformer["t_bus"]
        for (_i, i) in enumerate(transformer["t_connections"])
            if haskey(data["admittance_map"], (t_bus, i))
                for (_j, j) in enumerate(transformer["t_connections"])
                    if haskey(data["admittance_map"], (t_bus, j))
                        if transformer["dss"]["phases"] == 3
                            admit_matrix[data["admittance_map"][(t_bus, i)], data["admittance_map"][(t_bus, j)]] += transformer["p_matrix"][_i+4,_j+4]
                        elseif transformer["dss"]["phases"] == 1
                            admit_matrix[data["admittance_map"][(t_bus, i)], data["admittance_map"][(t_bus, j)]] += transformer["p_matrix"][_i+2,_j+2]
                        end
                    end
                end
                f_bus = transformer["f_bus"]
                for (_j, j) in enumerate(transformer["f_connections"])
                    if haskey(data["admittance_map"], (f_bus, j))
                        if transformer["dss"]["phases"] == 3
                            admit_matrix[data["admittance_map"][(t_bus, i)], data["admittance_map"][(f_bus, j)]] += transformer["p_matrix"][_i+4,_j]
                        elseif transformer["dss"]["phases"] == 1
                            admit_matrix[data["admittance_map"][(t_bus, i)], data["admittance_map"][(f_bus, j)]] += transformer["p_matrix"][_i+2,_j]
                        end
                    end
                end
            end
        end
    end
    

function add_mc_3w_transformer_p_matrix!(transformer::Dict{String,<:Any}, data::Dict{String,<:Any}, admit_matrix::Matrix{ComplexF64})
    f_bus = transformer["f_bus"]
    for (_i, i) in enumerate(transformer["f_connections"])
        if haskey(data["admittance_map"], (f_bus, i))
            for (_j, j) in enumerate(transformer["f_connections"])
                if haskey(data["admittance_map"], (f_bus, j))
                    admit_matrix[data["admittance_map"][(f_bus, i)], data["admittance_map"][(f_bus, j)]] += transformer["p_matrix"][_i,_j]
                end
            end
            for (indx, t_bus) in enumerate(transformer["t_bus"])
                for (_, t_connections) in enumerate(transformer["t_connections"][indx])
                    for (_j, j) in enumerate(t_connections)
                        if haskey(data["admittance_map"], (t_bus, j))
                            if transformer["dss"]["phases"] == 3
                                admit_matrix[data["admittance_map"][(f_bus, i)], data["admittance_map"][(t_bus, j)]] += transformer["p_matrix"][_i,_j+4]
                            elseif transformer["dss"]["phases"] == 1
                                admit_matrix[data["admittance_map"][(f_bus, i)], data["admittance_map"][(t_bus, j)]] += transformer["p_matrix"][_i,_j+2]
                            end
                        end
                    end
                end
            end
        end
    end
    for (indx, t_bus) in enumerate(transformer["t_bus"])
        for (_, t_connections) in enumerate(transformer["t_connections"][indx])
            for (_i, i) in enumerate(t_connections)
                if haskey(data["admittance_map"], (t_bus, i))
                    for (_j, j) in enumerate(transformer["t_connections"][indx])
                        if haskey(data["admittance_map"], (t_bus, j))
                            if transformer["dss"]["phases"] == 3
                                admit_matrix[data["admittance_map"][(t_bus, i)], data["admittance_map"][(t_bus, j)]] += transformer["p_matrix"][_i+4,_j+4]
                            elseif transformer["dss"]["phases"] == 1
                                admit_matrix[data["admittance_map"][(t_bus, i)], data["admittance_map"][(t_bus, j)]] += transformer["p_matrix"][_i+2,_j+2]
                            end
                        end
                    end
                    f_bus = transformer["f_bus"]
                    for (_j, j) in enumerate(transformer["f_connections"])
                        if haskey(data["admittance_map"], (f_bus, j))
                            if transformer["dss"]["phases"] == 3
                                admit_matrix[data["admittance_map"][(t_bus, i)], data["admittance_map"][(f_bus, j)]] += transformer["p_matrix"][_i+4,_j]
                            elseif transformer["dss"]["phases"] == 1
                                admit_matrix[data["admittance_map"][(t_bus, i)], data["admittance_map"][(f_bus, j)]] += transformer["p_matrix"][_i+2,_j]
                            end
                        end
                    end
                end
            end
        end
    end
end


function add_mc_load_p_matrix!(data::Dict{String,<:Any}, admit_matrix::Matrix{ComplexF64}, current_matrix::Matrix{ComplexF64})
    for (_, load) in data["load"]
        bus = load["load_bus"]
        for (_i, i) in enumerate(load["connections"])
            if haskey(data["admittance_map"], (bus, i))
                for (_j, j) in enumerate(load["connections"])
                    if haskey(data["admittance_map"], (bus, j))
                        admit_matrix[data["admittance_map"][(bus, i)], data["admittance_map"][(bus, j)]] += load["p_matrix"][_i,_j]
                        current_matrix[data["admittance_map"][(bus, i)], data["admittance_map"][(bus, j)]] += load["p_matrix"][_i,_j]
                    end
                end
            end
        end
    end
end


function add_mc_shunt_p_matrix!(data::Dict{String,<:Any}, admit_matrix::Matrix{ComplexF64})
    for (_, shunt) in data["shunt"]
        bus = shunt["shunt_bus"]
        for (_i, i) in enumerate(shunt["connections"])
            if haskey(data["admittance_map"], (bus, i))
                for (_j, j) in enumerate(shunt["connections"])
                    if haskey(data["admittance_map"], (bus, j))
                        admit_matrix[data["admittance_map"][(bus, i)], data["admittance_map"][(bus, j)]] += shunt["p_matrix"][_i,_j]
                    end
                end
            end
        end
    end
end


function build_mc_voltage_vector(data::Dict{String,<:Any})
    v = zeros(Complex{Float64}, length(keys(data["admittance_type"])), 1)
    for (indx, load) in data["load"] 
        if load["model"] == _PMD.POWER
            bus = load["load_bus"]
            for (_j, j) in enumerate(load["connections"])
                if haskey(data["admittance_map"], (bus, j))
                    v[data["admittance_map"][(bus, j)],1] = load["vnom_kv"]
                end
            end
        end
    end
    return v
end


function build_mc_current_vector(data::Dict{String,<:Any}, v::Matrix{ComplexF64})
    i = zeros(Complex{Float64}, length(keys(data["admittance_type"])), 1)
    for (_, gen) in data["gen"]
        bus = data["bus"][string(gen["gen_bus"])]
        # n = length(gen["connections"]) 
        n = 3
        p_matrix = zeros(Complex{Float64}, n, n)
        v = zeros(Complex{Float64}, n, 1)
        for i in gen["connections"]
            if i != 4
                v[i,1] = bus["vm"][i] * exp(1im * bus["va"][i] * pi/180)
                for j in gen["connections"]
                    if j != 4
                        p_matrix[i,j] = gen["p_matrix"][i,j]
                    end
                end
            end
        end
        
        i_update = p_matrix * v
        for (_j, j) in enumerate(gen["connections"])
            if (gen["gen_bus"], j) in keys(data["admittance_map"])
                i[data["admittance_map"][(gen["gen_bus"], j)],1] = i_update[_j,1]
            end
        end
    end
 
    return i
end
