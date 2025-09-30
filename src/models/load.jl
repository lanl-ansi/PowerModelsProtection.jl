
function _map_ravens2math_mc_admittance_load!(data_math::Dict{String,<:Any}; pass_props::Vector{String}=String[])
    if haskey(data_math, "load")
        for (name, load) in data_math["load"]
            n = length(load["connections"])
            y = zeros(Complex{Float64}, n, n)
            if load["configuration"] == _PMD.WYE
                if haskey(load, "pd") && haskey(load, "qd")
                    for (i, _i) in enumerate(load["connections"])
                        for (j, _j) in enumerate(load["connections"])
                            # need to fix for 4
                            if _i != 4 
                                s = conj.(load["pd"][i] + 1im .* load["qd"][i])
                                _y = (s * data_math["settings"]["power_scale_factor"]) / (load["vnom_kv"] * data_math["settings"]["voltage_scale_factor"])^2
                                y[i, i] += _y
                                y[i, j] -= _y
                                y[j, i] -= _y
                                y[j, j] += _y
                            end
                        end
                    end
                end
                load["p_matrix"] = y
            elseif load["configuration"] == _PMD.DELTA
                if haskey(load, "pd") && haskey(load, "qd")
                    for (i, _i) in enumerate(load["connections"])
                        length(load["pd"]) == n ? s = conj.(load["pd"][i] + 1im .* load["qd"][i]) : s = conj.(load["pd"][1] + 1im .* load["qd"][1])
                        for (j, _j) in enumerate(load["connections"])
                            if i != j
                                _y = (s * data_math["settings"]["power_scale_factor"]) / (load["vnom_kv"] * data_math["settings"]["voltage_scale_factor"])^2
                                println(_y)
                                y[i, i] += _y
                                y[i, j] -= _y
                            end
                        end
                    end
                end
                load["p_matrix"] = y
            end
        end
    end
end
