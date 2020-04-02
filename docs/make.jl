using Documenter, PowerModelsProtection

makedocs(
    modules = [PowerModelsProtection],
    format = Documenter.HTML(analytics = "", mathengine = Documenter.MathJax()),
    sitename = "PowerModelsProtection",
    authors = "Arthur Barnes, Jose Tabarez, and contributors.",
    pages = [
        "Home" => "index.md",
    ]
)

deploydocs(
    repo = "github.com/lanl-ansi/PowerModelsProtection.jl.git",
)
