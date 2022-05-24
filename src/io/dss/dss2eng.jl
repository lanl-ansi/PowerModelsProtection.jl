"helper function to build extra dynamics information for pvsystem objects"
function _dss2eng_solar_dynamics!(data_eng::Dict{String,<:Any}, data_dss::Dict{String,<:Any})
    if haskey(data_eng, "solar")
        for (id,solar) in data_eng["solar"]
            dss_obj = data_dss["pvsystem"][id]
            _PMD._apply_like!(dss_obj, data_dss, "pvsystem")
            defaults = _PMD._apply_ordered_properties(_PMD._create_pvsystem(id; _PMD._to_kwargs(dss_obj)...), dss_obj)
            if haskey(dss_obj, "irradiance")
                irradiance = dss_obj["irradiance"]
            else
                irradiance = defaults["irradiance"]
            end
            if haskey(dss_obj, "vminpu")
                vminpu = dss_obj["vminpu"]
            else
                vminpu = defaults["vminpu"]
            end
            if haskey(dss_obj, "kva")
                kva = dss_obj["kva"]
            else
                kva = defaults["kva"]
            end
            if haskey(dss_obj, "pmpp")
                pmpp = dss_obj["pmpp"]
            else
                pmpp = defaults["pmpp"]
            end
            if haskey(dss_obj, "pf")
                pf = dss_obj["pf"]
            else
                pf = defaults["pf"]
            end
            ncnd = length(solar["connections"]) >= 3 ? 3 : 1
            solar["i_max"] = fill(1/vminpu * kva / (ncnd/sqrt(3)*dss_obj["kv"]), ncnd)
            solar["solar_max"] = irradiance*pmpp
            solar["pf"] = pf
            solar["kva"] = kva
        end
    end
end


"helper function to build extra dynamics information for generator or vsource objects"
function _dss2eng_gen_dynamics!(data_eng::Dict{String,<:Any}, data_dss::Dict{String,<:Any})
    if haskey(data_eng, "generator")
        for (id, generator) in data_eng["generator"]
            if haskey(generator["dss"], "model")
                if generator["dss"]["model"] == 3
                    dss_obj = data_dss["generator"][id]
                    _PMD._apply_like!(dss_obj, data_dss, "generator")
                    defaults = _PMD._apply_ordered_properties(_PMD._create_generator(id; _PMD._to_kwargs(dss_obj)...), dss_obj)
                    zbase = defaults["kv"]^2/defaults["kva"]*1000
                    xdp = defaults["xdp"] * zbase
                    rp = xdp/defaults["xrdp"]
                    xdpp = defaults["xdpp"] * zbase
                    generator["xdp"] = fill(xdp, length(generator["connections"]))
                    generator["rp"] = fill(rp, length(generator["connections"]))
                    generator["xdpp"] = fill(xdpp, length(generator["connections"]))
                end
            end
        end
    end
end


"Helper function to convert dss data for monitors to engineering current transformer model."
function _dss2eng_ct!(data_eng::Dict{String,<:Any}, data_dss::Dict{String,<:Any})
    for (id, dss_obj) in get(data_dss, "monitor", Dict())
        if haskey(dss_obj, "turns")
            turns = split(dss_obj["turns"], ',')
            n_p = parse(Int, strip(split(turns[1], '[')[end]))
            n_s = parse(Int, strip(split(turns[2], ']')[1]))
            add_ct(data_eng, dss_obj["element"], "$id", n_p, n_s)
        elseif haskey(dss_obj, "n_p") && haskey(dss_obj, "n_s")
            add_ct(data_eng, dss_obj["element"], "$id", parse(Int,dss_obj["n_p"]), parse(Int,dss_obj["n_s"]))
        else
            @warn "Could not find turns ratio. CT $id not added."
        end
    end
end


