
function _map_mc_admittance_storage!(data_math::Dict{String,<:Any}; pass_props::Vector{String}=String[])
    if haskey(data_math, "storage")
        for (name, storage) in data_math["storage"]
            # n = length(storage["connections"])
            # p_matrix = zeros(Complex{Float64}, n, n)
            # for (_i, i) in enumerate(storage["connections"])
            #     p_matrix[_i, _i] += 1e-5*1im
            # end
            # storage["p_matrix"] = p_matrix
            z012 = [0.052409264+0.15722779im 0 0;0 0.040117165+0.16046866im 0;0 0 0.040117165+0.16046866im]
            if data_math["m"]
                z012 = [0.078613897+0.23584169im 0 0;0 0.060175747+0.24070299im 0;0 0 0.060175747+0.24070299im]./1000
            else
                z012 = [0.078613897+0.23584169im 0 0;0 0.060175747+0.24070299im 0;0 0 0.060175747+0.24070299im].*1000000
            end
            zabc = inv(_A) * z012 * _A
            storage["p_matrix"] = inv(zabc)
        end
    end
end


function  add_mc_storage_p_matrix!(data::Dict{String,<:Any}, admit_matrix::Dict{Tuple,Complex{Float64}})
    for (_, gen) in data["storage"]
        bus = gen["storage_bus"]
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


function build_mc_current_vector_gfmi_storage!(data::Dict{String,<:Any}, storage::Dict{String,<:Any}, v::Matrix{ComplexF64}, delta_i::Matrix{ComplexF64})
    bus = data["bus"][string(storage["storage_bus"])]
    n = storage["phases"]
    _v = [630/sqrt(3)*exp(0im*pi/180);630/sqrt(3)*exp(-120im*pi/180);630/sqrt(3)*exp(120im*pi/180)]
    i_update = storage["p_matrix"] * _v 
    storage["i_last"] = i_update
    if haskey(storage, "set")
        i_update = storage["set"]
    end
    for (_j, j) in enumerate(storage["connections"])
        if (storage["storage_bus"], j) in keys(data["admittance_map"])
            delta_i[data["admittance_map"][(storage["storage_bus"], j)],1] = i_update[_j,1]
        end
    end
end


function calc_mc_delta_current_gfmi!(data::Dict{String,<:Any}, storage::Dict{String,<:Any}, v::Matrix{ComplexF64}, delta_i::Matrix{ComplexF64}, y)
    haskey(storage, "i_last") ? nothing : storage["i_last"] = [0.0;0.0;0.0]
    bus = data["bus"][string(storage["storage_bus"])]
    switch = data["switch"]["$(storage["switch"])"]
    haskey(switch, ["y_delta"]) ? nothing : switch["y_delta"] = deepcopy(switch["p_matrix"]) .* 0.0
    f_bus = data["bus"]["$(switch["f_bus"])"]
    t_bus = data["bus"]["$(switch["t_bus"])"]
    _y = switch["p_matrix"][1:6,1:6]
    _v = zeros(Complex{Float64}, 6, 1)
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
    v012_f = inv(_A) * _v[1:3]
    v012_t = inv(_A) * _v[4:6]
    v012_delta = abs.(v012_f .- v012_t)
    iabc = _y * _v
    i012_f = inv(_A) * iabc[1:3] 
    i012_t = inv(_A) * iabc[4:6] 
    z012_t = v012_t ./ i012_t
end
