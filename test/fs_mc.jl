@testset "Unbalanced fault study" begin
    ut_trans_2w_yy_fault_study = FS.parse_file("../test/data/dist/ut_trans_2w_yy_fault_study.dss")
    case3_balanced_pv = FS.parse_file("../test/data/dist/case3_balanced_pv.dss")
    case3_balanced_pv_grid_forming = FS.parse_file("../test/data/dist/case3_balanced_pv_grid_forming.dss")
    case3_balanced_multi_pv_grid_following = FS.parse_file("../test/data/dist/case3_balanced_multi_pv_grid_following.dss")
    case3_balanced_parallel_pv_grid_following = FS.parse_file("../test/data/dist/case3_balanced_parallel_pv_grid_following.dss")
    case3_balanced_single_phase = FS.parse_file("../test/data/dist/case3_balanced_single_phase.dss")


    @testset "ut_trans_2w_yy_fault_study test fault study" begin
        sol = FS.run_mc_fault_study(ut_trans_2w_yy_fault_study, ipopt_solver)
        @test sol["1"]["lg"]["1"]["termination_status"] == MOI.LOCALLY_SOLVED
        @test calulate_error_percentage(sol["1"]["lg"]["1"]["solution"]["fault"]["currents"]["line1"][1], 1381.0) < .05
        @test sol["1"]["ll"]["1"]["termination_status"] == MOI.LOCALLY_SOLVED
        @test calulate_error_percentage(sol["1"]["ll"]["1"]["solution"]["fault"]["currents"]["line1"][1], 818.0) < .05
        @test sol["1"]["3p"]["1"]["termination_status"] == MOI.LOCALLY_SOLVED
        @test calulate_error_percentage(sol["1"]["3p"]["1"]["solution"]["fault"]["currents"]["line1"][1], 945.0) < .05
    end

    @testset "ut_trans_2w_yy_fault_study line to ground fault" begin
        data = deepcopy(ut_trans_2w_yy_fault_study)
        data["fault"] = Dict{String,Any}()
        data["fault"]["1"] = Dict("type" => "lg", "bus" => "3", "phases" => [1], "gr" => .00001)
        sol = FS.run_mc_fault_study(data, ipopt_solver)
        @test sol["3"]["lg"]["1"]["termination_status"] == MOI.LOCALLY_SOLVED
        @test calulate_error_percentage(sol["3"]["lg"]["1"]["solution"]["fault"]["currents"]["line2"][1], 785.0) < .05
    end

    @testset "ut_trans_2w_yy_fault_study 3-phase fault" begin
        data = deepcopy(ut_trans_2w_yy_fault_study)
        data["fault"] = Dict{String,Any}()
        data["fault"]["1"] = Dict("type" => "3p", "bus" => "3", "phases" => [1,2,3], "gr" => .005)
        sol = FS.run_mc_fault_study(data, ipopt_solver)
        @test sol["3"]["3p"]["1"]["termination_status"] == MOI.LOCALLY_SOLVED
        @test calulate_error_percentage(sol["3"]["3p"]["1"]["solution"]["fault"]["currents"]["line2"][1], 708.0) < .05
    end

    @testset "3-bus pv fault test single faults" begin
        data = deepcopy(case3_balanced_pv)
        data["fault"] = Dict{String,Any}()
        data["fault"]["1"] = Dict("type" => "3p", "bus" => "loadbus", "phases" => [1,2,3], "gr" => 0.005)
        sol = FS.run_mc_fault_study(data, ipopt_solver)
        @test sol["loadbus"]["3p"]["1"]["termination_status"] == MOI.LOCALLY_SOLVED
        @test calulate_error_percentage(sol["loadbus"]["3p"]["1"]["solution"]["fault"]["currents"]["pv_line"][1], 39.686) < .05
        data = deepcopy(case3_balanced_pv)
        data["fault"] = Dict{String,Any}()
        data["fault"]["1"] = Dict("type" => "lg", "bus" => "loadbus", "phases" => [2], "gr" => 0.005)
        sol = FS.run_mc_fault_study(data, ipopt_solver)
        @test sol["loadbus"]["lg"]["1"]["termination_status"] == MOI.LOCALLY_SOLVED
        @test calulate_error_percentage(sol["loadbus"]["lg"]["1"]["solution"]["fault"]["currents"]["pv_line"][1], 38.978) < .05
        data = deepcopy(case3_balanced_pv)
        data["fault"] = Dict{String,Any}()
        data["fault"]["1"] = Dict("type" => "ll", "bus" => "loadbus", "phases" => [1,2], "gr" => 0.005)
        sol = FS.run_mc_fault_study(data, ipopt_solver)
        @test sol["loadbus"]["ll"]["1"]["termination_status"] == MOI.LOCALLY_SOLVED
        @test calulate_error_percentage(sol["loadbus"]["ll"]["1"]["solution"]["fault"]["currents"]["pv_line"][1], 39.693) < .05
        # test the current limit bu placing large load to force off limits
        data = deepcopy(case3_balanced_pv)
        data["fault"] = Dict{String,Any}()
        data["fault"]["1"] = Dict("type" => "3p", "bus" => "loadbus", "phases" => [1,2,3], "gr" => 500)
        sol = FS.run_mc_fault_study(data, ipopt_solver)
        @test sol["loadbus"]["3p"]["1"]["termination_status"] == MOI.LOCALLY_SOLVED
        @test calulate_error_percentage(sol["loadbus"]["3p"]["1"]["solution"]["fault"]["currents"]["pv_line"][1], 35.523) < .05
    end

    @testset "c3-bus multiple pv grid_following fault test" begin
        data = deepcopy(case3_balanced_multi_pv_grid_following)
        data["fault"] = Dict{String,Any}()
        data["fault"]["1"] = Dict("type" => "lg", "bus" => "loadbus", "phases" => [1], "gr" => 0.0005)
        sol = FS.run_mc_fault_study(data, ipopt_solver)
        @test sol["loadbus"]["lg"]["1"]["termination_status"] == MOI.LOCALLY_SOLVED
        data = deepcopy(case3_balanced_multi_pv_grid_following)
        data["fault"] = Dict{String,Any}()
        data["fault"]["1"] = Dict("type" => "ll", "bus" => "loadbus", "phases" => [1,2], "gr" => 0.0005)
        sol = FS.run_mc_fault_study(data, ipopt_solver)
        @test sol["loadbus"]["ll"]["1"]["termination_status"] == MOI.LOCALLY_SOLVED
        data = deepcopy(case3_balanced_multi_pv_grid_following)
        data["fault"] = Dict{String,Any}()
        data["fault"]["1"] = Dict("type" => "3p", "bus" => "loadbus", "phases" => [1,2,3], "gr" => 0.0005)
        sol = FS.run_mc_fault_study(data, ipopt_solver)
        @test sol["loadbus"]["3p"]["1"]["termination_status"] == MOI.LOCALLY_SOLVED
        data = deepcopy(case3_balanced_multi_pv_grid_following)
        data["fault"] = Dict{String,Any}()
        data["fault"]["1"] = Dict("type" => "lg", "bus" => "pv_bus", "phases" => [1], "gr" => 0.0005)
        sol = FS.run_mc_fault_study(data, ipopt_solver)
        @test sol["pv_bus"]["lg"]["1"]["termination_status"] == MOI.LOCALLY_SOLVED
    end

    @testset "c3-bus parallel pv grid_following fault test" begin
        data = deepcopy(case3_balanced_parallel_pv_grid_following)
        data["fault"] = Dict{String,Any}()
        data["fault"]["1"] = Dict("type" => "lg", "bus" => "loadbus", "phases" => [1], "gr" => 0.0005)
        sol = FS.run_mc_fault_study(data, ipopt_solver)
        @test sol["loadbus"]["lg"]["1"]["termination_status"] == MOI.LOCALLY_SOLVED
        data = deepcopy(case3_balanced_multi_pv_grid_following)
        data["fault"] = Dict{String,Any}()
        data["fault"]["1"] = Dict("type" => "ll", "bus" => "loadbus", "phases" => [1,2], "gr" => 0.0005)
        sol = FS.run_mc_fault_study(data, ipopt_solver)
        @test sol["loadbus"]["ll"]["1"]["termination_status"] == MOI.LOCALLY_SOLVED
        data = deepcopy(case3_balanced_multi_pv_grid_following)
        data["fault"] = Dict{String,Any}()
        data["fault"]["1"] = Dict("type" => "3p", "bus" => "loadbus", "phases" => [1,2,3], "gr" => 0.0005)
        sol = FS.run_mc_fault_study(data, ipopt_solver)
        @test sol["loadbus"]["3p"]["1"]["termination_status"] == MOI.LOCALLY_SOLVED
        data = deepcopy(case3_balanced_multi_pv_grid_following)
        data["fault"] = Dict{String,Any}()
        data["fault"]["1"] = Dict("type" => "lg", "bus" => "pv_bus", "phases" => [1], "gr" => 0.0005)
        sol = FS.run_mc_fault_study(data, ipopt_solver)
        @test sol["pv_bus"]["lg"]["1"]["termination_status"] == MOI.LOCALLY_SOLVED
    end

    @testset "c3-bus pv grid_forming fault test island" begin
        case3_balanced_pv_grid_forming["gen"]["1"]["grid_forming"] = true
        case3_balanced_pv_grid_forming["bus"]["4"]["bus_type"] = 5
        case3_balanced_pv_grid_forming["branch"]["3"]["br_status"] = 0
        data = deepcopy(case3_balanced_pv_grid_forming)
        data["fault"] = Dict{String,Any}()
        data["fault"]["1"] = Dict("type" => "lg", "bus" => "loadbus", "phases" => [1], "gr" => 0.005)
        sol = FS.run_mc_fault_study(data, ipopt_solver)
        @test sol["loadbus"]["lg"]["1"]["termination_status"] == MOI.LOCALLY_SOLVED
        data = deepcopy(case3_balanced_multi_pv_grid_following)
        data["fault"] = Dict{String,Any}()
        data["fault"]["1"] = Dict("type" => "ll", "bus" => "loadbus", "phases" => [1,2], "gr" => 0.005)
        sol = FS.run_mc_fault_study(data, ipopt_solver)
        @test sol["loadbus"]["ll"]["1"]["termination_status"] == MOI.LOCALLY_SOLVED
        data = deepcopy(case3_balanced_multi_pv_grid_following)
        data["fault"] = Dict{String,Any}()
        data["fault"]["1"] = Dict("type" => "3p", "bus" => "loadbus", "phases" => [1,2,3], "gr" => 0.005)
        sol = FS.run_mc_fault_study(data, ipopt_solver)
        @test sol["loadbus"]["3p"]["1"]["termination_status"] == MOI.LOCALLY_SOLVED
        data = deepcopy(case3_balanced_multi_pv_grid_following)
        data["fault"] = Dict{String,Any}()
        data["fault"]["1"] = Dict("type" => "lg", "bus" => "pv_bus", "phases" => [1], "gr" => 0.005)
        sol = FS.run_mc_fault_study(data, ipopt_solver)
        @test sol["pv_bus"]["lg"]["1"]["termination_status"] == MOI.LOCALLY_SOLVED
    end

    @testset "c3-bus single phase test" begin
        case3_balanced_single_phase["gen"]["1"]["grid_forming"] = true
        case3_balanced_single_phase["bus"]["4"]["bus_type"] = 5
        data = deepcopy(case3_balanced_single_phase)
        data["fault"] = Dict{String,Any}()
        data["fault"]["1"] = Dict("type" => "lg", "bus" => "loadbus", "phases" => [1], "gr" => 0.005)
        sol = FS.run_mc_fault_study(data, ipopt_solver)
        @test sol["loadbus"]["lg"]["1"]["termination_status"] == MOI.LOCALLY_SOLVED
        @test calulate_error_percentage(sol["loadbus"]["lg"]["1"]["solution"]["fault"]["bus"]["current"][1], 862.0) < .05
        data = deepcopy(case3_balanced_single_phase)
        data["fault"] = Dict{String,Any}()
        data["fault"]["1"] = Dict("type" => "ll", "bus" => "loadbus", "phases" => [1,2], "gr" => 0.005)
        sol = FS.run_mc_fault_study(data, ipopt_solver)
        @test sol["loadbus"]["ll"]["1"]["termination_status"] == MOI.LOCALLY_SOLVED
        @test calulate_error_percentage(sol["loadbus"]["ll"]["1"]["solution"]["fault"]["bus"]["current"][1], 1259.0) < .05
        data = deepcopy(case3_balanced_single_phase)
        data["fault"] = Dict{String,Any}()
        data["fault"]["1"] = Dict("type" => "3p", "bus" => "loadbus", "phases" => [1,2,3], "gr" => 0.005)
        sol = FS.run_mc_fault_study(data, ipopt_solver)
        @test sol["loadbus"]["3p"]["1"]["termination_status"] == MOI.LOCALLY_SOLVED
        @test calulate_error_percentage(sol["loadbus"]["3p"]["1"]["solution"]["fault"]["bus"]["current"][1], 1455.0) < .05
        data = deepcopy(case3_balanced_single_phase)
        data["fault"] = Dict{String,Any}()
        data["fault"]["1"] = Dict("type" => "lg", "bus" => "loadbus2", "phases" => [2], "gr" => 0.005)
        sol = FS.run_mc_fault_study(data, ipopt_solver)
        @test sol["loadbus2"]["lg"]["1"]["termination_status"] == MOI.LOCALLY_SOLVED
        @test calulate_error_percentage(sol["loadbus2"]["lg"]["1"]["solution"]["fault"]["bus"]["current"][2], 640.0) < .05
        # @test sol["loadbus"]["ll"]["1"]["termination_status"] == MOI.LOCALLY_SOLVED
        # data = deepcopy(case3_balanced_multi_pv_grid_following)
        # data["fault"] = Dict{String,Any}()
        # data["fault"]["1"] = Dict("type" => "3p", "bus" => "loadbus", "phases" => [1,2,3], "gr" => 0.005)
        # sol = FS.run_mc_fault_study(data, ipopt_solver)
        # @test sol["loadbus"]["3p"]["1"]["termination_status"] == MOI.LOCALLY_SOLVED
        # data = deepcopy(case3_balanced_multi_pv_grid_following)
        # data["fault"] = Dict{String,Any}()
        # data["fault"]["1"] = Dict("type" => "lg", "bus" => "pv_bus", "phases" => [1], "gr" => 0.005)
        # sol = FS.run_mc_fault_study(data, ipopt_solver)
        # @test sol["pv_bus"]["lg"]["1"]["termination_status"] == MOI.LOCALLY_SOLVED
    end
end
