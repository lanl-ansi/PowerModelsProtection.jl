
function parse_opendss(io::IO)
    pm_data = _PMD.parse_file(io)
    pm_data["method"] = "PMD"
    return pm_data
end
