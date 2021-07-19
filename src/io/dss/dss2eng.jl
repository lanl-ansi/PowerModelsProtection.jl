"helper function to build extra dynamics information for pvsystem objects"
function _dss2eng_solar_dynamics!(data_eng::Dict{String,<:Any}, data_dss::Dict{String,<:Any})
    if haskey(data_eng, "solar")
        for (id,solar) in data_eng["solar"]
            dss_obj = data_dss["pvsystem"][id]

            _PMD._apply_like!(dss_obj, data_dss, "pvsystem")
            defaults = _PMD._apply_ordered_properties(_PMD._create_pvsystem(id; _PMD._to_kwargs(dss_obj)...), dss_obj)

            solar["i_max"] = (1/defaults["vminpu"]) * defaults["kva"] / 3
            solar["solar_max"] = defaults["irradiance"] * defaults["pmpp"]
            solar["kva"] = defaults["kva"]
            solar["pf"] = defaults["pf"]
        end
    end
end


"helper function to build extra dynamics information for generator or vsource objects"
function _dss2eng_gen_dynamics!(data_eng::Dict{String,<:Any}, data_dss::Dict{String,<:Any})
   if haskey(data_eng, "generator")
        for (id, generator) in data_eng["generator"]
            dss_obj = data_dss["generator"][id]

            _PMD._apply_like!(dss_obj, data_dss, "generator")
            defaults = _PMD._apply_ordered_properties(_PMD._create_generator(id; _PMD._to_kwargs(dss_obj)...), dss_obj)

            generator["zr"] = zeros(length(generator["connections"]))
            generator["zx"] = fill(defaults["xdp"] / defaults["kw"], length(generator["connections"]))
        end
    end

    if haskey(data_eng, "voltage_source")
        for (id, vsource) in data_eng["voltage_source"]
            vsource["zr"] = zeros(length(vsource["connections"]))
            vsource["zx"] = zeros(length(vsource["connections"]))
        end
    end
end


"helper function to convert dss data for monitors to engineering current transformer model"
function _dss2eng_ct!(data_eng::Dict{String,<:Any}, data_dss::Dict{String,<:Any})
    for (id, dss_obj) in get(data_dss, "monitor", Dict())
        if haskey(dss_obj, "turns")
            turns = split(dss_obj["turns"], ',')
            n_p = parse(Int, strip(split(turns[1], '[')[end]))
            n_s = parse(Int, strip(split(turns[2], ']')[begin]))
            add_ct(data_eng, dss_obj["element"], "$id", n_p, n_s)
        elseif haskey(dss_obj, "n_p") && haskey(dss_obj, "n_s")
            add_ct(data_eng, dss_obj["element"], "$id", parse(Int,dss_obj["n_p"]), parse(Int,dss_obj["n_s"]))
        else
            @warn "Could not find turns ratio. CT $id not added."
        end
    end
end


