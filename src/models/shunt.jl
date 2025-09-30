
function _map_mc_admittance_shunt!(data_math::Dict{String,<:Any}; pass_props::Vector{String}=String[])
    if haskey(data_math, "shunt")
        for (name, shunt) in data_math["shunt"]
            y = shunt["gs"] + 1im .* shunt["bs"]
            shunt["p_matrix"] = y
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