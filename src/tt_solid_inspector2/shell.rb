#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------

require "set"


module TT::Plugins::SolidInspector2
  # Based on Shellify by Anders Lyhagen. A thousand thanks for the code
  # contribution and feedback!
  class Shell


    PI2 = Math::PI * 2


    attr_reader :internal_faces, :reversed_faces


    def initialize(entities)
      @entities = entities
      @shell_faces = Set.new
      @internal_faces = Set.new
      @reversed_faces = Set.new
    end


    def resolve
      @internal_faces.clear
      @reversed_faces.clear
      @shell_faces = Set.new

      start_face = find_start_face(@entities, true)
      @shell_faces.merge(find_shell(start_face))

      # Trying to resolve "external" faces appear to yield incorrect results.
      # For now this is disabled until the functionality of 2.1 is restored.
      #start_face = find_start_face(@entities, false)
      #@shell_faces.merge(find_shell(start_face))

      # TODO: Is @reversed_faces ensured to return faces that only belong to the
      # shell or can the collection contain faces from @internal_faces?

      faces = @entities.grep(Sketchup::Face)
      @internal_faces = Set.new(faces).subtract(@shell_faces)
      nil
    end


    private


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
    # @return [Sketchup::Face]
    def find_start_face(entities, outside)
      # Ignore vertices with no faces attached.
      vertices = Set.new
      entities.grep(Sketchup::Edge) { |edge|
        vertices.merge(edge.vertices)
      }
      vertices.delete_if { |vertex| vertex.faces.empty? }

      # 1) Pick the vertex (v) with max z component.
      max_z_vertex = vertices.max { |a, b|
        a.position.z <=> b.position.z
      }

      # 2) For v, pick the attached edge (e) least aligned with the z axis.
      edges = max_z_vertex.edges.delete_if { |edge| edge.faces.empty? }
      edge = edges.min { |a, b|
        edge_normal_z_component(a) <=> edge_normal_z_component(b)
      }

      # 3) For e, pick the face attached with maximum |z| normal component.
      face = edge.faces.max { |a, b|
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
    # @param [Sketchup::Face] f
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
      other_face = edge.faces.find { |edge_face| edge_face != face }
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
      return nil if edge.faces.size == 1
      return get_other_face(edge, face) if edge.faces.size == 2

      edge_direction = edge_vector(edge, face)
      face_direction = face_normal(face)
      product = face_direction.cross(edge_direction)
      reversed = edge_reversed_in?(edge, face)

      minimum_angle = PI2
      shell_face = nil

      edge.faces.each { |other_face|
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
            next if processed.include?(edge) || edge.faces.size < 2

            processed << edge
            other_shell_face = find_other_shell_face(edge, face)

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
