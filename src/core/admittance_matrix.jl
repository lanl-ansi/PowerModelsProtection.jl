
function build_mc_admittance_matrix(data::Dict{String,<:Any})
    add_mc_admittance_map!(data)
    admit_matrix = Dict{Tuple,Complex{Float64}}()
    add_mc_generator_p_matrix!(data, admit_matrix)
    add_mc_branch_p_matrix!(data, admit_matrix)
    add_mc_transformer_p_matrix!(data, admit_matrix)
    data["settings"]["loading"] ? add_mc_load_p_matrix!(data, admit_matrix) : nothing 
    add_mc_shunt_p_matrix!(data, admit_matrix)
    # --> need to finish other devices 
    return _convert_sparse_matrix(admit_matrix)
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
    end


function add_mc_generator_p_matrix!(data::Dict{String,<:Any}, admit_matrix::Dict{Tuple,Complex{Float64}})
    for (_, gen) in data["gen"]
        bus = gen["gen_bus"]
        for (_i, i) in enumerate(gen["connections"])
            if haskey(data["admittance_map"], (bus, i))
                for (_j, j) in enumerate(gen["connections"])
                    if haskey(data["admittance_map"], (bus, j))
                        haskey(admit_matrix, (data["admittance_map"][(bus, i)], data["admittance_map"][(bus, j)])) ? admit_matrix[(data["admittance_map"][(bus, i)], data["admittance_map"][(bus, j)])] += gen["p_matrix"][_i,_j] : admit_matrix[(data["admittance_map"][(bus, i)], data["admittance_map"][(bus, j)])] = gen["p_matrix"][_i,_j]
                    end
                end
            end
        end
    end
end


# function add_mc_voltage_source_p_matrix!(data::Dict{String,<:Any}, admit_matrix::Dict{Tuple,Complex{Float64}}, gen::Dict{String,<:Any})
#     bus = gen["gen_bus"]
#     for (_i, i) in enumerate(gen["connections"])
#         if haskey(data["admittance_map"], (bus, i))
#             for (_j, j) in enumerate(gen["connections"])
#                 if haskey(data["admittance_map"], (bus, j))
#                     haskey(admit_matrix, (data["admittance_map"][(bus, i)], data["admittance_map"][(bus, j)])) ? admit_matrix[(data["admittance_map"][(bus, i)], data["admittance_map"][(bus, j)])] += gen["p_matrix"][_i,_j] : admit_matrix[(data["admittance_map"][(bus, i)], data["admittance_map"][(bus, j)])] = gen["p_matrix"][_i,_j]
#                 end
#             end
#         end
#     end
# end



function add_mc_branch_p_matrix!(data::Dict{String,<:Any}, admit_matrix::Dict{Tuple,Complex{Float64}})
    for (indx, branch) in data["branch"]
        f_bus = branch["f_bus"]
        for (_i, i) in enumerate(branch["f_connections"])
            if haskey(data["admittance_map"], (f_bus, i))
                for (_j, j) in enumerate(branch["f_connections"])
                    if haskey(data["admittance_map"], (f_bus, j))
                        haskey(admit_matrix, (data["admittance_map"][(f_bus, i)], data["admittance_map"][(f_bus, j)])) ? admit_matrix[(data["admittance_map"][(f_bus, i)], data["admittance_map"][(f_bus, j)])] += branch["p_matrix"][_i,_j] : admit_matrix[(data["admittance_map"][(f_bus, i)], data["admittance_map"][(f_bus, j)])] = branch["p_matrix"][_i,_j]
                    end
                end
                t_bus = branch["t_bus"]
                for (_j, j) in enumerate(branch["t_connections"])
                    if haskey(data["admittance_map"], (t_bus, j))
                        haskey(admit_matrix, (data["admittance_map"][(f_bus, i)], data["admittance_map"][(t_bus, j)])) ? admit_matrix[(data["admittance_map"][(f_bus, i)], data["admittance_map"][(t_bus, j)])] += branch["p_matrix"][_i,_j+length(branch["t_connections"])] : admit_matrix[(data["admittance_map"][(f_bus, i)], data["admittance_map"][(t_bus, j)])] = branch["p_matrix"][_i,_j+length(branch["t_connections"])]
                    end
                end
            end
        end
        t_bus = branch["t_bus"]
        for (_i, i) in enumerate(branch["t_connections"])
            if haskey(data["admittance_map"], (t_bus, i))
                for (_j, j) in enumerate(branch["t_connections"])
                    if haskey(data["admittance_map"], (t_bus, j))
                        haskey(admit_matrix, (data["admittance_map"][(t_bus, i)], data["admittance_map"][(t_bus, j)])) ? admit_matrix[(data["admittance_map"][(t_bus, i)], data["admittance_map"][(t_bus, j)])] += branch["p_matrix"][_i+length(branch["t_connections"]),_j+length(branch["t_connections"])] : admit_matrix[(data["admittance_map"][(t_bus, i)], data["admittance_map"][(t_bus, j)])] = branch["p_matrix"][_i+length(branch["t_connections"]),_j+length(branch["t_connections"])]
                    end
                end
                f_bus = branch["f_bus"]
                for (_j, j) in enumerate(branch["f_connections"])
                    if haskey(data["admittance_map"], (f_bus, j))
                        haskey(admit_matrix, (data["admittance_map"][(t_bus, i)], data["admittance_map"][(f_bus, j)])) ? admit_matrix[(data["admittance_map"][(t_bus, i)], data["admittance_map"][(f_bus, j)])] += branch["p_matrix"][_i+length(branch["f_connections"]),_j] : admit_matrix[(data["admittance_map"][(t_bus, i)], data["admittance_map"][(f_bus, j)])] = branch["p_matrix"][_i+length(branch["f_connections"]),_j]
                    end
                end
            end
        end
    end
