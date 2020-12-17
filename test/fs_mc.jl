@testset "unbalance fault study" begin
    @testset "3-bus case" begin
        # result = FS.run_mc_fault_study("../test/data/dist/case3_balanced_pv.dss", ipopt_solver)
        result = FS.run_mc_fault_study("../test/data/dist/ut_trans_2w_yy_fault_study.dss", ipopt_solver)
        @test result["1"]["lg"][1]["termination_status"] == MOI.LOCALLY_SOLVED
        @test isapprox(result["1"]["lg"][1]["solution"]["fault"]["currents"]["line1"][1], 1381; atol = 10e0)
        @test result["1"]["ll"][1]["termination_status"] == MOI.LOCALLY_SOLVED
        @test isapprox(result["1"]["ll"][1]["solution"]["fault"]["currents"]["line1"][1], 818; atol = 10e0)
        @test result["1"]["3p"][1]["termination_status"] == MOI.LOCALLY_SOLVED
        @test isapprox(result["1"]["3p"][1]["solution"]["fault"]["currents"]["line1"][1], 945; atol = 10e0)
    end

    @testset "3-bus case lg fault" begin
        # result = FS.run_mc_fault_study("../test/data/dist/case3_balanced_pv.dss", ipopt_solver)
        data = FS.parse_file("../test/data/dist/ut_trans_2w_yy_fault_study.dss")
        data["fault"] = Dict{String, Any}()
        data["fault"]["1"] = Dict("type" => "lg", "bus" => "3", "phases" => [1], "gr" => .00001)
        result = FS.run_mc_fault_study(data, ipopt_solver)
        @test result["3"]["lg"][1]["termination_status"] == MOI.LOCALLY_SOLVED
        @test isapprox(result["3"]["lg"][1]["solution"]["fault"]["currents"]["line2"][1], 785; atol = 10e0)
        data["fault"] = Dict{String, Any}()
        data["fault"]["1"] = Dict("type" => "3p", "bus" => "3", "phases" => [1,2,3], "gr" => .005)
        result = FS.run_mc_fault_study(data, ipopt_solver)
        @test result["3"]["3p"][1]["termination_status"] == MOI.LOCALLY_SOLVED
        @test isapprox(result["3"]["3p"][1]["solution"]["fault"]["currents"]["line2"][1], 708; atol = 10e0)
    end


    # test compared to results from opendss
    @testset "34-bus fault study from opendss" begin
        @testset "bus 808 all fault test" begin
            data = FS.parse_file("../test/data/dist/ShortCircuitCases/ieee34Mod2_SC_Case_II.dss")
            data["fault"] = Dict{String, Any}()
            data["fault"]["1"] = Dict("type" => "lg", "bus" => "808", "phases" => [1], "gr" => .00001)
            result = FS.run_mc_fault_study(data, ipopt_solver)
            @test result["808"]["lg"][1]["termination_status"] == MOI.LOCALLY_SOLVED
            @test isapprox(result["808"]["lg"][1]["solution"]["fault"]["currents"]["l3"][1], 431.0; atol = 1e0)

            data["fault"] = Dict{String, Any}()
            data["fault"]["1"] = Dict("type" => "lg", "bus" => "808", "phases" => [3], "gr" => .00001)
            result = FS.run_mc_fault_study(data, ipopt_solver)
            @test result["808"]["lg"][1]["termination_status"] == MOI.LOCALLY_SOLVED
            @test isapprox(result["808"]["lg"][1]["solution"]["fault"]["currents"]["l3"][3], 430.2; atol = 1e0)

            data = FS.parse_file("../test/data/dist/ShortCircuitCases/ieee34Mod2_SC_Case_II.dss")
            data["fault"] = Dict{String, Any}()
            data["fault"]["1"] = Dict("type" => "lg", "bus" => "856", "phases" => [2], "gr" => .00001)
            result = FS.run_mc_fault_study(data, ipopt_solver)
            @test result["856"]["lg"][1]["termination_status"] == MOI.LOCALLY_SOLVED
            @test isapprox(result["856"]["lg"][1]["solution"]["fault"]["currents"]["l26b"][2], 173.1; atol = 1e0)

            data["fault"] = Dict{String, Any}()
            data["fault"]["1"] = Dict("type" => "ll", "bus" => "808", "phases" => [1,2], "gr" => .00001)
            result = FS.run_mc_fault_study(data, ipopt_solver)
            @test result["808"]["ll"][1]["termination_status"] == MOI.LOCALLY_SOLVED
            # test a phase
            @test isapprox(result["808"]["ll"][1]["solution"]["fault"]["currents"]["l3"][1], 412.9; atol = 1e0)
            # test b phase
            @test isapprox(result["808"]["ll"][1]["solution"]["fault"]["currents"]["l3"][2], 412.9; atol = 1e0)

            data["fault"] = Dict{String, Any}()
            data["fault"]["1"] = Dict("type" => "llg", "bus" => "808", "phases" => [2,3], "gr" => .00001, "pr" => .00001)
            result = FS.run_mc_fault_study(data, ipopt_solver)
            @test result["808"]["llg"][1]["termination_status"] == MOI.LOCALLY_SOLVED
            # test a phase
            @test isapprox(result["808"]["llg"][1]["solution"]["fault"]["currents"]["l3"][2], 450.5; atol = 1e0)
            # test b phase
            @test isapprox(result["808"]["llg"][1]["solution"]["fault"]["currents"]["l3"][3], 447.7; atol = 1e0)

            data["fault"] = Dict{String, Any}()
            data["fault"]["1"] = Dict("type" => "3p", "bus" => "808", "phases" => [1,2,3], "gr" => .00001)
            result = FS.run_mc_fault_study(data, ipopt_solver)
            @test result["808"]["3p"][1]["termination_status"] == MOI.LOCALLY_SOLVED
            # test a phase
            @test isapprox(result["808"]["3p"][1]["solution"]["fault"]["currents"]["l3"][1], 474.6; atol = 1e0)
            # test b phase
            @test isapprox(result["808"]["3p"][1]["solution"]["fault"]["currents"]["l3"][2], 473.7; atol = 1e0)
            # test c phase
            @test isapprox(result["808"]["3p"][1]["solution"]["fault"]["currents"]["l3"][3], 462.5; atol = 1e0)

            data["fault"] = Dict{String, Any}()
            data["fault"]["1"] = Dict("type" => "3pg", "bus" => "808", "phases" => [1,2,3], "gr" => .00001, "pr" => .00001)
            result = FS.run_mc_fault_study(data, ipopt_solver)
            @test result["808"]["3pg"][1]["termination_status"] == MOI.LOCALLY_SOLVED
            # test a phase
            @test isapprox(result["808"]["3pg"][1]["solution"]["fault"]["currents"]["l3"][1], 471.9; atol = 1e0)
            # test b phase
            @test isapprox(result["808"]["3pg"][1]["solution"]["fault"]["currents"]["l3"][2], 473.8; atol = 1e0)
            # test c phase
            @test isapprox(result["808"]["3pg"][1]["solution"]["fault"]["currents"]["l3"][3], 465.3; atol = 1e0)
        end
    end

    @testset "3-bus pv fault test" begin
        data = FS.parse_file("../test/data/dist/case3_balanced_pv.dss")
        data["fault"] = Dict{String, Any}()
        data["fault"]["1"] = Dict("type" => "3p", "bus" => "loadbus", "phases" => [1,2,3], "gr" => 0.0005)
        result = FS.run_mc_fault_study(data, ipopt_solver)
        @test result["loadbus"]["3p"][1]["termination_status"] == MOI.LOCALLY_SOLVED
        @test isapprox(result["loadbus"]["3p"][1]["solution"]["fault"]["currents"]["pv_line"][1], 39.686; atol = 1e0)
        data = FS.parse_file("../test/data/dist/case3_balanced_pv.dss")
        data["fault"] = Dict{String, Any}()
        data["fault"]["1"] = Dict("type" => "lg", "bus" => "loadbus", "phases" => [2], "gr" => 0.0005)
        result = FS.run_mc_fault_study(data, ipopt_solver)
        @test result["loadbus"]["lg"][1]["termination_status"] == MOI.LOCALLY_SOLVED
        @test isapprox(result["loadbus"]["lg"][1]["solution"]["fault"]["currents"]["pv_line"][1], 38.978; atol = 1e0)
        data = FS.parse_file("../test/data/dist/case3_balanced_pv.dss")
        data["fault"] = Dict{String, Any}()
        data["fault"]["1"] = Dict("type" => "ll", "bus" => "loadbus", "phases" => [1,2], "gr" => 0.0005)
        result = FS.run_mc_fault_study(data, ipopt_solver)
        @test result["loadbus"]["ll"][1]["termination_status"] == MOI.LOCALLY_SOLVED
        @test isapprox(result["loadbus"]["ll"][1]["solution"]["fault"]["currents"]["pv_line"][1], 39.693; atol = 1e0)
        # test the current limit bu placing large load to force off limits
        data = FS.parse_file("../test/data/dist/case3_balanced_pv.dss")
        data["fault"] = Dict{String, Any}()
        data["fault"]["1"] = Dict("type" => "3p", "bus" => "loadbus", "phases" => [1,2,3], "gr" => 500)
        result = FS.run_mc_fault_study(data, ipopt_solver)
        @test result["loadbus"]["3p"][1]["termination_status"] == MOI.LOCALLY_SOLVED
        @test isapprox(result["loadbus"]["3p"][1]["solution"]["fault"]["currents"]["pv_line"][1], 35.523; atol = 1e0)
    end
    
    @testset "3-bus pv fault test" begin
        data = FS.parse_file("../test/data/dist/case3_balanced_pv.dss")
        data["fault"] = Dict{String, Any}()
        data["fault"]["1"] = Dict("type" => "3p", "bus" => "pv_bus", "phases" => [1,2,3], "gr" => 0.0005)
        result = FS.run_mc_fault_study(data, ipopt_solver)
        @test result["pv_bus"]["3p"][1]["termination_status"] == MOI.LOCALLY_SOLVED
        data = FS.parse_file("../test/data/dist/case3_balanced_pv.dss")
        data["fault"] = Dict{String, Any}()
        data["fault"]["1"] = Dict("type" => "lg", "bus" => "pv_bus", "phases" => [1], "gr" => 0.0005)
        result = FS.run_mc_fault_study(data, ipopt_solver)
        @test result["pv_bus"]["lg"][1]["termination_status"] == MOI.LOCALLY_SOLVED
        data = FS.parse_file("../test/data/dist/case3_balanced_pv.dss")
        data["fault"] = Dict{String, Any}()
        data["fault"]["1"] = Dict("type" => "ll", "bus" => "pv_bus", "phases" => [1,2], "gr" => 0.0005)
        result = FS.run_mc_fault_study(data, ipopt_solver)
        @test result["pv_bus"]["ll"][1]["termination_status"] == MOI.LOCALLY_SOLVED
    end

    @testset "3-bus grid forming pv fault test" begin
        data = FS.parse_file("../test/data/dist/case3_balanced_pv_gridforming.dss")
        data["fault"] = Dict{String, Any}()
        data["fault"]["1"] = Dict("type" => "3p", "bus" => "loadbus", "phases" => [1,2,3], "gr" => .500)
        data["microgrid"] = true
        for (i, gen) in data["gen"]
            gen["name"] == "pv1" ? gen["grid_forming"] = true : nothing 
        end
        result = FS.run_mc_fault_study(data, ipopt_solver)
        @test result["loadbus"]["3p"][1]["termination_status"] == MOI.LOCALLY_SOLVED
        v_r = result["loadbus"]["3p"][1]["solution"]["bus"]["pv_bus"]["vr"]
        v_i = result["loadbus"]["3p"][1]["solution"]["bus"]["pv_bus"]["vi"]
        v = v_r + 1im*v_i
        @test isapprox(abs(v[1]), .11085; atol = 0.01)

        data = FS.parse_file("../test/data/dist/case3_balanced_pv_gridforming.dss")
        data["fault"] = Dict{String, Any}()
        data["fault"]["1"] = Dict("type" => "3p", "bus" => "loadbus", "phases" => [1,2,3], "gr" => 0.0005)
        data["microgrid"] = true
        for (i, gen) in data["gen"]
            gen["name"] == "pv1" ? gen["grid_forming"] = true : nothing 
        end
        result = FS.run_mc_fault_study(data, ipopt_solver)
        @test result["loadbus"]["3p"][1]["termination_status"] == MOI.LOCALLY_SOLVED
        v_r = result["loadbus"]["3p"][1]["solution"]["bus"]["pv_bus"]["vr"]
        v_i = result["loadbus"]["3p"][1]["solution"]["bus"]["pv_bus"]["vi"]
        v = v_r + 1im*v_i
        @test isapprox(abs(v[1]), 0.0277888; atol = 0.001)

        data = FS.parse_file("../test/data/dist/case3_balanced_pv_gridforming.dss")
        data["fault"] = Dict{String, Any}()
        data["fault"]["1"] = Dict("type" => "3pg", "bus" => "loadbus", "phases" => [1,2,3], "gr" => 0.0005, "pr" => 0.0005)
        data["microgrid"] = true
        for (i, gen) in data["gen"]
            gen["name"] == "pv1" ? gen["grid_forming"] = true : nothing 
        end
        result = FS.run_mc_fault_study(data, ipopt_solver)
        @test result["loadbus"]["3pg"][1]["termination_status"] == MOI.LOCALLY_SOLVED
        v_r = result["loadbus"]["3pg"][1]["solution"]["bus"]["pv_bus"]["vr"]
        v_i = result["loadbus"]["3pg"][1]["solution"]["bus"]["pv_bus"]["vi"]
        v = v_r + 1im*v_i
        @test isapprox(abs(v[1]), 0.0279377; atol = 0.001)

        data = FS.parse_file("../test/data/dist/case3_balanced_pv_gridforming.dss")
        data["fault"] = Dict{String, Any}()
        data["fault"]["1"] = Dict("type" => "ll", "bus" => "loadbus", "phases" => [1,2], "gr" => 0.0005)
        data["microgrid"] = true
        for (i, gen) in data["gen"]
            gen["name"] == "pv1" ? gen["grid_forming"] = true : nothing 
        end
        result = FS.run_mc_fault_study(data, ipopt_solver)
        @test result["loadbus"]["ll"][1]["termination_status"] == MOI.LOCALLY_SOLVED
        v_r = result["loadbus"]["ll"][1]["solution"]["bus"]["pv_bus"]["vr"]
        v_i = result["loadbus"]["ll"][1]["solution"]["bus"]["pv_bus"]["vi"]
        v = v_r + 1im*v_i
        @test isapprox(abs(v[1]), 0.03333; atol = 0.001)
        @test isapprox(abs(v[2]), 0.03091179; atol = 0.001)
        @test isapprox(abs(v[3]), 1.0; atol = 0.001)

        data = FS.parse_file("../test/data/dist/case3_balanced_pv_gridforming.dss")
        for (i, gen) in data["gen"]
            gen["name"] == "pv1" ? gen["grid_forming"] = true : nothing 
        end
        data["fault"] = Dict{String, Any}()
        data["fault"]["1"] = Dict("type" => "llg", "bus" => "loadbus", "phases" => [1,2], "gr" => 0.0005, "pr" => 0.0005)
        data["microgrid"] = true
        result = FS.run_mc_fault_study(data, ipopt_solver)
        @test result["loadbus"]["llg"][1]["termination_status"] == MOI.LOCALLY_SOLVED
        v_r = result["loadbus"]["llg"][1]["solution"]["bus"]["pv_bus"]["vr"]
        v_i = result["loadbus"]["llg"][1]["solution"]["bus"]["pv_bus"]["vi"]
        v = v_r + 1im*v_i
        @test isapprox(abs(v[1]), 0.0313028; atol = 0.001)
        @test isapprox(abs(v[2]), 0.0313028; atol = 0.001)
        @test isapprox(abs(v[3]), 1.0; atol = 0.001)

        data = FS.parse_file("../test/data/dist/case3_balanced_pv_gridforming.dss")
        data["fault"] = Dict{String, Any}()
        data["fault"]["1"] = Dict("type" => "lg", "bus" => "loadbus", "phases" => [1], "gr" => 0.0005)
        data["microgrid"] = true
        for (i, gen) in data["gen"]
            gen["name"] == "pv1" ? gen["grid_forming"] = true : nothing 
        end
        result = FS.run_mc_fault_study(data, ipopt_solver)
        @test result["loadbus"]["lg"][1]["termination_status"] == MOI.LOCALLY_SOLVED
        v_r = result["loadbus"]["lg"][1]["solution"]["bus"]["pv_bus"]["vr"]
        v_i = result["loadbus"]["lg"][1]["solution"]["bus"]["pv_bus"]["vi"]
        v = v_r + 1im*v_i
        @test isapprox(abs(v[1]), 0.0464314; atol = 0.001)
        @test isapprox(abs(v[2]), 1.0; atol = 0.001)
    end
    @testset "2 pq inverter pv fault test" begin
        data = FS.parse_file("../test/data/dist/case3_balanced_pv_2.dss")
        data["fault"] = Dict{String, Any}()
        data["fault"]["1"] = Dict("type" => "lg", "bus" => "loadbus", "phases" => [1], "gr" => 0.0005)
        result = FS.run_mc_fault_study(data, ipopt_solver)
        @test result["loadbus"]["lg"][1]["termination_status"] == MOI.LOCALLY_SOLVED
        data = FS.parse_file("../test/data/dist/case3_balanced_pv_2.dss")
        data["fault"] = Dict{String, Any}()
        data["fault"]["1"] = Dict("type" => "ll", "bus" => "loadbus", "phases" => [1,2], "gr" => 0.0005)
        result = FS.run_mc_fault_study(data, ipopt_solver)
        @test result["loadbus"]["ll"][1]["termination_status"] == MOI.LOCALLY_SOLVED
        data = FS.parse_file("../test/data/dist/case3_balanced_pv_2.dss")
        data["fault"] = Dict{String, Any}()
        data["fault"]["1"] = Dict("type" => "3p", "bus" => "loadbus", "phases" => [1,2,3], "gr" => 0.0005)
        result = FS.run_mc_fault_study(data, ipopt_solver)
        @test result["loadbus"]["3p"][1]["termination_status"] == MOI.LOCALLY_SOLVED
        data = FS.parse_file("../test/data/dist/case3_balanced_pv_2.dss")
        data["fault"] = Dict{String, Any}()
        data["fault"]["1"] = Dict("type" => "lg", "bus" => "pv_bus", "phases" => [1], "gr" => 0.0005)
        result = FS.run_mc_fault_study(data, ipopt_solver)
        @test result["pv_bus"]["lg"][1]["termination_status"] == MOI.LOCALLY_SOLVED
    end
    @testset "2 pq inverter grid-forming pv fault test" begin
        data = FS.parse_file("../test/data/dist/case3_balanced_pv_2_gridforming.dss")
        # TODO: Do I need to explicitly set the inverters as grid-forming?
        data["branch"]["4"]["br_status"] = 0
        data["fault"] = Dict{String, Any}()
        data["fault"]["1"] = Dict("type" => "lg", "bus" => "loadbus", "phases" => [1], "gr" => 0.0005)
        result = FS.run_mc_fault_study(data, ipopt_solver)
        @test result["loadbus"]["lg"][1]["termination_status"] == MOI.LOCALLY_SOLVED
        v_r = result["loadbus"]["lg"][1]["solution"]["bus"]["pv_bus"]["vr"]
        v_i = result["loadbus"]["lg"][1]["solution"]["bus"]["pv_bus"]["vi"]
        @test isapprox(abs(v_r[1]), 0.5484553319545448; atol = 0.001)
        @test isapprox(abs(v_i[1]), 0.0029269286321313317; atol = 0.001)
        @test isapprox(abs(v_r[2]), 0.6828942947492501; atol = 0.001)
        @test isapprox(abs(v_i[2]), 0.8827951107227415; atol = 0.001)
    end 
    @testset "2 islands pq inverter grid-forming pv fault test" begin
        data = FS.parse_file("../test/data/dist/case3_balanced_pv_2_islands_gridforming.dss")
        for (i, gen) in data["gen"]
            gen["name"] == "pv1" ? gen["grid_forming"] = true : nothing 
            gen["name"] == "pv2" ? gen["grid_forming"] = true : nothing 
        end        
        data["branch"]["2"]["br_status"] = 0
        data["branch"]["5"]["br_status"] = 0        
        data["fault"] = Dict{String, Any}()
        data["fault"]["1"] = Dict("type" => "lg", "bus" => "loadbus", "phases" => [1], "gr" => 0.0005)
        result = FS.run_mc_fault_study(data, ipopt_solver)
        @test result["loadbus"]["lg"][1]["termination_status"] == MOI.LOCALLY_SOLVED

        v_r = result["loadbus"]["lg"][1]["solution"]["bus"]["pv1_bus"]["vr"]
        v_i = result["loadbus"]["lg"][1]["solution"]["bus"]["pv1_bus"]["vi"]
        @test isapprox(v_r[1], 0.0222495; atol = 0.001)
        @test isapprox(v_i[1], -0.0013008; atol = 0.001)
        @test isapprox(v_r[2], -0.500003; atol = 0.001)
        @test isapprox(v_i[2], -0.866026; atol = 0.001)

        v_r = result["loadbus"]["lg"][1]["solution"]["bus"]["pv2_bus"]["vr"]
        v_i = result["loadbus"]["lg"][1]["solution"]["bus"]["pv2_bus"]["vi"]
        @test isapprox(v_r[1], 1.0; atol = 0.001)
        @test isapprox(v_i[1], -2.04801e-6; atol = 0.001)
        @test isapprox(v_r[2], -0.500003; atol = 0.001)
        @test isapprox(v_i[2], -0.866026; atol = 0.001)        
    end 
end
