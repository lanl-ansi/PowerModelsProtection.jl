### A Pluto.jl notebook ###
# v0.14.5

using Markdown
using InteractiveUtils

# ╔═╡ 79a625ce-b80f-11eb-1c52-0dbc35b93173
begin
	import Pkg
	Pkg.activate(mktempdir())
	Pkg.add(
		[
			Pkg.PackageSpec(; name="PowerModelsProtection", rev="ref/pmd-v11"),
			Pkg.PackageSpec(; name="Ipopt"),
		]
	)
end

# ╔═╡ 3f140cc1-0192-446b-8841-4c3d58d038f1
begin
	using PowerModelsProtection
	import Ipopt
end

# ╔═╡ bf475390-f3cd-4afd-b652-d9fe0efef977
md"""
# PowerModelsProtection.jl: Transmission Fault Studies

In this example we introduce how to perform fault studies on a transmission data set (i.e., using a matpower input file).

First we need to create the appropriate versions of PowerModelsProtection and Ipopt.
"""

# ╔═╡ cfe37cf2-c9d2-446a-bb08-f823fc284ad2
md"""
## Using PowerModelsProtection

Once the proper environment is populated, import the necessary packages,
"""

# ╔═╡ 40e52828-851e-46aa-944f-4e81f116101b
md"""
and initialize a solver, in this case an Ipopt.Optimizer based solver...
"""

# ╔═╡ 74ec696c-0f33-4258-875e-b2f5908c0b72
ipopt_solver = optimizer_with_attributes(Ipopt.Optimizer, "print_level"=>0, "tol"=>1e-6)

# ╔═╡ 672cf68a-e9c0-47b0-a462-a644892b58f7
md"""
## Loading a transmission data set

To load a transmission dataset, we use the `parse_file` function. In this case we are using a 5-bus case included in our unit-tests.
"""

# ╔═╡ e5d332e0-3037-44e7-b7db-b572f5c13fae
case5_fault = parse_file(joinpath(dirname(pathof(PowerModelsProtection)), "..", "test", "data", "trans", "case5_fault.m"))

# ╔═╡ 72379e8d-0b04-4b15-a901-8e11d4f2df22
md"""
## Preparing the network
"""

# ╔═╡ 300cbe9e-738d-4dda-9efc-a5c0f1fef320
begin
	data_fault = deepcopy(case5_fault)

	prepare_transmission_data!(
		data_fault;
		flat_start=true,
		neglect_line_charging=true,
		neglect_transformer=true,
		zero_gen_setpoints=true
	)
end

# ╔═╡ 24e9b099-bd62-43ce-8d08-7d6df3b674e0
md"""
## Adding a fault

To add a fault, use the helper function `add_fault!(data, fault_id, bus_id, fault_resistance)`
"""

# ╔═╡ 0dfb6ee7-9b10-4754-b870-14bf3fc2654d
add_fault!(data_fault, 1, 2, 0.0001)

# ╔═╡ 07f28faa-415e-4857-8ade-9ca070fba10d
md"""
## Running a fault study

To run a fault study with one or more faults under the `"fault"` Dict, use the `solve_fault_study` function
"""

# ╔═╡ f87daf52-e2dc-4350-9240-7adaf36990ce
results_fault = solve_fault_study(data_fault, ipopt_solver)

# ╔═╡ da32ad85-0811-403e-86e4-f672ac2336cf
md"""
## Running without adding faults

To run a fault study over all buses, we should first build the list of fault studies using the `build_fault_study` function.
"""

# ╔═╡ fa968a71-ddc9-4ce1-9ee7-8a39165811d6
fault_study = build_fault_study(case5_fault)

# ╔═╡ 03cee420-413c-499f-83e4-08339656b8a8
md"""
We can then run all of these fault studies in series using the `solve_fault_study` function.
"""

# ╔═╡ d91d6fdb-1aa9-434e-8be1-ff622128110a
begin
	data_no_faults = deepcopy(case5_fault)

	prepare_transmission_data!(
		data_no_faults;
		flat_start=true,
		neglect_line_charging=true,
		neglect_transformer=true,
		zero_gen_setpoints=true
	)

	results_fault_study = solve_fault_study(data_no_faults, fault_study, ipopt_solver)
end

# ╔═╡ Cell order:
# ╟─bf475390-f3cd-4afd-b652-d9fe0efef977
# ╠═79a625ce-b80f-11eb-1c52-0dbc35b93173
# ╟─cfe37cf2-c9d2-446a-bb08-f823fc284ad2
# ╠═3f140cc1-0192-446b-8841-4c3d58d038f1
# ╟─40e52828-851e-46aa-944f-4e81f116101b
# ╠═74ec696c-0f33-4258-875e-b2f5908c0b72
# ╟─672cf68a-e9c0-47b0-a462-a644892b58f7
# ╠═e5d332e0-3037-44e7-b7db-b572f5c13fae
# ╟─72379e8d-0b04-4b15-a901-8e11d4f2df22
# ╠═300cbe9e-738d-4dda-9efc-a5c0f1fef320
# ╟─24e9b099-bd62-43ce-8d08-7d6df3b674e0
# ╠═0dfb6ee7-9b10-4754-b870-14bf3fc2654d
# ╟─07f28faa-415e-4857-8ade-9ca070fba10d
# ╠═f87daf52-e2dc-4350-9240-7adaf36990ce
# ╟─da32ad85-0811-403e-86e4-f672ac2336cf
# ╠═fa968a71-ddc9-4ce1-9ee7-8a39165811d6
# ╟─03cee420-413c-499f-83e4-08339656b8a8
# ╠═d91d6fdb-1aa9-434e-8be1-ff622128110a
