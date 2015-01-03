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

    # @param [Sketchup::Entities]
    #
    # @return [Array<SolidErrors::Error>]
    def self.find_errors(entities)
      raise TypeError unless entities.is_a?(Sketchup::Entities)

      if Settings.debug_mode?
        puts ""
        puts "ErrorFinder.find_errors"
      end

      errors = []

      self.time("Total analysis") {

        mesh_border_edges = []
        hole_edges = []
        edges_with_internal_faces = []

        all_faces = entities.grep(Sketchup::Face)

        Sketchup.status_text = "Inspecting edges..."

        # First check the edges.
        entities.grep(Sketchup::Edge) { |edge|
          num_faces = edge.faces.size
          if num_faces == 0
            errors << SolidErrors::StrayEdge.new(edge)
          elsif num_faces == 1
            face = edge.faces.first
            if face.outer_loop.edges.include?(edge)
              mesh_border_edges << edge
            else
              hole_edges << edge
            end
          elsif num_faces > 2
            edges_with_internal_faces << edge
          end
        }

        Sketchup.status_text = "Analyzing edges..."

        if mesh_border_edges.size > 0
          Sketchup.status_text = "Sorting surface borders..."
          self.group_connected_edges(mesh_border_edges).each { |edges|
            errors << SolidErrors::SurfaceBorder.new(edges)
          }
        end

        if hole_edges.size > 0
          Sketchup.status_text = "Sorting face holes..."
          self.group_connected_edges(hole_edges).each { |edges|
            errors << SolidErrors::FaceHole.new(edges)
          }
        end

        is_manifold = all_faces.size > 0 &&
                      mesh_border_edges.empty? &&
                      hole_edges.empty?

        if is_manifold
          Sketchup.status_text = "Resolving manifold..."

          self.time("Resolving manifold") {
            shell = Shell.new(entities)
            shell.resolve

            shell.internal_faces.each { |face|
              errors << SolidErrors::InternalFace.new(face)
            }

            shell.reversed_faces.each { |face|
              errors << SolidErrors::ReversedFace.new(face)
            }
          } # time
        else
          # Cannot determine what faces are internal until all holes in the mesh
          # is closed.
          edges_with_internal_faces.each { |edge|
            errors << SolidErrors::InternalFaceEdge.new(edge)
          }
        end

        # Detect if there are nested entities.
        self.time("Instance detection") {
          groups = entities.grep(Sketchup::Group)
          components = entities.grep(Sketchup::ComponentInstance)
          instances = groups + components
          instances.each { |instance|
            errors << SolidErrors::NestedInstance.new(instance)
          }
        } # time

        # Detect image entities.
        self.time("Image detection") {
          entities.grep(Sketchup::Image) { |image|
            errors << SolidErrors::ImageEntity.new(image)
          }
        } # time

        # Detect small edges.
        if Settings.detect_short_edges?
          self.time("Short edge detection") {
            self.find_short_edges(entities) { |edge|
              errors << SolidErrors::ShortEdge.new(edge)
            }
          } # time
        end

      }

      if Settings.debug_mode?
        puts ""
      end

      Sketchup.status_text = ""

      errors
    end


    # @param [Array<SolidErrors::Error>] errors
    #
    # @yield [Sketchup::Edge] edge Edge shorter than the threshold.
    #
    # @return [Nil]
    def self.find_short_edges(entities, &block)
      threshold = Settings.short_edge_threshold
      entities.grep(Sketchup::Edge) { |edge|
        if edge.length < threshold
          block.call(edge)
        end
      }
      nil
    end


    # @param [Array<SolidErrors::Error>] errors
    # @param [Sketchup::Entities] entities
    #
    # @return [Boolean]
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


    # @param [Array<Sketchup::Edge>] edges
    #
    # @return [Array<Array<Sketchup::Edge>>]
    def self.group_connected_edges(edges)
      # Group connected error-edges.
      groups = []
      stack = edges.to_a.clone
      until stack.empty?
        cluster = []
        cluster << stack.shift

        # Find connected errors
        edge = cluster.first
        haystack = self.neighbour_edges(edge) & stack
        until haystack.empty?
          next_edge = haystack.shift

          if stack.include?(next_edge)
            cluster << next_edge
            stack.delete(next_edge)
            haystack += self.neighbour_edges(next_edge) & stack
          end
        end

        groups << cluster
      end
      groups
    end


    # @param [Sketchup::Edge] edge
    #
    # @return [Array<Sketchup::Edge>]
    def self.neighbour_edges(edge)
      (edge.start.edges + edge.end.edges) - [edge]
    end


    # @param [String] message
    # @param [Block] block
    #
    # @return [Nil]
    def self.time(message, &block)
      start_time = Time.new
      block.call
      elapsed_time = Time.now - start_time
      if Settings.debug_mode?
        puts "> #{message} took: #{elapsed_time}s"
      end
      nil
    end

  end # module ErrorFinder

end # module TT::Plugins::SolidInspector2
