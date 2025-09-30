
function _map_mc_admittance_load!(data_math::Dict{String,<:Any}; pass_props::Vector{String}=String[])
    if haskey(data_math, "load")
        for (name, load) in data_math["load"]
            if load["response"] != ConstantI
                n = length(load["connections"])
                y = zeros(Complex{Float64}, n, n)
                if load["configuration"] == _PMD.WYE
                    if haskey(load, "pd") && haskey(load, "qd")
                        for (i, _i) in enumerate(load["connections"])
                            if _i != 4 
                                s = conj.(load["pd"][i] + 1im .* load["qd"][i])
                                _y = (s * data_math["settings"]["power_scale_factor"]) / (load["vnom_kv"][i] * data_math["settings"]["voltage_scale_factor"])^2
                                y[i, i] += _y
                            end
                        end
                    end
                elseif load["configuration"] == _PMD.DELTA
                    if haskey(load, "pd") && haskey(load, "qd")
                        for (i, _i) in enumerate(load["connections"])
                            length(load["pd"]) == n ? s = conj.(load["pd"][i] + 1im .* load["qd"][i]) : s = conj.(load["pd"][1] + 1im .* load["qd"][1])
                            for (j, _j) in enumerate(load["connections"])
                                if i != j
                                    _y = (s * data_math["settings"]["power_scale_factor"]) / (load["vnom_kv"][i]*sqrt(3) * data_math["settings"]["voltage_scale_factor"])^2
                                    y[i, i] += _y
                                    y[i, j] -= _y
                                end
                            end
                        end
                    end
                end
                load["p_matrix"] = y
            end
        end
    end
end



"""
"""
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


