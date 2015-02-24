#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------


require 'testup/testcase'


class TC_Legend < TestUp::TestCase

  PLUGIN = TT::Plugins::SolidInspector2


  def setup
    eye = Geom::Point3d.new(0, 0, 1000)
    target = Geom::Point3d.new(0, 0, 0)
    up = Y_AXIS
    camera = Sketchup::Camera.new(eye, target, up)
    Sketchup.active_model.active_view.camera = camera
  end

  def teardown
    # ...
  end


  def create_legend(x, y)
    position = Geom::Point3d.new(x, y , 0)
    legend = PLUGIN::WarningLegend.new(position)
    legend
  end


  # ========================================================================== #
  # method Legend.intersect?

  def test_intersect_Query_intersecting
    legend1 = create_legend(0, 0)
    legend2 = create_legend(5, 5)
    view = Sketchup.active_model.active_view

    result = legend1.intersect?(legend2, view)
    assert(result, "Legends should intersect")
  end

  def test_intersect_Query_not_intersecting_x
    legend1 = create_legend(0, 0)
    legend2 = create_legend(5, 500)
    view = Sketchup.active_model.active_view

    result = legend1.intersect?(legend2, view)
    assert_equal(false, result, "Legends should not intersect")
  end

  def test_intersect_Query_not_intersecting_xy
    legend1 = create_legend(0, 0)
    legend2 = create_legend(500, 500)
    view = Sketchup.active_model.active_view

    result = legend1.intersect?(legend2, view)
    assert_equal(false, result, "Legends should not intersect")
  end


  # ========================================================================== #
  # method Legend.on_screen?

  def test_on_screen_Query_on_screen
    legend1 = create_legend(0, 0)
    view = Sketchup.active_model.active_view

    result = legend1.on_screen?(view)
    assert(result, "Legend should be on screen")
  end

  def test_on_screen_Query_off_screen
    legend1 = create_legend(-500, -500)
    view = Sketchup.active_model.active_view

    result = legend1.on_screen?(view)
    assert_equal(false, result, "Legend should be on screen")
  end


end # class
