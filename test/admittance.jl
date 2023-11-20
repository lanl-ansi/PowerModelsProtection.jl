@testset "Admittance test for components" begin
    @info "source checks"
    @testset  "source check Bus_example3" begin 
        model = PowerModelsProtection.instantiate_mc_admittance_model(Bus_example3) 
        p_matrix = model.data["gen"]["1"]["p_matrix"]
        @test calculate_error_percentage(real(p_matrix[1,1]), 1668079.689) < .001
        @test calculate_error_percentage(imag(p_matrix[1,1]), -6014804.171) < .001
        @test calculate_error_percentage(real(p_matrix[1,4]), -1668079.689) < .001
        @test calculate_error_percentage(imag(p_matrix[1,4]), 6014804.171) < .001
        @test calculate_error_percentage(real(p_matrix[5,5]), 1668079.6899) < .001
        @test calculate_error_percentage(imag(p_matrix[5,5]), -6014804.171) < .001
        @test calculate_error_percentage(real(p_matrix[6,6]), 1668079.689) < .001
        @test calculate_error_percentage(imag(p_matrix[6,6]), -6014804.171) < .001
    end
    @testset "2w y-y transformer test" begin
        model = PowerModelsProtection.instantiate_mc_admittance_model(wye_wye_fault) 
        p_matrix = model.data["transformer"]["1"]["p_matrix"]
        @test isapprox(real(p_matrix[1,1]), 0.0350450455; atol = 1e-5)
        @test isapprox(imag(p_matrix[1,1]), -0.05840841123; atol = 1e-5)
        @test isapprox(real(p_matrix[1,4]), -0.0350450455; atol = 1e-5)
        @test isapprox(imag(p_matrix[1,4]), 0.05840840917; atol = 1e-5)
        @test isapprox(real(p_matrix[5,5]), 0.2930548349; atol = 1e-5)
        @test isapprox(imag(p_matrix[5,5]), -0.4920781573; atol = 1e-5)
        @test isapprox(real(p_matrix[8,8]), 0.8791645046; atol = 1e-5)
        @test isapprox(imag(p_matrix[8,8]), -1.476234488; atol = 1e-5)
    end

    @testset "2w d-y lag transformer test" begin
        model = PowerModelsProtection.instantiate_mc_admittance_model(delta_wye_lag) 
        p_matrix = model.data["transformer"]["1"]["p_matrix"]
        @test isapprox(real(p_matrix[1,1]), 0.02430724356; atol = 1e-5)
        @test isapprox(imag(p_matrix[1,1]), -0.04051207398; atol = 1e-5)
        @test isapprox(real(p_matrix[1,4]), 0.0; atol = 1e-5)
        @test isapprox(imag(p_matrix[1,4]), 0.0; atol = 1e-5)
        @test isapprox(real(p_matrix[5,5]), 0.2772977941; atol = 1e-5)
        @test isapprox(imag(p_matrix[5,5]), -0.4629963392; atol = 1e-5)
        @test isapprox(real(p_matrix[8,8]), 0.8318933824; atol = 1e-5)
        @test isapprox(imag(p_matrix[8,8]), -1.388989033; atol = 1e-5)
    end

@testset "center tap transformer test" begin
        model = PowerModelsProtection.instantiate_mc_admittance_model(simple_center_tap) 
        p_matrix = model.data["transformer"]["1"]["p_matrix"]
        @test isapprox(real(p_matrix[1,1]), 0.1069198529; atol = 1e-5)
        @test isapprox(imag(p_matrix[1,1]), -0.1514697935; atol = 1e-5)
        @test isapprox(real(p_matrix[1,4]), 3.207595586; atol = 1e-5)
        @test isapprox(imag(p_matrix[1,4]), -4.544093747; atol = 1e-5)
        @test isapprox(real(p_matrix[3,3]), 534.2988189; atol = 1e-5)
        @test isapprox(imag(p_matrix[3,3]), -384.5472844; atol = 1e-5)
        @test isapprox(real(p_matrix[4,4]), 534.2988189; atol = 1e-5)
        @test isapprox(real(p_matrix[6,6]), 534.2710411; atol = 1e-5)
        # only values that is off at 1e-5 tol
        @test isapprox(imag(p_matrix[4,4]), -384.5472913; atol = 1e-4)
        @test isapprox(imag(p_matrix[6,6]), -384.5472913; atol = 1e-4)
    end

    @testset "3w d-y lag transformer test" begin
        model = PowerModelsProtection.instantiate_mc_admittance_model(delta_wye_3w) 
        p_matrix = model.data["transformer"]["1"]["p_matrix"]
        @test isapprox(real(p_matrix[1,1]), 0.03116007786; atol = 1e-5)
        @test isapprox(imag(p_matrix[1,1]), -0.05193346447; atol = 1e-5)
        @test isapprox(real(p_matrix[1,4]), 0.0; atol = 1e-5)
        @test isapprox(imag(p_matrix[1,4]), 0.0; atol = 1e-5)
        @test isapprox(real(p_matrix[5,5]), 0.4636022018; atol = 1e-5)
        @test isapprox(imag(p_matrix[5,5]), -0.4654044089; atol = 1e-5)
        @test isapprox(real(p_matrix[8,8]), 1.390806605 ; atol = 1e-5)
        @test isapprox(imag(p_matrix[8,8]), -1.396213242; atol = 1e-5)
        @test isapprox(real(p_matrix[12,11]), -56.64638877 ; atol = 1e-5)
        @test isapprox(imag(p_matrix[12,11]), 33.98783326; atol = 1e-5)
        @test isapprox(real(p_matrix[12,12]), 169.9391663 ; atol = 1e-5)
        @test isapprox(imag(p_matrix[12,12]), -101.963506; atol = 1e-5)
    end

end