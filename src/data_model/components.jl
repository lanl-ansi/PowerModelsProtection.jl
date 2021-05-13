""
function create_fault(type::String, bus::String, f_connections::Vector{Int}, t_connections::Vector{Int}, resistance::Real, phase_resistance::Real)::Dict{String,Any}
    return getfield(PowerModelsProtection, Symbol("_create_$(type)_fault"))(bus, f_connections, t_connections, resistance, phase_resistance)
end


""
function create_fault(type::String, bus::String, f_connections::Vector{Int}, t_connections::Vector{Int}, resistance::Real)::Dict{String,Any}
    return getfield(PowerModelsProtection, Symbol("_create_$(type)_fault"))(bus, f_connections, t_connections, resistance)
end


""
function create_fault(type::String, bus::String, f_connections::Vector{Int}, resistance::Real)::Dict{String,Any}
    return getfield(PowerModelsProtection, Symbol("_create_$(type)_fault"))(bus, f_connections, resistance)
end


""
function create_fault(type::String, bus::String, f_connections::Vector{Int}, resistance::Real, phase_resistance::Real)::Dict{String,Any}
    return getfield(PowerModelsProtection, Symbol("_create_$(type)_fault"))(bus, f_connections, resistance, phase_resistance)
end


""
function _create_3p_fault(bus::String, f_connections::Vector{Int}, phase_resistance::Real)::Dict{String,Any}
    @assert length(f_connections) == 3
    ncnds = length(f_connections)

    Gf = zeros(Real, ncnds, ncnds)
    for i in 1:ncnds
        for j in 1:ncnds
            if i != j
                Gf[i,j] = -1/phase_resistance
            else
                Gf[i,j] = 2 * (1/phase_resistance)
            end
        end
    end

    return Dict{String,Any}(
        "bus" => bus,
        "f_connections" => f_connections,
        "t_connections" => f_connections,
        "fault_type" => "3p",
        "g" => Gf,
        "b" => zeros(Real, ncnds, ncnds),
        "status" => _PMD.ENABLED,
    )
end


""
function _create_3pg_fault(bus::String, f_connections::Vector{Int}, resistance::Real, phase_resistance::Real)::Dict{String,Any}
    @assert length(f_connections) == 3
    ncnds = length(f_connections)

    Gf = zeros(Real, ncnds, ncnds)

    gp = 1 / phase_resistance
    gf = 1 / resistance
    gtot = 3 * gp + gf
    gpp = gp^2 / gtot
    gpg = gp * gf / gtot

    for i in 1:ncnds
        for j in 1:ncnds
            if i == j
                Gf[i,j] = 2 * gpp + gpg
            else
                Gf[i,j] = -gpp
            end
        end
    end

    return Dict{String,Any}(
        "bus" => bus,
        "f_connections" => f_connections,
        "t_connections" => f_connections,
        "fault_type" => "3p",
        "g" => Gf,
        "b" => zeros(Real, ncnds, ncnds),
        "status" => _PMD.ENABLED,
    )
end


""
function _create_ll_fault(bus::String, f_connections::Vector{Int}, t_connections::Vector{Int}, phase_resistance::Real)::Dict{String,Any}
    @assert length(f_connections) == length(t_connections) == 1
    ncnds = length(f_connections) + length(t_connections)

    Gf = zeros(Real, ncnds, ncnds)
    for i in 1:ncnds
        for j in 1:ncnds
            if i == j
                Gf[i,j] = 1 / phase_resistance
            else
                Gf[i,j] = -1 / phase_resistance
            end
        end
    end

    return Dict{String,Any}(
        "bus" => bus,
        "f_connections" => [f_connections; t_connections],
        "t_connections" => [f_connections; t_connections],
        "fault_type" => "ll",
        "g" => Gf,
        "b" => zeros(Real, ncnds, ncnds),
        "status" => _PMD.ENABLED,
    )
end


""
function _create_llg_fault(bus::String, f_connections::Vector{Int}, t_connections::Vector{Int}, resistance::Real, phase_resistance::Real)::Dict{String,Any}
    @assert length(f_connections) == length(t_connections) == 1
    ncnds = length(f_connections) + length(t_connections)

    Gf = zeros(Real, ncnds, ncnds)

    gp = 1 / phase_resistance
    gf = 1 / resistance
    gtot = 2 * gp + gf
    gpp = gp^2  / gtot
    gpg = gp * gf / gtot

    for i in 1:ncnds
        for j in 1:ncnds
            if i == j
                Gf[i,j] = gpp + gpg
            else
                Gf[i,j] = -gpp
            end
        end
    end

    return Dict{String,Any}(
        "bus" => bus,
        "f_connections" => [f_connections; t_connections],
        "t_connections" => [f_connections; t_connections],
        "fault_type" => "llg",
        "g" => Gf,
        "b" => zeros(Real, ncnds, ncnds),
        "status" => _PMD.ENABLED,
    )
end


""
function _create_lg_fault(bus::String, f_connections::Vector{Int}, resistance::Real)::Dict{String,Any}
    @assert length(f_connections) == 1
    ncnds = length(f_connections)

    Gf = zeros(Real, ncnds, ncnds)

    for i in 1:ncnds
        Gf[i,i] = 1 / resistance
    end

    return Dict{String,Any}(
        "bus" => bus,
        "f_connections" => f_connections,
        "t_connections" => f_connections,
        "fault_type" => "lg",
        "g" => Gf,
        "b" => zeros(Real, ncnds, ncnds),
        "status" => _PMD.ENABLED,
    )
end


""
function add_fault!(data::Dict{String,Any}, name::String, type::String, bus::String, f_connections::Vector{Int}, t_connections::Vector{Int}, resistance::Real, phase_resistance::Real)
    if !haskey(data, "fault")
        data["fault"] = Dict{String,Any}()
    end

    fault = create_fault(type, bus, f_connections, t_connections, resistance, phase_resistance)

    fault["name"] = name
    data["fault"][name] = fault
end


""
function add_fault!(data::Dict{String,Any}, name::String, type::String, bus::String, f_connections::Vector{Int}, t_connections::Vector{Int}, resistance::Real)
    if !haskey(data, "fault")
        data["fault"] = Dict{String,Any}()
    end

    fault = create_fault(type, bus, f_connections, t_connections, resistance)

    fault["name"] = name
    data["fault"][name] = fault
end


""
function add_fault!(data::Dict{String,Any}, name::String, type::String, bus::String, f_connections::Vector{Int}, resistance::Real)
    if !haskey(data, "fault")
        data["fault"] = Dict{String,Any}()
    end

    fault = create_fault(type, bus, f_connections, resistance)

    fault["name"] = name
    data["fault"][name] = fault
end


""
function add_fault!(data::Dict{String,Any}, name::String, type::String, bus::String, f_connections::Vector{Int}, resistance::Real, phase_resistance::Real)
    if !haskey(data, "fault")
        data["fault"] = Dict{String,Any}()
    end

    fault = create_fault(type, bus, f_connections, resistance, phase_resistance)

    fault["name"] = name
    data["fault"][name] = fault
end
