

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

function save_to_file(wdir::String, Indices::Vector{Int}, filename::String)
	# I_result.-1: Indices start at 0 (in python.... or any other decent programming language)
	@info("Writing File "*filename*" .... ")
	CSV.write(wdir*"/"*filename*".csv",
	  	 	  DataFrame(constraints = Indices.-1))
end

function read_data(wdir::String, file_suffix::String)
	# Read Data From CSV Files
	@info("Reading A, b, x_bounds...")
	A_data = CSV.read(wdir*"/A_"*file_suffix*".csv",
					  delim=',', header=false)
	b_data = CSV.read(wdir*"/b_"*file_suffix*".csv",
					  delim=',', header=false, types=Dict(1=>Float64))

	# Create Array A and Vector b from DataFrame
	A =  hcat([A_data[:, i] for i in 1:size(A_data, 2)]...)
	b = b_data[:,1]

	x_bounds = CSV.read(wdir*"/x_bounds_"*file_suffix*".csv",
					    delim=',', header=false, types=Dict(1=>Float64))
	# Read X Bounds or set as empty Vector
	x_bounds = size(x_bounds, 2) > 0 ? x_bounds[:,1] : Array{Float64, 1}()

	return A, b, x_bounds
end

function run_redundancy_removal(wdir::String, file_suffix::String, input_optimizer; kwargs...)
	set_logger(wdir)
	A, b, x_bounds = read_data(wdir, file_suffix)
	essentaial_set = run_redundancy_removal(A, b, x_bounds, input_optimizer; kwargs...)
	@info("Number of non-redundant constraints: $(length(essentaial_set))" )
	filename = "cbco_"*file_suffix*"_"*Dates.format(now(), "ddmm_HHMM")
	save_to_file(wdir, essentaial_set, filename)
	@info("Everything Done!")
	return filename
end

function run_redundancy_removal(A::Array{Float64}, b::Vector{Float64}, x_bounds::Vector{Float64}, input_optimizer;
								filter_only::Bool=true, parallel::Bool=true, preprocessing::Bool=true)

	global optimizer = input_optimizer

	m = collect(1:length(b))
	if preprocessing
		@info("Preprocessing...")
		@info("Removing duplicate rows...")
		# Remove douplicates
		condition_unique = .!nonunique(DataFrame(hcat(A,b)))
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
