# @testset "Protection Operation Tests" begin
    test_case1 = "../test/data/dist/3bus_example.dss"
    # test_case2 = "5bus_example.dss"

    # dss2eng_extensions = [_dss2eng_curve!,_dss2eng_fuse!,_dss2eng_ct!,_dss2eng_relay!]

    # eng2math_extensions = [_eng2math_fault!,_eng2math_protection!]

    # map_math2eng_extensions = Dict{String,Function}(
    #     "_map_math2eng_fault!" => _map_math2eng_fault!,
    #     "_map_math2eng_protection!" => _map_math2eng_protection!
    # )

    # solution_processors = [solution_fs!,solution_protection!]

    # @testset "Parsing .dss protection objects" begin
        data_eng = parse_file(test_case1) 
        data_math = PMD.transform_data_model(data_eng)
        fault_studies = build_mc_sparse_fault_study(data_eng)
        println(keys(fault_studies))

        # sol = solve_mc_fault_study(data, fault_studies, ipopt_solver)

#         @testset "dss parser found all objects" begin
#             @test haskey(data_dss, "relay")
#             @test haskey(data_dss, "fuse")
#             @test haskey(data_dss, "tcc_curve")
#             @test haskey(data_dss, "monitor")
#         end  
        
#         @testset "parser can't convert protection devices to eng model" begin
#             data = deepcopy(data_dss)
#             eng_data = _PMD.parse_opendss(data)
#             @test !haskey(eng_data, "relay")
#             @test !haskey(eng_data, "fuse")
#             @test !haskey(eng_data, "tcc_curve")
#             @test !haskey(eng_data, "monitor")
#             @test !haskey(eng_data, "protection")
#         end

#         @testset "dss2eng_extensions convert protection equipment" begin
#             data = deepcopy(data_dss)
#             eng_data = _PMD.parse_opendss(data;dss2eng_extensions=dss2eng_extensions)
#             @testset "Relays were converted" begin
#                 protection = eng_data["protection"]
#                 @test haskey(protection, "relays")
#                 @test haskey(protection, "C_Transformers")
#                 @test haskey(protection, "fuses")
#                 @test haskey(protection, "curves")
#             end
#         end
#     end

#     @testset "math2eng conversion of protection equipment" begin
#         data_eng = parse_file(test_case1)
#         data_math = _PMD.transform_data_model(data_eng; eng2math_extensions=eng2math_extensions)
#         @testset "Protection equipment is converted" begin
#             @test haskey(data_math, "relay")
#             @test haskey(data_math, "curve")
#             @test haskey(data_math, "fuse")
#             @test haskey(data_math, "c_transformer")
#         end
#         # make sure all were transferred, and enumeration was accurate
#         @testset "Objects accurately converted" begin
#             num_relays_eng = 0
#             for (id, _) in get(data_eng["protection"], "relays", Dict())
#                 num_relays_eng = num_relays_eng + length(data_eng["protection"]["relays"]["$id"])
#             end
#             num_fuses_eng = 0
#             for (id, _) in get(data_eng["protection"], "fuses", Dict())
#                 num_fuses_eng = num_fuses_eng + length(data_eng["protection"]["fuses"]["$id"])
#             end
#             num_cts_eng = length(data_eng["protection"]["C_Transformers"])
#             num_curves_eng = length(data_eng["protection"]["curves"])
#             @test num_relays_eng == length(data_math["relay"])
#             @test num_curves_eng == length(data_math["curve"])
#             @test num_fuses_eng == length(data_math["fuse"])
#             @test num_cts_eng == length(data_math["c_transformer"])

#             map_dict = Dict{String,Any}("branch" => Dict{String,Any}(), "bus" => Dict{String,Any}())
#             for (_, obj) in get(data_math, "branch", Dict())
#                 map_dict["branch"]["$(obj["name"])"] = obj["index"]
#             end
#             for (_, obj) in get(data_math, "bus", Dict())
#                 map_dict["bus"]["$(obj["name"])"] = obj["index"]
#             end
#             enum_success = 0
#             for (id, obj) in get(data_math, "relay", Dict())
#                 if obj["prot_obj"] == :branch
#                     if map_dict["branch"]["$(obj["element"])"] == obj["element_enum"]
#                         enum_success = enum_success + 1
#                     end
#                 else
#                     if map_dict["bus"]["$(obj["element"])"] == obj["element_enum"]
#                         enum_success = enum_success + 1
#                     end
#                 end
#             end
#             for (id, obj) in get(data_math, "fuse", Dict())
#                 if map_dict["branch"]["$(obj["element"])"] == obj["element_enum"]
#                     enum_success = enum_success + 1
#                 end
#             end
#             for (id, obj) in get(data_math, "c_transformer", Dict())
#                 if map_dict["branch"]["$(obj["element"])"] == obj["element_enum"]
#                     enum_success = enum_success + 1
#                 end
#             end
#             @testset "Enumeration is accurate" begin
#                 @test enum_success == num_cts_eng + num_fuses_eng + num_relays_eng
#             end

