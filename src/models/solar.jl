
function _map_ravens2math_mc_admittance_solar!(data_math::Dict{String,<:Any}; pass_props::Vector{String}=String[])
    if haskey(data_math, "gen")
        for (name, gen) in data_math["gen"]
            if gen["model_type"] == "pv_systems"
                n = length(gen["connections"])
                y = zeros(Complex{Float64}, n, n)
                if gen["configuration"] == _PMD.WYE
                    for (i, connection) in enumerate(gen["connections"])
                        y[i, i] = 1 / 1e6im
                    end
                else
                    lklklkj
                end
                gen["p_matrix"] = y
            end
        end
    end
end