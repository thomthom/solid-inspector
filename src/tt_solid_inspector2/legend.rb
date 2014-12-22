#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------


module TT::Plugins::SolidInspector2

  require File.join(PATH, "drawing_helper.rb")
  require File.join(PATH, "gl", "label.rb")


  class Legend

    include DrawingHelper

    LEADER_COLOR = Sketchup::Color.new(255, 153, 0)

    attr :position

    def initialize(position)
      @position = position
    end

    # return [Geom::BoundingBox]
    def bounds(view)
      raise NotImplementedError
    end

    def intersect?(legend, view)
      unless legend.is_a?(Legend)
        raise TypeError, "Must be enother #{self.class}"
      end
      if Sketchup.version.to_i < 15
        raise NotImplementedError, "Need to implement SU2014 workaround."
      else
        !bounds(view).intersect(legend.bounds(view)).empty?
      end
    end

    # return [Integer] Leader length in pixels
    def leader_length
      20
    end

    # return [Geom::Vector3d] Leader vector
    def leader_vector
      Geom::Vector3d.new(leader_length, 0, 0)
    end

    # return [Integer] Icon size in pixels
    def icon_size
      16
    end

    def on_screen?(view)
      screen = Geom::BoundingBox.new
      screen.add(ORIGIN, [view.vpwidth, view.vpheight, 0])
      if Sketchup.version.to_i < 15
        raise NotImplementedError, "Need to implement SU2014 workaround."
      else
        !screen.intersect(bounds(view)).empty?
      end
    end

    # return [Geom::Point3d]
    def screen_position(view)
      point = screen_point(@position, view)
    end

    # return [Geom::Vector3d] Leader vector
    def screen_position_vector(view)
      point = screen_point(@position, view)
      ORIGIN.vector_to(point)
    end

    # @param [Sketchup::View] view
    def draw(view)
      return false unless on_screen?(view)
      vector = leader_vector
      draw_leader(vector, view)
      draw_icon(vector, view)
      true
    end

    # @param [Geom::Vector] direction
    # @param [Sketchup::View] view
    def draw_leader(direction, view)
      pt1 = screen_point(@position, view)
      pt2 = pt1.offset(leader_vector)

      view.drawing_color = LEADER_COLOR
      view.line_width = 2
      view.line_stipple = ''

      draw2d_point_square(pt1, 6, view)

      line = adjust_to_pixel_grid([pt1, pt2])
      view.draw2d(GL_LINES, pt1, pt2)
      nil
    end

    # @param [Geom::Vector] direction
    # @param [Sketchup::View] view
    def draw_icon(offset, view)
      raise NotImplementedError
    end

  end # class Legend


  class LegendGroup < Legend

    def initialize(legend)
      super(legend.position)
      @legends = []
      add_legend(legend)
    end

    def add_legend(legend)
      @legends << legend
    end

    def bounds(view)
      bounds = Geom::BoundingBox.new

      legend_bounds = @legends.first.bounds(view)
      bounds.add(legend_bounds)

      text_width = (GL_Text::CHAR_WIDTH * @legends.size.to_s.size) + 25
      point1 = legend_bounds.max
      point2 = point1.offset(X_AXIS, text_width)
      bounds.add(point2)

      bounds
    end

    def draw(view)
      # TODO: Need to account for different legend types.
      @legends.first.draw(view)

      if @legends.size > 1
        pt1 = screen_position(view)
        pt2 = pt1.offset(leader_vector)
        text_pt = pt2.offset(X_AXIS, icon_size + 4)
        text_pt = adjust_to_pixel_grid([text_pt])[0]
        label = GL_Label.new(view, "#{@legends.size}", text_pt)
        label.draw(view)
      end
    end

  end # class LegendGroup


  class WarningLegend < Legend

    WARNING_COLOR     = Sketchup::Color.new(255, 153, 0)
    EXCLAMATION_COLOR = Sketchup::Color.new(  0,   0, 0)

    def bounds(view)
      boundingbox = Geom::BoundingBox.new
      half_icon_size = icon_size / 2
      points = [
        Geom::Point3d.new(-2, -2 - half_icon_size, 0),
        Geom::Point3d.new(2 + leader_length + icon_size, 2 + half_icon_size, 0)
      ]
      points = offset_points(points, screen_position_vector(view))
      boundingbox.add(points)
      boundingbox
    end

    def draw_icon(offset, view)
      view.drawing_color = WARNING_COLOR
      view.line_width = 2
      view.line_stipple = ''

      half_icon_size = icon_size / 2

      triangle = [
        Geom::Point3d.new(leader_length,       half_icon_size, 0),
        Geom::Point3d.new(leader_length + icon_size,  half_icon_size, 0),
        Geom::Point3d.new(leader_length +  half_icon_size, -half_icon_size, 0)
      ]
      triangle = offset_points(triangle, screen_position_vector(view))
      triangle = adjust_to_pixel_grid(triangle)
      view.draw2d(GL_TRIANGLES, triangle)

      view.drawing_color = EXCLAMATION_COLOR
      exclamation = [
        Geom::Point3d.new(leader_length + half_icon_size,  half_icon_size - 2, 0),
        Geom::Point3d.new(leader_length + half_icon_size,  half_icon_size - 4, 0),
        Geom::Point3d.new(leader_length + half_icon_size,  half_icon_size - 6, 0),
        Geom::Point3d.new(leader_length + half_icon_size, -half_icon_size + 5, 0)
      ]
      exclamation = offset_points(exclamation, screen_position_vector(view))
      exclamation = adjust_to_pixel_grid(exclamation)
      view.draw2d(GL_LINES, exclamation)
      nil
    end

  end # class Warning


end # module TT::Plugins::SolidInspector2
