#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------

require "set"


module TT::Plugins::SolidInspector2

  require File.join(PATH, "errors.rb")
  require File.join(PATH, "shell.rb")


  module ErrorFinder

    def self.find_errors(entities, transformation, debug = false)
      raise TypeError unless entities.is_a?(Sketchup::Entities)

      if Settings.debug_mode?
        puts ""
        puts "ErrorFinder.find_errors"
      end
      total_start_time = Time.new

      # TODO: Separate entities in group of them being connected to each other.

      errors = []
      border_edges = Set.new
      possible_internal_faces = Set.new
      possible_reversed_faces = Set.new
      edges_with_internal_faces = Set.new
      internal_faces = Set.new
      reversed_faces = Set.new
      oriented_faces = Set.new
      all_faces = entities.grep(Sketchup::Face)

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

        Sketchup.status_text = "Resolving manifold..."

        start_time = Time.new

        shell = Shell.new(entities)
        Sketchup.active_model.start_operation("Shellify", true) # DEBUG
        shell.resolve
        Sketchup.active_model.commit_operation # DEBUG
        shell.internal_faces.each { |face|
          errors << SolidErrors::InternalFace.new(face)
        }

        elapsed_time = Time.now - start_time
        if Settings.debug_mode?
          puts "> Resolving manifold took: #{elapsed_time}s"
        end
      end


      # Detect if there are nested entities.
      start_time = Time.new
      groups = entities.grep(Sketchup::Group)
      components = entities.grep(Sketchup::ComponentInstance)
      instances = groups + components
      instances.each { |instance|
        errors << SolidErrors::NestedInstance.new(instance)
      }
      elapsed_time = Time.now - start_time
      if Settings.debug_mode?
        puts "> Instance detection took: #{elapsed_time}s"
      end


      # Detect image entities.
      start_time = Time.new
      entities.grep(Sketchup::Image) { |image|
        errors << SolidErrors::ImageEntity.new(image)
      }
      elapsed_time = Time.now - start_time
      if Settings.debug_mode?
        puts "> Image detection took: #{elapsed_time}s"
      end


      # Detect small edges.
      if Settings.detect_short_edges?
        start_time = Time.new
        self.find_short_edges(entities) { |edge|
          errors << SolidErrors::ShortEdge.new(edge)
        }
        elapsed_time = Time.now - start_time
        if Settings.debug_mode?
          puts "> Short edge detection took: #{elapsed_time}s"
        end
      end


      Sketchup.status_text = ""

      elapsed_time = Time.now - total_start_time
      if Settings.debug_mode?
        puts "> Total analysis took: #{elapsed_time}s"
        puts ""
      end

      errors
    end


    def self.find_short_edges(entities, &block)
      threshold = Settings.short_edge_threshold
      entities.grep(Sketchup::Edge) { |edge|
        if edge.length < threshold
          block.call(edge)
        end
      }
      nil
    end


    def self.find_largest_faces(faces)
      faces.max { |a, b| a.area <=> b.area }
    end


    def self.find_start_face(faces, transformation)
      # We try to inspect the largest faces first in an attempt to avoid
      # precision issues that might occur with tiny faces.
      sorted_faces = faces.sort { |a, b| b.area <=> a.area }
      sorted_faces.each { |face|
        if self.face_outward?(face, transformation, true)
          return [face, false]
        elsif self.face_outward?(face, transformation, false)
          return [face, true]
        end
      }
      nil
    end


    # @param [Set<Sketchup::Face>] faces Manifold surface faces.
    # @param [Sketchup::Face] faces Face to orient the surface by.
    def self.find_reversed_faces(faces, start_face, start_reversed, &block)
      #puts ""
      #puts "ErrorFinder.find_reversed_faces"
      #puts "> faces: #{faces.to_a}"
      #puts "> processed: #{processed.to_a}"
      processed = Set.new
      unless start_face.is_a?(Sketchup::Face)
        raise TypeError, "start_face must be Sketchup::Face: #{start_face.inspect}"
      end
      reversed = Set.new
      if start_reversed
        reversed << start_face
        block.call(start_face)
      end
      stack = [start_face]
      until stack.empty?
        face = stack.shift
        next if processed.include?(face)
        #next unless faces.include?(face)
        processed << face
        face.edges.each { |edge|
          next_faces = edge.faces.select { |f| f != face && faces.include?(f) }
          raise RuntimeError, "Unexpected internal faces" if next_faces.size > 1
          raise RuntimeError, "Unexpected border face" if next_faces.empty?
          #next if next_faces.empty?
          next_face = next_faces[0]
          next if processed.include?(next_face)
          #next unless faces.include?(next_face)
          next if stack.include?(next_face)
          if reversed.include?(face)
            # If the current face is reversed we must check that the edge is
            # not reversed in both faces.
            if edge.reversed_in?(face) != edge.reversed_in?(next_face)
              reversed << next_face
              block.call(next_face)
            end
          else
            # If the edge is reversed on both faces then the next face is
            # reversed.
            if edge.reversed_in?(face) == edge.reversed_in?(next_face)
              reversed << next_face
              block.call(next_face)
            end
          end
          stack << next_face
        }
      end
      #puts ""
      reversed
    end


    def self.fix_errors(errors, entities)
      all_errors_fixed = true
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
        model.start_operation("Repair Solid", true)
        entities.erase_entities(entities_to_be_erased.to_a)
        remaining_errors.each { |error|
          begin
            error.fix
          rescue NotImplementedError => e
            all_errors_fixed = false
          end
        }
        model.commit_operation
      rescue
        #model.abort_operation
        model.commit_operation
        raise
      end
      all_errors_fixed
    end


    def self.reversed_face?(face, transformation, entity_set = [])
      entities = face.parent.entities
      point_on_face = self.point_on_face(face)
      # Shoot rays in the direction of the front side of the face. If we hit
      # odd number of intersections the face is facing "inward" in the manifold.
      ray = [point_on_face, face.normal]
      ray = self.transform_ray(ray, transformation)
      intersections = self.count_ray_intersections(ray, entities, entity_set)
      #if intersections % 2 > 0
      #  puts ""
      #  puts "Face: #{face.entityID} - Intersections: #{intersections}"
      #  puts "> Reversed: #{intersections % 2 > 0}"
      #  puts "> Entities Set: #{entity_set.size}"
      #  puts "> Ray: #{ray.inspect}"
      #  puts "> Transformation: #{transformation.to_a}"
      #  puts "> Point on Face: #{point_on_face.inspect}"
      #  puts "> Face Normal: #{face.normal.inspect}"
      #  puts ""
      #  self.count_ray_intersections(ray, entities, entity_set, true)
      #end
      intersections % 2 > 0
    end


    def self.face_outward?(face, transformation, front_face_direction = true)
      entities = face.parent.entities
      point_on_face = self.point_on_face(face)
      # Shoot rays in each direction of the face and count how many times it
      # intersect with the current entities set.
      direction = front_face_direction ? face.normal : face.normal.reverse!
      ray = [point_on_face, direction]
      ray = self.transform_ray(ray, transformation)
      !self.hit_entities?(ray, entities)
    end


    def self.count_ray_intersections(ray, entities, entity_set = [], debug=false)
      #puts "" if debug
      #puts "count_ray_intersections" if debug
      #Sketchup.active_model.active_entities.add_cpoint(ray.first)
      model = entities.model
      entity_set = entities.to_a if entity_set.empty?
      direction = ray[1]
      result = model.raytest(ray, false)
      count = 0
      #puts "> Before loop" if debug
      until result.nil?
        #puts "  > ITERATION:" if debug
        #raise "Safety Break!" if count > 100 # Temp safety limit.
        point, path = result
        #puts "  > #{point.inspect} - #{path.inspect}" if debug
        # Check if the returned point hit within the instance.
        if path.last.parent.entities == entities
          puts "  > Valid Entities" if debug
          if entity_set.include?(path.last)
            puts "  > In entities set - incrementing..." if debug
            count += 1
          end
        end
        #Sketchup.active_model.active_entities.add_cpoint(ray.first)
        #Sketchup.active_model.active_entities.add_cpoint(point)
        #Sketchup.active_model.active_entities.add_cline(ray.first, point)
        ray = [point, direction]
        result = model.raytest(ray, false)
      end
      #puts "> After loop" if debug
      if path && !entity_set.include?(path.last)
        # If the last entity we hit was not part of entity_set - meaning an
        # internal face - it could be that it hit an internal face that is close
        # to an outer face. The tolerance in SketchUp means the ray won't hit
        # the final outer face. To account for this we assume this is the case
        # and increment the hit count. This should correct some faces being
        # reversed when they shouldn't.
        # There might be some other edge cases where this happens internally -
        # in which case I don't think it can be caught. Model with such close
        # tolerances between the entities will have issues.
        #puts "> Miss!" if debug
        if path.last.parent.entities == entities
          #puts "  > Increment!" if debug
          count += 1
        end
        #p path.last
        #p path.last.parent.entities
        #p entities
        #pt2 = point.offset(Z_AXIS, 10)
        #Sketchup.active_model.active_entities.add_cline(point, pt2)
      end
      #puts "> Count #{count}" if debug
      count
    end


    def self.hit_entities?(ray, entities)
      #Sketchup.active_model.active_entities.add_cpoint(ray.first)
      model = entities.model
      direction = ray[1]
      result = model.raytest(ray, false)
      count = 0
      until result.nil?
        #raise "Safety Break!" if count > 100 # Temp safety limit.
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
      invalid = Sketchup::Face::PointOnVertex | Sketchup::Face::PointOnEdge
      mesh = face.mesh(PolygonMeshPoints)
      (1..mesh.count_polygons).each { |i|
        points = mesh.polygon_points_at(i)
        point = self.average(points)
        # Make sure the point is not on the border of the face - as that can
        # lead to false positives.
        classification = face.classify_point(point)
        if classification & invalid == 0
          return point
        end
      }
      # TODO: Consider raising an error that can be catched - excluding the face
      # for processing since this can lead to unpredictable results.
      warn "Degenerate face! (EntityID: #{face.entityID})"
      points = mesh.polygon_points_at(1)
      point = self.average(points)
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