end


function add_mc_transformer_p_matrix!(data::Dict{String,<:Any}, admit_matrix::Dict{Tuple,Complex{Float64}})
    for (indx, transformer) in data["transformer"]
if typeof(transformer["t_bus"]) == Vector{Int}
            add_mc_3w_transformer_p_matrix!(transformer, data, admit_matrix)
        else
            add_mc_2w_transformer_p_matrix!(transformer, data, admit_matrix)
        end
    end
end


function add_mc_2w_transformer_p_matrix!(transformer::Dict{String,<:Any}, data::Dict{String,<:Any}, admit_matrix::Dict{Tuple,Complex{Float64}})
        f_bus = transformer["f_bus"]
        for (_i, i) in enumerate(transformer["f_connections"])
            if haskey(data["admittance_map"], (f_bus, i))
                for (_j, j) in enumerate(transformer["f_connections"])
                    if haskey(data["admittance_map"], (f_bus, j))
                        haskey(admit_matrix, (data["admittance_map"][(f_bus, i)], data["admittance_map"][(f_bus, j)])) ? admit_matrix[(data["admittance_map"][(f_bus, i)], data["admittance_map"][(f_bus, j)])] += transformer["p_matrix"][_i,_j] : admit_matrix[(data["admittance_map"][(f_bus, i)], data["admittance_map"][(f_bus, j)])] = transformer["p_matrix"][_i,_j]
                    end
                end
                t_bus = transformer["t_bus"]
                for (_j, j) in enumerate(transformer["t_connections"])
                    if haskey(data["admittance_map"], (t_bus, j))
                        if transformer["phases"] == 3
                            haskey(admit_matrix, (data["admittance_map"][(f_bus, i)], data["admittance_map"][(t_bus, j)])) ? admit_matrix[(data["admittance_map"][(f_bus, i)], data["admittance_map"][(t_bus, j)])] += transformer["p_matrix"][_i,_j+4] : admit_matrix[(data["admittance_map"][(f_bus, i)], data["admittance_map"][(t_bus, j)])] = transformer["p_matrix"][_i,_j+4]
                        elseif transformer["phases"] == 1
                            haskey(admit_matrix, (data["admittance_map"][(f_bus, i)], data["admittance_map"][(t_bus, j)])) ? admit_matrix[(data["admittance_map"][(f_bus, i)], data["admittance_map"][(t_bus, j)])] += transformer["p_matrix"][_i,_j+2] : admit_matrix[(data["admittance_map"][(f_bus, i)], data["admittance_map"][(t_bus, j)])] = transformer["p_matrix"][_i,_j+2]
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
                        if transformer["phases"] == 3
                            haskey(admit_matrix, (data["admittance_map"][(t_bus, i)], data["admittance_map"][(t_bus, j)])) ? admit_matrix[(data["admittance_map"][(t_bus, i)], data["admittance_map"][(t_bus, j)])] += transformer["p_matrix"][_i+4,_j+4] : admit_matrix[(data["admittance_map"][(t_bus, i)], data["admittance_map"][(t_bus, j)])] = transformer["p_matrix"][_i+4,_j+4]
                        elseif transformer["phases"] == 1
                            haskey(admit_matrix, (data["admittance_map"][(t_bus, i)], data["admittance_map"][(t_bus, j)])) ? admit_matrix[(data["admittance_map"][(t_bus, i)], data["admittance_map"][(t_bus, j)])] += transformer["p_matrix"][_i+2,_j+2] : admit_matrix[(data["admittance_map"][(t_bus, i)], data["admittance_map"][(t_bus, j)])] = transformer["p_matrix"][_i+2,_j+2]
                        end
                    end
                end
                f_bus = transformer["f_bus"]
                for (_j, j) in enumerate(transformer["f_connections"])
                    if haskey(data["admittance_map"], (f_bus, j))
                        if transformer["phases"] == 3
                            haskey(admit_matrix, (data["admittance_map"][(t_bus, i)], data["admittance_map"][(f_bus, j)])) ? admit_matrix[(data["admittance_map"][(t_bus, i)], data["admittance_map"][(f_bus, j)])] += transformer["p_matrix"][_i+4,_j] : admit_matrix[(data["admittance_map"][(t_bus, i)], data["admittance_map"][(f_bus, j)])] = transformer["p_matrix"][_i+4,_j]
                        elseif transformer["phases"] == 1
                            haskey(admit_matrix, (data["admittance_map"][(t_bus, i)], data["admittance_map"][(f_bus, j)])) ? admit_matrix[(data["admittance_map"][(t_bus, i)], data["admittance_map"][(f_bus, j)])] += transformer["p_matrix"][_i+2,_j] : admit_matrix[(data["admittance_map"][(t_bus, i)], data["admittance_map"][(f_bus, j)])] = transformer["p_matrix"][_i+2,_j]
                        end
                    end
                end
            end
        end
    end
    

