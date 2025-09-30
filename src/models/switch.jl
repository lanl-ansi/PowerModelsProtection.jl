
function _map_ravens2math_mc_admittance_switch!(data_math::Dict{String,<:Any}; pass_props::Vector{String}=String[])
    # neds to be fixed and replaced 
    if haskey(data_math, "switch")
        for (name, switch) in data_math["switch"]
            if switch["state"] == 1
                n = length(switch["f_connections"])
                z = zeros(Complex{Float64}, n, n)
                z_shunt = zeros(Complex{Float64}, n, n)
                for (i, j) in enumerate(switch["f_connections"])
                    z[i,i] = .01+0.0im
                    z_shunt[i,i] = 1e9im
                end
                z1 = inv(z) + inv(z_shunt)
                z2 = -inv(z)
                z3 = z2
                z4 = inv(z) + inv(z_shunt)
                switch["p_matrix"] = [z1 z2; z3 z4]
            else
                n = length(switch["f_connections"])
                z = zeros(Complex{Float64}, n, n)
                z_shunt = zeros(Complex{Float64}, n, n)
                for (i, j) in enumerate(switch["f_connections"])
                    z[i,i] = 1e6+0.0im
                    z_shunt[i,i] = 1e9im
                end
                z1 = inv(z) + inv(z_shunt)
                z2 = -inv(z)
                z3 = z2
                z4 = inv(z) + inv(z_shunt)
                switch["p_matrix"] = [z1 z2; z3 z4]
            end
            # if abs(LA.det(switch["p_matrix"])) > 100 || LA.cond(switch["p_matrix"]) > 100
            #     println("Switch $(switch["name"]) matrix has high condition")
            # end
        end
    end
end
