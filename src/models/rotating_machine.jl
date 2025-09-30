function _map_ravens2math_mc_admittance_generator!(data_math::Dict{String,<:Any}; pass_props::Vector{String}=String[])
    if haskey(data_math, "gen")
        for (name, gen) in data_math["gen"]
            if occursin("generator", gen["source_id"])
                if gen["gen_model"] == 1
                    y = zeros(Complex{Float64}, 4, 4)
                    for (i, pg) in enumerate(gen["pg"])
                        kv = gen["vnom_kv"]
                        s = -(pg + 1im * gen["qg"][i])
                        y_ = conj(s) / kv^2 / 1000
                        y[i, i] += y_
                        y[i, 4] -= y[i, i]
                        y[4, i] -= y[i, 4]
                        y[4, 4] += y[i, i]
                    end
                end
                gen["p_matrix"] = y
            end
        end
    end
end