function add_mc_3w_transformer_p_matrix!(transformer::Dict{String,<:Any}, data::Dict{String,<:Any}, admit_matrix::Dict{Tuple,Complex{Float64}})
    f_bus = transformer["f_bus"]
    for (_i, i) in enumerate(transformer["f_connections"])
        if haskey(data["admittance_map"], (f_bus, i))
            for (_j, j) in enumerate(transformer["f_connections"])
                if haskey(data["admittance_map"], (f_bus, j))
                    haskey(admit_matrix, (data["admittance_map"][(f_bus, i)], data["admittance_map"][(f_bus, j)])) ? admit_matrix[(data["admittance_map"][(f_bus, i)], data["admittance_map"][(f_bus, j)])] += transformer["p_matrix"][_i,_j] : admit_matrix[(data["admittance_map"][(f_bus, i)], data["admittance_map"][(f_bus, j)])] = transformer["p_matrix"][_i,_j]
                end
            end
            for (indx, t_bus) in enumerate(transformer["t_bus"])
                for (_, t_connections) in enumerate(transformer["t_connections"][indx])
                    for (_j, j) in enumerate(t_connections)
                        if haskey(data["admittance_map"], (t_bus, j))
                            if transformer["phases"] == 3
                                haskey(admit_matrix, (data["admittance_map"][(f_bus, i)], data["admittance_map"][(t_bus, j)])) ? admit_matrix[(data["admittance_map"][(f_bus, i)], data["admittance_map"][(t_bus, j)])] += transformer["p_matrix"][_i,_j+4] : admit_matrix[(data["admittance_map"][(f_bus, i)], data["admittance_map"][(t_bus, j)])] = transformer["p_matrix"][_i,_j+4]
                            elseif transformer["phases"] == 1
                                haskey(admit_matrix, (data["admittance_map"][(f_bus, i)], data["admittance_map"][(t_bus, j)])) ? admit_matrix[(data["admittance_map"][(f_bus, i)], data["admittance_map"][(t_bus, j)])] += transformer["p_matrix"][_i,j*3] : admit_matrix[(data["admittance_map"][(f_bus, i)], data["admittance_map"][(t_bus, j)])] = transformer["p_matrix"][_i,j*3]
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
                    for (indx_i, _) in enumerate(transformer["t_connections"])
                        for (_j, j) in enumerate(transformer["t_connections"][indx_i])
                        if haskey(data["admittance_map"], (t_bus, j))
                            if transformer["phases"] == 3
                                haskey(admit_matrix, (data["admittance_map"][(t_bus, i)], data["admittance_map"][(t_bus, j)])) ? admit_matrix[(data["admittance_map"][(t_bus, i)], data["admittance_map"][(t_bus, j)])] += transformer["p_matrix"][_i+4,_j+4] : admit_matrix[(data["admittance_map"][(t_bus, i)], data["admittance_map"][(t_bus, j)])] = transformer["p_matrix"][_i+4,_j+4]
                            elseif transformer["phases"] == 1
                                if _i == indx
                                        haskey(admit_matrix, (data["admittance_map"][(t_bus, i)], data["admittance_map"][(t_bus, j)])) ? admit_matrix[(data["admittance_map"][(t_bus, i)], data["admittance_map"][(t_bus, j)])] += transformer["p_matrix"][i*3,j*3] : admit_matrix[(data["admittance_map"][(t_bus, i)], data["admittance_map"][(t_bus, j)])] = transformer["p_matrix"][i*3,j*3]
                                    else
                                        haskey(admit_matrix, (data["admittance_map"][(t_bus, i)], data["admittance_map"][(t_bus, j)])) ? admit_matrix[(data["admittance_map"][(t_bus, i)], data["admittance_map"][(t_bus, j)])] += transformer["p_matrix"][i*3,j*3] : admit_matrix[(data["admittance_map"][(t_bus, i)], data["admittance_map"][(t_bus, j)])] = transformer["p_matrix"][i*3,j*3]
                                    end
                                end
                            end
                        end
                    end
                    f_bus = transformer["f_bus"]
                    for (_j, j) in enumerate(transformer["f_connections"])
                        if haskey(data["admittance_map"], (f_bus, j))
                            if transformer["phases"] == 3
                                haskey(admit_matrix, (data["admittance_map"][(t_bus, i)], data["admittance_map"][(f_bus, j)])) ? admit_matrix[(data["admittance_map"][(t_bus, i)], data["admittance_map"][(f_bus, j)])] += transformer["p_matrix"][_i+4,_j] : admit_matrix[(data["admittance_map"][(t_bus, i)], data["admittance_map"][(f_bus, j)])] = transformer["p_matrix"][_i+4,_j]
                            elseif transformer["phases"] == 1
                                haskey(admit_matrix, (data["admittance_map"][(t_bus, i)], data["admittance_map"][(f_bus, j)])) ? admit_matrix[(data["admittance_map"][(t_bus, i)], data["admittance_map"][(f_bus, j)])] += transformer["p_matrix"][i*3,_j] : admit_matrix[(data["admittance_map"][(t_bus, i)], data["admittance_map"][(f_bus, j)])] = transformer["p_matrix"][i*3,_j]
                            end
                        end
                    end
                end
            end
        end
    end
end


function add_mc_load_p_matrix!(data::Dict{String,<:Any}, admit_matrix::Dict{Tuple,Complex{Float64}})
    for (_, load) in data["load"]
        bus = load["load_bus"]
        for (_i, i) in enumerate(load["connections"])
            if haskey(data["admittance_map"], (bus, i))
                for (_j, j) in enumerate(load["connections"])
                    if haskey(data["admittance_map"], (bus, j))
                        haskey(admit_matrix, (data["admittance_map"][(bus, i)], data["admittance_map"][(bus, j)])) ? admit_matrix[(data["admittance_map"][(bus, i)], data["admittance_map"][(bus, j)])] += load["p_matrix"][_i,_j] : admit_matrix[(data["admittance_map"][(bus, i)], data["admittance_map"][(bus, j)])] = load["p_matrix"][_i,_j]
                    end
                end
            end
        end
    end
end


