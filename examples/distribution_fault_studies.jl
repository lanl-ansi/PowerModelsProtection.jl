### A Pluto.jl notebook ###
# v0.14.5

using Markdown
using InteractiveUtils

# ╔═╡ 5bd5ba00-b80f-11eb-037d-23da9d05bd8f
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

# ╔═╡ a15bb2b2-4de9-4278-a66f-5610a389c91a
begin
	using PowerModelsProtection
	import Ipopt
end

# ╔═╡ 30bdf5a7-c2fb-4e7c-ae7f-2d6d218b48c4
md"""
# PowerModelsProtection.jl: Distribution Fault Studies

In this example we introduce how to perform fault studies on a distribution data set (i.e., using a dss input file).

First we need to create the appropriate versions of PowerModelsProtection and Ipopt.
"""

# ╔═╡ 12d39c49-9663-40f3-9bd4-60f61290ab8c
md"""
## Using PowerModelsProtection

Once the proper environment is populated, import the necessary packages,
"""

# ╔═╡ 73c4b79b-658a-4bbe-ba68-c8c6757a3f95
md"""
and initialize a solver, in this case an Ipopt.Optimizer based solver...
"""

# ╔═╡ e1650dca-5906-4b9a-bb49-ea9c9673f0f1
ipopt_solver = optimizer_with_attributes(Ipopt.Optimizer, "print_level"=>0, "tol"=>1e-6)

# ╔═╡ f18e90af-6794-4b54-b393-766ba07d640d
md"""
## Loading a distribution data set

To load a distribution dataset, we use the `parse_file` function. In this case we are using a 3-bus case with PV, included in our unit-tests.
"""

# ╔═╡ 11593aa2-41fa-4472-a827-265450cde01e
case3_balanced_pv = parse_file(joinpath(dirname(pathof(PowerModelsProtection)), "..", "test", "data", "dist", "case3_balanced_pv.dss"))

# ╔═╡ cd3a4444-a53f-4cd8-98aa-38a2c38b36a0
md"""
## Adding a fault

To add a fault, we may use the `add_fault!` helper function
"""

# ╔═╡ 527a7b43-06a1-488e-8adb-7412b27d6252
begin
	data = deepcopy(case3_balanced_pv)
	add_fault!(data, "testfault", "lg", "loadbus", [1,4], 0.001)
end

# ╔═╡ 02532285-f208-4895-bb59-beca03762ca3
md"""
## Solving a fault study

To solve a fault study on a data structure that already includes one or more faults, use the `solve_mc_fault_study` function
"""

# ╔═╡ e7b2c028-04ce-4665-9865-0182ca0fa775
result = solve_mc_fault_study(data, ipopt_solver)

# ╔═╡ 85f02ccb-413a-4773-bb89-1b80847a2e76
result["solution"]["fault"]["testfault"]

# ╔═╡ 92ca69b8-8360-4774-906b-4acf1d041734
result["solution"]["line"]["pv_line"]

# ╔═╡ e21066af-8c06-47e2-bfb8-363b36241b88
md"""
## Running without a predefined fault

To generate a list of faults for a data structure, use the `build_mc_fault_study` function
"""

# ╔═╡ bb44ea07-d4cd-467f-a67a-974ae3590935
fault_study = build_mc_fault_study(data)

# ╔═╡ 8d5fb92b-ea31-4b8d-a6c9-7806266713b5
md"""
To solve all of these fault studies in series, use the `solve_mc_fault_study` function with the `fault_studies` just generated by `build_mc_fault_study`
"""

# ╔═╡ 0f23609c-c45c-4319-8c99-0c79db3cc7c6
results_fault_study = solve_mc_fault_study(data, fault_study, ipopt_solver)

# ╔═╡ Cell order:
# ╟─30bdf5a7-c2fb-4e7c-ae7f-2d6d218b48c4
# ╠═5bd5ba00-b80f-11eb-037d-23da9d05bd8f
# ╟─12d39c49-9663-40f3-9bd4-60f61290ab8c
# ╠═a15bb2b2-4de9-4278-a66f-5610a389c91a
# ╟─73c4b79b-658a-4bbe-ba68-c8c6757a3f95
# ╠═e1650dca-5906-4b9a-bb49-ea9c9673f0f1
# ╟─f18e90af-6794-4b54-b393-766ba07d640d
# ╠═11593aa2-41fa-4472-a827-265450cde01e
# ╟─cd3a4444-a53f-4cd8-98aa-38a2c38b36a0
# ╠═527a7b43-06a1-488e-8adb-7412b27d6252
# ╟─02532285-f208-4895-bb59-beca03762ca3
# ╠═e7b2c028-04ce-4665-9865-0182ca0fa775
# ╠═85f02ccb-413a-4773-bb89-1b80847a2e76
# ╠═92ca69b8-8360-4774-906b-4acf1d041734
# ╟─e21066af-8c06-47e2-bfb8-363b36241b88
# ╠═bb44ea07-d4cd-467f-a67a-974ae3590935
# ╟─8d5fb92b-ea31-4b8d-a6c9-7806266713b5
# ╠═0f23609c-c45c-4319-8c99-0c79db3cc7c6
