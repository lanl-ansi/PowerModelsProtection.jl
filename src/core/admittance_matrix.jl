
function build_mc_admittance_matrix(data::Dict{String,<:Any}; loading=loading, )
    # add_mc_admittance_map!(data)
    # admit_matrix = Dict{Tuple,Complex{Float64}}()
    # add_mc_branch_p_matrix!(data, admit_matrix)
    # add_mc_switch_p_matrix!(data, admit_matrix)
    # add_mc_generator_p_matrix!(data, admit_matrix)
    # add_mc_transformer_p_matrix!(data, admit_matrix)
    # add_mc_storage_p_matrix!(data, admit_matrix)
    # loading ? add_mc_load_p_matrix!(data, admit_matrix) : nothing
    # add_mc_shunt_p_matrix!(data, admit_matrix)
    # # --> need to finish other devices
    add_mc_admittance_map!(data)
    admit_matrix = Dict{Tuple,Complex{Float64}}()
    add_mc_branch_p_matrix!(data, admit_matrix)
    println("Y matrix (@branches) condition : ", LA.cond(Array(_convert_sparse_matrix(admit_matrix)), 2))
    add_mc_transformer_p_matrix!(data, admit_matrix)
    println("Y matrix (@transformers) condition : ", LA.cond(Array(_convert_sparse_matrix(admit_matrix)), 2))
    add_mc_storage_p_matrix!(data, admit_matrix)
    println("Y matrix (@storage) condition : ", LA.cond(Array(_convert_sparse_matrix(admit_matrix)), 2))
    add_mc_switch_p_matrix!(data, admit_matrix)
    println("Y matrix (@switches) condition : ", LA.cond(Array(_convert_sparse_matrix(admit_matrix)), 2))
    add_mc_generator_p_matrix!(data, admit_matrix)
    println("Y matrix (@generators) condition : ", LA.cond(Array(_convert_sparse_matrix(admit_matrix)), 2))
    # loading ? add_mc_load_p_matrix!(data, admit_matrix) : nothing
    add_mc_load_p_matrix!(data, admit_matrix)
    println("Y matrix (@loads) condition : ", LA.cond(Array(_convert_sparse_matrix(admit_matrix)), 2))
    add_mc_shunt_p_matrix!(data, admit_matrix)
    println("Y matrix (@shunts) condition : ", LA.cond(Array(_convert_sparse_matrix(admit_matrix)), 2))
    return _convert_sparse_matrix(admit_matrix)
end

function add_mc_admittance_map!(data_math::Dict{String,<:Any})
    admittance_map = Dict{Tuple,Int}()
    admittance_type = Dict{Int,Any}()
    indx = 1
# TODO determine if bus is inactive
    if haskey(data_math, "microgrid_buses")
        for idx in data_math["microgrid_buses"]
            bus = data_math["bus"][idx]
            id = bus["index"]
            if bus["bus_type"] != 4 
                for (i, t) in enumerate(bus["terminals"])
                    if !(bus["grounded"][i])
                        admittance_map[(id, t)] = indx
                        admittance_type[indx] = bus["bus_type"]
                        indx += 1
                    end
                end
            end
        end
    else
        for (_, bus) in data_math["bus"]
            id = bus["index"]
            if bus["bus_type"] != 4 
                for (i, t) in enumerate(bus["terminals"])
                        if !(bus["grounded"][i])
                            admittance_map[(id, t)] = indx
                            admittance_type[indx] = bus["bus_type"]
                            indx += 1
                        end
                    end
                end
            end
        end
    data_math["admittance_map"] = admittance_map
    data_math["admittance_type"] = admittance_type
end


function add_mc_generator_p_matrix!(data::Dict{String,<:Any}, admit_matrix::Dict{Tuple,Complex{Float64}})
    for (_, gen) in data["gen"]
        if gen["gen_status"] == 1
            if gen["admit_model"] == VoltageSourceElement
                add_mc_voltage_source_p_matrix!(data, admit_matrix, gen)
            elseif gen["admit_model"] == PVSystemElement
                # add_mc_solar_p_matrix!(data, admit_matrix, gen)
            elseif gen["admit_model"] == RotatingMachineElement
                add_mc_rotating_machine_p_matrix!(data, admit_matrix, gen)
            end
        end
    end
end


