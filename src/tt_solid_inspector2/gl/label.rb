#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------

module TT::Plugins::SolidInspector2

  require File.join(PATH, "object_utils.rb")


  class GL_Label

    include ObjectUtils

    # Background colour for the adjustment labels.
    COLOR_BACKGROUND = Sketchup::Color.new(0, 0, 0, 220)

    attr_reader :caption, :position

    def initialize(view, caption = "", screen_position = ORIGIN)
      @position = screen_position
      text_point = text_position(view, screen_position)
      @caption = GL_Text.new(caption, text_point.x, text_point.y)
      @background_frame, @background_arrow = frame_points(view, screen_position)
    end

    def caption=(value)
      @caption.text = value.to_s
    end

    def point_inside?(view, screen_point)
      polygon = frame_points(view, @position).flatten
      Geom.point_in_polygon_2D(screen_point, polygon, true)
    end

    def set_position(view, screen_position)
      @position = screen_position
      @background_frame, @background_arrow = frame_points(view, screen_position)
      @caption.position = text_position(view, screen_position)
      nil
    end

    def draw(view)
      view.line_stipple = ''
      view.drawing_color = COLOR_BACKGROUND
      view.draw2d(GL_TRIANGLES, @background_arrow)
      view.draw2d(GL_QUADS, @background_frame)
      @caption.draw(view)
      nil
    end

    # @return [String]
    def inspect
      object_info(" #{@caption}")
    end

    private

    def frame_points(view, screen_position)
      text_width = GL_Text::CHAR_WIDTH * @caption.text.size
      tr = Geom::Transformation.new(screen_position)
      box = [
        Geom::Point3d.new(5, -10, 0),
        Geom::Point3d.new(5 + text_width + 10, -10, 0),
        Geom::Point3d.new(5 + text_width + 10,  10, 0),
        Geom::Point3d.new(5,  10, 0)
      ].each { |pt| pt.transform!(tr) }
      arrow = [
        Geom::Point3d.new(0,  0, 0),
        Geom::Point3d.new(5,  5, 0),
        Geom::Point3d.new(5, -5, 0)
      ].each { |pt| pt.transform!(tr) }
      [box, arrow]
    end

    def text_position(view, screen_position)
      tr = Geom::Transformation.new(screen_position)
      Geom::Point3d.new(10, 0 - GL_Text::CHAR_HEIGHT - 5, 0).transform(tr)
    end

  end # class GL_Label
end # module TT::Plugins::SolidInspector2
