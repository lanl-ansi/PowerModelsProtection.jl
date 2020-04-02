@testset "unbalance fault study" begin
    @testset "3-bus case" begin
        result = FS.run_mc_fault_study("../test/data/dist/ut_trans_2w_yy.dss", ipopt_solver)
        @test isapprox(result["1"]["lg"][1]["solution"]["fault"]["currents"]["line.line1"][1], 1381; atol = 10e0)
        @test isapprox(result["1"]["ll"][1]["solution"]["fault"]["currents"]["line.line1"][1], 818; atol = 10e0)
        @test isapprox(result["1"]["3p"][1]["solution"]["fault"]["currents"]["line.line1"][1], 945; atol = 10e0)
    end

    # test compared to results from opendss
    @testset "34-bus fault study from opendss" begin
        @testset "bus 808 all fault test" begin
            data = FS.parse_file("../test/data/dist/ShortCircuitCases/ieee34Mod2_SC_Case_II.dss")
            data["fault"] = Dict{String, Any}()
            data["fault"]["1"] = Dict("type" => "lg", "bus" => "808", "phases" => [1], "gr" => .00001)
            result = FS.run_mc_fault_study(data, ipopt_solver)
            @test result["808"]["lg"][1]["termination_status"] == LOCALLY_SOLVED
            @test isapprox(result["808"]["lg"][1]["solution"]["fault"]["currents"]["line.l3"][1], 431.0; atol = 1e0)

            data["fault"] = Dict{String, Any}()
            data["fault"]["1"] = Dict("type" => "lg", "bus" => "808", "phases" => [3], "gr" => .00001)
            result = FS.run_mc_fault_study(data, ipopt_solver)
            @test result["808"]["lg"][1]["termination_status"] == LOCALLY_SOLVED
            @test isapprox(result["808"]["lg"][1]["solution"]["fault"]["currents"]["line.l3"][3], 430.2; atol = 1e0)

            data = FS.parse_file("../test/data/dist/ShortCircuitCases/ieee34Mod2_SC_Case_II.dss")
            data["fault"] = Dict{String, Any}()
            data["fault"]["1"] = Dict("type" => "lg", "bus" => "856", "phases" => [2], "gr" => .00001)
            result = FS.run_mc_fault_study(data, ipopt_solver)
            @test result["856"]["lg"][1]["termination_status"] == LOCALLY_SOLVED
            @test isapprox(result["856"]["lg"][1]["solution"]["fault"]["currents"]["line.l26b"][2], 173.1; atol = 1e0)

            data["fault"] = Dict{String, Any}()
            data["fault"]["1"] = Dict("type" => "ll", "bus" => "808", "phases" => [1,2], "gr" => .00001)
            result = FS.run_mc_fault_study(data, ipopt_solver)
            @test result["808"]["ll"][1]["termination_status"] == LOCALLY_SOLVED
            # test a phase
            @test isapprox(result["808"]["ll"][1]["solution"]["fault"]["currents"]["line.l3"][1], 412.9; atol = 1e0)
            # test b phase
            @test isapprox(result["808"]["ll"][1]["solution"]["fault"]["currents"]["line.l3"][2], 412.9; atol = 1e0)

            data["fault"] = Dict{String, Any}()
            data["fault"]["1"] = Dict("type" => "llg", "bus" => "808", "phases" => [2,3], "gr" => .00001, "pr" => .00001)
            result = FS.run_mc_fault_study(data, ipopt_solver)
            @test result["808"]["llg"][1]["termination_status"] == LOCALLY_SOLVED
            # test a phase
            @test isapprox(result["808"]["llg"][1]["solution"]["fault"]["currents"]["line.l3"][2], 450.5; atol = 1e0)
            # test b phase
            @test isapprox(result["808"]["llg"][1]["solution"]["fault"]["currents"]["line.l3"][3], 447.7; atol = 1e0)

            data["fault"] = Dict{String, Any}()
            data["fault"]["1"] = Dict("type" => "3p", "bus" => "808", "phases" => [1,2,3], "gr" => .00001)
            result = FS.run_mc_fault_study(data, ipopt_solver)
            @test result["808"]["3p"][1]["termination_status"] == LOCALLY_SOLVED
            # test a phase
            @test isapprox(result["808"]["3p"][1]["solution"]["fault"]["currents"]["line.l3"][1], 474.6; atol = 1e0)
            # test b phase
            @test isapprox(result["808"]["3p"][1]["solution"]["fault"]["currents"]["line.l3"][2], 473.7; atol = 1e0)
            # test c phase
            @test isapprox(result["808"]["3p"][1]["solution"]["fault"]["currents"]["line.l3"][3], 462.5; atol = 1e0)

            data["fault"] = Dict{String, Any}()
            data["fault"]["1"] = Dict("type" => "3pg", "bus" => "808", "phases" => [1,2,3], "gr" => .00001, "pr" => .00001)
            result = FS.run_mc_fault_study(data, ipopt_solver)
            @test result["808"]["3pg"][1]["termination_status"] == LOCALLY_SOLVED
            # test a phase
            @test isapprox(result["808"]["3pg"][1]["solution"]["fault"]["currents"]["line.l3"][1], 471.9; atol = 1e0)
            # test b phase
            @test isapprox(result["808"]["3pg"][1]["solution"]["fault"]["currents"]["line.l3"][2], 473.8; atol = 1e0)
            # test c phase
            @test isapprox(result["808"]["3pg"][1]["solution"]["fault"]["currents"]["line.l3"][3], 465.3; atol = 1e0)
        end
    end
end