function add_mc_shunt_p_matrix!(data::Dict{String,<:Any}, admit_matrix::Dict{Tuple,Complex{Float64}})
    for (_, shunt) in data["shunt"]
        bus = shunt["shunt_bus"]
        for (_i, i) in enumerate(shunt["connections"])
            if haskey(data["admittance_map"], (bus, i))
                for (_j, j) in enumerate(shunt["connections"])
                    if haskey(data["admittance_map"], (bus, j))
                        haskey(admit_matrix, (data["admittance_map"][(bus, i)], data["admittance_map"][(bus, j)])) ? admit_matrix[(data["admittance_map"][(bus, i)], data["admittance_map"][(bus, j)])] += shunt["p_matrix"][_i,_j] : admit_matrix[(data["admittance_map"][(bus, i)], data["admittance_map"][(bus, j)])] = shunt["p_matrix"][_i,_j]
                    end
                end
            end
        end
    end
end


function build_mc_voltage_vector(data::Dict{String,<:Any})
    v = zeros(Complex{Float64}, length(keys(data["admittance_type"])), 1)
    for (indx, bus) in data["bus"] 
        if haskey(bus, "vm")
            for (_j, j) in enumerate(bus["terminals"])
                if haskey(data["admittance_map"], (bus["bus_i"], j))
                    v[data["admittance_map"][(bus["bus_i"], j)],1] = bus["vm"][_j] * data["settings"]["voltage_scale_factor"] * exp(1im*bus["va"][_j]*pi/180)
                end
            end
        else
            for (_j, j) in enumerate(bus["terminals"])
                if haskey(data["admittance_map"], (bus["bus_i"], j))
                    v[data["admittance_map"][(bus["bus_i"], j)],1] = bus["vbase"] * data["settings"]["voltage_scale_factor"] * exp(1im*-2/3*pi*(j-1))
                end
            end
        end
    end
    return v
end


"""
    builds current vector for constant current injection sources
"""
function build_mc_current_vector(data::Dict{String,<:Any}, v::Matrix{ComplexF64})
    i = zeros(Complex{Float64}, length(keys(data["admittance_type"])), 1)
    # TODO look at models for gen and how they are defined
    for (_, gen) in data["gen"]
        if occursin("voltage_source.", gen["source_id"])
            if gen["gen_status"] == 1
                bus = data["bus"][string(gen["gen_bus"])]
                n = 3 #TODO fix when 4 is included
                p_matrix = zeros(Complex{Float64}, n, n)
                v = zeros(Complex{Float64}, n, 1)
                for i in gen["connections"]
                    if i != 4
                        v[i,1] = bus["vm"][i] * data["settings"]["voltage_scale_factor"] * exp(1im * bus["va"][i] * pi/180)
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
        end
    end
    return i
end


" defines i based on setting reg points vs setting current based on voltage"
function build_mc_delta_current_control_vector(data, v, z_matrix)
    (n, m) = size(v)
    delta_i = zeros(Complex{Float64}, n, 1)
    build_mc_delta_current_control_inverter!(delta_i, v, data)
    return _SP.sparse(delta_i)
end


function build_mc_delta_current_control_inverter!(delta_i, v, data)
    for (_, gen) in data["gen"]
        if occursin("solar.", gen["source_id"])
            # convert to inverter model
            if gen["pv_model"] == 4
                if gen["grid_forming"]
                    calc_mc_delta_current_control_gfmi!(gen, delta_i, v, data)
                else
                    nothing
                end
            elseif gen["pv_model"] == 5 
                if gen["grid_forming"]
                    if haskey(gen, "pre_fault_i")
                        bus = gen["gen_bus"]
                        for (_j, j) in enumerate(gen["connections"]) 
                            if j != 4
                                delta_i[data["admittance_map"][(bus, j)], 1] += gen["pre_fault_i"][j] 
                            end
                        end
                    end
                end
            end
        end
    end
end


function calc_mc_delta_current_control_gfmi!(gen, delta_i, v, data)
    bus = gen["gen_bus"]
    v_solar = [gen["vg"][1]; gen["vg"][1]*exp(-2im/3*pi); gen["vg"][1]*exp(2im/3*pi)]
    pg = gen["pg"]
    haskey(gen, "qg") ? qg = gen["qg"] : qg = gen["pg"].*0.0
    s = pg .+ 1im .* qg
    s_seq = s[1]
    v_seq = inv(_A)*v_solar
    i_seq = conj(s_seq/v_seq[2])
    i_inj = _A*[0;i_seq;0]
    s = [v_solar[1,1]*conj(i_inj[1,1]);v_solar[2,1]*conj(i_inj[2,1]);v_solar[3,1]*conj(i_inj[3,1])]
    for (_j, j) in enumerate(gen["connections"]) 
        if j != 4
            delta_i[data["admittance_map"][(bus, j)], 1] += i_inj[j] 
        end
    end
end


function update_mc_delta_current_control_vector(model, v)
    (n, m) = size(v)
    delta_i = zeros(Complex{Float64}, n, 1)
    update_mc_delta_current_gfmi_control!(delta_i, v, model.data)
    return _SP.sparse(delta_i)
end


function update_mc_delta_current_gfmi_control!(delta_i, v, data)
    for (_, gen) in data["gen"]
        if occursin("solar.", gen["source_id"])
            if gen["grid_forming"]
                if gen["pv_model"] == 4
                    update_mc_delta_current_gfmi_control_vbalance!(gen, delta_i, v, data) 
                    # update_mc_delta_current_gfmi_control_k_factor!(gen, delta_i, v, data)
                elseif gen["pv_model"] == 5
                    update_mc_delta_current_gfmi_control_k_factor!(gen, delta_i, v, data)
                end
            end
        end
    end
end


