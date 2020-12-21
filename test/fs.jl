@testset "Balanced fault study" begin
    @testset "5-bus fault example" begin
        data = PM.parse_file("../test/data/trans/case5_fault.m", import_all=true)

        # use flat start
        for (i, b) in data["bus"]
            b["vm"] = 1
            b["va"] = 0
            b["vmax"] = 2
            b["vmin"] = 0
        end

        # neglect line charging
        for (k, br) in data["branch"]
            br["b_fr"] = 0
            br["b_to"] = 0
            br["tap"] = 1
            br["shift"] = 0
        end

        for (k, g) in data["gen"]
            g["pg"] = 0
            g["qg"] = 0
        end

        data["fault"] = Dict{String,Any}()
        data["fault"]["1"] = Dict("bus" => 2, "r" => 0.0001)
        study_results = FS.run_fault_study(data, ipopt_solver)
        result = study_results["2"][1]
        solution = result["solution"]

        @test result["termination_status"] == MOI.LOCALLY_SOLVED

        bus = result["solution"]["bus"]["1"]
        @test isapprox(abs(bus["vr"] + 1im * bus["vi"]), 0.0610503; atol = 1e-3)

        bus = result["solution"]["bus"]["3"]
        @test isapprox(abs(bus["vr"] + 1im * bus["vi"]), 0.0279175; atol = 1e-3)

        bus = result["solution"]["bus"]["4"]
        @test isapprox(abs(bus["vr"] + 1im * bus["vi"]), 0.0529499; atol = 1e-3)

        bus = result["solution"]["bus"]["10"]
        @test isapprox(abs(bus["vr"] + 1im * bus["vi"]), 0.0645659; atol = 1e-3)
    end

    @testset "3-bus fault example with inverter" begin
        data = PM.parse_file("../test/data/trans/case3_fault_inverter.m", import_all=true)

        # use flat start
        # use flat start
        for (i, b) in data["bus"]
            b["vm"] = 1
            b["va"] = 0
            b["vmax"] = 2
            b["vmin"] = 0
        end


        # neglect line charging
        for (k, br) in data["branch"]
            br["b_fr"] = 0
            br["b_to"] = 0
        end

        data["fault"] = Dict{String,Any}()
        data["fault"]["1"] = Dict("bus" => 2, "r" => 0.0001)
        study_results = FS.run_fault_study(data, ipopt_solver)
        result = study_results["2"][1]
        solution = result["solution"]

        @test result["termination_status"] == LOCALLY_SOLVED

        @test isapprox(result["objective"], -4.323499; atol = 1e-3)

        bus = result["solution"]["bus"]["2"]
        @test isapprox(abs(bus["vr"] + 1im * bus["vi"]), 0.000444; atol = 1e-3)

        bus = result["solution"]["bus"]["3"]
        @test isapprox(abs(bus["vr"] + 1im * bus["vi"]), 0.048233; atol = 1e-3)

        bus = result["solution"]["bus"]["4"]
        @test isapprox(abs(bus["vr"] + 1im * bus["vi"]), 0.196538; atol = 1e-3)

        gen = result["solution"]["gen"]["1"]
        @test isapprox(abs(gen["crg"] + 1im * gen["cig"]), 2.829868; atol = 1e-3)
        @test isapprox(angle(gen["pg"] + 1im * gen["qg"]), 0.0; atol = 1e-3)
    end
end
