@testset "unbalance fault study" begin
    # @testset "3-bus case" begin
    #     # result = FS.run_mc_fault_study("../test/data/dist/13Bus/IEEE13NodeCkt.dss", ipopt_solver)
    #     # result = FS.run_mc_fault_study("../test/data/dist/ut_trans_2w_yy.dss", ipopt_solver)
    #     result = FS.run_mc_fault_study("../test/data/dist/34Bus/Run_IEEE34Mod1.dss", ipopt_solver)
    # end 
    # test compared to results from opendss 
    @testset "34-bus fault study from opendss" begin
        @testset "bus 808 all fault test" begin
            data = FS.parse_file("../test/data/dist/ShortCircuitCases/ieee34Mod2_SC_Case_II.dss")
            data["fault"] = Dict{String, Any}()
            data["fault"]["1"] = Dict("type" => "lg", "bus" => "808", "phases" => [1], "gr" => .00001)
            result = FS.run_mc_fault_study(data, ipopt_solver)
            @test result["808"]["lg"][1]["termination_status"] == PMs.LOCALLY_SOLVED
            @test isapprox(result["808"]["lg"][1]["solution"]["fault"]["currents"]["line.l3"][1], 431.0; atol = 1e0)

            data["fault"] = Dict{String, Any}()
            data["fault"]["1"] = Dict("type" => "lg", "bus" => "808", "phases" => [3], "gr" => .00001)
            result = FS.run_mc_fault_study(data, ipopt_solver)
            @test result["808"]["lg"][1]["termination_status"] == PMs.LOCALLY_SOLVED
            @test isapprox(result["808"]["lg"][1]["solution"]["fault"]["currents"]["line.l3"][3], 430.2; atol = 1e0)

            data["fault"] = Dict{String, Any}()
            data["fault"]["1"] = Dict("type" => "ll", "bus" => "808", "phases" => [1,2], "gr" => .00001)
            result = FS.run_mc_fault_study(data, ipopt_solver)
            @test result["808"]["ll"][1]["termination_status"] == PMs.LOCALLY_SOLVED
            # test a phase 
            @test isapprox(result["808"]["ll"][1]["solution"]["fault"]["currents"]["line.l3"][1], 412.9; atol = 1e0)
            # test b phase 
            @test isapprox(result["808"]["ll"][1]["solution"]["fault"]["currents"]["line.l3"][2], 412.9; atol = 1e0)

            data["fault"] = Dict{String, Any}()
            data["fault"]["1"] = Dict("type" => "3p", "bus" => "808", "phases" => [1,2,3], "gr" => .00001)
            result = FS.run_mc_fault_study(data, ipopt_solver)
            @test result["808"]["3p"][1]["termination_status"] == PMs.LOCALLY_SOLVED
            # test a phase 
            @test isapprox(result["808"]["3p"][1]["solution"]["fault"]["currents"]["line.l3"][1], 474.6; atol = 1e0)
            # test b phase 
            @test isapprox(result["808"]["3p"][1]["solution"]["fault"]["currents"]["line.l3"][2], 473.7; atol = 1e0)
            # test c phase 
            @test isapprox(result["808"]["3p"][1]["solution"]["fault"]["currents"]["line.l3"][3], 462.5; atol = 1e0)

            data["fault"] = Dict{String, Any}()
            data["fault"]["1"] = Dict("type" => "3pg", "bus" => "808", "phases" => [1,2,3], "gr" => .00001, "pr" => .00001)
            result = FS.run_mc_fault_study(data, ipopt_solver)
            @test result["808"]["3pg"][1]["termination_status"] == PMs.LOCALLY_SOLVED
            # test a phase 
            @test isapprox(result["808"]["3pg"][1]["solution"]["fault"]["currents"]["line.l3"][1], 471.9; atol = 1e0)
            # test b phase 
            @test isapprox(result["808"]["3pg"][1]["solution"]["fault"]["currents"]["line.l3"][2], 473.8; atol = 1e0)
            # test c phase 
            @test isapprox(result["808"]["3pg"][1]["solution"]["fault"]["currents"]["line.l3"][3], 465.3; atol = 1e0)


            
        end
        
        
        # "Line.L3"


        # data["fault"]["2"] = Dict("type" => "3pg", "bus" => "808", "phases" => [1,2,3], "gr" => .00001, "pr" => .00001)
        
        # println(keys(result))
        # println(keys(result["808"]))
    end 
    # pmd = PMD.parse_file("../test/data/dist/ShortCircuitCases/ieee34Mod2_SC_Case_II.dss")
    # sol = PMD.run_mc_pf_iv(pmd, PMs.IVRPowerModel, ipopt_solver)
    # println(sol)
end 