function update_mc_delta_current_gfmi_control_vbalance!(gen, delta_i, v, data)
    transformer = data["transformer"][gen["transformer_id"]]
    f_bus = data["bus"]["$(transformer["f_bus"])"]
    t_bus = data["bus"]["$(transformer["t_bus"])"]
    y = transformer["p_matrix"][5:8,1:8]
    _v = zeros(Complex{Float64}, 8, 1)
    indx = 1
    for (_j, j) in enumerate(f_bus["terminals"])
        if haskey(data["admittance_map"], (f_bus["bus_i"], j))
            _v[indx, 1] = v[data["admittance_map"][(f_bus["bus_i"], j)], 1]
        else
            _v[indx, 1] = 0.0
        end
        indx += 1
    end
    for (_j, j) in enumerate(t_bus["terminals"])
        if haskey(data["admittance_map"], (t_bus["bus_i"], j))
            _v[indx, 1] = v[data["admittance_map"][(t_bus["bus_i"], j)], 1]
        else
            _v[indx, 1] = 0.0
        end
        indx += 1
    end
    i_abc = (transformer["p_matrix"][1:4,1:8]*_v)
    i_012 = inv(_A) * [i_abc[1,1];i_abc[2,1];i_abc[3,1]] 
    v_012 = inv(_A) * [_v[1,1];_v[2,1];_v[3,1]]
    z_1 = v_012[2,1]/i_012[2,1]
    z_2 = v_012[3,1]/i_012[3,1]
    v_inv = [f_bus["vbase"]; f_bus["vbase"]*exp(-2im/3*pi); f_bus["vbase"]*exp(2im/3*pi)] .* data["settings"]["voltage_scale_factor"]
    v_012 = inv(_A) * v_inv
    i_012 = [0;v_012[2,1]/z_1;v_012[3,1]/z_2] 
    i_inj = _A*[0;v_012[2,1]/z_1;v_012[3,1]/z_2] 
    for (_j, j) in enumerate(gen["connections"]) 
        if j != 4
            if abs(i_inj[j]) > gen["i_max"][1]
                delta_i[data["admittance_map"][(gen["gen_bus"], j)], 1] += gen["i_max"][1]* exp(1im*angle(i_inj[j]))
            else
                delta_i[data["admittance_map"][(gen["gen_bus"], j)], 1] += i_inj[j]
            end
        end
    end
end


function update_mc_delta_current_gfmi_control_k_factor!(gen, delta_i, v, data)
    transformer = data["transformer"][gen["transformer_id"]]
    f_bus = data["bus"]["$(transformer["f_bus"])"]
    t_bus = data["bus"]["$(transformer["t_bus"])"]
    y = transformer["p_matrix"][5:8,1:8]
    _v = zeros(Complex{Float64}, 8, 1)
    indx = 1
    for (_j, j) in enumerate(f_bus["terminals"])
        if haskey(data["admittance_map"], (f_bus["bus_i"], j))
            _v[indx, 1] = v[data["admittance_map"][(f_bus["bus_i"], j)], 1]
        else
            _v[indx, 1] = 0.0
        end
        indx += 1
    end
    for (_j, j) in enumerate(t_bus["terminals"])
        if haskey(data["admittance_map"], (t_bus["bus_i"], j))
            _v[indx, 1] = v[data["admittance_map"][(t_bus["bus_i"], j)], 1]
        else
            _v[indx, 1] = 0.0
        end
        indx += 1
    end
    v_012 = inv(_A) * [_v[1,1];_v[2,1];_v[3,1]]
    i_abc = (transformer["p_matrix"][1:4,1:8]*_v)
    i_012 = inv(_A) * [i_abc[1,1];i_abc[2,1];i_abc[3,1]] 
    v_012 = inv(_A) * [_v[1,1];_v[2,1];_v[3,1]]
    z_1 = v_012[2,1]/i_012[2,1]
    z_2 = v_012[3,1]/i_012[3,1]
    v_inv = [f_bus["vbase"]; f_bus["vbase"]*exp(-2im/3*pi); f_bus["vbase"]*exp(2im/3*pi)] .* data["settings"]["voltage_scale_factor"]
    v_012 = inv(_A) * v_inv
    i_012 = [0;v_012[2,1]/z_1;v_012[3,1]/z_2] 
    i_inj = _A*[0;v_012[2,1]/z_1;v_012[3,1]/z_2] 
    for (_j, j) in enumerate(gen["connections"]) 
        if j != 4
            if abs(i_inj[j]) > gen["i_max"][1]
                delta_i[data["admittance_map"][(gen["gen_bus"], j)], 1] += gen["i_max"][1]* exp(1im*angle(i_inj[j]))
            else
                delta_i[data["admittance_map"][(gen["gen_bus"], j)], 1] += i_inj[j]
            end
        end
    end
end

" defines i based on voltage vs setting current based on reg"
function build_mc_delta_current_vector(data, v, z_matrix)
    (n, m) = size(v)
    delta_i = zeros(Complex{Float64}, n, 1)
    data["settings"]["loading"] ? build_mc_delta_current_load!(delta_i, v, data) : nothing
    build_mc_delta_current_generator!(delta_i, v, data)
    build_mc_delta_current_inverter!(delta_i, v, data, z_matrix)
    return _SP.sparse(delta_i)
end


function build_mc_delta_current_generator!(delta_i, v, data)
    for (_, gen) in data["gen"]
        if occursin("generator", gen["source_id"])
            if gen["gen_model"] == 1 
                calc_delta_current_generator!(gen, delta_i, v, data)
            end
        end
    end
end


function calc_delta_current_generator!(gen, delta_i, v, data)
    bus = gen["gen_bus"]
    if occursin("generator", gen["source_id"])
        if gen["gen_model"] == 1
            for (_j, j) in enumerate(gen["connections"])
                if haskey(data["admittance_map"], (bus, j)) 
                    s = -(gen["pg"][_j] + 1im * gen["qg"][_j])
                    y = conj(s) / gen["vnom_kv"]^2 / 1000
                    delta_i[data["admittance_map"][(bus, j)], 1] += conj(s * data["settings"]["power_scale_factor"] / v[data["admittance_map"][(bus, j)], 1])  - y * v[data["admittance_map"][(bus, j)], 1]
                end
            end
        end
    end
