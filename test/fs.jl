@testset "balance fault study" begin
    @testset "7-bus Fault Example" begin
        data = PM.parse_file("../test/data/trans/case5.raw", import_all=true)

        # use flat start
        for (i,b) in data["bus"]
            b["vm"] = 1
            b["va"] = 0
        end

        # neglect line charging
        for (k,br) in data["branch"]
            br["b_fr"] = 0
            br["b_to"] = 0
        end

        data["fault"] = Dict{String, Any}()
        data["fault"]["1"] = Dict("bus" => 2, "r" => 0.0001)
        study_results = FS.run_fault_study(data, ipopt_solver)
        result = study_results["2"][1]
        solution = result["solution"]

        @test result["termination_status"] == LOCALLY_SOLVED

        bus = result["solution"]["bus"]["1"]
        @test isapprox(abs(bus["vr"] + 1im*bus["vi"]), 0.0610503; atol = 1e-3)

        bus = result["solution"]["bus"]["3"]
        @test isapprox(abs(bus["vr"] + 1im*bus["vi"]), 0.0279175; atol = 1e-3)

        bus = result["solution"]["bus"]["4"]
        @test isapprox(abs(bus["vr"] + 1im*bus["vi"]), 0.0529499; atol = 1e-3)

        bus = result["solution"]["bus"]["10"]
        @test isapprox(abs(bus["vr"] + 1im*bus["vi"]), 0.0645659; atol = 1e-3)
    end
end
