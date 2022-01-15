
include("../src/RedundancyRemoval.jl")
import .RedundancyRemoval
using Test, Logging
using Clp
# using Plots
using DataFrames, CSV

# wdir = "C:/Users/riw/tubCloud/Uni/Market_Tool/pomato_studies/data_temp/julia_files/cbco_data"
# RedundancyRemoval.run_redundancy_removal_fbmc_domain(wdir, Clp.Optimizer)
# domain_data = DataFrame!(CSV.File(wdir*"/cbco_info.csv"))
# non_redundant_domain = copy(domain_data[:, ["index", "timestep"]])
# non_redundant_domain[!, :in_domain] .= false
# if parallel
# 	Threads.@threads for t in unique(domain_data[:, :timestep])
# 		A = hcat([domain_data[domain_data[:, :timestep] .== t, i] for i in 7:size(domain_data, 2)]...)
# 		b = domain_data[domain_data[:, :timestep] .== t, :ram]
# 		essentaial_set = redundancy_removal_fbmc_domain(A, b, input_optimizer)
# 		tmp = [false for i in 1:length(b)]
# 		tmp[essentaial_set] .= true
# 		@inbounds non_redundant_domain[!, "in_domain"][domain_data[:, :timestep] .== t] = tmp
# 	end
# else

ConsoleLogger(stdout, Logging.Error) |> global_logger#
function dummy_data()
	A_nonredundant = [-1. 1; 	# x2 <= x1 + 3
					  1. -1; 	# x2 >= x1 - 6
					  0 1; 		# x2 <=  2
					  1 1; 		# x2 <= -x1 + 5
					  -1 -1; 	# x2 >= -x1
					  1 0; 		# x1 <= 4
					  0 -1; 	# x2 >= -2
					  -1 0] 	# x1 >= -2
	b_nonredundant = [3, 5, 2, 5, 2, 4, 2, 2.]

	A_redundant = [0 1; 0 -1; 1 0;-1 0]
	b_redundant = [1, 1, 1, 1]

	A_redundant = vcat([A_redundant for i in 1:100]...)
	b_redundant = vcat([5 .+ b_redundant for i in 1:100]...)
	b_redundant = b_redundant + 4*rand(length(b_redundant))
	A = vcat(A_redundant, A_nonredundant)
	b = vcat(b_redundant, b_nonredundant)

	x_bounds = [100. for x in 1:length(b)]
	nonredundant_indices = collect(length(b) - length(b_nonredundant) + 1:length(b))

	return A, b, x_bounds, nonredundant_indices
end

# function plot_redundancy_removal()
# 	A, b, x_bounds, nonredundant_indices = dummy_data()
# 	optimizer = Clp.Optimizer
# 	essential_set = RedundancyRemoval.run_redundancy_removal(A, b, x_bounds,
# 															 optimizer, parallel=false, filter_only=false)
# 	f_x = x -> (-A[:, 1] .* x + b) ./ A[:, 2]
# 	f_y = x -> (-A[:, 2] .* x + b) ./ A[:, 1]
# 	r = -20:20
# 	plot_limit = 12
# 	plt = Plots.plot(xlims=(-plot_limit, plot_limit), ylims=(-plot_limit, plot_limit), legend=false)
# 	y = hcat([f_x(i) for i in r]...)
# 	x = hcat([f_y(i) for i in r]...)
# 	for i in 1:length(b)
# 		color = i in essential_set ? :red : :blue
# 		if !(any(y[i, :] .== NaN) | any(y[i, :] .== Inf))
# 			Plots.plot!(plt, r, y[i, :], color=color)
# 		else
# 			Plots.plot!(plt, x[i, :], r, color=color)
# 		end
# 	end
# 	plt
# end



@testset "All" begin
	@testset "RedundancyRemoval Parallel, Filter" begin

		A, b, x_bounds, nonredundant_indices = dummy_data()
		optimizer = Clp

		essential_set = RedundancyRemoval.run_redundancy_removal(A, b, x_bounds,
																 optimizer, parallel=true, filter_only=true)
		@test length(setdiff(essential_set, nonredundant_indices)) == 0
	end

	@testset "RedundancyRemoval Parallel, Filter, witout x_bounds" begin

		A, b, x_bounds, nonredundant_indices = dummy_data()
		optimizer = Clp
		x_bounds = Array{Float64, 1}()
		essential_set = RedundancyRemoval.run_redundancy_removal(A, b, x_bounds,
																 optimizer, parallel=true, filter_only=true)
		@test length(setdiff(essential_set, nonredundant_indices)) == 0
	end

	@testset "RedundancyRemoval Parallel, Filter=false" begin
		A, b, x_bounds, nonredundant_indices = dummy_data()
		optimizer = Clp
		essential_set = RedundancyRemoval.run_redundancy_removal(A, b, x_bounds,
																 optimizer, parallel=true, filter_only=false)
		@test length(setdiff(essential_set, nonredundant_indices)) == 0
	end

	@testset "RedundancyRemoval Singlethreaded" begin
		A, b, x_bounds, nonredundant_indices = dummy_data()
		optimizer = Clp
		essential_set = RedundancyRemoval.run_redundancy_removal(A, b, x_bounds,
																 optimizer, parallel=false, filter_only=false)
		@test length(setdiff(essential_set, nonredundant_indices)) == 0
	end

	@testset "Step by Step Run for non-redundant indices" begin
		A, b, x_bounds, nonredundant_indices = dummy_data()
		m = collect(1:length(b))
		# Interior point z = zero
		z = zeros(size(A, 2))
		I = Array{Int, 1}()
		m = nonredundant_indices
		model = RedundancyRemoval.build_model(size(A, 2), A[I,:], b[I], x_bounds)
		while true
			k = m[1]
			alpha, x_opt = RedundancyRemoval.is_redundant(model, A[k,:], b[k])
			@test alpha # alpha == true
			j = RedundancyRemoval.RayShoot(A, b, m, z, x_opt)
			@test j in nonredundant_indices
			model = RedundancyRemoval.add_constraint(model, A[j,:], b[j])
			m = setdiff(m, j)
			push!(I, j)
			if length(m) == 0
				break
			end
		end
	end

	@testset "Run IEEE from file" begin
		dir = cd(pwd, "..")*"/examples/"
		file_suffix = "ieee118"
		optimizer = Clp
		file = RedundancyRemoval.run_redundancy_removal(dir, file_suffix, optimizer)
		@test isfile(dir*file*".csv")
	end

	@testset "FlowBased Domain Reduction" begin
		dir = cd(pwd, "..")*"/examples"
		RedundancyRemoval.run_redundancy_removal_fbmc_domain(dir, Clp)
	end
end
