#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------


module TT::Plugins::SolidInspector2
  module GL_Helper

    private

    POLYGON_MESH_POINTS    = 0
    POLYGON_MESH_UVQ_FRONT = 1
    POLYGON_MESH_UVQ_BACK  = 2
    POLYGON_MESH_NORMALS   = 4

    PIXEL_OFFSET = 1

    def draw_instance(view, instance)
      points = boundingbox_segments(instance.bounds)
      view.line_stipple = ""
      view.line_width = 2
      view.draw(GL_LINES, points)
      nil
    end

    def draw_edge(view, edge)
      points = offset_toward_camera(view, edge.vertices)
      view.line_stipple = ""
      view.line_width = 3
      view.draw(GL_LINES, points)
      nil
    end

    def draw_face(view, face)
      mesh = face.mesh(POLYGON_MESH_POINTS)
      points = offset_toward_camera(view, mesh.points)
      triangles = []
      mesh.polygons.each { |polygon|
        polygon.each { |index|
          # Indicies start at 1 and can be negative to indicate edge smoothing.
          # Must take this into account when looking up the points in our array.
          triangles << points[index.abs - 1]
        }
      }
      view.draw(GL_TRIANGLES, triangles)
      nil
    end

    def offset_toward_camera(view, *args)
      if args.size > 1
        return offset_toward_camera(args)
      end
      points = args.first
      offset_direction = view.camera.direction.reverse!
      points.map { |point|
        point = point.position if point.respond_to?(:position)
        # Model.pixels_to_model converts argument to integers.
        size = view.pixels_to_model(2, point) * 0.01
        point.offset(offset_direction, size)
      }
    end

    def boundingbox_segments(boundingbox)
      points = []

      points << boundingbox.corner(0)
      points << boundingbox.corner(1)

      points << boundingbox.corner(1)
      points << boundingbox.corner(3)

      points << boundingbox.corner(3)
      points << boundingbox.corner(2)

      points << boundingbox.corner(2)
      points << boundingbox.corner(0)

      points << boundingbox.corner(0)
      points << boundingbox.corner(4)

      points << boundingbox.corner(1)
      points << boundingbox.corner(5)

      points << boundingbox.corner(3)
      points << boundingbox.corner(7)

      points << boundingbox.corner(2)
      points << boundingbox.corner(6)

      points << boundingbox.corner(4)
      points << boundingbox.corner(5)

      points << boundingbox.corner(5)
      points << boundingbox.corner(7)

      points << boundingbox.corner(7)
      points << boundingbox.corner(6)

      points << boundingbox.corner(6)
      points << boundingbox.corner(4)

      points
    end

  end # module GL_Helper
end # module TT::Plugins::SolidInspector2
