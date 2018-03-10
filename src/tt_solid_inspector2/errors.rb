#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------

require "set"


module TT::Plugins::SolidInspector2

  require File.join(PATH, "gl_helper.rb")


  module SolidErrors

    class SolidError

      ERROR_COLOR_EDGE = Sketchup::Color.new(255, 0, 0, 255).freeze
      ERROR_COLOR_FACE = Sketchup::Color.new(255, 0, 0, 128).freeze

      include GL_Helper

      def self.type_name
        self.name.split("::").last
      end

      def self.display_name
        self.name
      end

      def self.description
        ""
      end

      attr_accessor :entities

      def initialize(entities)
        raise TypeError if entities.nil?
        if entities.is_a?(Enumerable)
          @entities = entities.clone
        else
          @entities = [entities]
        end
        @fixed = false
      end

      def fix
        raise NotImplementedError
      end

      def fixed?
        @fixed ? true : false
      end

      # TODO: This should be a class property.
      def fixable?
        is_a?(Fixable)
      end

      def draw(view, transformation = nil)
        raise NotImplementedError
      end

      def to_json(*args)
        data = {
          :id         => object_id,
          :is_fixable => fixable?
        }
        data.to_json(*args)
      end

    end # class


    # Healing MeshHoles:
    # c1 = average of hole vertices
    #
    # pts = []
    # for each edge in hole
    #   pts << project c1 to face.plane connected to edge
    # end
    # c2 = average of pts
    #
    # c3 = average of c1 and c2
    #
    # for each edge in hole
    #   add face from edge vertices to c3
    # end


    module Fixable
    end # module


    # Mix-in module to mark that an error can be fixed by erasing the entity.
    # The purpose of this is to be able to perform a bulk erase operation which
    # is much faster than calling .erase! on each entity.
    module EraseToFix

      include Fixable

      def fix
        entity = @entities.find { |entity| entity.valid? }
        return false if entity.nil?
        entities = entity.parent.entities
        entities.erase_entities(@entities)
        @fixed = true
        true
      end

    end # module


    # The face is hidden itself.
    # Faces hidden because their group or layer is invisible are not reported.
    class HiddenFace < SolidError
      
      include Fixable
      
      def self.display_name
        "Hidden Faces"
      end

      def self.description
        "Hidden faces will not be exported to STL file, and may cause holes "\
        "in a mesh."
      end

      def fix
        face = @entities[0]
        return false if face.deleted?

        face.visible=true

        @fixed = true
        true
      end

      def draw(view, transformation = nil)
        view.drawing_color = ERROR_COLOR_FACE
        draw_face(view, @entities[0], transformation)
        view.drawing_color = ERROR_COLOR_EDGE
        @entities[0].edges.each { |edge|
          draw_edge(view, edge, transformation)
        }
        nil
      end

    end # class


    # The edge a border edge, connected to one face, but not part of an inner
    # loop. It could be part of a stray face, border of a non-manifold surface
    # or part of a complex hole that needs multiple faces to heal.
    class BorderEdge < SolidError

      def self.display_name
        "Border Edges"
      end

      def self.description
        "Border edges are connected to only one face and therefore doesn't "\
        "form a manifold. These cannot be fixed automatically and must be "\
        "fixed by hand."
      end

      def draw(view, transformation = nil)
        view.drawing_color = ERROR_COLOR_EDGE
        draw_edge(view, @entities[0], transformation)
        nil
      end

    end # class


    # The edge is a border edge, connected to one face, and part of one of the
    # inner loops of the face.
    class HoleEdge < SolidError

      include EraseToFix

      def self.display_name
        "Hole Edges"
      end

      def self.description
        "Hole edges are edges forming a hole within a face. These are "\
        "fixed automatically by removing the hole all together."
      end

      def fix
        return false if @entities[0].deleted?
        # Find all the edges for the inner loop the edge is part of and erase all
        # of them.
        entities = @entities[0].parent
        face = @entities[0].faces.first
        edge_loop = face.loops.find { |loop| loop.edges.include?(@entities[0]) }
        entities.erase_entities(edge_loop.edges)
        @fixed = true
        true
      end

      def draw(view, transformation = nil)
        view.drawing_color = ERROR_COLOR_EDGE
        draw_edge(view, @entities[0], transformation)
        nil
      end

    end # class


    # This class is used to mark edges connected to internal faces when the mesh
    # has holes which prevent the inner face detection from working reliably.
    class InternalFaceEdge < SolidError

      def self.display_name
        "Internal Face Edges"
      end

      def self.description
        "Internal face edges are edges connected to internal faces. However, "\
        "if there are holes in the mesh it is not possible to reliably "\
        "determine which faces are internal. Fix the holes in the mesh and "\
        "then run the tool again."
      end

      def draw(view, transformation = nil)
        view.drawing_color = ERROR_COLOR_EDGE
        draw_edge(view, @entities[0], transformation)
        nil
      end

    end # class


    # The face is located on the inside of what could be a manifold mesh.
    class InternalFace < SolidError

      include EraseToFix

      def self.display_name
        "Internal Faces"
      end

      def self.description
        "Internal faces are faces located on the inside of a mesh that should "\
        "be a solid. These are automatically fixed by erasing the internal "\
        "faces."
      end

      def draw(view, transformation = nil)
        view.drawing_color = ERROR_COLOR_FACE
        draw_face(view, @entities[0], transformation)
        # TODO: Draw edges? Maybe in 2d to ensure the face is seen?
        nil
      end

    end # class


    # The face is located on the inside of what could be a manifold mesh.
    class ExternalFace < SolidError

      include EraseToFix

      def self.display_name
        "External Faces"
      end

      def self.description
        "External faces are faces located on the outside of a mesh that should "\
        "be a solid. These are automatically fixed by erasing the internal "\
        "faces."
      end

      def draw(view, transformation = nil)
        view.drawing_color = ERROR_COLOR_FACE
        draw_face(view, @entities[0], transformation)
        nil
      end

    end # class


    # The face is not oriented consistently with the rest of the surface of the
    # manifold. It is facing "inwards" and should be reversed.
    class ReversedFace < SolidError

      include Fixable

      def self.display_name
        "Reversed Faces"
      end

      def self.description
        "Many applications will not be able to treat a mesh as a solid if the "\
        "face normal (direction) isn't all uniform. The front side of a face "\
        "must be facing outwards. These can be fixed automatically by "\
        "reversing the faces."
      end

      def fix
        face = @entities[0]
        return false if face.deleted?

        # First read the UV data before we reverse the face. Otherwise the
        # UV data will be destroyed.
        front_material = face.material
        back_material = face.back_material

        front_mapping = uv_mapping(face, true)
        back_mapping = uv_mapping(face, false)

        front_projection = get_projection(face, true)
        back_projection = get_projection(face, false)

        # Now the face can be reversed before we apply the materials again.
        # This must be done here because reversing the face destroy the UV
        # mapping applied.
        face.reverse!

        apply_material(face, back_material, back_mapping, true)
        apply_material(face, front_material, front_mapping, false)

        apply_projection(face, back_projection, true)
        apply_projection(face, front_projection, false)

        @fixed = true
        true
      end

      def draw(view, transformation = nil)
        view.drawing_color = ERROR_COLOR_FACE
        draw_face(view, @entities[0], transformation)
        view.drawing_color = ERROR_COLOR_EDGE
        @entities[0].edges.each { |edge|
          draw_edge(view, edge, transformation)
        }
        nil
      end

      private

      def uv_mapping(face, front)
        material = (front) ? face.material : face.back_material
        if material && material.texture
          start_point = face.vertices.first.position
          #start_point.transform!(face.model.edit_transform.inverse)

          points = [start_point]
          points << points[0].offset(face.normal.axes.x, 10)
          points << points[0].offset(face.normal.axes.y, 10)
          points << points[1].offset(face.normal.axes.y, 10)

          tw = Sketchup.create_texture_writer
          uvh = face.get_UVHelper(true, true, tw)

          entities = face.parent.entities

          mapping = []
          points.each_with_index { |point, index|
            uvq = (front) ? uvh.get_front_UVQ(point) : uvh.get_back_UVQ(point)
            mapping << point
            mapping << uvq_to_uv(uvq)
          }

          mapping
        else
          nil
        end
      end

      def apply_material(face, material, uv_mapping, front)
        if material && uv_mapping
          face.position_material(material, uv_mapping, front)
        else
          if front
            face.material = material
          else
            face.back_material = material
          end
        end
        nil
      end

      def uvq_to_uv(uvq)
        Geom::Point3d.new(uvq.x / uvq.z, uvq.y / uvq.z, 1.0)
      end

      def apply_projection(face, projection, front)
        if projection && face.respond_to?(:set_texture_projection)
          face.set_texture_projection(projection, front)
        end
        nil
      end

      def get_projection(face, front)
        if face.respond_to?(:get_texture_projection)
          face.get_texture_projection(front)
        else
          nil
        end
      end

    end # class


    # Stray edges which isn't part in forming any faces.
    class StrayEdge < SolidError

      include EraseToFix

      def self.display_name
        "Stray Edges"
      end

      def self.description
        "Stray edges are not connected to any faces and doesn't form any part "\
        "of solids. These are automatically fixed by erasing the stray edges."
      end

      def draw(view, transformation = nil)
        view.drawing_color = ERROR_COLOR_EDGE
        draw_edge(view, @entities[0], transformation)
        nil
      end

    end # class


    # Edges that form the border of a surface or a hole in the mesh.
    class SurfaceBorder < SolidError

      def self.display_name
        "Surface Borders"
      end

      def self.description
        "Edges that form the border of a surface or a hole in the mesh. "\
        "These cannot be fixed automatically. Manually close the mesh and "\
        "run the tool again."
      end

      def draw(view, transformation = nil)
        view.drawing_color = ERROR_COLOR_EDGE
        @entities.each { |edge|
          draw_edge(view, edge, transformation)
        }
        nil
      end

    end # class


    # Edges that form the a hole in a face.
    class FaceHole < SolidError

      include EraseToFix

      def self.display_name
        "Face Holes"
      end

      def self.description
        "Edges that form the a hole in a face. These are fixed automatically "\
        "by erasing the hole."
      end

      def draw(view, transformation = nil)
        view.drawing_color = ERROR_COLOR_EDGE
        @entities.each { |edge|
          draw_edge(view, edge, transformation)
        }
        nil
      end

    end # class


    # TODO: Is this needed? STL export flattens the nested hierarchy of
    #   instances.
    # Maybe it shouldn't "fix" by exploding but instead yield a message to why
    # SketchUp's Entity Info dialog doesn't say "Solid".
    class NestedInstance < SolidError

      def self.display_name
        "Nested Instances"
      end

      def self.description
        "Nested instances will be exported correctly to STL file format by "\
        "the Trimble SketchUp STL exporter, but SketchUp's Solid Tools and "\
        "#{PLUGIN_NAME} doesn't treat nested instances as a solid."
      end

      def fix
        # For now we don't try to "fix" anything. As the fix should be opted in
        # for. Maybe a preference?
        raise NotImplementedError

        return false if @entities[0].deleted?
        @entities[0].explode
        @fixed = true
        true
      end

      def draw(view, transformation = nil)
        view.drawing_color = ERROR_COLOR_EDGE
        draw_instance(view, @entities[0], transformation)
        nil
      end

    end # class


    class ImageEntity < SolidError

      def self.display_name
        "Image Entity"
      end

      def self.description
        "Image entities isn't exported by the Trimble SketchUp STL exporter, "\
        "but it prevent SketchUp's Solid Tools from performing it's "\
        "operations on the object."
      end

      def draw(view, transformation = nil)
        view.drawing_color = ERROR_COLOR_EDGE
        draw_instance(view, @entities[0], transformation)
        nil
      end

    end # class


    class ShortEdge < SolidError

      def self.display_name
        "Short Edges"
      end

      def self.description
        "Small geometry might cause unpredictable results due to precision "\
        "errors. It's beneficial to try to avoid such small geometry. This "\
        "cannot be automatically fixed. You might want to scale the model up "\
        "by factors of 10 to work around such problems."
      end

      def draw(view, transformation = nil)
        view.drawing_color = ERROR_COLOR_EDGE
        draw_edge(view, @entities[0], transformation)
        nil
      end

    end # class

  end # module SolidErrors

end # module TT::Plugins::SolidInspector2
