
using Documenter
using RedundancyRemoval

makedocs(sitename="RedundancyRemoval.jl",
    authors = "Richard Weinhold",
    pages = [
        "Introducion" => "index.md",
        ],
    );

deploydocs(
    repo = "github.com/richard-weinhold/RedundancyRemoval.git",
    branch = "gh-pages"
)
