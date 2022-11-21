#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------


module TT::Plugins::SolidInspector2
  module DrawingHelper

    def adjust_to_pixel_grid(points, mid_pixel = false)
      points.map { |point|
        point.x = point.x.to_i
        point.y = point.y.to_i
        point.z = point.z.to_i
        if mid_pixel
          point.x -= 0.5
          point.y -= 0.5
          point.z -= 0.5
        end
        point
      }
    end

    def draw2d_point_square(point, size, view)
      half_size = size / 2.0
      points = [
        point.offset([-half_size, -half_size, 0]),
        point.offset([ half_size, -half_size, 0]),
        point.offset([ half_size,  half_size, 0]),
        point.offset([-half_size,  half_size, 0])
      ]
      points = adjust_to_pixel_grid(points)
      view.draw2d(GL_QUADS, points)
    end

    def mid_point(edge)
      pt1, pt2 = edge.vertices.map { |vertex| vertex.position }
      Geom.linear_combination(0.5, pt1, 0.5, pt2)
    end

    def offset_points(points, vector)
      points.map { |point| point.offset(vector) }
    end

    def screen_point(point, view)
      point2d = view.screen_coords(point)
      point2d.z = 0
      point2d
    end

  end # module DrawingHelper
end # module TT::Plugins::SolidInspector2