function build_mc_voltage_vector(data::Dict{String,<:Any})
    v = zeros(Complex{Float64}, length(keys(data["admittance_type"])), 1)
    for (indx, bus) in data["bus"]
        terminals = copy(bus["terminals"])
        4 in terminals ? terminals = terminals[1:end-1] : nothing
        terminals == 3 ? m = 1/sqrt(3) : m = 1
        if haskey(bus, "vm")
            for (_j, j) in enumerate(terminals)
                if haskey(data["admittance_map"], (bus["bus_i"], j))
                    v[data["admittance_map"][(bus["bus_i"], j)],1] = bus["vm"][_j] * data["settings"]["voltage_scale_factor"] * exp(1im*bus["va"][_j]*pi/180)
                end
            end
        else
            for (_j, j) in enumerate(terminals)
                if haskey(data["admittance_map"], (bus["bus_i"], j))
                    v[data["admittance_map"][(bus["bus_i"], j)],1] = bus["vnom_kv"][_j] * data["settings"]["voltage_scale_factor"] * m * exp(1im*-2/3*pi*(j-1))
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
    for (_, gen) in data["gen"]
        if gen["admit_model"] == VoltageSourceElement
            build_mc_current_vector_voltage_source!(data, gen, v, i)
        elseif gen["admit_model"] == PVSystemElement
            # build_mc_current_vector_solar!(data, gen, v, i)
        end
    end
    for (_, storage) in data["storage"]
        if storage["grid_forming"]
            build_mc_current_vector_gfmi_storage!(data, storage, v, i)
        end
    end
    for (_, load) in data["load"]
        if load["response"] == ConstantI
            build_mc_current_vector_current!(data, load, v, i)
        end
    end
    return i
end


" defines i based on setting reg points vs setting current based on voltage"
function build_mc_delta_current_control_vector(data::Dict{String,<:Any}, v::Matrix{ComplexF64}, y)
    (n, m) = size(v)
    delta_i = zeros(Complex{Float64}, n, 1)
    return _SP.sparse(delta_i)
end


" defines i based on voltage vs setting current based on reg"
function build_mc_delta_current_vector(data, v)
    (n, m) = size(v)
    delta_i = zeros(Complex{Float64}, n, 1)
    return _SP.sparse(delta_i)
end


function update_mc_delta_current_vector(model, v)
    (n, m) = size(v)
    delta_i = zeros(Complex{Float64}, n, 1)
    update_mc_delta_current_load!(delta_i, v, model.data)
    update_mc_delta_current_gen!(delta_i, v, model.data)
    return delta_i
end


function update_mc_fault_delta_current_vector(model, v)
    (n, m) = size(v)
    delta_i = zeros(Complex{Float64}, n, 1)
    update_mc_fault_delta_current_gen!(delta_i, v, model.data)
    return delta_i
end


function update_mc_delta_current_control_vector(model, v, y)
    (n, m) = size(v)
    delta_i = zeros(Complex{Float64}, n, 1)
    update_mc_delta_current_inverter!(delta_i, v, model.data, y)
    return delta_i, y
end


function update_mc_delta_current_inverter!(delta_i, v, data, y)
    for (_, gen) in data["gen"]
        if gen["admit_model"] == PVSystemElement
            if gen["grid_forming"]
                # calc_mc_delta_current_gfmi!(gen, delta_i, v, data)
            else
                calc_mc_delta_current_gfli!(data, gen, v, delta_i)
            end
        end
    end
    for (_, storage) in data["storage"]
        if storage["grid_forming"]
            calc_mc_delta_current_gfmi!(data, storage, v, delta_i, y)
        end
    end
end


function update_mc_fault_delta_current_control_vector(model, v, y)
    (n, m) = size(v)
    delta_i = zeros(Complex{Float64}, n, 1)
    update_mc_fault_delta_current_inverter!(delta_i, v, model.data, y)
    return delta_i, y
end


function update_mc_fault_delta_current_inverter!(delta_i, v, data, y)
    for (_, gen) in data["gen"]
        if gen["admit_model"] == PVSystemElement
            if gen["grid_forming"]
                # calc_mc_delta_current_gfmi!(gen, delta_i, v, data)
            else
                calc_mc_fault_delta_current_gfli!(data, gen, v, delta_i)
            end
        end
    end
    for (_, storage) in data["storage"]
        if storage["grid_forming"]
            calc_mc_fault_delta_current_gfmi!(data, storage, v, delta_i, y)
        end
    end
end