end


function build_mc_delta_current_load!(delta_i, v, data)
    for (_, load) in data["load"]
        if load["model"] == _PMD.POWER
            calc_delta_current_load_constantpq!(load, delta_i, v, data)
        end
    end
end


function calc_delta_current_load_constantpq!(load, delta_i, v, data)
    bus = load["load_bus"]
    if load["configuration"] == _PMD.WYE
        n = length(load["connections"])
        for (_j, j) in enumerate(load["connections"])
            if haskey(data["admittance_map"], (bus, j))
                s = load["pd"][_j] + 1im .* load["qd"][_j]
                y = load["p_matrix"][_j,_j] 
                if abs(v[data["admittance_map"][(bus, j)], 1]) < load["vminpu"] * load["vnom_kv"]*data["settings"]["voltage_scale_factor"]
                    y_vmin = conj(s*data["settings"]["power_scale_factor"]) / (load["vnom_kv"]*load["vminpu"]*data["settings"]["voltage_scale_factor"])^2
                    delta_i[data["admittance_map"][(bus, j)], 1] -= v[data["admittance_map"][(bus, j)], 1] * (y_vmin - y)
                elseif abs(v[data["admittance_map"][(bus, j)], 1]) > load["vmaxpu"] * load["vnom_kv"]*data["settings"]["voltage_scale_factor"]
                    y_vmax = conj(s*data["settings"]["power_scale_factor"]) / (load["vnom_kv"]*load["vmaxpu"]*data["settings"]["voltage_scale_factor"])^2 
                    delta_i[data["admittance_map"][(bus, j)], 1] -= v[data["admittance_map"][(bus, j)], 1] * (y_vmax - y)
                else
                    delta_i[data["admittance_map"][(bus, j)], 1] -= conj(s * data["settings"]["power_scale_factor"] / v[data["admittance_map"][(bus, j)], 1])  - y * v[data["admittance_map"][(bus, j)], 1]
                end
            end
        end
    elseif load["configuration"] == _PMD.DELTA
        n = length(load["connections"])
        phases = load["dss"]["phases"]
        if phases == 1
            i = load["connections"][1]
            j = load["connections"][2]
            if haskey(data["admittance_map"], (bus, i)) && haskey(data["admittance_map"], (bus, j))
                s = load["pd"][1] + 1im .* load["qd"][1]
                y = load["p_matrix"][1,1]
                if abs(v[data["admittance_map"][(bus, i)], 1] - v[data["admittance_map"][(bus, j)], 1]) < load["vminpu"] * load["vnom_kv"]*data["settings"]["voltage_scale_factor"]
                    y_vmin = conj(s*data["settings"]["power_scale_factor"]) / (load["vnom_kv"]*load["vminpu"]*data["settings"]["voltage_scale_factor"])^2
                    delta_i[data["admittance_map"][(bus, i)], 1] -= (v[data["admittance_map"][(bus, i)], 1] - v[data["admittance_map"][(bus, j)], 1]) * (y_vmin - y)
                elseif abs(v[data["admittance_map"][(bus, i)], 1] - v[data["admittance_map"][(bus, j)], 1]) > load["vmaxpu"] * load["vnom_kv"]*data["settings"]["voltage_scale_factor"]
                    y_vmax = conj(s*data["settings"]["power_scale_factor"]) / (load["vnom_kv"]*load["vmaxpu"]*data["settings"]["voltage_scale_factor"])^2
                    delta_i[data["admittance_map"][(bus, i)], 1] -= (v[data["admittance_map"][(bus, i)], 1] - v[data["admittance_map"][(bus, j)], 1]) * (y_vmax - y)
                else
                    delta_i[data["admittance_map"][(bus, i)], 1] -= conj(s * data["settings"]["power_scale_factor"] / (v[data["admittance_map"][(bus, i)], 1] - v[data["admittance_map"][(bus, j)], 1]))  - y * (v[data["admittance_map"][(bus, i)], 1] - v[data["admittance_map"][(bus, j)], 1])
                end
            end
        else
            for (_i, i) in enumerate(load["connections"])
                if haskey(data["admittance_map"], (bus, i))
                    for (_j, j) in enumerate(load["connections"])
                        if _i < _j 
                            if haskey(data["admittance_map"], (bus, j))
                                length(load["pd"]) == n ? s = load["pd"][_i] + 1im .* load["qd"][_i] : s = load["pd"][1] + 1im .* load["qd"][1]
                                y = -load["p_matrix"][_i,_j]
                                if abs(v[data["admittance_map"][(bus, i)], 1] - v[data["admittance_map"][(bus, j)], 1]) < load["vminpu"] * load["vnom_kv"]*data["settings"]["voltage_scale_factor"]
                                    y_vmin = conj(s*data["settings"]["power_scale_factor"]) / (load["vnom_kv"]*load["vminpu"]*data["settings"]["voltage_scale_factor"])^2
                                    delta_i[data["admittance_map"][(bus, i)], 1] -= (v[data["admittance_map"][(bus, i)], 1] - v[data["admittance_map"][(bus, j)], 1]) * (y_vmin - y)
                                elseif abs(v[data["admittance_map"][(bus, i)], 1] - v[data["admittance_map"][(bus, j)], 1]) > load["vmaxpu"] * load["vnom_kv"]*data["settings"]["voltage_scale_factor"]
                                    y_vmax = conj(s*data["settings"]["power_scale_factor"]) / (load["vnom_kv"]*load["vmaxpu"]*data["settings"]["voltage_scale_factor"])^2
                                    delta_i[data["admittance_map"][(bus, i)], 1] -= (v[data["admittance_map"][(bus, i)], 1] - v[data["admittance_map"][(bus, j)], 1]) * (y_vmax - y)
                                else
                                    delta_i[data["admittance_map"][(bus, i)], 1] -= conj(s * data["settings"]["power_scale_factor"] / (v[data["admittance_map"][(bus, i)], 1] - v[data["admittance_map"][(bus, j)], 1]))  - y * (v[data["admittance_map"][(bus, i)], 1] - v[data["admittance_map"][(bus, j)], 1])
                                end
                            end
                        end
                    end
                end
            end
        end

    end
