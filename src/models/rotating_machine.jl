
function _map_mc_admittance_rotating_machine!(data_math::Dict{String,<:Any}; pass_props::Vector{String}=String[])
    if haskey(data_math, "gen")
        for (name, gen) in data_math["gen"]
            if haskey(gen, "admit_model")
                if gen["admit_model"] == RotatingMachineElement
                    n = length(gen["connections"])
                    y = zeros(Complex{Float64}, n, n)
                    if gen["configuration"] == _PMD.WYE
                        if haskey(gen, "pg") && haskey(gen, "qg")
                            for (i, _i) in enumerate(gen["connections"])
                                if _i != 4 
                                    s = -(conj.(gen["pg"][i] + 1im .* gen["qg"][i]))
                                    _y = (s * data_math["settings"]["power_scale_factor"]) / (gen["vnom_kv"][i] * data_math["settings"]["voltage_scale_factor"])^2
                                    y[i, i] += _y
                                end
                            end
                        end
                    elseif gen["configuration"] == _PMD.DELTA            
                        Nothing
                    end
                    gen["p_matrix"] = y
                end
            end
        end
    end
end


function add_mc_rotating_machine_p_matrix!(data::Dict{String,<:Any}, admit_matrix::Dict{Tuple,Complex{Float64}}, gen::Dict{String,<:Any})
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


function calc_mc_delta_current_rotating_machine!(data::Dict{String,<:Any}, gen::Dict{String,<:Any}, v::Matrix{ComplexF64}, i::Matrix{ComplexF64})
    if gen["gen_status"] == 1
        println(gen)
        bus = data["bus"][string(gen["gen_bus"])]
        s = -(gen["pg"] + 1im * gen["qg"]) * data["settings"]["power_scale_factor"] 
        for (_j, j) in enumerate(gen["connections"])
            if (gen["gen_bus"], j) in keys(data["admittance_map"])
                i[data["admittance_map"][(gen["gen_bus"], j)],1] = conj(s[_j]/v[_j])
            end
        end
    end
end


# function _map_ravens2math_mc_admittance_generator!(data_math::Dict{String,<:Any}; pass_props::Vector{String}=String[])
#     if haskey(data_math, "gen")
#         for (name, gen) in data_math["gen"]
#             if occursin("generator", gen["source_id"])
#                 if gen["gen_model"] == 1
#                     y = zeros(Complex{Float64}, 4, 4)
#                     for (i, pg) in enumerate(gen["pg"])
#                         kv = gen["vnom_kv"]
#                         s = -(pg + 1im * gen["qg"][i])
#                         y_ = conj(s) / kv^2 / 1000
#                         y[i, i] += y_
#                         y[i, 4] -= y[i, i]
#                         y[4, i] -= y[i, 4]
#                         y[4, 4] += y[i, i]
#                     end
#                 end
#                 gen["p_matrix"] = y
#             end
#         end
#     end
# end


function update_mc_delta_current_gen!(delta_i, v, data)
    for (_, gen) in data["gen"]
        if haskey(gen, "admit_model")
            if gen["admit_model"] == RotatingMachineElement
                calc_delta_current_gen_constantpq!(gen, delta_i, v, data)
            end
        end
    end
end

function calc_delta_current_gen_constantpq!(gen, delta_i, v, data)
    bus = gen["gen_bus"]
    if gen["configuration"] == _PMD.WYE
        n = length(gen["connections"])
        for (_j, j) in enumerate(gen["connections"])
            if haskey(data["admittance_map"], (bus, j))
                s = -(gen["pg"][_j] + 1im .* gen["qg"][_j])
                y = gen["p_matrix"][_j,_j]
                delta_i[data["admittance_map"][(bus, j)], 1] -= conj(s * data["settings"]["power_scale_factor"] / v[data["admittance_map"][(bus, j)], 1])  - y * v[data["admittance_map"][(bus, j)], 1] 
            end
        end
    elseif gen["configuration"] == _PMD.DELTA
        nothing
    end
end


function update_mc_fault_delta_current_gen!(delta_i, v, data)
    for (_, gen) in data["gen"]
        if haskey(gen, "admit_model")
            if gen["admit_model"] == RotatingMachineElement
                calc_fault_delta_current_gen_constantpq!(gen, delta_i, v, data)
            end
        end
    end
end

function calc_fault_delta_current_gen_constantpq!(gen, delta_i, v, data)
    bus = gen["gen_bus"]
    if gen["configuration"] == _PMD.WYE
        n = length(gen["connections"])
        y = gen["p_matrix"][1:n,1:n]
        _v = zeros(ComplexF64, n, 1)
        _vg = zeros(ComplexF64, n, 1)
        for (_j, j) in enumerate(gen["connections"])
            if haskey(data["admittance_map"], (bus, j))
                _v[_j,1] = v[data["admittance_map"][(bus, j)], 1]
                _vg[_j,1] = gen["v_gen"][_j]
            end
        end
        if gen["phases"] == 1
            if abs(_vg[1,1] - _v[1,1]) > .5
                delta_i[data["admittance_map"][(bus, gen["connections"][1])], 1] -= ((_vg[1,1] - _v[1,1])/(1im*gen["xdp"])  - gen["i"][1]) *.1
                gen["i"][1] -= delta_i[data["admittance_map"][(bus, gen["connections"][1])], 1]
                println(abs(gen["i"][1]))
                # println((_vg[1,1] - _v[1,1])/(1im*gen["xdp"]) - y[1,1] * _v[1,1] )
            end
        else
             if !(haskey(gen, "i12"))
                gen["i12"] = zeros(ComplexF64, 2, 1)
            end
            _v = zeros(Complex{Float64}, 3, 1)
            for i in gen["connections"]
                if i != 4
                    for i in gen["connections"]
                        if i != 4
                            _v[i,1] = v[data["admittance_map"][(bus, gen["connections"][i])], 1]
                        end
                    end
                end
            end
            v012 = inv(_A) * _v
            i1_delta = ((_vg[1,1] - v012[2,1])/(1im*gen["xdp"])  - gen["i12"][1]) *.1
            i2_delta = (v012[3,1]/(1im*gen["xdpp"])  - gen["i12"][2]) *.1
            gen["i12"][1] -= i1_delta
            gen["i12"][2] += i2_delta
            i_abc = _A*[0.0;i1_delta;i2_delta] 
            for (_i, i) in enumerate(gen["connections"])
                if i != 4
                    delta_i[data["admittance_map"][(bus, gen["connections"][1])], 1] -=  i_abc[_i]
                end
            end
        end
    elseif gen["configuration"] == _PMD.DELTA
        nothing
    end
end



function remove_rotating_machines!(model)
    for (i, gen) in model.data["gen"]
        if gen["admit_model"] == RotatingMachineElement
            bus = gen["gen_bus"]
            gen["i"] = zeros(ComplexF32, length(gen["connections"]), length(["connections"]))
            for (_i, i) in enumerate(gen["connections"])
                if haskey(model.data["admittance_map"], (bus, i))
                    for (_j, j) in enumerate(gen["connections"])
                        if haskey(model.data["admittance_map"], (bus, j))
                            model.y[model.data["admittance_map"][(bus, i)], model.data["admittance_map"][(bus, j)]] -= gen["p_matrix"][_i,_j]
                        end
                    end
                end
            end
        end
    end
end