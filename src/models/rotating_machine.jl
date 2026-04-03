
function _setup_currents_pmp_rotating_machine!(data_math::Dict{String,<:Any})
    if haskey(data_math, "gen")
        for (name, gen) in data_math["gen"]if haskey(gen, "admit_model")
                if gen["admit_model"] == RotatingMachineElement
                    gen["i_inj"] = fill(0.0+1im*0.0, gen["phases"])
                    gen["s_inj"] = fill(0.0+1im*0.0, gen["phases"])
                end
            end
        end
    end
end


function _map_mc_admittance_rotating_machine!(data_math::Dict{String,<:Any}; pass_props::Vector{String}=String[])
    if haskey(data_math, "gen")
        for (name, gen) in data_math["gen"]
            if haskey(gen, "admit_model")
                if gen["admit_model"] == RotatingMachineElement
                    z = 1e6
                    n = length(gen["connections"])
                    p_matrix = zeros(Complex{Float64}, n, n)
                    for (i, j) in enumerate(gen["connections"])
                        if j != 4
                            p_matrix[i,i] = 1/z
                        else
                            for (m, k) in enumerate(gen["connections"])
                                if k != 4
                                    p_matrix[i,i] += 1/z 
                                    p_matrix[i,m] = -1/z 
                                end
                            end
                        end
                    end
                    gen["p_matrix"] = p_matrix
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
        if gen["gen_status"] == 1
            if haskey(gen, "admit_model")
                if gen["admit_model"] == RotatingMachineElement
                    calc_delta_current_gen_constantpq!(gen, delta_i, v, data)
                end
            end
        end
    end
end

function calc_delta_current_gen_constantpq!(gen, delta_i, v, data)
    bus = data["bus"][string(gen["gen_bus"])]
    n = gen["phases"]
    if gen["configuration"] == _PMD.WYE
        if gen["phases"] == 1
            s = (gen["pg"][1] + 1im * gen["qg"][1]) * data["settings"]["power_scale_factor"]
            _v = v[data["admittance_map"][(bus["bus_i"], gen["connections"][1])], 1]
            delta_s = s - _v * conj(gen["i_inj"][1])
            i_update = conj(delta_s/_v)
            delta_i[data["admittance_map"][(gen["gen_bus"], gen["connections"][1])],1] += i_update
            gen["i_inj"][1] += i_update
            gen["s_inj"][1] = conj(gen["i_inj"][1]) * _v
        else
            for (_j, j) in enumerate(gen["connections"])
                if haskey(data["admittance_map"], (bus, j))
                    s = (gen["pg"][_j] + 1im .* gen["qg"][_j]) * data["settings"]["power_scale_factor"]
                    _v = v[data["admittance_map"][(bus["bus_i"], gen["connections"][_j])], 1]
                    delta_s = s - _v * conj(gen["i_inj"][_j])
                    i_update = conj(delta_s/_v)
                    delta_i[data["admittance_map"][(gen["gen_bus"], gen["connections"][_j])],1] += i_update
                    gen["i_inj"][_j] += i_update
                    gen["s_inj"][_j] = conj(gen["i_inj"][1]) * _v
                end
            end
        end
    elseif gen["configuration"] == _PMD.DELTA
        nothing
    end
end
    

function update_mc_fault_delta_current_gen!(delta_i, v, data)
    for (_, gen) in data["gen"]
        if gen["gen_status"] == 1
            if haskey(gen, "admit_model")
                if gen["admit_model"] == RotatingMachineElement
                    calc_fault_delta_current_gen_constantpq!(gen, delta_i, v, data)
                end
            end
        end
    end
end

function calc_fault_delta_current_gen_constantpq!(gen, delta_i, v, data)
    bus = gen["gen_bus"]
    n = gen["phases"]
    if gen["configuration"] == _PMD.WYE
        if gen["phases"] == 1
            _v = v[data["admittance_map"][(bus, gen["connections"][1])], 1]
            _vg = gen["v_gen"][1]
            if abs(_vg - _v) > .5
                i_update = (_vg - _v)/(1im*gen["xdp"]) - gen["i_inj"][1]
                delta_i[data["admittance_map"][(bus, gen["connections"][1])],1] += i_update
                gen["i_inj"][1] += i_update
            end
        else
            _v = zeros(ComplexF64, n, 1)
            for (_j, j) in enumerate(gen["connections"])
                if haskey(data["admittance_map"], (bus, j))
                    _v[_j,1] = v[data["admittance_map"][(bus, j)], 1]
                end
            end
            v012 = inv(_A) * _v  
            vg012 = inv(_A) * gen["v_gen"]
            i012 = inv(A) * [gen["i_inj"][1];gen["i_inj"][2];gen["i_inj"][3]]
            if abs(vg012[2,1] - v012[2,1]) > .5
                i1_delta = (vg012[2,1] - v012[2,1])/(1im*gen["xdp"]) - i012[2]
                i2_delta = -v012[3,1]/(1im*gen["xdpp"]) - i012[3]
                i_abc = _A*[0.0;i1_delta;i2_delta] 
                for (_j, j) in enumerate(gen["connections"])
                    if haskey(data["admittance_map"], (bus, j))
                        delta_i[data["admittance_map"][(bus, gen["connections"][1])], 1] +=  i_abc[_j]
                        gen["i_inj"][_j] += i_abc[_j]
                    end
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