"helper function for converting dss relay to engineering relay model"
function _dss2eng_relay!(data_eng::Dict{String,<:Any}, data_dss::Dict{String,<:Any})
    for (id, dss_obj) in get(data_dss, "relay", Dict())
        if haskey(dss_obj, "basefreq") && dss_obj["basefreq"] != data_eng["settings"]["base_frequency"]
            @warn "basefreq=$(dss_obj["basefreq"]) on line.$id does not match circuit basefreq=$(data_eng["settings"]["base_frequency"])"
        end
        relay_type = dss_obj["type"]
        phase = [1,2,3]
        t_breaker = 0
        shots = 1
        if haskey(dss_obj, "breaker_time")
            t_breaker = parse(Float64, dss_obj["breaker_time"])
        elseif haskey(dss_obj, "t_breaker")
            t_breaker = parse(Float64, dss_obj["t_breaker"])
        elseif haskey(dss_obj, "breakertime")
            t_breaker = parse(Float64, dss_obj["breakertime"])
        end
        if haskey(dss_obj, "shots")
            shots = parse(Float64, dss_obj["shots"])
        end
        if haskey(dss_obj, "phase")
            phases = split(dss_obj["phase"], ',')
            N = length(phases)
            phase = zeros(Int, N)
            for i = 1:N
                if i == 1
                    phase[i] = parse(Int64, strip(split(strip(phases[i]), '[')[end]))
                elseif i < N
                    phase[i] = parse(Int64, strip(phases[i]))
                else
                    phase[i] = parse(Int64, strip(split(strip(phases[i]), ']')[begin]))
                end
            end
        end
        element = "<none>"
        if haskey(dss_obj, "element")
            element = dss_obj["element"]
        elseif haskey(dss_obj, "element1")
            element = dss_obj["element1"]
        elseif haskey(dss_obj, "monitoredobj")
            element = dss_obj["monitoredobj"]
        else
            @warn "Relay $id does not have a monitored object."
        end
        if haskey(dss_obj, "phasetrip")
            TS = parse(Float64, dss_obj["phasetrip"])
        else
            TS = parse(Float64, dss_obj["ts"])
        end
        if haskey(dss_obj, "tdphase")
            TDS = parse(Float64, dss_obj["tdphase"])
        else
            TDS = parse(Float64, dss_obj["tds"])
        end
        if relay_type == "overcurrent"
            if haskey(dss_obj, "ct") || haskey(dss_obj, "cts")
                if haskey(dss_obj, "cts")
                    ct = dss_obj["cts"]
                else
                    ct = dss_obj["ct"]
                end
                add_relay(data_eng, element, "$id", TS, TDS, ct;phase=phase,t_breaker=t_breaker,shots=shots)
            else
                add_relay(data_eng, element, "$id", TS, TDS;phase=phase,t_breaker=t_breaker,shots=shots)
            end
        elseif relay_type == "differential"
            if haskey(dss_obj, "cts")
                ct_vec = split(dss_obj["cts"], ',')
            else
                ct_vec = split(dss_obj["ct"], ',')
            end
            N = length(ct_vec)
            for i = 1:N
                if i == 1
                    ct_vec[i] = split(strip(ct_vec[i]), '[')[end]
                elseif i < N
                    ct_vec[i] = strip(ct_vec[i])
                else
                    ct_vec[i] = split(strip(ct_vec[i]), ']')[begin]
                end
            end
            if haskey(dss_obj, "element2") || haskey(dss_obj, "monitoredobj2")
                element2 = "<none>"
                if haskey(dss_obj, "element2")
                    element2 = dss_obj["element2"]
                elseif haskey(dss_obj, "monitoredobj2")
                    element2 = dss_obj["monitoredobj2"]
                else
                    @warn "Relay $id does not have a monitored object."
                end
                add_relay(data_eng, element, element2, "$id", TS, TDS, ct_vec;phase=phase,t_breaker=t_breaker)
            else
                add_relay(data_eng, element, "$id", TS, TDS, ct_vec;phase=phase,t_breaker=t_breaker)
            end
        elseif relay_type == "differential_dir"
            element2 = "<none>"
            if haskey(dss_obj, "element2")
                element2 = dss_obj["element2"]
            elseif haskey(dss_obj, "monitoredobj2")
                element2 = dss_obj["monitoredobj2"]
            else
                @warn "Relay $id does not have a monitored object."
            end
            add_relay(data_eng, element, element2, "$id", parse(Float64, dss_obj["trip_angle"]))
        end
    end
end    
    

function _dss2eng_fuse!(data_eng::Dict{String,<:Any}, data_dss::Dict{String,<:Any})
    for (id, dss_obj) in get(data_dss, "fuse", Dict())
        if haskey(dss_obj, "basefreq") && dss_obj["basefreq"] != data_eng["settings"]["base_frequency"]
            @warn "basefreq=$(dss_obj["basefreq"]) on line.$id does not match circuit basefreq=$(data_eng["settings"]["base_frequency"])"
        end
    end
end


function _dss2eng_curve!(data_eng::Dict{String,<:Any}, data_dss::Dict{String,<:Any})
    for (id, dss_obj) in get(data_dss, "curve", Dict())
end