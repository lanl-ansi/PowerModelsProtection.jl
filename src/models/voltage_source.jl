
"""
    admittance model 
"""
function _map_mc_admittance_voltage_source!(data_math::Dict{String,<:Any}; pass_props::Vector{String}=String[])
    if haskey(data_math, "gen")
        for (name, gen) in data_math["gen"]
            if haskey(gen, "admit_model")
                if gen["admit_model"] == VoltageSourceElement
                    # add check 
                    if haskey(gen, "z")
                        z = gen["z"]
                    else
                        z = gen["rs"] .+ gen["xs"] * 1im
                    end
                    gen["p_matrix"] = inv(z[1:3, 1:3])
                end
            end
        end
    end
end


"""
    current model 
"""
function build_mc_current_vector_voltage_source!(data::Dict{String,<:Any}, gen::Dict{String,<:Any}, v::Matrix{ComplexF64}, i::Matrix{ComplexF64})
    if gen["gen_status"] == 1
        bus = data["bus"][string(gen["gen_bus"])]
        4 in gen["connections"] ? n = length(gen["connections"]) -1 : n = length(gen["connections"])
        p_matrix = zeros(Complex{Float64}, n, n)
        _v = zeros(Complex{Float64}, n, 1)
        for i in gen["connections"]
            if i != 4
                _v[i,1] = bus["vm"][i] * data["settings"]["voltage_scale_factor"] * exp(1im * bus["va"][i] * pi/180)
                for j in gen["connections"]
                    if j != 4
                        p_matrix[i,j] = gen["p_matrix"][i,j]
                    end
                end
            end
        end
        i_update = p_matrix * _v
        for (_j, j) in enumerate(gen["connections"])
            if (gen["gen_bus"], j) in keys(data["admittance_map"])
                i[data["admittance_map"][(gen["gen_bus"], j)],1] = i_update[_j,1]
            end
        end
    end
end


function add_mc_voltage_source_p_matrix!(data::Dict{String,<:Any}, admit_matrix::Dict{Tuple,Complex{Float64}}, gen::Dict{String,<:Any})
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