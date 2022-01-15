

function set_logger(wdir::String)
	# global_logger(ConsoleLogger(stdout, Logging.Info))
	if isfile(wdir*"/logs/RedundancyRemoval.log")
		TeeLogger(MinLevelLogger(FileLogger(wdir*"/logs/RedundancyRemoval.log", append=true), Logging.Info),
		          ConsoleLogger(stdout, Logging.Info)) |> global_logger
		println("Logfile Found, logging to console and logfile.")
	else
		TeeLogger(ConsoleLogger(stdout, Logging.Info)) |> global_logger
		println("No logfile Found, logging only to console.")
	end
end

function set_global_optimizer(input_optimizer)
	global optimizer = input_optimizer.Optimizer
	global optimizer_package = input_optimizer
end

function save_to_file(wdir::String, Indices::Vector{Int}, filename::String)
	# I_result.-1: Indices start at 0 (in python.... or any other decent programming language)
	@info("Writing File "*filename*" .... ")
	CSV.write(wdir*"/"*filename*".csv",
	  	 	  DataFrame(constraints = Indices.-1))
end

function read_data(wdir::String, file_suffix::String)
	# Read Data From CSV Files
	@info("Reading A, b, x_bounds...")
	A_data = DataFrame(CSV.File(wdir*"/A_"*file_suffix*".csv",
					    delim=',', header=false), copycols=true)
	b_data = DataFrame(CSV.File(wdir*"/b_"*file_suffix*".csv",
					    delim=',', header=false, types=Dict(1=>Float64)), copycols=true)

	# Create Array A and Vector b from DataFrame
	A =  hcat([A_data[:, i] for i in 1:size(A_data, 2)]...)
	b = b_data[:,1]

	x_bounds = DataFrame(CSV.File(wdir*"/x_bounds_"*file_suffix*".csv",
					      delim=',', header=false, types=Dict(1=>Float64)), copycols=true)
	# Read X Bounds or set as empty Vector
	x_bounds = size(x_bounds, 2) > 0 ? x_bounds[:,1] : Array{Float64, 1}()

	return A, b, x_bounds
end


"""
    run_redundancy_removal(
        wdir::String, 
        file_suffix::String, 
        optimizer_package; 
        kwargs...)

    run_redundancy_removal(
        A::Array{Float64}, 
        b::Vector{Float64}, 
        x_bounds::Vector{Float64}, 
        optimizer_package;
        filter_only::Bool=true, 
        parallel::Bool=true,
        preprocessing::Bool=true)


Runs the RedundancyRemoval on files in wdir, the files that the program is looking for are A.csv,
b.csv and x_bounds.csv with suffix or directly supply the inputs Array and Vectors. 

See the examples folder for exact formatting. Generally the input matrix A represents a PTDF matrix,
where rows represent lines/contingencies and columns nodal power injections, vector b the line
capacity for each row in the PTDF matrix and the x_bounds vector represents the symmetrical bounds
for nodal injections. 

The resulting vector I holds indices of rows where A[:, I] x <= b[I] is a non-redundant system of 
inequalities equivalent to the full system of inequalities.  

Optional arguments can be used to influence the execution of the algorithm. The algorithm can be
executed using multiple threads. In that case sections of the checked indices are run in parallel to
filter out redundant indices. After each pass, sections are combined and re-run. When
parallel=False, the algorithm will be run single threaded, meaning all indices will be checked
sequentially in a single pass. If parallel=True, segements will be filtered and then combines. If
filter_only=True, the last pass will be executed single threaded, if filter_only=False the method
LPTest will be executed in paralell for all remaining indices. 

The resulting essential set will be saved to the wdir. 

"""
function run_redundancy_removal(wdir::String, file_suffix::String, optimizer_package; kwargs...)
	set_logger(wdir)
	A, b, x_bounds = read_data(wdir, file_suffix)
	essentaial_set = run_redundancy_removal(A, b, x_bounds, optimizer_package; kwargs...)
	@info("Number of non-redundant constraints: $(length(essentaial_set))" )
	filename = "cbco_"*file_suffix*"_"*Dates.format(now(), "ddmm_HHMM_SSsss")
	save_to_file(wdir, essentaial_set, filename)
	@info("Everything Done!")
	return filename
end