"Helper function for converting dss relay to engineering relay model."
function _dss2eng_relay!(data_eng::Dict{String,<:Any}, data_dss::Dict{String,<:Any})
    monitor_type_list = ["line", "load", "gen"]
    defaults_dict = Dict{String,Any}(
            "float_dict" => Dict{String,Any}(
                "phasetrip" => 1.0,
                "groundtrip" => 1.0,
                "tdphase" => 1.0,
                "tdground" => 1.0,
                "phaseinst" => 0.0,
                "groundinst" => 0.0,
                "delay" => 0.0,
                "kvbase" => 0.0,
                "47%pickup" => 2.0,
                "46%pickup" => 20.0,
                "breakertime" => 0.0,
            ),
            "int_dict" => Dict{String,Any}(
                "monitoredterm" => 1,
                "switchedterm" => 1,
                "reset" => 15,
                "shots" => 4,
                "46isqt" => 1
            ),
            "str_dict" => Dict{String,Any}(
                "type" => "current",
                "phasecurve" => "none",
                "groundcurve" => "none",
                "overvoltcurve" => "none",
                "undervoltcurve" => "none",
            ),
    )
    for (id, dss_obj) in get(data_dss, "relay", Dict())
        eng_obj = Dict{String,Any}()
        if !haskey(dss_obj, "monitoredobj")
            @warn "relay $(dss_obj["name"]) does not have a monitoredobj and will be disabled"
            eng_obj["status"] = 0
            eng_obj["monitoredobj"] = "none"
        else
            if !haskey(dss_obj, "enabled")
                @warn "relay $(dss_obj["name"]) does not have enable key and will be set to enable"
                eng_obj["status"] = 1
            else
                if dss_obj["enabled"] == "yes" || dss_obj["enabled"] == "true"
                    eng_obj["status"] = 1
                else
                    eng_obj["status"] = 0
                end
            end
            eng_obj["monitoredobj"] = dss_obj["monitoredobj"]
            if !haskey(dss_obj, "switchedobj")
                eng_obj["switchedobj"] = dss_obj["monitoredobj"]
            else
                eng_obj["switchedobj"] = dss_obj["switchedobj"]
            end
            for monitor_type in monitor_type_list
                for (id, dss_monit_obj) in get(data_dss, monitor_type, Dict())
                    if dss_obj["monitoredobj"] == id
                        eng_obj["monitor_type"] = monitor_type
                    end
                end
            end
        end
        if haskey(dss_obj, "basefreq") && dss_obj["basefreq"] != data_eng["settings"]["base_frequency"]
            @warn "basefreq=$(dss_obj["basefreq"]) on line.$id does not match circuit basefreq=$(data_eng["settings"]["base_frequency"])"
        end
        for (default_id, default_value) in get(defaults_dict, "float_dict", Dict())
            if !haskey(dss_obj, default_id)
                eng_obj[default_id] = default_value
            end
        end
        for (default_id, default_value) in get(defaults_dict, "int_dict", Dict())
            if !haskey(dss_obj, default_id)
                eng_obj[default_id] = default_value
            end
        end
        for (default_id, default_value) in get(defaults_dict, "str_dict", Dict())
            if !haskey(dss_obj, default_id)
                eng_obj[default_id] = default_value
            end
        end
        if !haskey(dss_obj, "type")
            @warn "relay $id does not have a type defined setting it to current"
            eng_obj["type"] = "current"
            eng_obj["recloseintervals"] = [.5, 2.0, 2.0]
        else
            if dss_obj["type"] == "current"
                if !haskey(dss_obj, "recloseintervals")
                    eng_obj["recloseintervals"] = [.5, 2.0, 2.0]
                end
            elseif dss_obj["type"] == "voltage"
                if !haskey(dss_obj, "recloseintervals")
                    eng_obj["recloseintervals"] = 5.0
                end
            end
        end
        _PMD._add_eng_obj!(data_eng, "relay", id, eng_obj)
    end
end


"Helper function for converting dss fuse to engineering fuse"
function _dss2eng_fuse!(data_eng::Dict{String,<:Any}, data_dss::Dict{String,<:Any})
    defaults_dict = Dict{String,Any}(
            "float_dict" => Dict{String,Any}(
                "delay" => 0.0,
            ),
            "int_dict" => Dict{String,Any}(
                "monitoredterm" => 1,
                "switchedterm" => 1,
            ),
            "str_dict" => Dict{String,Any}(
                "fusecurve" => "tlink",
            ),
    )
    for (id, dss_obj) in get(data_dss, "fuse", Dict())
        eng_obj = Dict{String,Any}()
        if !haskey(dss_obj, "monitoredobj")
            @warn "fuse $(dss_obj["name"]) does not have a monitoredobj and will be disabled"
            eng_obj["status"] = 0
            eng_obj["monitoredobj"] = "none"
        else
            if !haskey(dss_obj, "enabled")
                @warn "fuse $(dss_obj["name"]) does not have enable key and will be set to enable"
                eng_obj["status"] = 1
            else
                if dss_obj["enabled"] == "yes" || dss_obj["enabled"] == "true"
                    eng_obj["status"] = 1
                else
                    eng_obj["status"] = 0
                end
            end
            eng_obj["monitoredobj"] = dss_obj["monitoredobj"]
            if !haskey(dss_obj, "switchedobj")
                eng_obj["switchedobj"] = dss_obj["monitoredobj"]
            else
                eng_obj["switchedobj"] = dss_obj["switchedobj"]
            end
        end
        _PMD._add_eng_obj!(data_eng, "relay", id, eng_obj)
    end
