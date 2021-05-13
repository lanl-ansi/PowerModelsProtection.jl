""
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


""
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
