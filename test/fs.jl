@testset "balance fault study" begin
    @testset "7-bus Fault Example" begin
        data = FS.parse_file("../test/data/trans/B7FaultExample.raw")

        # use flat start
        for (i,b) in data["bus"]
            b["vm"] = 1
            b["va"] = 0
        end

        # neglect line charging
        for (k,br) in net["branch"]
            br["b_fr"] = 0
            br["b_to"] = 0
        end        

        data["fault"] = Dict{String, Any}()
        data["fault"]["1"] = Dict("bus" => "3", "gf" => 10000)
        study_results = FS.run_fault_study(data, ipopt_solver)
        result = study_results["1"]
        solution = result["solution"]

        @test result["termination_status"] == PMs.LOCALLY_SOLVED

        bus = result["solution"]["bus"]["1"]
        @test isapprox(abs(bus["vr"] + 1im*bus["vi"]), 0.201545; atol = 1e-5)
        
        bus = result["solution"]["bus"]["2"]
        @test isapprox(abs(bus["vr"] + 1im*bus["vi"]), 0.200887; atol = 1e-5)
        
        bus = result["solution"]["bus"]["3"]
        @test isapprox(abs(bus["vr"] + 1im*bus["vi"]), 0.000405; atol = 1e-5)        
        
        bus = result["solution"]["bus"]["7"]
        @test isapprox(abs(bus["vr"] + 1im*bus["vi"]), 0.259611; atol = 1e-5)        
    end 
end 