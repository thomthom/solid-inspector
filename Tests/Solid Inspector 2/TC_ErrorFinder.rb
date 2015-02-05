#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------


require 'testup/testcase'


class TC_ErrorFinder < TestUp::TestCase

  PLUGIN = TT::Plugins::SolidInspector2


  def setup
    open_new_model()
    PLUGIN::Settings.detect_short_edges = true
    PLUGIN::Settings.short_edge_threshold = 3.mm
  end

  def teardown
    # ...
  end


  # @return [Sketchup::Model]
  def load_test_model(filename)
    basename = File.basename(__FILE__, ".*")
    file = File.join(__dir__, basename, filename)
    Sketchup.open_file(file)
    Sketchup.active_model
  end


  # ========================================================================== #
  # method ErrorFinder.find_errors

  def test_find_errors_model_bottle_base_top_skp
    model = load_test_model("bottle base top.skp")
    instance = model.entities[0]
    entities = instance.entities

    result = PLUGIN::ErrorFinder.find_errors(entities)

    errors = result.grep(PLUGIN::SolidErrors::ReversedFace)
    assert_equal(103, errors.size, "Unexpected number of ReversedFaces")

    errors = result.grep(PLUGIN::SolidErrors::InternalFace)
    assert_equal(26, errors.size, "Unexpected number of InternalFaces")

    errors = result.grep(PLUGIN::SolidErrors::ShortEdge)
    assert_equal(141, errors.size, "Unexpected number of ShortEdges")

    assert_equal(270, result.size, "Unexpected number of errors found")
  end


  def test_find_errors_model_box_skp
    model = load_test_model("box.skp")
    instance = model.entities[0]
    entities = instance.definition.entities

    result = PLUGIN::ErrorFinder.find_errors(entities)

    errors = result.grep(PLUGIN::SolidErrors::SurfaceBorder)
    assert_equal(4, errors.size, "Unexpected number of SurfaceBorders")

    errors = result.grep(PLUGIN::SolidErrors::InternalFaceEdge)
    assert_equal(324, errors.size, "Unexpected number of InternalFaceEdges")

    errors = result.grep(PLUGIN::SolidErrors::ShortEdge)
    assert_equal(328, errors.size, "Unexpected number of ShortEdges")

    assert_equal(656, result.size, "Unexpected number of errors found")
  end


  def test_find_errors_model_Bracket_V2_skp
    model = load_test_model("Bracket V2.skp")
    instance = model.entities[0]
    entities = instance.definition.entities

    result = PLUGIN::ErrorFinder.find_errors(entities)

    errors = result.grep(PLUGIN::SolidErrors::ReversedFace)
    assert_equal(7, errors.size, "Unexpected number of ReversedFace")

    errors = result.grep(PLUGIN::SolidErrors::ShortEdge)
    assert_equal(344, errors.size, "Unexpected number of ShortEdges")

    assert_equal(351, result.size, "Unexpected number of errors found")
  end


  def test_find_errors_model_coil_skp
    model = load_test_model("coil.skp")
    instance = model.entities[0]
    entities = instance.entities

    result = PLUGIN::ErrorFinder.find_errors(entities)

    assert_equal(241, result.size, "Unexpected number of errors found")

    errors = result.grep(PLUGIN::SolidErrors::InternalFace)
    assert_equal(241, errors.size, "Unexpected number of InternalFaces")
  end


  def test_find_errors_model_example_skp
    model = load_test_model("example.skp")
    entities = model.entities
    transformation = IDENTITY

    result = PLUGIN::ErrorFinder.find_errors(entities)

    errors = result.grep(PLUGIN::SolidErrors::StrayEdge)
    assert_equal(120, errors.size, "Unexpected number of StrayEdges")

    errors = result.grep(PLUGIN::SolidErrors::SurfaceBorder)
    assert_equal(15, errors.size, "Unexpected number of SurfaceBorders")

    errors = result.grep(PLUGIN::SolidErrors::InternalFaceEdge)
    assert_equal(13, errors.size, "Unexpected number of InternalFaceEdges")

    errors = result.grep(PLUGIN::SolidErrors::ShortEdge)
    assert_equal(111, errors.size, "Unexpected number of ShortEdges")

    assert_equal(259, result.size, "Unexpected number of errors found")
  end


  def test_find_errors_model_FacePlateV3_skp
    model = load_test_model("FacePlateV3.skp")
    entities = model.entities
    transformation = IDENTITY

    result = PLUGIN::ErrorFinder.find_errors(entities)

    errors = result.grep(PLUGIN::SolidErrors::InternalFace)
    assert_equal(4, errors.size, "Unexpected number of InternalFaces")

    errors = result.grep(PLUGIN::SolidErrors::ShortEdge)
    assert_equal(2112, errors.size, "Unexpected number of ShortEdges")

    assert_equal(2116, result.size, "Unexpected number of errors found")
  end


  def test_find_errors_model_GEB_hollow_solids_skp_Group1
    model = load_test_model("GEB hollow solids.skp")
    definition = model.definitions["Group#1"]
    instance = definition.instances[0]
    entities = definition.entities

    result = PLUGIN::ErrorFinder.find_errors(entities)

    assert_equal(0, result.size, "Unexpected number of errors found")
  end


  def test_find_errors_model_GEB_hollow_solids_skp_Group3
    model = load_test_model("GEB hollow solids.skp")
    definition = model.definitions["Group#3"]
    instance = definition.instances[0]
    entities = definition.entities

    result = PLUGIN::ErrorFinder.find_errors(entities)

    errors = result.grep(PLUGIN::SolidErrors::ReversedFace)
    assert_equal(46, errors.size, "Unexpected number of ReversedFaces")

    assert_equal(46, result.size, "Unexpected number of errors found")
  end


  def test_find_errors_model_GEB_hollow_solids_skp_Group4
    model = load_test_model("GEB hollow solids.skp")
    definition = model.definitions["Group#4"]
    instance = definition.instances[0]
    entities = definition.entities

    result = PLUGIN::ErrorFinder.find_errors(entities)

    assert_equal(53, result.size, "Unexpected number of errors found")

    errors = result.grep(PLUGIN::SolidErrors::ReversedFace)
    assert_equal(53, errors.size, "Unexpected number of ReversedFaces")
  end


  def test_find_errors_model_GEB_hollow_solids_skp_Group2
    model = load_test_model("GEB hollow solids.skp")
    definition = model.definitions["Group#2"]
    instance = definition.instances[0]
    entities = definition.entities

    result = PLUGIN::ErrorFinder.find_errors(entities)

    errors = result.grep(PLUGIN::SolidErrors::ReversedFace)
    assert_equal(18, errors.size, "Unexpected number of ReversedFaces")

    assert_equal(18, result.size, "Unexpected number of errors found")
  end


  def test_find_errors_model_Horse_skp
    model = load_test_model("Horse.skp")
    instance = model.entities[0]
    entities = instance.definition.entities

    result = PLUGIN::ErrorFinder.find_errors(entities)

    errors = result.grep(PLUGIN::SolidErrors::ReversedFace)
    assert_equal(55, errors.size, "Unexpected number of ReversedFace")

    assert_equal(55, result.size, "Unexpected number of errors found")
  end


  def test_find_errors_model_IncorrectReversedFaces_skp
    model = load_test_model("IncorrectReversedFaces.skp")
    instance = model.entities[0]
    entities = instance.definition.entities

    result = PLUGIN::ErrorFinder.find_errors(entities)

    errors = result.grep(PLUGIN::SolidErrors::StrayEdge)
    assert_equal(3, errors.size, "Unexpected number of StrayEdges")

    errors = result.grep(PLUGIN::SolidErrors::ReversedFace)
    assert_equal(2, errors.size, "Unexpected number of ReversedFaces")

    errors = result.grep(PLUGIN::SolidErrors::ShortEdge)
    assert_equal(70, errors.size, "Unexpected number of ShortEdges")

    assert_equal(75, result.size, "Unexpected number of errors found")
  end


  def test_find_errors_model_ManifoldEdgeCase_skp
    model = load_test_model("ManifoldEdgeCase.skp")
    instance = model.entities[0]
    entities = instance.entities

    result = PLUGIN::ErrorFinder.find_errors(entities)

    assert_equal(0, result.size, "Unexpected number of errors found")
  end


  def test_find_errors_model_new_build_skp
    model = load_test_model("new build.skp")
    instance = model.entities[0]
    entities = instance.definition.entities

    result = PLUGIN::ErrorFinder.find_errors(entities)

    errors = result.grep(PLUGIN::SolidErrors::ReversedFace)
    assert_equal(81, errors.size, "Unexpected number of ReversedFace")

    errors = result.grep(PLUGIN::SolidErrors::InternalFace)
    assert_equal(6, errors.size, "Unexpected number of InternalFaces")

    assert_equal(87, result.size, "Unexpected number of errors found")
  end


  def test_find_errors_model_ReversedFaces_SmallModel_skp
    model = load_test_model("ReversedFaces-SmallModel.skp")
    entities = model.entities
    transformation = IDENTITY

    result = PLUGIN::ErrorFinder.find_errors(entities)

    assert_equal(550, result.size, "Unexpected number of errors found")

    errors = result.grep(PLUGIN::SolidErrors::ShortEdge)
    assert_equal(550, errors.size, "Unexpected number of ShortEdges")
  end


  def test_find_errors_model_RIB_19_12_v3_skp_gruppo1
    model = load_test_model("RIB 19.12_v3.skp")
    definition = model.definitions["Gruppo#1"]
    instance = definition.instances[0]
    entities = definition.entities

    result = PLUGIN::ErrorFinder.find_errors(entities)

    assert_equal(298, result.size, "Unexpected number of errors found")

    errors = result.grep(PLUGIN::SolidErrors::ShortEdge)
    assert_equal(298, errors.size, "Unexpected number of ShortEdges")
  end


  def test_find_errors_model_RIB_19_12_v3_skp_gruppo4
    model = load_test_model("RIB 19.12_v3.skp")
    definition = model.definitions["Gruppo#4"]
    instance = definition.instances[0]
    entities = definition.entities

    result = PLUGIN::ErrorFinder.find_errors(entities)

    assert_equal(0, result.size, "Unexpected number of errors found")
  end


  def test_find_errors_model_RIB_19_12_v3_skp_gruppo3
    model = load_test_model("RIB 19.12_v3.skp")
    definition = model.definitions["Gruppo#3"]
    instance = definition.instances[0]
    entities = definition.entities

    result = PLUGIN::ErrorFinder.find_errors(entities)

    assert_equal(0, result.size, "Unexpected number of errors found")
  end


  def test_find_errors_model_RIB_19_12_v3_skp_gruppo5
    model = load_test_model("RIB 19.12_v3.skp")
    definition = model.definitions["Gruppo#5"]
    instance = definition.instances[0]
    entities = definition.entities

    result = PLUGIN::ErrorFinder.find_errors(entities)

    assert_equal(0, result.size, "Unexpected number of errors found")
  end


  def test_find_errors_model_RIB_19_12_v3_skp_gruppo2
    model = load_test_model("RIB 19.12_v3.skp")
    definition = model.definitions["Gruppo#2"]
    instance = definition.instances[0]
    entities = definition.entities

    result = PLUGIN::ErrorFinder.find_errors(entities)

    assert_equal(22, result.size, "Unexpected number of errors found")

    errors = result.grep(PLUGIN::SolidErrors::ShortEdge)
    assert_equal(22, errors.size, "Unexpected number of ShortEdges")
  end


  def test_find_errors_model_Shellifyexamples_skp_Group6
    model = load_test_model("Shellifyexamples.skp")
    definition = model.definitions["Group#6"]
    instance = definition.instances[0]
    entities = definition.entities

    result = PLUGIN::ErrorFinder.find_errors(entities)

    assert_equal(3, result.size, "Unexpected number of errors found")

    errors = result.grep(PLUGIN::SolidErrors::InternalFace)
    assert_equal(3, errors.size, "Unexpected number of InternalFaces")
  end


  def test_find_errors_model_Shellifyexamples_skp_Group3
    model = load_test_model("Shellifyexamples.skp")
    definition = model.definitions["Group#3"]
    instance = definition.instances[0]
    entities = definition.entities

    result = PLUGIN::ErrorFinder.find_errors(entities)

    assert_equal(80, result.size, "Unexpected number of errors found")

    errors = result.grep(PLUGIN::SolidErrors::InternalFace)
    assert_equal(80, errors.size, "Unexpected number of InternalFaces")
  end


  def test_find_errors_model_Shellifyexamples_skp_Group1
    model = load_test_model("Shellifyexamples.skp")
    definition = model.definitions["Group#1"]
    instance = definition.instances[0]
    entities = definition.entities

    result = PLUGIN::ErrorFinder.find_errors(entities)

    errors = result.grep(PLUGIN::SolidErrors::StrayEdge)
    assert_equal(1, errors.size, "Unexpected number of StrayEdges")

    errors = result.grep(PLUGIN::SolidErrors::SurfaceBorder)
    assert_equal(19, errors.size, "Unexpected number of SurfaceBorders")

    errors = result.grep(PLUGIN::SolidErrors::InternalFaceEdge)
    assert_equal(115, errors.size, "Unexpected number of InternalFaceEdges")

    assert_equal(135, result.size, "Unexpected number of errors found")
  end


  def test_find_errors_model_Shellifyexamples_skp_Group2
    model = load_test_model("Shellifyexamples.skp")
    definition = model.definitions["Group#2"]
    instance = definition.instances[0]
    entities = definition.entities

    result = PLUGIN::ErrorFinder.find_errors(entities)

    errors = result.grep(PLUGIN::SolidErrors::InternalFace)
    assert_equal(2027, errors.size, "Unexpected number of InternalFaces")

    errors = result.grep(PLUGIN::SolidErrors::ReversedFace)
    assert_equal(1478, errors.size, "Unexpected number of ReversedFaces")

    assert_equal(3505, result.size, "Unexpected number of errors found")
  end


  def test_find_errors_model_Shellifyexamples_skp_Group2_3
    model = load_test_model("Shellifyexamples.skp")
    definition = model.definitions["Group2#3"]
    instance = definition.instances[0]
    entities = definition.entities

    result = PLUGIN::ErrorFinder.find_errors(entities)

    assert_equal(17132, result.size, "Unexpected number of errors found")

    errors = result.grep(PLUGIN::SolidErrors::SurfaceBorder)
    assert_equal(2, errors.size, "Unexpected number of SurfaceBorders")

    errors = result.grep(PLUGIN::SolidErrors::InternalFaceEdge)
    assert_equal(17065, errors.size, "Unexpected number of InternalFaceEdges")

    errors = result.grep(PLUGIN::SolidErrors::ShortEdge)
    assert_equal(65, errors.size, "Unexpected number of ShortEdges")
  end


  def test_find_errors_model_solid_tools_use_case_skp
    model = load_test_model("solid_tools use_case.skp")
    instance = model.entities[0]
    entities = instance.entities

    result = PLUGIN::ErrorFinder.find_errors(entities)

    errors = result.grep(PLUGIN::SolidErrors::ReversedFace)
    assert_equal(144, errors.size, "Unexpected number of ReversedFaces")

    assert_equal(144, result.size, "Unexpected number of errors found")
  end


  def test_find_errors_model_solidproblem_skp
    model = load_test_model("solidproblem.skp")
    instance = model.entities[0]
    entities = instance.entities

    result = PLUGIN::ErrorFinder.find_errors(entities)

    assert_equal(225, result.size, "Unexpected number of errors found")

    errors = result.grep(PLUGIN::SolidErrors::InternalFace)
    assert_equal(225, errors.size, "Unexpected number of InternalFaces")
  end


  def test_find_errors_model_SolidTest_skp_Group2
    model = load_test_model("SolidTest.skp")
    definition = model.definitions["Group#2"]
    instance = definition.instances[0]
    entities = definition.entities

    result = PLUGIN::ErrorFinder.find_errors(entities)

    assert_equal(0, result.size, "Unexpected number of errors found")
  end


  def test_find_errors_model_SolidTest_skp_Group1
    model = load_test_model("SolidTest.skp")
    definition = model.definitions["Group#1"]
    instance = definition.instances[0]
    entities = definition.entities

    result = PLUGIN::ErrorFinder.find_errors(entities)

    errors = result.grep(PLUGIN::SolidErrors::StrayEdge)
    assert_equal(3, errors.size, "Unexpected number of StrayEdges")

    errors = result.grep(PLUGIN::SolidErrors::SurfaceBorder)
    assert_equal(4, errors.size, "Unexpected number of SurfaceBorders")

    errors = result.grep(PLUGIN::SolidErrors::FaceHole)
    assert_equal(1, errors.size, "Unexpected number of FaceHoles")

    errors = result.grep(PLUGIN::SolidErrors::InternalFaceEdge)
    assert_equal(4, errors.size, "Unexpected number of InternalFaceEdges")

    assert_equal(12, result.size, "Unexpected number of errors found")
  end


  def test_find_errors_model_SolidTest_skp_Group9
    model = load_test_model("SolidTest.skp")
    definition = model.definitions["Group#11"]
    instance = definition.instances[0]
    entities = definition.entities

    result = PLUGIN::ErrorFinder.find_errors(entities)

    errors = result.grep(PLUGIN::SolidErrors::ReversedFace)
    assert_equal(1, errors.size, "Unexpected number of ReversedFaces")

    assert_equal(1, result.size, "Unexpected number of errors found")
  end


  def test_find_errors_model_SolidTest_skp_Group10
    model = load_test_model("SolidTest.skp")
    definition = model.definitions["Group#10"]
    instance = definition.instances[0]
    entities = definition.entities

    result = PLUGIN::ErrorFinder.find_errors(entities)

    errors = result.grep(PLUGIN::SolidErrors::ReversedFace)
    assert_equal(10, errors.size, "Unexpected number of ReversedFaces")

    assert_equal(10, result.size, "Unexpected number of errors found")
  end


  def test_find_errors_model_SolidTest_skp_Group3
    model = load_test_model("SolidTest.skp")
    definition = model.definitions["Group#3"]
    instance = definition.instances[0]
    entities = definition.entities

    result = PLUGIN::ErrorFinder.find_errors(entities)

    assert_equal(211, result.size, "Unexpected number of errors found")

    errors = result.grep(PLUGIN::SolidErrors::InternalFace)
    assert_equal(211, errors.size, "Unexpected number of InternalFaces")
  end


  def test_find_errors_model_SolidTest_skp_Group5
    model = load_test_model("SolidTest.skp")
    definition = model.definitions["Group#5"]
    instance = definition.instances[0]
    entities = definition.entities

    result = PLUGIN::ErrorFinder.find_errors(entities)

    errors = result.grep(PLUGIN::SolidErrors::InternalFace)
    assert_equal(1667, errors.size, "Unexpected number of InternalFaces")

    errors = result.grep(PLUGIN::SolidErrors::ReversedFace)
    assert_equal(223, errors.size, "Unexpected number of ReversedFaces")

    assert_equal(1890, result.size, "Unexpected number of errors found")
  end


  def test_find_errors_model_SolidTest_skp_Group4
    model = load_test_model("SolidTest.skp")
    definition = model.definitions["Group#4"]
    instance = definition.instances[0]
    entities = definition.entities

    result = PLUGIN::ErrorFinder.find_errors(entities)

    errors = result.grep(PLUGIN::SolidErrors::InternalFace)
    assert_equal(1472, errors.size, "Unexpected number of InternalFaces")

    errors = result.grep(PLUGIN::SolidErrors::ReversedFace)
    assert_equal(268, errors.size, "Unexpected number of ReversedFaces")

    assert_equal(1740, result.size, "Unexpected number of errors found")
  end


  def test_find_errors_model_SolidHouseDisconnected_skp_Component27
    model = load_test_model("SolidHouseDisconnected.skp")
    definition = model.definitions["Component#27"]
    instance = definition.instances[0]
    entities = definition.entities

    result = PLUGIN::ErrorFinder.find_errors(entities)

    assert_equal(0, result.size, "Unexpected number of errors found")
  end


  def test_find_errors_model_DisconnectedEdge_skp
    model = load_test_model("DisconnectedEdge.skp")
    instance = model.entities[0]
    entities = instance.entities

    result = PLUGIN::ErrorFinder.find_errors(entities)

    assert_equal(1, result.size, "Unexpected number of errors found")

    errors = result.grep(PLUGIN::SolidErrors::StrayEdge)
    assert_equal(1, errors.size, "Unexpected number of StrayEdges")
  end


end # class
