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

# ╔═╡ e1650dca-5906-4b9a-bb49-ea9c9673f0f1
ipopt_solver = optimizer_with_attributes(Ipopt.Optimizer, "print_level"=>0, "tol"=>1e-6)

# ╔═╡ 11593aa2-41fa-4472-a827-265450cde01e
case3_balanced_pv = parse_file(joinpath(dirname(pathof(PowerModelsProtection)), "..", "test", "data", "dist", "case3_balanced_pv.dss"))

# ╔═╡ 527a7b43-06a1-488e-8adb-7412b27d6252
begin
	data = deepcopy(case3_balanced_pv)
	add_fault!(data, "testfault", "lg", "loadbus", [1,4], 0.001)
end

# ╔═╡ e7b2c028-04ce-4665-9865-0182ca0fa775
result = solve_mc_fault_study(data, ipopt_solver)

# ╔═╡ 85f02ccb-413a-4773-bb89-1b80847a2e76
result["solution"]["fault"]["testfault"]

# ╔═╡ 92ca69b8-8360-4774-906b-4acf1d041734
result["solution"]["line"]["pv_line"]

# ╔═╡ Cell order:
# ╠═5bd5ba00-b80f-11eb-037d-23da9d05bd8f
# ╠═a15bb2b2-4de9-4278-a66f-5610a389c91a
# ╠═e1650dca-5906-4b9a-bb49-ea9c9673f0f1
# ╠═11593aa2-41fa-4472-a827-265450cde01e
# ╠═527a7b43-06a1-488e-8adb-7412b27d6252
# ╠═e7b2c028-04ce-4665-9865-0182ca0fa775
# ╠═85f02ccb-413a-4773-bb89-1b80847a2e76
# ╠═92ca69b8-8360-4774-906b-4acf1d041734
