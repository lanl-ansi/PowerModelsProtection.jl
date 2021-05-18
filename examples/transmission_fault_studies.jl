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

# ╔═╡ 74ec696c-0f33-4258-875e-b2f5908c0b72
ipopt_solver = optimizer_with_attributes(Ipopt.Optimizer, "print_level"=>0, "tol"=>1e-6)

# ╔═╡ e5d332e0-3037-44e7-b7db-b572f5c13fae
case5_fault = parse_file(joinpath(dirname(pathof(PowerModelsProtection)), "..", "test", "data", "trans", "case5_fault.m"))

# ╔═╡ 07f28faa-415e-4857-8ade-9ca070fba10d


# ╔═╡ Cell order:
# ╠═79a625ce-b80f-11eb-1c52-0dbc35b93173
# ╠═3f140cc1-0192-446b-8841-4c3d58d038f1
# ╠═74ec696c-0f33-4258-875e-b2f5908c0b72
# ╠═e5d332e0-3037-44e7-b7db-b572f5c13fae
# ╠═07f28faa-415e-4857-8ade-9ca070fba10d
