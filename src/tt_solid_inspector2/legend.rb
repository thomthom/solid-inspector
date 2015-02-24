#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------


module TT::Plugins::SolidInspector2

  require File.join(PATH, "drawing_helper.rb")
  require File.join(PATH, "geometry.rb")
  require File.join(PATH, "gl", "label.rb")
  require File.join(PATH, "gl", "text.rb")


  class Legend

    include DrawingHelper

    LEADER_COLOR = Sketchup::Color.new(255, 153, 0)

    attr_accessor :position, :tooltip

    def initialize(position)
      @position = position
      @tooltip = ""
    end

    # return [Geom::BoundingBox]
    def bounds(view)
      raise NotImplementedError
    end

    def intersect?(legend, view)
      unless legend.is_a?(Legend)
        raise TypeError, "Must be enother #{self.class}"
      end
      bounds1 = bounds(view)
      bounds2 = legend.bounds(view)
      bounds_intersect?(bounds1, bounds2)
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

    def mouse_over?(point2d, view)
      bounds(view).contains?(point2d)
    end

    def on_screen?(view)
      screen = Geom::BoundingBox.new
      screen.add(ORIGIN, [view.vpwidth, view.vpheight, 0])
      bounds_intersect?(screen, bounds(view))
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

    private

    # Wrapper method to handle SketchUp 2014 and older which had a bugged
    # implementation of Geom::BoundingBox.intersect
    #
    # @param [Geom::BoundingBox] bounds1
    # @param [Geom::BoundingBox] bounds2
    #
    # @return [Boolean]
    def bounds_intersect?(bounds1, bounds2)
      if Sketchup.version.to_i < 15
        return false if bounds1.empty? || bounds2.empty?

        return false if bounds1.max.x < bounds2.min.x
        return false if bounds1.min.x > bounds2.max.x

        return false if bounds1.max.y < bounds2.min.y
        return false if bounds1.min.y > bounds2.max.y

        return false if bounds1.max.z < bounds2.min.z
        return false if bounds1.min.z > bounds2.max.z
      end
      !bounds1.intersect(bounds2).empty?
    end

  end # class Legend


  # This currently assumes all legends are ShortEdgeLegends. If adding new ones
  # the handling needs to change.
  class LegendGroup < Legend

    attr_reader :legends

    def initialize(legend)
      super(legend.position)
      @legends = []
      add_legend(legend)
    end

    def add_legend(legend)
      @legends << legend
      nil
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

    def tooltip
      return @legends[0].tooltip if @legends.size == 1
      lengths = @legends.map { |legend| legend.edge.length }
      min = lengths.min
      max = lengths.max
      # Compare by string and not length to account for model unit precision.
      # We want a range to be displayed only if the range can be expressed with
      # the current model unit precision.
      if min.to_s == max.to_s
        "Short Edges (#{min})"
      else
        "Short Edges (#{min}–#{max})"
      end
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


  class ShortEdgeLegend < WarningLegend

    attr_reader :edge
    attr_reader :error

    def initialize(error, transformation)
      @error = error
      @edge = error.entities[0]
      point = Geometry.mid_point(edge).transform(transformation)
      super(point)
    end

    def tooltip
      return "" if @edge.deleted?
      "Short Edge (#{@edge.length})"
    end

  end # class ShortEdgeLegend


end # module TT::Plugins::SolidInspector2
