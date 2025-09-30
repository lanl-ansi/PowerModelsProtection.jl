
function _map_mc_admittance_solar!(data_math::Dict{String,<:Any}; pass_props::Vector{String}=String[])
    if haskey(data_math, "gen")
        for (name, gen) in data_math["gen"]
            if gen["admit_model"] == PVSystem
                z = (gen["vg"] .* data_math["settings"]["voltage_scale_factor"]).^2 ./ -(gen["pg"] .+ gen["qg"] .*1im) ./ data_math["settings"]["power_scale_factor"]
                n = length(gen["connections"])
                p_matrix = zeros(Complex{Float64}, n, n)
                for (i, j) in enumerate(gen["connections"])
                    if j != 4
                        p_matrix[i,i] = 1/z[i]
                    else
                        for (m, k) in enumerate(gen["connections"])
                            if k != 4
                                p_matrix[i,i] += 1/z[m]
                                p_matrix[i,m] = -1/z[m]
                            end
                        end
                    end
                end
                gen["p_matrix"] = p_matrix
            end
        end
    end
end


function add_mc_solar_p_matrix!(data::Dict{String,<:Any}, admit_matrix::Dict{Tuple,Complex{Float64}}, gen::Dict{String,<:Any})
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


function build_mc_current_vector_solar!(data::Dict{String,<:Any}, gen::Dict{String,<:Any}, v::Matrix{ComplexF64}, i::Matrix{ComplexF64})
    nothing 
end


# TODO need fix for other gfli
function calc_mc_delta_current_gfli!(data::Dict{String,<:Any}, gen::Dict{String,<:Any}, v::Matrix{ComplexF64}, delta_i::Matrix{ComplexF64})
    for (_, gen) in data["gen"]
        if gen["admit_model"] == PVSystem
            if gen["gen_status"] == 1
                if gen["balanced"] == "true"
                    calc_mc_delta_current_gfli_balanced!(data, gen, v, delta_i)
                end
            end
        end
    end
end


function calc_mc_delta_current_gfli_balanced!(data::Dict{String,<:Any}, gen::Dict{String,<:Any}, v::Matrix{ComplexF64}, delta_i::Matrix{ComplexF64})
    bus = data["bus"][string(gen["gen_bus"])]
    n = gen["phases"]
    if gen["phases"] == 1
        p_matrix = gen["p_matrix"][1,1] 
        _v = v[data["admittance_map"][(bus["bus_i"], gen["connections"][1])], 1]
        delta_s = -(gen["pg"][1] + 1im * gen["qg"][1]) * data["settings"]["power_scale_factor"] - _v * conj(p_matrix * _v)
        i_update = conj(delta_s/_v)
        if abs(i_update + p_matrix * _v) > gen["imax"]
            i_update = gen["imax"] * exp(-1im*angle(_v)) - p_matrix * _v
        end
        i_update = i_update - gen["i_last"][1]
        gen["i_last"][1] += i_update
        gen["output"] = _v * (conj(p_matrix*_v) + conj(i_update))
        delta_i[data["admittance_map"][(gen["gen_bus"], gen["connections"][1])],1] = i_update
    elseif gen["phases"] == 3
        _v = zeros(Complex{Float64}, n, 1)
        p_matrix = zeros(Complex{Float64}, n, n)
        for i in gen["connections"]
            if i != 4
                _v[i,1] = v[data["admittance_map"][(bus["bus_i"], gen["connections"][i])], 1]
                for j in gen["connections"]
                    if j != 4
                        p_matrix[i,j] = gen["p_matrix"][i,j]
                    end
                end
            end
        end
        v012 = inv(_A) * _v
        i012 = inv(_A) * p_matrix * _v 
        delta_s = -(gen["pg"][1] + 1im * gen["qg"][1]) * data["settings"]["power_scale_factor"] - v012[2] * conj(i012[2])
        ipos = conj(delta_s/v012[2])
        i012_update = [0;ipos;0] .- i012
        if abs(i012_update[2] + i012[2]) > gen["imax"]
            i012_update = [0;gen["imax"]*exp(-1im*angle(v012[2]));0] .- i012
        end
        i_update = (_A * i012_update) .- gen["i_last"]
        gen["i_last"] += i_update
        gen["output"] = [_v[1] 0 0;0 _v[2] 0;0 0 _v[3]] * (conj(p_matrix*_v) .+ conj(i_update))
        for (_j, j) in enumerate(gen["connections"])
            if (gen["gen_bus"], j) in keys(data["admittance_map"])
                delta_i[data["admittance_map"][(gen["gen_bus"], j)],1] = i_update[_j,1] # check 
            end
        end
    end
end