end


function calc_delta_current_load_constanti!(load, delta_i, v, data)
    bus = load["load_bus"]
    if load["configuration"] == _PMD.WYE
        n = length(load["connections"])
        for (_j, j) in enumerate(load["connections"])
            if haskey(data["admittance_map"], (bus, j))
                constant_i = conj(((load["pd"][_j] + 1im .* load["qd"][_j]) * data["settings"]["power_scale_factor"]) / (load["vnom_kv"] * data["settings"]["voltage_scale_factor"])) 
                y = load["p_matrix"][_j,_j] 
                delta_i[data["admittance_map"][(bus, j)], 1] -= (abs(constant_i) - abs(y * v[data["admittance_map"][(bus, j)], 1])) * (cos(angle(y * v[data["admittance_map"][(bus, j)], 1])) + 1im * sin(angle(y * v[data["admittance_map"][(bus, j)], 1]))) 
            end
        end
    elseif load["configuration"] == _PMD.DELTA
        n = length(load["connections"])
        phases = load["dss"]["phases"]
        if phases == 1
            i = load["connections"][1]
            j = load["connections"][2]
            if haskey(data["admittance_map"], (bus, i)) && haskey(data["admittance_map"], (bus, j))
                constant_i = conj(((load["pd"][1] + 1im .* load["qd"][1]) * data["settings"]["power_scale_factor"]) / (load["vnom_kv"] * data["settings"]["voltage_scale_factor"])) 
                y = load["p_matrix"][1,1]
                delta_i[data["admittance_map"][(bus, i)], 1] -= (abs(constant_i) - abs(y * (v[data["admittance_map"][(bus, i)], 1] - v[data["admittance_map"][(bus, j)], 1]))) * (cos(angle(y * (v[data["admittance_map"][(bus, i)], 1] - v[data["admittance_map"][(bus, j)], 1]))) + 1im * sin(angle(y * (v[data["admittance_map"][(bus, i)], 1] - v[data["admittance_map"][(bus, j)], 1]))))
            end
        else
            for (_i, i) in enumerate(load["connections"])
                if haskey(data["admittance_map"], (bus, i))
                    for (_j, j) in enumerate(load["connections"])
                        if _i < _j 
                            if haskey(data["admittance_map"], (bus, j))
                                length(load["pd"]) == n ? s = load["pd"][_i] + 1im .* load["qd"][_i] : s = load["pd"][1] + 1im .* load["qd"][1]
                                constant_i = conj((s * data["settings"]["power_scale_factor"]) / (load["vnom_kv"] * data["settings"]["voltage_scale_factor"])) 
                                y = -load["p_matrix"][_i,_j]
                                delta_i[data["admittance_map"][(bus, i)], 1] -= (abs(constant_i) - abs(y * (v[data["admittance_map"][(bus, i)], 1] - v[data["admittance_map"][(bus, j)], 1]))) * (cos(angle(y * (v[data["admittance_map"][(bus, i)], 1] - v[data["admittance_map"][(bus, j)], 1]))) + 1im * sin(angle(y * (v[data["admittance_map"][(bus, i)], 1] - v[data["admittance_map"][(bus, j)], 1]))))
                            end
                        end
                    end
                end
            end
        end

    end
end


function calc_delta_current_load_current!(load, delta_i, v, data)
    bus = load["load_bus"]
    if load["configuration"] == _PMD.WYE
        n = length(load["connections"])
        for (_j, j) in enumerate(load["connections"])
            if haskey(data["admittance_map"], (bus, j))
                s = load["pd"][_j] + 1im * load["qd"][_j]
                y = conj.((s*data["settings"]["power_scale_factor"]) / (load["vnom_kv"]*data["settings"]["voltage_scale_factor"])^2) 
                _i = conj.((s*data["settings"]["power_scale_factor"]) / (load["vnom_kv"]*data["settings"]["voltage_scale_factor"])) 
                if abs(v[data["admittance_map"][(bus, j)], 1]) < load["vminpu"] * load["vnom_kv"]*data["settings"]["voltage_scale_factor"]
                    y_vmin = conj(s*data["settings"]["power_scale_factor"]) / (load["vnom_kv"]*load["vminpu"]*data["settings"]["voltage_scale_factor"])^2
                    delta_i[data["admittance_map"][(bus, j)], 1] -= v[data["admittance_map"][(bus, j)], 1] * (y_vmin - y)
                elseif abs(v[data["admittance_map"][(bus, j)], 1]) > load["vmaxpu"] * load["vnom_kv"]*data["settings"]["voltage_scale_factor"]
                    y_vmax = conj(s*data["settings"]["power_scale_factor"]) / (load["vnom_kv"]*load["vmaxpu"]*data["settings"]["voltage_scale_factor"])^2 
                    delta_i[data["admittance_map"][(bus, j)], 1] -= v[data["admittance_map"][(bus, j)], 1] * (y_vmax - y)
                else
                    delta_i[data["admittance_map"][(bus, j)], 1] -= _i  - y * v[data["admittance_map"][(bus, j)], 1]
                end
            end
        end
    end
