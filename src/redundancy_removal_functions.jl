


function return_optimizer()
	global optimizer
	global optimizer_package
	if string(optimizer_package) == "Gurobi"
		return optimizer_with_attributes(optimizer, "OutputFlag" => 0,
			"Method" => 0, "Presolve" => 0,
			"PreDual" => 0, "Aggregate" => 0)
	elseif string(optimizer_package) == "Clp"
		return optimizer_with_attributes(optimizer, "LogLevel" => 0,
		"SolveType" => 0, "PresolveType" => 1, 
		"DualTolerance" => 1e-10, "PrimalTolerance" => 1e-10,
		)
	else
		return optimizer
	end
end


function is_redundant(model::JuMP.Model, constraint::Vector{Float64}, rhs::Float64)
	tmp_constraint = @constraint(model, constraint' * model[:x] <= rhs + 1)
	@objective(model, Max, constraint' * model[:x])
	JuMP.optimize!(model)
	@debug("Solution", JuMP.value.(model[:x]))
	@debug("Obj Value", JuMP.objective_value(model))
	@debug("Number of constraints $(num_constraints(model,
		GenericAffExpr{Float64,VariableRef},
		MOI.LessThan{Float64}))")
	if JuMP.termination_status(model) == MOI.OPTIMAL
		objective_value = JuMP.objective_value(model)
		x_opt = JuMP.value.(model[:x])
		JuMP.delete(model, tmp_constraint)
		if objective_value > rhs
			return true, x_opt, model
		else
			return false, x_opt, model
		end
	else
		JuMP.delete(model, tmp_constraint)
		return false, [], model
	end
end

function build_model(dim::Int, A::Array{Float64},
    				 b::Vector{Float64}, x_bounds::Vector{Float64})

	model = Model(return_optimizer())
	MOI.set(model, MOI.Silent(), true)

	if size(x_bounds, 1) > 0
		@info("Building Model with bounds on x!")
		@variable(model, x[i=1:dim], lower_bound=-x_bounds[i], upper_bound=x_bounds[i])
	else
		@info("Building Model with x free!")
		@variable(model, x[i=1:dim], lower_bound=-1E6, upper_bound=1E6)
		# @variable(model, x[i=1:dim])
	end

	@constraint(model, con[i=1:size(A, 1)], A[i,:]' * x <= b[i])
	# @constraint(model, sum(x[i] for i in 1:dim) == 0)
	return model
end

function add_constraint(model::JuMP.Model, constraint::Vector{Float64}, rhs::Float64)
	@constraint(model, sum(constraint .* model[:x]) <= rhs)
	return model
end

function RayShoot(A::Array{Float64}, b::Vector{Float64}, m::Vector{Int},
	              z::Vector{Float64}, x_opt::Vector{Float64})
	### Set-up
	stepsize = 1
	i = 0
	counter = 0
	max_iterations = 10
	## Define Ray (vector from interior point z to x_op)
	r = x_opt - z
	## Subset m to only contain constraints violated by x_opt
	m_hat = m[findall(x-> x>0, A[m,:]*x_opt - b[m])]
	# m_hat = m
	if length(m_hat) == 0
		 @debug("WARNING: m_hat empty, possibly numerical error")
		 @debug("Moving further outside along the Ray")
		 m_hat = m[findall(x-> x>=0, A[m,:]*x_opt*1.01 - b[m])]
		 @debug("m_hat $(m_hat), length = $(length(m_hat))!")
		 if length(m_hat) == 0
		 	@error("m_hat still empty. Numerical Error!")
		 end
	end

	while true
		point = z + r*i
		temp = A[m_hat,:]*point - b[m_hat]
		# If 1 constraint is hit, return it
		constraints_hit = size(findall(x-> x>0, temp), 1)
		if constraints_hit == 1
			@debug("Constraint hit: $(m_hat[findall(x->x>0, temp)]) With i = $i, stepsize = $stepsize")
			return m_hat[findfirst(x->x>0, temp)]
		# If more than one constraint is hit:
		# 1) Check for breaking condition:
		#	 If True return either the first of the constraints hit
		# 2) 1) Go one step back, to where no constraint was hit
		#    2) Continue forward with 1/10 of stepsize
		#	 3) Increase counter, since this procedure is limited by
		#	    float number of decimal places for increment i
		elseif constraints_hit > 1
			# Check breaking condition
			if counter > max_iterations
				@debug("Counter > $(max_iterations), returning first of the constraints hit!")
				@debug("Constraints hit: $(m_hat[findall(x->x>0, temp)]) With i = $i")
				return m_hat[findfirst(x->x>0, temp)]
			else
				# Going back and reducing stepsize by 10th
				counter += 1
				i = i - exp10(-stepsize)
				stepsize += 1
			end
		# No constraint is hit, incease increment i by stepsize
		else
			i = i + exp10(-stepsize)
		end
	end
end

function main(A::Array{Float64}, b::Vector{Float64},  m::Vector{Int},
			  I::Vector{Int}, x_bounds::Vector{Float64}, z::Vector{Float64})
	@info("Starting Algorithm with I of size: $(length(I))")
	@info("and with m of size: $(length(m))")
	# Set-up
	# Make counter to print out progress every number of steps
	steps = 5
	to_check = length(m)
	stepsize = round(to_check/steps)
	save_points = [Int(x) for x in stepsize:stepsize:to_check]
	# Make sure only 100 save_points are available, remove the first ones
	if length(save_points) > steps
		save_points = save_points[(length(save_points) + 1 - steps):end]
	end
	### Build base model
	model = build_model(size(A, 2), A[I,:], b[I], x_bounds)
	# Start Algorithm
	while true
		k = m[1]
		@debug("checking constraint k = $k")
		# Check redundancy of constraint k
		alpha, x_opt = is_redundant(model, A[k,:], b[k])
		if alpha
			# If true, rayshoot and add constraint j to the model
			j = RayShoot(A, b, m, z, x_opt)
			@debug("k = $k and j = $j")
			model = add_constraint(model, A[j,:], b[j])
			m = setdiff(m, j)
			push!(I, j)
		else
			# if not, remove constraint from m
			m = setdiff(m, k)
		end
		# print progress at specified when size(m) hit certain threasholds
		if length(m) in save_points
			percentage = Int(100 - 100/steps*findfirst(x -> x==length(m), save_points))
			progress_bar = repeat("#", Int(round(percentage/5)))*repeat(" ", Int(round((100-percentage)/5)))
			timestamp = Dates.format(now(), "dd.mm - HH:MM:SS")
			report = "- Size of I $(length(I)) - Found Redundant $(to_check - length(I) - length(m)) - Remaining $(length(m)) - "
			thread = " on Thread: "*string(Threads.threadid())
			@info(progress_bar*string(percentage)*"%"*report*timestamp*thread)
		end
		if length(m) == 0  # Conclude when m is empty
			break
		end
	end
	return I
end

function split_m(m::Vector{Int}, splits::Int)
	m_segments = []
	segment_length = Int(floor(length(m)/splits))
	for i in 1:splits - 1
		push!(m_segments, m[(i-1)*segment_length + 1:i*segment_length])
	end
	push!(m_segments, m[(splits-1)*segment_length + 1:end])
 	return m_segments
end

function split_m_indices(m::Vector{Int}, splits::Int)
	m_segments = []
	segment_length = Int(floor(length(m)/splits))
	for i in 1:splits - 1
		push!(m_segments, collect((i-1)*segment_length + 1:i*segment_length))
	end
	push!(m_segments, collect((splits-1)*segment_length + 1:length(m)))
 	return m_segments
end

function parallel_filter(A::Array{Float64}, b::Vector{Float64},
						 m::Vector{Int}, x_bounds::Vector{Float64},
						 z::Vector{Float64}, splits::Int)

	m_segments = split_m(m, Int(splits))
	m_segments = split_m_indices(m, Int(splits))
	indices = zeros(Bool, length(m))
	Threads.@threads for m_seg in m_segments
		idx = main(A[m[m_seg], :], b[m[m_seg]], collect(1:length(m_seg)), Array{Int, 1}(), x_bounds, z)
		@inbounds indices[m_seg[idx]] .= true
		@info("Nonredundant indices $(length(m_seg[idx])) from process: $(Threads.threadid())")
	end
	@info("Length of m: $(length(m[indices]))")
	return m[indices]
end

function solve_parallel(model::JuMP.Model, A::Array{Float64}, b::Vector{Float64},
						filtered_m::Vector{Int}, x_bounds::Vector{Float64},
					   	r::Vector{Int})
	JuMP.set_optimizer(model, return_optimizer())
	MOI.set(model, MOI.Silent(), true)

	indices = zeros(Bool, length(r))
	@info("Start wit LPTest on proc: $(Threads.threadid())")
	for k in 1:length(r)
		model_index = findfirst(x -> x == filtered_m[r[k]], filtered_m)
		@objective(model, Max, A[k, :]' * model[:x])
		JuMP.delete(model, model[:con][model_index])
		JuMP.optimize!(model)
		if !(JuMP.objective_value(model) <  b[k])
			@constraint(model, sum(A[k, :] .* model[:x]) <= b[k])
			indices[k] = true
		end
		if k%50 == 0
			timestamp = Dates.format(now(), "dd.mm - HH:MM:SS")
			@info("$(k) constraints done on proc: $(Threads.threadid()) - $(timestamp)")
		end
	end
	return indices
end

function main_parallel_filter_lp(A::Array{Float64}, b::Vector{Float64},
					   			 m::Vector{Int}, I::Vector{Int}, x_bounds::Vector{Float64},
					   			 z::Vector{Float64})

	filtered_m = copy(m)
	min_splits = floor(Int, length(filtered_m)/20)
	filter_splits = Threads.nthreads()*2 > min_splits ? min_splits : Threads.nthreads()*2
	while true
		tmp_m = parallel_filter(A, b, filtered_m, x_bounds, z, Int(filter_splits))
		@info("Size of m $(length(filtered_m)) reduced to m* $(length(tmp_m))")
		if Int(filter_splits) <= Threads.nthreads()/2
			@info("Finshied with parallel filter!")
			filtered_m = tmp_m
			break
		else
			filter_splits = floor(Int, filter_splits/2)
		end
		filtered_m = tmp_m
	end
	I = zeros(Bool, length(filtered_m))
	number_ranges = maximum(Int, [floor(Int, length(filtered_m)/500), Threads.nthreads()])
	ranges = split_m_indices(filtered_m, number_ranges)
	@info("Run final LP Test in $(number_ranges) Segements.")
	base_model = build_model(size(A, 2), A[filtered_m, :], b[filtered_m], x_bounds)
	Threads.@threads for range in ranges
		@info("LP Test with length $(length(range)) on proc id: $(Threads.threadid())")
		indices = solve_parallel(copy(base_model), A[filtered_m[range], :],
								 b[filtered_m[range]], filtered_m, x_bounds, range)
		@inbounds I[range[indices]] .= true
		@info("Done with LP Test on proc id: $(Threads.threadid())")
	end
	return filtered_m[I]
end

function main_parallel_filter(A::Array{Float64}, b::Vector{Float64},
					   		  m::Vector{Int}, I::Vector{Int}, x_bounds::Vector{Float64},
					   		  z::Vector{Float64})
	filtered_m = copy(m)
	min_splits = floor(Int, length(filtered_m)/20)
	filter_splits = Threads.nthreads()*2 > min_splits ? min_splits : Threads.nthreads()*2
	while true
		tmp_m = parallel_filter(A, b, filtered_m, x_bounds, z, Int(filter_splits))
		@info("Size of m $(length(filtered_m)) reduced to m* $(length(tmp_m))")
		if Int(filter_splits) <= Threads.nthreads()/2
			@info("Finshied with parallel filter!")
			filtered_m = tmp_m
			break
		else
			filter_splits = floor(Int, filter_splits/2)
		end
		filtered_m = tmp_m
	end
	@info("Run final RedundancyRemoval single threaded.")
	I_result = main(A, b, filtered_m, Array{Int, 1}(), x_bounds, z)
	return I_result
end