"""
	run_redundancy_removal_fbmc_domain(
        wdir::String, 
        optimizer_package; 
        parallel::Bool=false)

Run the RedundancyRemoval algorithm for each timedependant system of inequalities, namely zonal
day-ahead domains for commercial exchange (FBMC Domains). This function will go through each
timestep and presolve the system of inequalities Ax <= b, where A is the zonal PTDF, x zonal net
positions and b the remaining capacitiy on the network elements (RAM). 

See the examples folder for exact formatting of the input data (Ab_info.csv). 

The optional argument parallel makes the process run in parallel, generally the default setting
false seems to work best, as the overhead of Threading the problem outweighs its benefits since 
the systems are of low dimensionality (< 20). 

"""
function run_redundancy_removal_fbmc_domain(wdir::String, optimizer_package; parallel::Bool=false)

	set_logger(wdir)
	domain_data = DataFrame!(CSV.File(wdir*"/Ab_info.csv"))
	non_redundant_domain = copy(domain_data[:, ["index", "timestep"]])
	non_redundant_domain[!, :index] .+= 1
	non_redundant_domain[!, :in_domain] .= false

	if parallel
		timesteps = unique(domain_data[:, :timestep])
		threads = 4
		split_timesteps = split_m(collect(1:length(timesteps)), threads)
		@info("Using $(threads) threads for RedundancyRemoval")
		Threads.@threads for segment in split_timesteps
			for i in segment
				t = timesteps[i]
				@info("Run RedundancyRemoval for timestep $(t)")
				with_logger(NullLogger()) do
					A = hcat([domain_data[domain_data[:, :timestep] .== t, i] for i in 7:size(domain_data, 2)]...)
					b = domain_data[domain_data[:, :timestep] .== t, :ram]
					essentaial_set = redundancy_removal_fbmc_domain(A, b, optimizer_package)
					tmp = [false for i in 1:length(b)]
					tmp[essentaial_set] .= true
					@inbounds non_redundant_domain[!, "in_domain"][domain_data[:, :timestep] .== t] = tmp
				end
			end
		end
	else
		for t in unique(domain_data[:, :timestep])
			@info("Run RedundancyRem for timestep $(t)")
			with_logger(NullLogger()) do
				A = hcat([domain_data[domain_data[:, :timestep] .== t, i] for i in 7:size(domain_data, 2)]...)
				b = domain_data[domain_data[:, :timestep] .== t, :ram]
				essentaial_set = redundancy_removal_fbmc_domain(A, b, optimizer_package)
				tmp = [false for i in 1:length(b)]
				tmp[essentaial_set] .= true
				non_redundant_domain[!, "in_domain"][domain_data[:, :timestep] .== t] = tmp
			end
		end
	end

	@info("Number of non-redundant constraints: $(length(non_redundant_domain[non_redundant_domain[:, :in_domain], :index]))" )
	filename = "cbco_"*Dates.format(now(), "ddmm_HHMM_SSsss")
	save_to_file(wdir, non_redundant_domain[non_redundant_domain[:, :in_domain], :index], filename)
	@info("Everything Done!")
end

function redundancy_removal_fbmc_domain(A::Array{Float64}, b::Vector{Float64}, optimizer_package)
	set_global_optimizer(optimizer_package)
	z = zeros(size(A, 2))
	I = Array{Int, 1}()
	m = collect(1:length(b))
	x_bounds = Array{Float64, 1}()
	return main(A, b, m, I, x_bounds, z)
end

function run_redundancy_removal(A::Array{Float64}, b::Vector{Float64}, x_bounds::Vector{Float64}, optimizer_package;
								filter_only::Bool=true, parallel::Bool=true, preprocessing::Bool=true)

	set_global_optimizer(optimizer_package)
	m = collect(1:length(b))
	if preprocessing
		@info("Preprocessing...")
		@info("Removing duplicate rows...")
		# Remove douplicates
		condition_unique = .!nonunique(DataFrame(hcat(A,b), :auto))
		@info("Removing all zero rows...")
		# Remove cb = co rows
		condition_zero = vcat([!all(A[i, :] .== 0) for i in 1:length(b)])
		m = m[condition_unique .& condition_zero]
		@info("Removed $(length(b) - length(m)) rows in preprocessing!")
	end
	# Interior point z = zero
	z = zeros(size(A, 2))
	I = Array{Int, 1}()
	m = setdiff(m, I)
	@info("Starting with m size of length $(length(m))")
	if parallel
		if filter_only
			@info("Running parallel: filter only")
			essentaial_set = main_parallel_filter(A, b, m, I, x_bounds, z)
		else
			@info("Running parallel: filter until Threads/2 then parallel LPTest")
			essentaial_set = main_parallel_filter_lp(A, b, m, I, x_bounds, z)
		end
	else
		@info("Running sequential")
		essentaial_set = main(A, b, m, I, x_bounds, z)
	end
	return essentaial_set
end