function build_mc_delta_current_load!(delta_i, v, data)
    for (_, load) in data["load"]
        if load["response"] == ConstantPQ
            calc_delta_current_load_constantpq!(load, delta_i, v, data)
        # elseif load["response"] == ConstantI
        #     println(opoopo)
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
                if abs(v[data["admittance_map"][(bus, j)], 1]) < load["vlowpu"] * load["vnom_kv"][_j]*data["settings"]["voltage_scale_factor"]
                    y_vmin = conj(s*data["settings"]["power_scale_factor"]) / (load["vnom_kv"][_j]*load["vlowpu"]*data["settings"]["voltage_scale_factor"])^2
                    delta_i[data["admittance_map"][(bus, j)], 1] -= v[data["admittance_map"][(bus, j)], 1] * (y_vmin - y) - load["i_last"][_j]
                    load["i_last"][_j] = v[data["admittance_map"][(bus, j)], 1] * (y_vmin - y)
                elseif abs(v[data["admittance_map"][(bus, j)], 1]) > load["vmaxpu"] * load["vnom_kv"][_j]*data["settings"]["voltage_scale_factor"]
                    y_vmax = conj(s*data["settings"]["power_scale_factor"]) / (load["vnom_kv"][_j]*load["vmaxpu"]*data["settings"]["voltage_scale_factor"])^2 
                    delta_i[data["admittance_map"][(bus, j)], 1] -= v[data["admittance_map"][(bus, j)], 1] * (y_vmax - y) - load["i_last"][_j]
                    load["i_last"][_j] = v[data["admittance_map"][(bus, j)], 1] * (y_vmax - y)
                else
                    delta_i[data["admittance_map"][(bus, j)], 1] -= conj(s * data["settings"]["power_scale_factor"] / v[data["admittance_map"][(bus, j)], 1])  - y * v[data["admittance_map"][(bus, j)], 1] - load["i_last"][_j]
                    load["i_last"][_j] = conj(s * data["settings"]["power_scale_factor"] / v[data["admittance_map"][(bus, j)], 1])  - y * v[data["admittance_map"][(bus, j)], 1] 
                end
            end
        end
    elseif load["configuration"] == _PMD.DELTA
        n = length(load["connections"])
        phases = isa(load["dss"]["phases"], String) ? parse(Int, load["dss"]["phases"]) : load["dss"]["phases"]
        if phases == 1
            i = load["connections"][1]
            j = load["connections"][2]
            if haskey(data["admittance_map"], (bus, i)) && haskey(data["admittance_map"], (bus, j))
                s = load["pd"][1] + 1im .* load["qd"][1]
                y = load["p_matrix"][1,1]
                if abs(v[data["admittance_map"][(bus, i)], 1] - v[data["admittance_map"][(bus, j)], 1]) < load["vlowpu"] * load["vnom_kv"][1]*sqrt(3)*data["settings"]["voltage_scale_factor"]
                    y_vmin = conj(s*data["settings"]["power_scale_factor"]) / (load["vnom_kv"][1]*load["vlowpu"]*sqrt(3)*data["settings"]["voltage_scale_factor"])^2
                    i_ij = (v[data["admittance_map"][(bus, i)], 1] - v[data["admittance_map"][(bus, j)], 1]) * (y_vmin - y) - load["i_last"][1]
                    delta_i[data["admittance_map"][(bus, i)], 1] -= i_ij
                    delta_i[data["admittance_map"][(bus, j)], 1] -= -i_ij
                    load["i_last"][1] = (v[data["admittance_map"][(bus, i)], 1] - v[data["admittance_map"][(bus, j)], 1]) * (y_vmin - y)
                elseif abs(v[data["admittance_map"][(bus, i)], 1] - v[data["admittance_map"][(bus, j)], 1]) > load["vmaxpu"] * load["vnom_kv"][1]*sqrt(3)*data["settings"]["voltage_scale_factor"]
                    y_vmax = conj(s*data["settings"]["power_scale_factor"]) / (load["vnom_kv"][1]*load["vmaxpu"]*sqrt(3)*data["settings"]["voltage_scale_factor"])^2
                    i_ij = (v[data["admittance_map"][(bus, i)], 1] - v[data["admittance_map"][(bus, j)], 1]) * (y_vmax - y) - load["i_last"][1]
                    delta_i[data["admittance_map"][(bus, i)], 1] -= i_ij
                    delta_i[data["admittance_map"][(bus, j)], 1] -= -i_ij
                    load["i_last"][1] = (v[data["admittance_map"][(bus, i)], 1] - v[data["admittance_map"][(bus, j)], 1]) * (y_vmax - y)
                else
                    i_ij = conj(s * data["settings"]["power_scale_factor"] / (v[data["admittance_map"][(bus, i)], 1] - v[data["admittance_map"][(bus, j)], 1]))  - y * (v[data["admittance_map"][(bus, i)], 1] - v[data["admittance_map"][(bus, j)], 1]) - load["i_last"][1]
                    delta_i[data["admittance_map"][(bus, i)], 1] -= i_ij
                    delta_i[data["admittance_map"][(bus, j)], 1] -= -i_ij
                    load["i_last"][1] = conj(s * data["settings"]["power_scale_factor"] / (v[data["admittance_map"][(bus, i)], 1] - v[data["admittance_map"][(bus, j)], 1]))  - y * (v[data["admittance_map"][(bus, i)], 1] - v[data["admittance_map"][(bus, j)], 1])
                end
            end
        else
            idx = 1
            for (_i, i) in enumerate(load["connections"])
                if haskey(data["admittance_map"], (bus, i))
                    for (_j, j) in enumerate(load["connections"])
                        if _i < _j
                            if haskey(data["admittance_map"], (bus, j))
                                length(load["pd"]) == n ? s = load["pd"][_i] + 1im .* load["qd"][_i] : s = load["pd"][1] + 1im .* load["qd"][1]
                                y = -load["p_matrix"][_i,_j]
                                if abs(v[data["admittance_map"][(bus, i)], 1] - v[data["admittance_map"][(bus, j)], 1]) < load["vlowpu"] * load["vnom_kv"]*sqrt(3)*data["settings"]["voltage_scale_factor"]
                                    y_vmin = conj(s*data["settings"]["power_scale_factor"]) / (load["vnom_kv"]*sqrt(3)*load["vlowpu"]*data["settings"]["voltage_scale_factor"])^2
                                    i_ij = (v[data["admittance_map"][(bus, i)], 1] - v[data["admittance_map"][(bus, j)], 1]) * (y_vmin - y) - load["i_last"][idx]
                                    delta_i[data["admittance_map"][(bus, i)], 1] -= i_ij
                                    delta_i[data["admittance_map"][(bus, j)], 1] -= -i_ij
                                    load["i_last"][idx] = (v[data["admittance_map"][(bus, i)], 1] - v[data["admittance_map"][(bus, j)], 1]) * (y_vmin - y)
                                elseif abs(v[data["admittance_map"][(bus, i)], 1] - v[data["admittance_map"][(bus, j)], 1]) > load["vmaxpu"] * load["vnom_kv"]*sqrt(3)*data["settings"]["voltage_scale_factor"]
                                    y_vmax = conj(s*data["settings"]["power_scale_factor"]) / (load["vnom_kv"]*sqrt(3)load["vmaxpu"]*data["settings"]["voltage_scale_factor"])^2
                                    i_ij = (v[data["admittance_map"][(bus, i)], 1] - v[data["admittance_map"][(bus, j)], 1]) * (y_vmax - y) - load["i_last"][idx]
                                    delta_i[data["admittance_map"][(bus, i)], 1] -= i_ij
                                    delta_i[data["admittance_map"][(bus, j)], 1] -= -i_ij
                                    load["i_last"][idx] = (v[data["admittance_map"][(bus, i)], 1] - v[data["admittance_map"][(bus, j)], 1]) * (y_vmax - y)
                                else
                                    i_ij = conj(s * data["settings"]["power_scale_factor"] / (v[data["admittance_map"][(bus, i)], 1] - v[data["admittance_map"][(bus, j)], 1]))  - y * (v[data["admittance_map"][(bus, i)], 1] - v[data["admittance_map"][(bus, j)], 1]) - load["i_last"][idx]
                                    delta_i[data["admittance_map"][(bus, i)], 1] -= i_ij
                                    delta_i[data["admittance_map"][(bus, j)], 1] -= -i_ij
                                    load["i_last"][idx] = conj(s * data["settings"]["power_scale_factor"] / (v[data["admittance_map"][(bus, i)], 1] - v[data["admittance_map"][(bus, j)], 1]))  - y * (v[data["admittance_map"][(bus, i)], 1] - v[data["admittance_map"][(bus, j)], 1])
                                end
                                idx += 1
                            end
                        end
                    end
                end
            end
        end
    end
end


function update_mc_delta_current_load!(delta_i, v, data)
    for (_, load) in data["load"]
        if data["settings"]["loading"]
            if load["response"] == ConstantPQ
                calc_delta_current_load_constantpq!(load, delta_i, v, data)
            end
        end
    end
end