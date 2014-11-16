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

    def self.find_errors(entities, transformation, debug = false)
      raise TypeError unless entities.is_a?(Sketchup::Entities)

      # TODO: Separate entities in group of them being connected to each other.

      errors = []
      border_edges = Set.new
      possible_internal_faces = Set.new
      possible_reversed_faces = Set.new
      edges_with_internal_faces = Set.new

      Sketchup.status_text = "Inspecting edges..."

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
          edges_with_internal_faces << edge
        end
      }

      Sketchup.status_text = "Analyzing edges..."

      if border_edges.size > 0
        mesh_border_edges = []
        hole_edges = []

        border_edges.each { |edge|
          face = edge.faces.first
          if face.outer_loop.edges.include?(edge)
            mesh_border_edges << edge
          else
            hole_edges << edge
          end
        }

        Sketchup.status_text = "Sorting surface borders..."
        self.group_connected_edges(mesh_border_edges).each { |edges|
          errors << SurfaceBorder.new(edges)
        }

        Sketchup.status_text = "Sorting face holes..."
        self.group_connected_edges(hole_edges).each { |edges|
          errors << FaceHole.new(edges)
        }
      end


      if edges_with_internal_faces.size > 0 && border_edges.size > 0
        # Cannot determine what faces are internal until all holes in the mesh
        # is closed.
        edges_with_internal_faces.each { |edge|
          errors << InternalFaceEdge.new(edge)
        }
      elsif edges_with_internal_faces.size > 0

        # Determine which faces are internal.

        if debug
          model = Sketchup.active_model
          model.start_operation("Find Internal Faces")

          outer_front_material = model.materials.add("Outer Skin Front Face")
          outer_front_material.color = Sketchup::Color.new(0, 255, 0)

          outer_back_material = model.back_materials.add("Outer Skin Back Face")
          outer_back_material.color = Sketchup::Color.new(0, 128, 0)

          inner_front_material = model.materials.add("Inner Skin Front Face")
          inner_front_material.color = Sketchup::Color.new(255, 0, 0)

          inner_back_material = model.back_materials.add("Inner Skin Back Face")
          inner_back_material.color = Sketchup::Color.new(128, 0, 0)
        end

        Sketchup.status_text = "Finding external faces by ray tracing..."

        # Shoot rays to find outer skin faces that we are 100% certain are not
        # internal.
        start_time = Time.new
        outer_faces = Set.new
        entities.grep(Sketchup::Face) { |face|
          if self.face_outward?(face, transformation, true)
            if debug
              face.material = outer_front_material
              face.back_material = outer_back_material
            end
            outer_faces << face
          elsif self.face_outward?(face, transformation, false)
            if debug
              face.material = outer_front_material
              face.back_material = outer_back_material
            end
            outer_faces << face
            errors << ReversedFace.new(face)
            possible_reversed_faces.delete(face)
          else
            possible_internal_faces << face
          end
        }
        elapsed_time = Time.now - start_time
        puts "> Ray tracing took: #{elapsed_time}s"

        Sketchup.status_text = "Finding internal faces..."

        # Find faces that we know for sure must be internal.
        possible_internal_faces.to_a.each { |face|
          is_internal = face.edges.any? { |edge|
            outer = edge.faces.reject { |f|
              f == face || !outer_faces.include?(f)
            }
            outer.size > 1
          }
          if is_internal
            if debug
              face.material = inner_front_material
              face.back_material = inner_back_material
            end
            errors << InternalFace.new(face)
            possible_internal_faces.delete(face)
          end
        }

        # Iteratively find outer skin faces. We are looking for faces where at
        # least two of it's edges connect to one other face confirmed to not be
        # internal. We keep refining this until we find now new faces that match
        # this criteria.
        materials = []
        materials_back = []

        i = 0
        loop do
          i += 1

          Sketchup.status_text = "Refining search for internal faces (#{i})..."

          puts "> Refine: #{i}"
          if debug
            material = entities.model.materials.add("RefineFront")
            back_material = entities.model.materials.add("RefineBack")
            materials << material
            materials_back << back_material
          end

          new_outer = Set.new

          possible_internal_faces.to_a.each { |face|
            outer_neighbours = face.edges.select { |edge|
              edge.faces.any? { |f| outer_faces.include?(f) }
            }
            if outer_neighbours.size > 1
              if debug
                face.material = material
                face.back_material = back_material
              end
              new_outer << face
            end
          }

          outer_faces.merge(new_outer)
          possible_internal_faces.subtract(new_outer)

          break if new_outer.empty?
          raise "Safety Break!" if i > 100 # Temp safety limit.
        end

        if debug && materials.size > 1
          puts "> Adjusting refinement colors..."
          puts "  > #{materials.size}"

          front_color_step = 192.0 / materials.size
          back_color_step = 128.0 / materials.size

          materials.size.times { |i|
            front_color = (front_color_step * i).to_i
            material = materials[i]
            material.color = Sketchup::Color.new(front_color, front_color, 255)

            back_color = (back_color_step * i).to_i
            back_material = materials_back[i]
            back_material.color = Sketchup::Color.new(back_color, back_color, 128)
          }
        end

        if debug
          model.commit_operation
        end

        # The remaining faces should all be internal faces.
        possible_internal_faces.each { |face|
          errors << InternalFace.new(face)
        }
      end

      # If there was no border edges or faces connected to more than two faces
      # then we can scan the surface of the mesh to check that the face normals
      # are oriented consistently.
      # Stray edges are ignored from this because they won't interfere with the
      # surface detection.
      is_manifold = border_edges.empty? && edges_with_internal_faces.empty?
      if is_manifold

        Sketchup.status_text = "Analyzing face normals..."

        possible_reversed_faces.each { |face|
          # TODO: Smarter detection of reversed faces when multiple reversed
          # faces are connected.
          if self.reversed_face?(face, transformation)
            errors << ReversedFace.new(face)
          end
        }
        # TODO: Take into account that all faces could be consistently faced
        # "inward" and they might all need to be reversed. Take one face and
        # check if it's facing "outward" - if it doesn't, reverse all the faces.
      end

      Sketchup.status_text = ""

      errors
    end


    def self.reversed_face?(face, transformation)
      entities = face.parent.entities
      point_on_face = self.point_on_face(face)
      # Shoot rays in the direction of the front side of the face. If we hit
      # odd number of intersections the face is facing "inward" in the manifold.
      ray = [point_on_face, face.normal]
      ray = self.transform_ray(ray, transformation)
      intersections = self.count_ray_intersections(ray, entities)
      intersections % 2 > 0
    end


    def self.face_outward?(face, transformation, front_face_direction = true)
      entities = face.parent.entities
      # TODO: Check if the centroid is over a hole? Maybe use the centroid of
      # one of the face's triangles?
      point_on_face = self.point_on_face(face)
      # Shoot rays in each direction of the face and count how many times it
      # intersect with the current entities set.
      direction = front_face_direction ? face.normal : face.normal.reverse!
      ray = [point_on_face, direction]
      ray = self.transform_ray(ray, transformation)
      !self.hit_entities?(ray, entities)
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


    def self.hit_entities?(ray, entities)
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
          return true
        end
        #Sketchup.active_model.active_entities.add_cpoint(ray.first)
        #Sketchup.active_model.active_entities.add_cpoint(point)
        #Sketchup.active_model.active_entities.add_cline(ray.first, point)
        ray = [point, direction]
        result = model.raytest(ray, false)
      end
      false
    end


    def self.point_on_face(face)
      mesh = face.mesh(0) # TODO: Constant
      points = mesh.polygon_points_at(1)
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


    def self.group_connected_edges(edges)
      # Group connected error-edges.
      groups = []
      stack = edges.clone
      until stack.empty?
        cluster = []
        cluster << stack.shift

        # Find connected errors
        edge = cluster.first
        haystack = ([edge.start.edges + edge.end.edges] - [edge]).first & stack
        until haystack.empty?
          e = haystack.shift

          if stack.include?( e )
            cluster << e
            stack.delete( e )
            haystack += ([e.start.edges + e.end.edges] - [e]).first & stack
          end
        end

        groups << cluster
      end
      groups
    end

  end # module


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


  module Fixable
  end # module


  # Mix-in module to mark that an erro can be fixed by erasing the entity.
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


  # The edge a border edge, connected to one face, but not part of an inner
  # loop. It could be part of a stray face, border of a non-manifold surface or
  # part of a complex hole that needs multiple faces to heal.
  class BorderEdge < SolidError

    def self.display_name
      "Border Edges"
    end

    def self.description
      "Border edges are connected to only one face and therefore doesn't form "\
      "a manifold. These cannot be fixed automatically and must be fixed by "\
      "hand."
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
      "Hole edges are edges forming a hole within a face. These can be fixed "\
      "automatically by removing the hole all together."
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
      "determine which faces are internal. Fix the holes in the mesh and then "\
      "run the tool again."
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
      "be a solid. These can be automatically fixed by erasing them."
    end

    def draw(view, transformation = nil)
      view.drawing_color = ERROR_COLOR_FACE
      draw_face(view, @entities[0], transformation)
      # TODO: Draw edges? Maybe in 2d to ensure the face is seen?
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
      "face normal (direciton) isn't all uniform. The front side of a face "\
      "must be facing outwards. These can be fixed automatically by reversing "\
      "the faces."
    end

    def fix
      return false if @entities[0].deleted?
      @entities[0].reverse!
      @fixed = true
      true
    end

    def draw(view, transformation = nil)
      view.drawing_color = ERROR_COLOR_FACE
      draw_face(view, @entities[0], transformation)
      nil
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
      "of solids. These can automatically fixed by erasing them."
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
      "Edges that form the border of a surface or a hole in the mesh."
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
      "Edges that form the a hole in a face."
    end

    def draw(view, transformation = nil)
      view.drawing_color = ERROR_COLOR_EDGE
      @entities.each { |edge|
        draw_edge(view, edge, transformation)
      }
      nil
    end

  end # class


  # TODO: Is this needed? STL export flattens the nested hierarchy of instances.
  # Maybe it shouldn't "fix" by exploding but instead yield a message to why
  # SketchUp's Enity Info dialog doesn't say "Solid".
  class NestedInstance < SolidError

    def self.display_name
      "Nested Instances"
    end

    def fix
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

end # module TT::Plugins::SolidInspector2