end


"Helper function for converting dss tcc_curves to engineering model"
function _dss2eng_curve!(data_eng::Dict{String,<:Any}, data_dss::Dict{String,<:Any})
    for (id, dss_obj) in get(data_dss, "tcc_curve", Dict())
        eng_obj = Dict{String,Any}()
        if startswith(strip(dss_obj["c_array"]),'[')
        c_string = split(split(split(strip(dss_obj["c_array"]),'[')[end],']')[1],',')
        elseif startswith(strip(dss_obj["c_array"]),'"')
        c_string = split(split(split(strip(dss_obj["c_array"]),'"')[end],'"')[1],',')
        elseif startswith(strip(dss_obj["c_array"]),''')
        c_string = split(split(split(strip(dss_obj["c_array"]),''')[end],''')[1],',')
        end
        if startswith(strip(dss_obj["t_array"]),'[')
        t_string = split(split(split(strip(dss_obj["t_array"]),'[')[end],']')[1],',')
        elseif startswith(strip(dss_obj["t_array"]),'"')
        t_string = split(split(split(strip(dss_obj["t_array"]),'"')[end],'"')[1],',')
        elseif startswith(strip(dss_obj["t_array"]),''')
        t_string = split(split(split(strip(dss_obj["t_array"]),''')[end],''')[1],',')
        end
        c_array, t_array = [],[]
        for i = 1:length(c_string)
            push!(c_array,parse(Float64,c_string[i]))
        end
        eng_obj["c_array"] = c_array
        for i = 1:length(t_string)
            push!(t_array,parse(Float64,t_string[i]))
        end
        eng_obj["t_array"] = t_array
        if haskey(dss_obj, "npts")
            npts = parse(Int,dss_obj["npts"])
            if (length(c_array) != npts) || (length(t_array) != npts)
                if length(c_array) > npts
                    @warn "c_array is longer than the npts. Truncating array."
                    cut_points = length(c_array) - npts
                    c_array = c_array[cut_points+1:length(c_array)]
                end
                if length(t_array) > npts
                    @warn "t_array is longer than the npts. Truncating array."
                    cut_points = length(t_array) - npts
                    t_array = t_array[cut_points+1:length(t_array)]
                end
                if length(t_array) < npts
                    @warn "t_array is shorter than npts. Adding time values."
                    t_len = length(t_array)
                    for i=0:npts - t_len - 1
                        push!(t_array, t_array[t_len+i]/2)
                    end
                end
                if length(c_array) < npts
                    @warn "c_array is shorter than npts. Adding current values."
                    c_len = length(c_array)
                    (a,b) = _bisection(c_array[c_len],t_array[c_len],c_array[c_len-1],t_array[c_len-1])
                    for i=1:npts - c_len
                        push!(c_array, round((a/t_array[c_len+i]+1)^(1/b)))
                    end
                end
            end
        else
            if length(c_array) != length(t_array)
                c_len = length(c_array)
                t_len = length(t_array)
                if c_len < t_len
                    @warn "c_array is shorter than t_array. Adding current values."
                    c_len = length(c_array)
                    (a,b) = _bisection(c_array[c_len],t_array[c_len],c_array[c_len-1],t_array[c_len-1])
                    for i=1:npts - c_len
                        push!(c_array, round((a/t_array[c_len+i]+1)^(1/b)))
                    end
                else
                    @warn "t_array is shorter than c_array. Adding time values."
                    for i=0:c_len - t_len - 1
                        push!(t_array, t_array[t_len+i]/2)
                    end
                end
            end
            npts = length(c_array)
        end
        eng_obj["npts"] = npts
        _PMD._add_eng_obj!(data_eng, "tcc_curve", id, eng_obj)
    end
end


"helper function to define generator typr from opendss models"
function _dss2eng_gen_model!(data_eng::Dict{String,<:Any}, data_dss::Dict{String,<:Any})
    if haskey(data_eng, "generator")
        for (id, generator) in data_eng["generator"]
            if haskey(generator["dss"], "model")
                generator["gen_model"] = generator["dss"]["model"]
            else
                generator["gen_model"] = 1
            end
        end
    end
end