
function _map_ravens2math_mc_admittance_storage!(data_math::Dict{String,<:Any}; pass_props::Vector{String}=String[])
    if haskey(data_math, "storage")
        for (name, gen) in data_math["storage"]
            n = length(gen["connections"])
            y = zeros(Complex{Float64}, n, n)
            a = 1*exp(120im*pi/180)
            A = [1 1 1;1 a a^2;1 a^2 a]
            # z_012=[.1+.6im 0+0im 0+0im;0+0im .1+.6im 0+0im;0+0im 0+0im .1+.6im] * .0001
            # z_012=[1e6im 0+0im 0+0im;0+0im 1e6im 0+0im;0+0im 0+0im 1e6im]
            # z =  A^-1*z_012*A
            z = [1+1im 0+0im 0+0im;0+0im 1+1im 0+0im;0+0im 0+0im 1+1im] .* 1e9
            # z_012=[.5+2.0im 0+0im 0+0im;0+0im .1+.6im 0+0im;0+0im 0+0im .1+.6im] *.001
            # z =  A^-1*z_012*A
            z1 = inv(z[1:3, 1:3])
            z2 = -inv(z[1:3, 1:3])
            # z_012=[0+0.0im 0+0im 0+0im;0+0im 1e6im 0+0im;0+0im 0+0im 0+0im]
            #         z =  A^-1*z_012*A

            #         z = [1e6im 0+0im 0+0im;0+0im 1e6im 0+0im;0+0im 0+0im 1e6im]
            #         z1 = inv(z[1:3, 1:3])
            #         z2 = -inv(z[1:3, 1:3])
            gen["p_matrix"] = [z1 z2; z2 z1]
            # if gen["configuration"] == _PMD.WYE
            #     for (i, connection) in enumerate(gen["connections"])
            #         y[i, i] = 1 / 1e6im
            #     end
            # end
            # gen["p_matrix"] = y
        end
    end
end