#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------

require "set"


module TT::Plugins::SolidInspector2

  require File.join(PATH, "gl_helper.rb")


  module ErrorFinder

    def self.find_errors(entities, transformation)
      raise TypeError unless entities.is_a?(Sketchup::Entities)

      errors = []
      border_edges = Set.new
      possible_internal_faces = Set.new
      possible_reversed_faces = Set.new

      # First check the edges.
      entities.grep(Sketchup::Edge) { |edge|
        num_faces = edge.faces.size
        if num_faces == 2
          # If an edge between two faces is reversed in both then one of the
          # faces needs to be reversed.
          face1, face2 = edge.faces
          if edge.reversed_in?(face1) == edge.reversed_in?(face2)
            possible_reversed_faces.merge(edge.faces)
          end
        elsif num_faces == 0
          errors << StrayEdge.new(edge)
          is_manifold = false
        elsif num_faces == 1
          # We want to later sort the edges by what hole they belong to.
          border_edges << edge
        elsif num_faces > 2
          # We don't know yet which of the edges are internal. We process these
          # later.
          possible_internal_faces.merge(edge.faces)
        end
      }

      if border_edges.size > 0
        border_edges.each { |edge|
          face = edge.faces.first
          if face.outer_loop.edges.include?(edge)
            # Face part of mesh border.
            # TODO: Sort edges by the border they belong to.
            errors << BorderEdge.new(edge)
          else
            errors << HoleEdge.new(edge)
          end
        }
      end

      if possible_internal_faces.size > 0
        # Determine which faces are internal.
        possible_internal_faces.each { |face|
          if self.internal_face?(face, transformation)
            errors << InternalFace.new(face)
          end
        }
      end

      # If there was no border edges or faces connected to more than two faces
      # then we can scan the surface of the mesh to check that the face normals
      # are oriented consistently.
      # Stray edges are ignored from this because they won't interfere with the
      # surface detection.
      is_manifold = border_edges.empty? && possible_internal_faces.empty?
      if is_manifold
        possible_reversed_faces.each { |face|
          if self.reversed_face?(face, transformation)
            errors << ReversedFace.new(face)
          end
        }
        # TODO: Take into account that all faces could be consistently faced
        # "inward" and they might all need to be reversed. Take one face and
        # check if it's facing "outward" - if it doesn't, reverse all the faces.
      end

      errors
    end


    def self.reversed_face?(face, transformation)
      entities = face.parent.entities
      centroid = self.centroid(face)
      # Shoot rays in the direction of the front side of the face. If we hit
      # odd number of intersections the face is facing "inward" in the manifold.
      ray = [centroid, face.normal]
      ray = self.transform_ray(ray, transformation)
      intersections = self.count_ray_intersections(ray, entities)
      intersections % 2 > 0
    end


    def self.internal_face?(face, transformation)
      entities = face.parent.entities
      # TODO: Check if the centroid is over a hole? Maybe use the centroid of
      # one of the face's triangles?
      centroid = self.centroid(face)
      # Shoot rays in each direction of the face and count how many times it
      # intersect with the current entities set.
      ray = [centroid, face.normal]
      ray = self.transform_ray(ray, transformation)
      intersections = self.count_ray_intersections(ray, entities)

      ray = [centroid, face.normal.reverse]
      ray = self.transform_ray(ray, transformation)
      intersections += self.count_ray_intersections(ray, entities)
      # Even number of intersections indiate the face is internal.
      intersections % 2 == 0
    end


    def self.count_ray_intersections(ray, entities)
      #Sketchup.active_model.active_entities.add_cpoint(ray.first)
      model = entities.model
      direction = ray[1]
      result = model.raytest(ray, false)
      count = 0
      until result.nil?
        raise "Safety Break!" if count > 100 # Temp safety limit.
        point, path = result
        # Check if the returned point hit within the instance.
        if path.last.parent.entities == entities
          count += 1
        end
        #Sketchup.active_model.active_entities.add_cpoint(ray.first)
        #Sketchup.active_model.active_entities.add_cpoint(point)
        #Sketchup.active_model.active_entities.add_cline(ray.first, point)
        ray = [point, direction]
        result = model.raytest(ray, false)
      end
      count
    end


    def self.centroid(face)
      points = face.vertices.map { |vertex| vertex.position }
      self.average(points)
    end


    def self.average(points)
      x = y = z = 0.0
      points.each { |point|
        x += point.x
        y += point.y
        z += point.z
      }
      num_points = points.size
      x /= num_points
      y /= num_points
      z /= num_points
      Geom::Point3d.new(x, y, z)
    end


    def self.transform_ray(ray, transformation)
      ray.map { |x| x.transform(transformation) }
    end

  end # module


  class SolidError

    ERROR_COLOR_EDGE = Sketchup::Color.new(255, 0, 0, 255).freeze
    ERROR_COLOR_FACE = Sketchup::Color.new(255, 0, 0, 128).freeze

    include GL_Helper

    attr_accessor :entity

    def initialize(entity)
      @entity = entity
      @fixed = false
      @erase_to_fix = false
    end

    def fix
      if @erase_to_fix
        return false if @entity.deleted?
        @entity.erase!
        @fixed = true
        true
      else
        raise NotImplementedError
      end
    end

    def fixed?
      @fixed ? true : false
    end

    def draw(view, transformation = nil)
      raise NotImplementedError
    end

  end # class


  # TODO: HiddenFace (?)
  # TODO: FaceHoleEdge
  # TODO: MeshHoleEdge (?)


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


  # Mix-in module to mark that an erro can be fixed by erasing the entity.
  # The purpose of this is to be able to perform a bulk erase operation which
  # is much faster than calling .erase! on each entity.
  module EraseToFix

    def initialize(*args)
      super
      @erase_to_fix = true
    end

  end # module


  # The edge a border edge, connected to one face, but not part of an inner
  # loop. It could be part of a stray face, border of a non-manifold surface or
  # part of a complex hole that needs multiple faces to heal.
  class BorderEdge < SolidError

    def draw(view, transformation = nil)
      view.drawing_color = ERROR_COLOR_EDGE
      draw_edge(view, @entity, transformation)
      nil
    end

  end # class


  # The edge is a border edge, connected to one face, and part of one of the
  # inner loops of the face.
  class HoleEdge < SolidError

    include EraseToFix

    def fix
      return false if @entity.deleted?
      # Find all the edges for the inner loop the edge is part of and erase all
      # of them.
      entities = @entity.parent
      face = @entity.faces.first
      edge_loop = face.loops.find { |loop| loop.edges.include?(@entity) }
      entities.erase_entities(edge_loop.edges)
      @fixed = true
      true
    end

    def draw(view, transformation = nil)
      view.drawing_color = ERROR_COLOR_EDGE
      draw_edge(view, @entity, transformation)
      nil
    end

  end # class


  # The face is located on the inside of what could be a manifold mesh.
  class InternalFace < SolidError

    include EraseToFix

    def draw(view, transformation = nil)
      view.drawing_color = ERROR_COLOR_FACE
      draw_face(view, @entity, transformation)
      # TODO: Draw edges? Maybe in 2d to ensure the face is seen?
      nil
    end

  end # class


  # The face is not oriented consistently with the rest of the surface of the
  # manifold. It is facing "inwards" and should be reversed.
  class ReversedFace < SolidError

    def fix
      return false if @entity.deleted?
      @entity.reverse!
      @fixed = true
      true
    end

    def draw(view, transformation = nil)
      view.drawing_color = ERROR_COLOR_FACE
      draw_face(view, @entity, transformation)
      nil
    end

  end # class


  # Stray edges which isn't part in forming any faces.
  class StrayEdge < SolidError

    include EraseToFix

    def draw(view, transformation = nil)
      view.drawing_color = ERROR_COLOR_EDGE
      draw_edge(view, @entity, transformation)
      nil
    end

  end # class


  # TODO: Is this needed? STL export flattens the nested hierarchy of instances.
  # Maybe it shouldn't "fix" by exploding but instead yield a message to why
  # SketchUp's Enity Info dialog doesn't say "Solid".
  class NestedInstance < SolidError

    def fix
      return false if @entity.deleted?
      @entity.explode
      @fixed = true
      true
    end

    def draw(view, transformation = nil)
      view.drawing_color = ERROR_COLOR_EDGE
      draw_instance(view, @entity, transformation)
      nil
    end

  end # class

end # module TT::Plugins::SolidInspector2
