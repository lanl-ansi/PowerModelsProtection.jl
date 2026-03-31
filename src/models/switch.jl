
function _map_mc_admittance_switch!(data_math::Dict{String,<:Any}; pass_props::Vector{String}=String[])
    # neds to be fixed and replaced 
    if haskey(data_math, "switch")
        for (name, switch) in data_math["switch"]
            if switch["state"] == 1
                z012 = [1.0+1.0im 0.0 0.0;0.0 1.0+1.0im 0.0;0.0 0.0 1.0+1.0im] .* .1
                c012 = -2*pi*data_math["settings"]["base_frequency"]*1im.*[1.0 0.0 0.0;0.0 1.1 0.0;0.0 0.0 1.1] .* .1
                zabc = A^-1*z012*A
                cabc = A^-1*c012*A
                n = length(switch["f_connections"])
                z = zeros(Complex{Float64}, n, n)
                for (i, j) in enumerate(switch["f_connections"])
                    z[i,i] = zabc[j,j] 
                end
                z1 = inv(z)
                z2 = -inv(z)
                z3 = z2
                z4 = inv(z)
                switch["p_matrix"] = [z1 z2; z3 z4]
            else
                n = length(switch["f_connections"])
                z = zeros(Complex{Float64}, n, n)
                for (i, j) in enumerate(switch["f_connections"])
                    z[i,i] = 1e6+1e6im
                end
                z1 = inv(z)
                z2 = -inv(z)
                z3 = z2
                z4 = inv(z)
                switch["p_matrix"] = [z1 z2; z3 z4]
            end
        end
    end
end


function add_mc_switch_p_matrix!(data::Dict{String,<:Any}, admit_matrix::Dict{Tuple,Complex{Float64}})
    for (indx, switch) in data["switch"]
        f_bus = switch["f_bus"]
        for (_i, i) in enumerate(switch["f_connections"])
            if haskey(data["admittance_map"], (f_bus, i))
                for (_j, j) in enumerate(switch["f_connections"])
                    if haskey(data["admittance_map"], (f_bus, j))
                        haskey(admit_matrix, (data["admittance_map"][(f_bus, i)], data["admittance_map"][(f_bus, j)])) ? admit_matrix[(data["admittance_map"][(f_bus, i)], data["admittance_map"][(f_bus, j)])] += switch["p_matrix"][_i,_j] : admit_matrix[(data["admittance_map"][(f_bus, i)], data["admittance_map"][(f_bus, j)])] = switch["p_matrix"][_i,_j]
                    end
                end
                t_bus = switch["t_bus"]
                for (_j, j) in enumerate(switch["t_connections"])
                    if haskey(data["admittance_map"], (t_bus, j))
                        haskey(admit_matrix, (data["admittance_map"][(f_bus, i)], data["admittance_map"][(t_bus, j)])) ? admit_matrix[(data["admittance_map"][(f_bus, i)], data["admittance_map"][(t_bus, j)])] += switch["p_matrix"][_i,_j+length(switch["t_connections"])] : admit_matrix[(data["admittance_map"][(f_bus, i)], data["admittance_map"][(t_bus, j)])] = switch["p_matrix"][_i,_j+length(switch["t_connections"])]
                    end
                end
            end
        end
        t_bus = switch["t_bus"]
        for (_i, i) in enumerate(switch["t_connections"])
            if haskey(data["admittance_map"], (t_bus, i))
                for (_j, j) in enumerate(switch["t_connections"])
                    if haskey(data["admittance_map"], (t_bus, j))
                        haskey(admit_matrix, (data["admittance_map"][(t_bus, i)], data["admittance_map"][(t_bus, j)])) ? admit_matrix[(data["admittance_map"][(t_bus, i)], data["admittance_map"][(t_bus, j)])] += switch["p_matrix"][_i+length(switch["t_connections"]),_j+length(switch["t_connections"])] : admit_matrix[(data["admittance_map"][(t_bus, i)], data["admittance_map"][(t_bus, j)])] = switch["p_matrix"][_i+length(switch["t_connections"]),_j+length(switch["t_connections"])]
                    end
                end
                f_bus = switch["f_bus"]
                for (_j, j) in enumerate(switch["f_connections"])
                    if haskey(data["admittance_map"], (f_bus, j))
                        haskey(admit_matrix, (data["admittance_map"][(t_bus, i)], data["admittance_map"][(f_bus, j)])) ? admit_matrix[(data["admittance_map"][(t_bus, i)], data["admittance_map"][(f_bus, j)])] += switch["p_matrix"][_i+length(switch["f_connections"]),_j] : admit_matrix[(data["admittance_map"][(t_bus, i)], data["admittance_map"][(f_bus, j)])] = switch["p_matrix"][_i+length(switch["f_connections"]),_j]
                    end
                end
            end
        end
    end
end


function update_mc_switch_p_matrix!(data::Dict{String,<:Any}, switch, p_matrix, y)
    f_bus = switch["f_bus"]
    for (_i, i) in enumerate(switch["f_connections"])
        if haskey(data["admittance_map"], (f_bus, i))
            for (_j, j) in enumerate(switch["f_connections"])
                if haskey(data["admittance_map"], (f_bus, j))
                    y[data["admittance_map"][(f_bus, i)], data["admittance_map"][(f_bus, j)]] += p_matrix[_i,_j] 
                end
            end
            t_bus = switch["t_bus"]
            for (_j, j) in enumerate(switch["t_connections"])
                if haskey(data["admittance_map"], (t_bus, j))
                    y[data["admittance_map"][(f_bus, i)], data["admittance_map"][(t_bus, j)]] += p_matrix[_i,_j+length(switch["t_connections"])] 
                end
            end
        end
    end
    t_bus = switch["t_bus"]
    for (_i, i) in enumerate(switch["t_connections"])
        if haskey(data["admittance_map"], (t_bus, i))
            for (_j, j) in enumerate(switch["t_connections"])
                if haskey(data["admittance_map"], (t_bus, j))
                    y[data["admittance_map"][(t_bus, i)], data["admittance_map"][(t_bus, j)]] += p_matrix[_i+length(switch["t_connections"]),_j+length(switch["t_connections"])] 
                end
            end
            f_bus = switch["f_bus"]
            for (_j, j) in enumerate(switch["f_connections"])
                if haskey(data["admittance_map"], (f_bus, j))
                    y[data["admittance_map"][(t_bus, i)], data["admittance_map"][(f_bus, j)]] += p_matrix[_i+length(switch["f_connections"]),_j] 
                end
            end
        end
    end
end