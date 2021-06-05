
using Documenter
using MarketModel

makedocs(sitename="RedundancyRemoval.jl",
    authors = "Richard Weinhold",
    pages = [
        "Introducion" => "index.md",
        ],
    );

deploydocs(
    repo = "github.com/richard-weinhold/RedundancyRemoval.git",
    devbranch = "master",
    branch = "gh-pages"
)

