using Documenter
using PowerModelsProtection

import Pluto
import Gumbo

const _FAST = findfirst(isequal("--fast"), ARGS) !== nothing

makedocs(
    modules=[PowerModelsProtection],
    format=Documenter.HTML(
        analytics="",
        mathengine=Documenter.MathJax(),
        prettyurls=false,
        collapselevel=1,
    ),
    sitename="PowerModelsProtection",
    authors="Arthur Barnes, Jose Tabarez, and contributors.",
    pages=[
        "Introduction" => "index.md",
        "Manual" => [
            "Getting Started" => "manual/quickguide.md",
            "Fault Model" => "manual/fault_models.md",
        ],
        "Tutorials" => [
            "Distribution Fault Studies" => "tutorials/distribution_fault_studies.md",
            "Transmission Fault Studies" => "tutorials/transmission_fault_studies.md",
        ],
        "API Reference" => [
            "Data Models" => "reference/data_models.md",
            "Problems" => "reference/problems.md",
            "Variables" => "reference/variables.md",
            "Constraints" => "reference/constraints.md",
        ],
    ],
)

# Insert HTML rendered from Pluto.jl into tutorial stubs as iframes
if !_FAST
    ss = Pluto.ServerSession()
    client = Pluto.ClientSession(Symbol("client", rand(UInt16)), nothing)
    ss.connected_clients[client.id] = client
    for file in readdir("examples", join=true)
        if endswith(file, ".jl")
            nb = Pluto.load_notebook_nobackup(file)
            client.connected_notebook = nb
            Pluto.update_run!(ss, nb, nb.cells)
            html = Pluto.generate_html(nb)

            fileout = "docs/build/tutorials/$(basename(file)).html"
            open(fileout, "w") do io
                write(io, html)
            end

            doc = open("docs/build/tutorials/$(replace(basename(file), ".jl" => ".html"))", "r") do io
                Gumbo.parsehtml(read(io, String))
            end

            # add style for full height iframe
            style = Gumbo.HTMLElement(:style)
            style.children = Gumbo.HTMLNode[Gumbo.HTMLText("iframe { height: 100vh; width: 100%; }")]
            push!(doc.root[1], style)

            # create iframe containing Pluto.jl rendered HTML
            iframe = Gumbo.HTMLElement(:iframe)
            iframe.attributes = Dict{AbstractString,AbstractString}(
                "src" => "$(basename(file)).html",
            )

            # edit existing html to replace :article with :iframe
            doc.root[2][1][2][2] = iframe

            # Overwrite HTML
            open("docs/build/tutorials/$(replace(basename(file), ".jl" => ".html"))", "w") do io
                Gumbo.prettyprint(io, doc)
            end
        end
    end
end


deploydocs(
    repo="github.com/lanl-ansi/PowerModelsProtection.jl.git",
)
