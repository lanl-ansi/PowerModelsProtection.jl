
function build_mc_3p_gf(terminals; phase_resistance=.01)
    Gf = zeros(Real, 3, 3)
    for i in terminals
        for j in terminals
            if i != j
                Gf[i, j] = -1 / phase_resistance
            else
                Gf[i, j] = 2 * (1 / phase_resistance)
            end
        end
    end
    return Gf
end


function build_mc_3pg_gf(terminals; phase_resistance=.01, ground_resistance=.001)
    Gf = zeros(Real, 3, 3)
    gp = 1 / phase_resistance
    gf = 1 / ground_resistance
    gtot = 3 * gp + gf
    gpp = gp^2 / gtot
    gpg = gp * gf / gtot
    for i in terminals
        for j in terminals
            if i == j
                Gf[i, j] = 2 * gpp + gpg
            else
                Gf[i, j] = -gpg
            end
        end
    end
    return Gf
end


function build_mc_ll_gf(terminals; phase_resistance=.01)
    Gf = zeros(Real, 3, 3)
    for i in terminals
        for j in terminals
            if i == j
                Gf[i, j] = 1 / phase_resistance
            else
                Gf[i, j] = -1 / phase_resistance
            end
        end
    end
    return Gf
end


function build_mc_llg_gf(terminals; phase_resistance=.001, ground_resistance=.001)
    Gf = zeros(Real, 3, 3)
    gp = 1 / phase_resistance
    gf = 1 / ground_resistance
    gtot = 2 * gp + gf
    gpp = gp^2 / gtot
    gpg = gp * gf / gtot
    for i in terminals
        for j in terminals
            if i == j
                Gf[i, j] = gpp + gpg
            else
                Gf[i, j] = -gpp
            end
        end
    end
    return Gf
end


function build_mc_lg_gf(terminals; ground_resistance=.01)
    Gf = zeros(Real, 3, 3)
    gf = 1 / ground_resistance
    for (_i, i) in enumerate(terminals)
        for (_j, j) in enumerate(terminals)
            if i == j
                Gf[i, j] = gf
            end
        end
    end
    return Gf
end


function add_mc_fault_gf(model, bus, fault)
    y = deepcopy(model.y)
    for (_n, n) in enumerate(fault["connections"])
        for (_m, m) in enumerate(fault["connections"])
            if haskey(model.data["admittance_map"], (bus["bus_i"], n)) && haskey(model.data["admittance_map"], (bus["bus_i"], m))
                i = model.data["admittance_map"][(bus["bus_i"],n)]
                j = model.data["admittance_map"][(bus["bus_i"],m)]
                y[i,j] += fault["GF"][n,m]
            end
        end
    end
    return y
end