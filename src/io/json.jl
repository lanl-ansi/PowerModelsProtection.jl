"""
    parse_json(io::IO)

Parser for data from PowerModelsProtection. Corrects enums and matrices saved as JSON.
"""
function parse_json(io::IO)
    data = JSON.parse(io)
    _PMD.correct_json_import!(data)

    return data
end


"""
    parse_json(file::String)

Parser for data from PowerModelsProtection. Corrects enums and matrices saved as JSON.
"""
function parse_json(file::String)
    open(file, "r") do io
        parse_json(io)
    end
end
