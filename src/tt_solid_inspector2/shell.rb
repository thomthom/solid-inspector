#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------

require "set"


module TT::Plugins::SolidInspector2
  # Based on Shellify by Anders Lyhagen
  class Shell

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
      @shell_faces.merge(find_shell(start_face).keys)

      # Trying to resolve "external" faces appear to yield incorrect results.
      # For now this is disabled until the functionality of 2.1 is restored.
      #start_face = find_start_face(@entities, false)
      #@shell_faces.merge(find_shell(start_face).keys)

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
    # @param [Sketchup::Entities] ents
    # @param [Boolean] outside
    #
    # @return [Sketchup::Face]
    def find_start_face(ents, outside)
      vs = ents.grep(Sketchup::Edge).map{|e| e.vertices}.flatten!.uniq!.find_all{|v| v.faces.length > 0}

      max_z = vs[0]
      vs.each { |v| max_z = v if v.position.z > max_z.position.z }

      es = max_z.edges.find_all{|e| e.faces.length > 0}
      max_e = es[0]
      es.each { |e| max_e = e if edge_normal_z_component(e) < edge_normal_z_component(max_e) }

      max_f = max_e.faces[0]
      max_e.faces.each { |f| max_f = f if face_normal(f).z.abs > face_normal(max_f).z.abs }

      return outside ? (face_normal(max_f).z < 0 ? reverse_face(max_f) : max_f) :
                       (face_normal(max_f).z > 0 ? reverse_face(max_f) : max_f)
    end


    # @param [Sketchup::Edge] e
    #
    # @return [Float]
    def edge_normal_z_component(e)
      return (e.vertices[0].position - e.vertices[1].position).normalize!.z.abs
    end


    # Construct a vector along the edge in the face's loop direction.
    #
    # @param [Sketchup::Edge] e
    # @param [Sketchup::Face] f
    #
    # @return [Geom::Vector3d]
    def edge_vector(e, f)
      return edge_reversed_in?(e, f) ? (e.vertices[0].position - e.vertices[1].position) :
                                 (e.vertices[1].position - e.vertices[0].position)
    end


    # The edges is known to have two faces, return the face that is not the
    # parameter. Reverse the other face if appropriate.
    #
    # @param [Sketchup::Edge] e
    # @param [Sketchup::Face] f
    #
    # @return [Sketchup::Face]
    def get_other_face(e, f)
      f1 = e.faces[0] == f ? e.faces[1] : e.faces[0]
      return edge_reversed_in?(e, f) == edge_reversed_in?(e, f1) ? reverse_face(f1) : f1
    end


    # Given a face known to be on the shell and one of its edges, find the other
    # shell face connected to the edge.
    #
    # @param [Sketchup::Edge] e
    # @param [Sketchup::Face] f
    #
    # @return [Sketchup::Face]
    def find_other_shell_face(e, f)

      return nil if e.faces.length == 1
      return get_other_face(e, f) if e.faces.length == 2

      c_e = edge_vector(e, f)
      c_n = face_normal(f)
      c_p = c_n.cross(c_e)
      c_dir = edge_reversed_in?(e, f)

      #min assignments
      min_a = Math::PI * 2
      shell_face = nil

      e.faces.each { |f0|
        unless f0 == f
          t_n = edge_reversed_in?(e, f0) == c_dir ? face_normal(f0).reverse : face_normal(f0)
          t_p = c_e.cross(t_n)
          a = t_p.dot(c_n) < 0 ? (Math::PI * 2) - c_p.angle_between(t_p) :
                                                  c_p.angle_between(t_p)
          if a < min_a
            min_a = a
            shell_face = f0
          end
        end
      }

      return c_dir == edge_reversed_in?(e, shell_face) ? reverse_face(shell_face) : shell_face
    end


    # @param [Sketchup::Face] start_face
    #
    # @return [Hash{Sketchup::Face => Nil}]
    def find_shell(start_face)

      front_q = []  #unprocessed shell faces
      face_h =  {}  #hash with expanded faces
      edge_h =  {}  #Hash with expanded edges
      shell_h = {}  #final shell

      #push start face
      front_q.push(start_face)
      face_h[start_face] = nil

      while front_q.length > 0 do

        f = front_q.pop
        shell_h[f] = nil

        f.loops.each { |loop|
          loop.edges.each { |e|
            if !edge_h.has_key?(e) && e.faces.length > 1
              edge_h[e] = nil
              f1 = find_other_shell_face(e, f)
              unless face_h.has_key?(f1)
                front_q.push(f1)
                face_h[f1] = nil
              end
            end
        }}
      end

      return shell_h
    end


  end # class Shell
end # module TT::Plugins::SolidInspector2
