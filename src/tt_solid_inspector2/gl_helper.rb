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


    def draw_instance(view, instance, transformation = nil)
      return false if instance.deleted?
      points = boundingbox_segments(instance.bounds)
      transform_points(points, transformation)
      view.line_stipple = ""
      view.line_width = 2
      view.draw(GL_LINES, points)
      true
    end


    def draw_edge(view, edge, transformation = nil)
      return false if edge.deleted?
      points = offset_toward_camera(view, edge.vertices)
      transform_points(points, transformation)
      view.line_stipple = ""
      view.line_width = 3
      view.draw(GL_LINES, points)
      true
    end


    def draw_face(view, face, transformation = nil, texture_id: nil)
      return false if face.deleted?

      flags = POLYGON_MESH_POINTS
      flags |= POLYGON_MESH_UVQ_BACK if texture_id

      mesh = face.mesh(flags)
      mesh_points = offset_toward_camera(view, mesh.points)
      mesh_uvs = mesh.uvs(false)
      transform_points(mesh_points, transformation)
      triangles = []
      uvs = []
      mesh.polygons.each { |polygon|
        polygon.each { |index|
          # Indicies start at 1 and can be negative to indicate edge smoothing.
          # Must take this into account when looking up the points in our array.
          i = index.abs - 1
          triangles << mesh_points[i]
          uvs << mesh_uvs[i] if texture_id
        }
      }
      if texture_id
        view.draw(GL_TRIANGLES, triangles, texture: texture_id, uvs: uvs)
      else
        view.draw(GL_TRIANGLES, triangles)
      end
      true
    end


    def transform_points(points, transformation)
      return false if transformation.nil?
      points.each { |point| point.transform!(transformation) }
      true
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
