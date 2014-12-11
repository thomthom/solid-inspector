#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------

require "set"


module TT::Plugins::SolidInspector2

  require File.join(PATH, "errors.rb")


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
          errors << SolidErrors::StrayEdge.new(edge)
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
          errors << SolidErrors::SurfaceBorder.new(edges)
        }

        Sketchup.status_text = "Sorting face holes..."
        self.group_connected_edges(hole_edges).each { |edges|
          errors << SolidErrors::FaceHole.new(edges)
        }
      end


      if edges_with_internal_faces.size > 0 && border_edges.size > 0
        # Cannot determine what faces are internal until all holes in the mesh
        # is closed.
        edges_with_internal_faces.each { |edge|
          errors << SolidErrors::InternalFaceEdge.new(edge)
        }
      elsif edges_with_internal_faces.size > 0

        # Determine which faces are internal.

        if debug
          model = Sketchup.active_model
          model.start_operation("Find Internal Faces")

          outer_front_material = model.materials.add("Outer Skin Front Face")
          outer_front_material.color = Sketchup::Color.new(0, 255, 0)

          outer_back_material = model.materials.add("Outer Skin Back Face")
          outer_back_material.color = Sketchup::Color.new(0, 128, 0)

          inner_front_material = model.materials.add("Inner Skin Front Face")
          inner_front_material.color = Sketchup::Color.new(255, 0, 0)

          inner_back_material = model.materials.add("Inner Skin Back Face")
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
            errors << SolidErrors::ReversedFace.new(face)
            possible_reversed_faces.delete(face)
          else

            face.material = "Purple" if debug
            face.back_material = face.material if debug

            possible_internal_faces << face
          end
        }
        elapsed_time = Time.now - start_time
        puts "> Ray tracing took: #{elapsed_time}s"

        Sketchup.status_text = "Finding internal faces..."

        internal_faces = Set.new

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
            internal_faces << face
            errors << SolidErrors::InternalFace.new(face)
            possible_internal_faces.delete(face)
          end
        }

        # Iteratively find outer skin faces. We are looking for faces where at
        # least two of it's edges connect to one other face confirmed to not be
        # internal. We keep refining this until we find no new faces that match
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

          # TODO: This isn't reliable. Need to iteratively find faces that are
          # connected to other faces verified to be internal. If any of the
          # edges have faces that all are marked for removal this face should be
          # also marked for removal.
          possible_internal_faces.to_a.each { |face|

            outer_neighbours = face.edges.select { |edge|
              edge.faces.any? { |f| outer_faces.include?(f) }
            }

            inner_neighbours = face.edges.select { |edge|
              edge.faces.all? { |f| f == face || internal_faces.include?(f) }
            }

            if outer_neighbours.size > 1 && inner_neighbours.empty?
              if debug #&& false # Reversed faces refinements
                face.material = material
                face.back_material = back_material
              end

              face.material = Sketchup::Color.new(0, 92, 0) if debug
              face.back_material = face.material if debug

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
          errors << SolidErrors::InternalFace.new(face)
        }
      end

      # If there was no border edges or faces connected to more than two faces
      # then we can scan the surface of the mesh to check that the face normals
      # are oriented consistently.
      # Stray edges are ignored from this because they won't interfere with the
      # surface detection.
      #
      # TODO(thomthom): When there are no border edges, perform this check by
      # ignoring the faces marked as internal.
      is_manifold = border_edges.empty? && edges_with_internal_faces.empty?
      if is_manifold

        Sketchup.status_text = "Analyzing face normals..."

        processed = Set.new()
        stack = possible_reversed_faces.to_a
        i = 0
        until stack.empty?
          face = stack.shift
          next if processed.include?(face)
          if self.reversed_face?(face, transformation)
            errors << SolidErrors::ReversedFace.new(face)
            faces = face.edges.map { |edge| edge.faces }
            faces.flatten!
            faces.reject! { |f|
              processed.include?(f) || possible_reversed_faces.include?(f)
            }
            processed << face
            stack.concat(faces)
          end
          i += 1
          raise "Safety Break!" if i > 1000 # Temp safety limit.
        end
      end

      Sketchup.status_text = ""

      errors
    end


    def self.fix_errors(errors, entities)
      # For performance reasons we sort out the different errors and handle them
      # differently depending on their traits.
      entities_to_be_erased = Set.new
      remaining_errors = []
      errors.each { |error|
        if error.is_a?(SolidErrors::EraseToFix)
          # We want to collect all the entities that can be erased and erase
          # them in one bulk operation for performance gain.
          entities_to_be_erased.merge(error.entities)
        else
          # All the others will be fixed one by one after erasing entities.
          remaining_errors << error
        end
      }

      # We want to erase the edges that are separating faces that are being
      # erased. Otherwise the operation leaves stray edges behind.
      stray_edges = Set.new
      entities_to_be_erased.grep(Sketchup::Face) { |face|
        face.edges.each { |edge|
          if edge.faces.all? { |f| entities_to_be_erased.include?(f) }
            stray_edges << edge
          end
        }
      }
      entities_to_be_erased.merge(stray_edges)

      # For extra safety we validate the entities.
      entities_to_be_erased.reject! { |entity| entity.deleted? }

      # Now we're ready to perform the cleanup operations.
      model = entities.model
      begin
        model.start_operation("Fix Solid", true)
        entities.erase_entities(entities_to_be_erased.to_a)
        remaining_errors.each { |error|
          begin
            error.fix
          rescue NotImplementedError => e
            p e
          end
        }
        model.commit_operation
      rescue
        #model.abort_operation
        model.commit_operation
        raise
      end
      nil
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

  end # module ErrorFinder

end # module TT::Plugins::SolidInspector2
