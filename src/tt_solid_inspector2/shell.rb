#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------

require "set"

require 'tt_solid_inspector2/error_reporter/error_reporter'


module TT::Plugins::SolidInspector2

  class HeisenBug < RuntimeError; end

  # Based on Shellify by Anders Lyhagen. A thousand thanks for the code
  # contribution and feedback!
  class Shell


    PI2 = Math::PI * 2


    attr_reader :internal_faces, :external_faces, :reversed_faces


    # @param [Sketchup::Entities] entities
    def initialize(entities)
      @entities = entities
      @shell_faces = nil
      @internal_faces = nil
      @external_faces = nil
      @reversed_faces = nil
    end


    # @return [Nil]
    def resolve
      @shell_faces = Set.new
      @internal_faces = Set.new
      @external_faces = Set.new
      @reversed_faces = Set.new

      # First we resolve a shell for faces oriented "outwards".
      shell_front = Set.new
      find_geometry_groups(@entities) { |geometry_group|
        start_face = find_start_face(geometry_group, true)
        next if start_face.nil?
        shell_front.merge(find_shell(start_face))

        # TODO: Perform both passes within this block.
      }
      # From this set of faces we can deduce the internal faces for this shell.
      # Note that this shell set might contain external faces, "flaps".
      # `@internal_faces` will be used in the next pass to skip these faces as
      # they have been already determined to be undesired.
      faces = @entities.grep(Sketchup::Face)
      @internal_faces = Set.new(faces).subtract(shell_front)

      # Because `find_shell` modify the `@reversed_faces` array we back up the
      # set so we can restore it afterwards otherwise we get incorrect results.
      temp_reversed_faces = @reversed_faces.dup

      # We then make a new pass an resolve a new shell looking for normals
      # in the opposite direction. This allow us to detect external faces.
      shell_back = Set.new
      find_geometry_groups(@entities) { |geometry_group|
        start_face = find_start_face(geometry_group, false)
        next if start_face.nil?
        shell_back.merge(find_shell(start_face))
      }

      # From the two sets we can resolve the actual shell which form a manifold.
      @shell_faces = shell_front.intersection(shell_back)

      # Given the final shell and the internal faces found we now know which
      # faces are external.
      @external_faces = Set.new(faces).subtract(@internal_faces)
                                      .subtract(@shell_faces)

      # Restore the set of reversed faces so we can correctly orient the
      # manifold.
      @reversed_faces = @shell_faces.intersection(temp_reversed_faces)
      nil
    end


    def valid?
      if @shell_faces.nil?
        raise RuntimeError, "`resolve` must be called before calling `valid?`"
      end
      @shell_faces.size > 0 && @shell_faces.all? { |face|
        face.edges.all? { |edge|
          faces = edge.faces.select { |f| @shell_faces.include?(f) }
          # Because there is the odd chance of an edge connected to more than
          # two faces we only check for edges that is connected to LESS than two
          # shell faces. Not sure if this is free of false positives, but all
          # the current test models pass this correctly.
          faces.size > 1
        }
      }
    end


    private


    # @param [Sketchup::Entities] entities
    #
    # @yield [Array<Entity>]
    #
    # @return [Integer]
    def find_geometry_groups(entities)
      num_groups = 0
      stack = entities.to_a
      until stack.empty?
        entity = stack.pop
        next unless entity.respond_to?(:all_connected)
        num_groups += 1
        geometry_group = entity.all_connected
        yield(geometry_group)
        stack = stack - geometry_group
      end
      num_groups
    end


    # @param [#faces] entity
    #
    # @return [Array<Sketchup::Face>]
    def get_faces(entity)
      entity.faces.reject { |face| @internal_faces.include?(face) }
    end


    # @param [Sketchup::Face] face
    #
    # @return [Geom::Vector3d]
    def face_normal(face)
      normal = face.normal
      if @reversed_faces.include?(face)
        normal.reverse!
      end
      normal
    end


    # @param [Sketchup::Edge] edge
    # @param [Sketchup::Face] face
    #
    # @return [Geom::Vector3d]
    def edge_reversed_in?(edge, face)
      reversed = edge.reversed_in?(face)
      if @reversed_faces.include?(face)
        reversed = !reversed
      end
      reversed
    end


    # @param [Sketchup::Face] face
    #
    # @return [Sketchup::Face]
    def reverse_face(face)
      if @reversed_faces.include?(face)
        @reversed_faces.delete(face)
      else
        @reversed_faces << face
      end
      face
    end


    # Find a start face on the shell:
    # 1) Pick the vertex (v) with max z component.
    #    (ignore vertices with no faces attached)
    # 2) For v, pick the attached edge (e) least aligned with the z axis
    # 3) For e, pick the face attached with maximum |z| normal component
    # 4) reverse face if necessary.
    #
    # Two issues:
    # 1) The selected face might be an external flap in which case Shellify will
    #    fail.
    # 2) If we pick a vertex connected to a hole, then the selected face may
    #    have max_f.normal.z == 0. In this case we are unable to determine
    #    whether to reverse the face.
    #
    # @param [Sketchup::Entities] entities
    # @param [Boolean] outside
    #
    # @return [Sketchup::Face, Nil]
    def find_start_face(entities, outside)
      # Ignore vertices with no faces attached.
      vertices = Set.new
      entities.grep(Sketchup::Edge) { |edge|
        vertices.merge(edge.vertices)
      }
      vertices.delete_if { |vertex| get_faces(vertex).empty? }
      return nil if vertices.empty?

      # 1) Pick the vertex (v) with max z component.
      max_z_vertex = vertices.max { |a, b|
        a.position.z <=> b.position.z
      }

      # 2) For v, pick the attached edge (e) least aligned with the z axis.
      edges = max_z_vertex.edges.delete_if { |edge| get_faces(edge).empty? }
      edge = edges.min { |a, b|
        # BUG #37: comparison of Sketchup::Edge with Sketchup::Edge failed
        # This throws an ArgumentError some times - which is strange. Almost
        # indicate that edge_normal_z_component yields NaN or something like
        # that. It's not been possible to reproduce this yet - so in an attempt
        # to get more data we throw a custom exception with more info.
        # This is a workaround until the Error Reporter can accept additional
        # custom data in its payload.
        val_a = edge_normal_z_component(a)
        val_b = edge_normal_z_component(b)
        result = val_a <=> val_b
        if result.nil?
          klass_a = a.class.name
          klass_b = b.class.name
          raise HeisenBug, "A: #{a.class.name} #{a.line.inspect} (#{val_a.inspect}) #{klass_a} - B: #{b.class.name} #{b.line.inspect} (#{val_b.inspect}) #{klass_b}"
        end
        result
      }

      # 3) For e, pick the face attached with maximum |z| normal component.
      face = get_faces(edge).max { |a, b|
        face_normal(a).z.abs <=> face_normal(b).z.abs
      }

      # 4) reverse face if necessary.
      if outside
        reverse_face(face) if face_normal(face).z < 0
      else
        reverse_face(face) if face_normal(face).z > 0
      end

      face
    end


    # @param [Sketchup::Edge] edge
    #
    # @return [Float]
    def edge_normal_z_component(edge)
      edge.line[1].z.abs
    end


    # Construct a vector along the edge in the face's loop direction.
    #
    # @param [Sketchup::Edge] edge
    # @param [Sketchup::Face] face
    #
    # @return [Geom::Vector3d]
    def edge_vector(edge, face)
      if edge_reversed_in?(edge, face)
        edge.end.position.vector_to(edge.start)
      else
        edge.start.position.vector_to(edge.end)
      end
    end


    # The edges is known to have two faces, return the face that is not the
    # argument. Reverse the other face if appropriate.
    #
    # @param [Sketchup::Edge] edge
    # @param [Sketchup::Face] face
    #
    # @return [Sketchup::Face]
    def get_other_face(edge, face)
      other_face = get_faces(edge).find { |edge_face| edge_face != face }
      return nil if other_face.nil? # Edge connected to same face.
      if edge_reversed_in?(edge, face) == edge_reversed_in?(edge, other_face)
        reverse_face(other_face)
      end
      other_face
    end


    # Given a face known to be on the shell and one of its edges, find the other
    # shell face connected to the edge.
    #
    # @param [Sketchup::Edge] edge
    # @param [Sketchup::Face] face
    #
    # @return [Sketchup::Face]
    def find_other_shell_face(edge, face)
      return nil if get_faces(edge).size == 1

      # If there is only two connected faces the other face is a easy choice.
      return get_other_face(edge, face) if get_faces(edge).size == 2

      # If there are more faces we need to figure out which one is the other
      # shell face.

      # Make sure to account for edges that might connect to itself multiple
      # times.
      return nil if get_faces(edge).count(face) > 1

      edge_direction = edge_vector(edge, face)
      face_direction = face_normal(face)
      product = face_direction.cross(edge_direction)
      reversed = edge_reversed_in?(edge, face)

      minimum_angle = PI2
      shell_face = nil

      get_faces(edge).each { |other_face|
        next if other_face == face

        other_face_direction = face_normal(other_face)
        if edge_reversed_in?(edge, other_face) == reversed
          other_face_direction.reverse!
        end

        other_product = edge_direction.cross(other_face_direction)

        angle = product.angle_between(other_product)
        if other_product.dot(face_direction) < 0
          angle = PI2 - angle
        end

        if angle < minimum_angle
          minimum_angle = angle
          shell_face = other_face
        end
      }

      # Example model where this happens: PrusaI3_Extruder2.skp
      # Six tiny faces sharing the same set of vertices.
      return nil if shell_face.nil?

      if edge_reversed_in?(edge, shell_face) == reversed
        reverse_face(shell_face)
      end

      shell_face
    end


    # Traverses the connected mesh for the given start face and resolves a set
    # of faces representing the outer shell of the mesh.
    #
    # @param [Sketchup::Face] start_face
    #
    # @return [Array<Sketchup::Face>]
    def find_shell(start_face)
      stack = [] # Unprocessed shell faces.
      processed = Set.new
      shell = Set.new

      # Set up stack.
      stack << start_face
      processed << start_face

      until stack.empty? do

        face = stack.pop
        shell << face

        # Look for neighbouring shell faces.
        face.loops.each { |loop|
          loop.edges.each { |edge|
            next if processed.include?(edge) || get_faces(edge).size < 2

            processed << edge
            other_shell_face = find_other_shell_face(edge, face)

            next if other_shell_face.nil?
            next if processed.include?(other_shell_face)

            stack << other_shell_face
            processed << other_shell_face
          }
        }
      end

      shell.to_a
    end


  end # class Shell
end # module TT::Plugins::SolidInspector2