#         end
#     end

#     @testset "Solution builder built into solve_mc_fault_study" begin
#         net = parse_file(test_case1; dss2eng_extensions=dss2eng_extensions)
#         add_fault!(net, "1", "lg", "primary", [1,4], 0.005)

#         solver = JuMP.with_optimizer(Ipopt.Optimizer)
#         solution = solve_mc_fault_study(net, solver)
#         solution_protection = solve_mc_fault_study(net, solver; eng2math_extensions=eng2math_extensions,map_math2eng_extensions=map_math2eng_extensions,solution_processors=solution_processors)

#         protection_operation(net,solution)

#         @testset "Solution builder and post processor got same results" begin
#             ids1 = []
#             ids2 = []
#             builder_dict = Dict{String,Any}()
#             for (id,obj) in get(solution_protection["solution"],"relay",Dict())
#                 push!(ids1,id)
#                 builder_dict["$id"] = Dict{String,Any}()
#                 for (phase,info) in get(obj, "phase", Dict())
#                     if info["state"] == "open"
#                         builder_dict["$id"]["$phase"] = info["op_times"][1]
#                     end
#                 end
#             end
#             for (id,obj) in get(solution_protection["solution"],"fuse",Dict())
#                 push!(ids1,id)
#                 builder_dict["$id"] = Dict{String,Any}()
#                 for (phase,info) in get(obj, "phase", Dict())
#                     if info["state"] == "open"
#                         str = split(info["op_times"],". ")
#                         str = split(str[2],"melt: ")[2]
#                         builder_dict["$id"]["$phase"] = parse(Float64,str)
#                     end
#                 end
#             end
#             post_dict = Dict{String,Any}()
#             for (id,obj) in get(solution["solution"],"relay",Dict())
#                 push!(ids2,id)
#                 post_dict["$id"] = Dict{String,Any}()
#                 for (phase,info) in get(obj, "phase", Dict())
#                     if info["state"] == "open"
#                         post_dict["$id"]["$phase"] = info["op_times"][1]
#                     end
#                 end
#             end
#             for (id,obj) in get(solution["solution"],"fuse",Dict())
#                 push!(ids2,id)
#                 post_dict["$id"] = Dict{String,Any}()
#                 for (phase,info) in get(obj, "phase", Dict())
#                     if info["state"] == "open"
#                         str = split(info["op_times"],". ")
#                         str = split(str[2],"melt: ")[2]
#                         post_dict["$id"]["$phase"] = parse(Float64,str)
#                     end
#                 end
#             end
#             same_relays = 0
#             for id in ids1
#                 if id in ids2
#                     same_relays = same_relays+1
#                 end
#             end
#             @test same_relays == length(ids1) == length(ids2)
#             for (id,obj) in builder_dict
#                 for phase in keys(obj)
#                     @test abs(builder_dict["$id"]["$phase"] - post_dict["$id"]["$phase"]) < 0.01
#                 end
#             end


#         end
#     end

#     @testset "Checking operation" begin
#         net = parse_file(test_case2; dss2eng_extensions=dss2eng_extensions)
#         solver = JuMP.with_optimizer(Ipopt.Optimizer)
#         PowerModelsProtection.add_fault!(net, "1", "3p", "loadbus1", [1,2,3], 0.005)

#         results = PowerModelsProtection.solve_mc_fault_study(net, solver;eng2math_extensions=[_eng2math_fault!,_eng2math_protection!],map_math2eng_extensions=_pmp_map_math2eng_extensions,solution_processors=[solution_fs!,solution_protection!])

#         @test haskey(results["solution"],"relay")
#         @test haskey(results["solution"],"fuse")

#         @test haskey(results["solution"]["fuse"], "f1")
#         @test haskey(results["solution"]["relay"], "r1")
#         @test haskey(results["solution"]["relay"], "r2")
#         @test haskey(results["solution"]["relay"], "r3")
#     end
# end