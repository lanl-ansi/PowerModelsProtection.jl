
function _map_ravens2math_mc_admittance_voltage_source!(data_math::Dict{String,<:Any}; pass_props::Vector{String}=String[])
    if haskey(data_math, "gen")
        for (name, gen) in data_math["gen"]
            if haskey(gen, "model_type")
                if gen["model_type"] == "energy_source"
                    # add check 
                    if haskey(gen, "z")
                        z = gen["z"]
                    else
                        z = [gen["rs"][1]+1im.*gen["xs"][1] 0+0im 0+0im;0+0im gen["rs"][2]+1im.*gen["xs"][2] 0+0im;0+0im 0+0im gen["rs"][3]+1im.*gen["xs"][3]]
                    end
                    a = 1*exp(120im*pi/180)
                    A = [1 1 1;1 a a^2;1 a^2 a]
                    z_012=[.5+2.0im 0+0im 0+0im;0+0im .1+.6im 0+0im;0+0im 0+0im .1+.6im] 
                    z =  A^-1*z_012*A
                    z1 = inv(z[1:3, 1:3])
                    z2 = -inv(z[1:3, 1:3])
                    gen["p_matrix"] = [z1 z2; z2 z1]
                    if abs(LA.det(gen["p_matrix"][1:3,1:3])) > 100 || LA.cond(gen["p_matrix"][1:3,1:3]) > 100
                        println("Gen $(gen["name"]) matrix has high condition")
                    end
                end
            end
        end
    end
end