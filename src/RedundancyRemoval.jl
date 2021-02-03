module RedundancyRemoval

using CSV, DataFrames, Dates, Logging, LoggingExtras
using LinearAlgebra
using JuMP
using Base.Threads

include("redundancy_removal_functions.jl")
include("main.jl")

export run_redundancy_removal

end # module
