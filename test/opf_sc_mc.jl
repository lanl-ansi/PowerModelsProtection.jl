@testset "Unbalanced opf and fault study" begin
    cases = Dict()
    cases["case3_unbalanced.dss"] = parse_file("../test/data/dist/case3_unbalanced.dss")
    

    @testset "test simple case" begin
        data = deepcopy(cases["case3_unbalanced.dss"])
        mn_data = PMD.make_multinetwork(data)
        mn_data["nw"]["1"] = deepcopy(mn_data["nw"]["0"])
        mn_data["mn_lookup"]["1"] = 1
        add_fault!(mn_data["nw"]["1"], "1", "3p", "loadbus", [1,2,3], 0.005)
        sol = solve_mc_opf_fault_study(mn_data, ipopt_solver)
    end
end