end


function build_mc_delta_current_inverter!(delta_i, v, data, z_matrix)
    for (_, gen) in data["gen"]
        if occursin("solar.", gen["source_id"])
            if gen["pv_model"] == 1
                if gen["grid_forming"]
                    calc_mc_delta_current_gfmi!(gen, delta_i, v, data)
                else
                    calc_mc_delta_current_gfli!(gen, delta_i, v, data)
                end
            end
        end
    end
end


function calc_mc_delta_current_gfli!(gen, delta_i, v, data)
    bus = gen["gen_bus"]
    pg = gen["pg"]
    haskey(gen, "qg") ? qg = gen["qg"] : qg = gen["pg"].*0.0
    s = (pg .+ 1im .* qg) .* data["settings"]["power_scale_factor"]
    if gen["configuration"] == _PMD.WYE
        if gen["balanced"]
            v_solar = zeros(Complex{Float64}, length(s), 1)
            for (_j, j) in enumerate(gen["connections"])
                if haskey(data["admittance_map"], (bus, j))
                    v_solar[_j, 1] = v[data["admittance_map"][(bus, j)], 1]
                end
            end
            s_seq = s[1] 
            v_seq = inv(_A)*v_solar
            i_seq = conj(s_seq/v_seq[2])
            if abs(i_seq) <= gen["i_max"][1]
                i_inj = _A*[0;i_seq;0]
            else
                i_inj = _A*[0;gen["i_max"][1]*exp(1im*angle(i_seq));0]
            end
            for (_j, j) in enumerate(gen["connections"]) 
                if j != 4
                    delta_i[data["admittance_map"][(bus, j)], 1] += i_inj[j] 
                end
            end
        else
            k = findall(x->x==4, gen["connections"])[1]
            for (_j, j) in enumerate(gen["connections"]) 
                if j != 4
                    i_inj = conj(s[_j]/v[data["admittance_map"][(bus, j)], 1])
                    if abs(i_inj) < gen["i_max"][_j]
                        delta_i[data["admittance_map"][(bus, j)], 1] += i_inj * exp(-1im*angle(i_inj))
                    else
                        delta_i[data["admittance_map"][(bus, j)], 1] += gen["i_max"][_j] * exp(-1im*angle(i_inj))
                    end
                end
            end
        end
    end
end


function calc_mc_delta_current_gfmi!(gen, delta_i, v, data)
    bus = gen["gen_bus"]
    pg = gen["pg"]
    haskey(gen, "qg") ? qg = gen["qg"] : qg = gen["pg"].*0.0
    s = (pg .+ 1im .* qg) .* data["settings"]["power_scale_factor"]
    if gen["configuration"] == _PMD.WYE
        if gen["balanced"]
            v_solar = zeros(Complex{Float64}, length(s), 1)
            for (_j, j) in enumerate(gen["connections"])
                if haskey(data["admittance_map"], (bus, j))
                    v_solar[_j, 1] = v[data["admittance_map"][(bus, j)], 1]
                end
            end
            s_seq = s[1] 
            v_seq = inv(_A)*v_solar
            i_seq = conj(s_seq/v_seq[2])
            if abs(i_seq) <= gen["i_max"][1]
                i_inj = _A*[0;i_seq;0]
            else
                i_inj = _A*[0;gen["i_max"][1]*exp(1im*angle(i_seq));0]
            end
            for (_j, j) in enumerate(gen["connections"]) 
                if j != 4
                    delta_i[data["admittance_map"][(bus, j)], 1] += i_inj[j] 
                end
            end
        else
            k = findall(x->x==4, gen["connections"])[1]
            for (_j, j) in enumerate(gen["connections"]) 
                if j != 4
                    i_inj = conj(s[_j]/v[data["admittance_map"][(bus, j)], 1])
                    if abs(i_inj) < gen["i_max"][_j]
                        delta_i[data["admittance_map"][(bus, j)], 1] += i_inj * exp(-1im*angle(i_inj))
                    else
                        delta_i[data["admittance_map"][(bus, j)], 1] += gen["i_max"][_j] * exp(-1im*angle(i_inj))
                    end
                end
            end
        end
    end
end

function update_mc_delta_current_vector(model, v)
    (n, m) = size(v)
    delta_i = zeros(Complex{Float64}, n, 1)
    update_mc_delta_current_generator!(delta_i, v, model.data)
    model.data["settings"]["loading"] ? update_mc_delta_current_load!(delta_i, v, model.data) : nothing
    update_mc_delta_current_inverter!(delta_i, v, model.data)
    return _SP.sparse(delta_i)
end


function update_mc_delta_current_generator!(delta_i, v, data)
    for (_, gen) in data["gen"]
        if occursin("generator", gen["source_id"])
            if gen["gen_model"] == 1
                calc_delta_current_generator!(gen, delta_i, v, data)
            end
        end
    end
end


function update_mc_delta_current_load!(delta_i, v, data)
    for (_, load) in data["load"]
        if data["settings"]["loading"]
            if load["response"] == ConstantPQ
                calc_delta_current_load_constantpq!(load, delta_i, v, data)
            elseif load["response"] == ConstantZ
               nothing
            elseif load["response"] == ConstantI
                calc_delta_current_load_constanti!(load, delta_i, v, data)
            end
        end
    end
end


function update_mc_delta_current_inverter!(delta_i, v, data)
    for (_, gen) in data["gen"]
        if occursin("solar.", gen["source_id"])
            if gen["pv_model"] == 1
                if gen["grid_forming"]
                    calc_mc_delta_current_gfmi!(gen, delta_i, v, data)
                else
                    calc_mc_delta_current_gfli!(gen, delta_i, v, data)
                end
            end
        end
    end
end