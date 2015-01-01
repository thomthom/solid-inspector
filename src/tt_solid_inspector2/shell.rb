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
      start_face = getStartFace(@entities, true)
      @shell_faces = Set.new(getShell(start_face).keys)
      faces = @entities.grep(Sketchup::Face)
      @internal_faces = Set.new(faces).subtract(@shell_faces)
      nil
    end


    private


    #find a start face on the shell:
    # 1) Pick the vertex (v) with max z component (ignore vertices with no faces attached)
    # 2) For v, pick the attached edge (e) least aligned with the z axis
    # 3) For e, pick the face attached with maximum |z| normal component
    # 4) reverse face if necessary
    #
    # Two issues:
    # 1) The selected face might be an external flap in which case Shellify will fail.
    # 2) If we pick a vertex connected to a hole, then the selected face may have
    #    max_f.normal.z == 0. In this case we are unable to determine whether to reverse the
    #    face.
    def getStartFace(ents, outside)
      vs = ents.grep(Sketchup::Edge).map{|e| e.vertices}.flatten!.uniq!.find_all{|v| v.faces.length > 0}

      max_z = vs[0]
      vs.each { |v| max_z = v if v.position.z > max_z.position.z }

      es = max_z.edges.find_all{|e| e.faces.length > 0}
      max_e = es[0]
      es.each { |e| max_e = e if getNormZComp(e) < getNormZComp(max_e) }

      max_f = max_e.faces[0]
      max_e.faces.each { |f| max_f = f if f.normal.z.abs > max_f.normal.z.abs }

      return outside ? (max_f.normal.z < 0 ? max_f.reverse! : max_f) :
                       (max_f.normal.z > 0 ? max_f.reverse! : max_f)
    end


    def getNormZComp(e)
      return (e.vertices[0].position - e.vertices[1].position).normalize!.z.abs
    end


    #construct a vector along the edge in the face's loop direction
    def getEdgeVector(e, f)
      return e.reversed_in?(f) ? (e.vertices[0].position - e.vertices[1].position) :
                                 (e.vertices[1].position - e.vertices[0].position)
    end


    #the edges is known to have two faces, return the face that is not the parameter.
    #reverse the other face if appropriate.
    def getOtherFace(e, f)
      f1 = e.faces[0] == f ? e.faces[1] : e.faces[0]
      return e.reversed_in?(f) == e.reversed_in?(f1) ? f1.reverse! : f1
    end


    #Given a face known to be on the shell and one of its edges, find the other shell face
    #connected to the edge.
    def getOtherShellFace(e, f)

      return nil if e.faces.length == 1
      return getOtherFace(e, f) if e.faces.length == 2

      c_e = getEdgeVector(e, f)
      c_n = f.normal
      c_p = c_n.cross(c_e)
      c_dir = e.reversed_in?(f)

      #min assignments
      min_a = Math::PI * 2
      shell_face = nil

      e.faces.each { |f0|
        unless f0 == f
          t_n = e.reversed_in?(f0) == c_dir ? f0.normal.reverse : f0.normal
          t_p = c_e.cross(t_n)
          a = t_p.dot(c_n) < 0 ? (Math::PI * 2) - c_p.angle_between(t_p) :
                                                  c_p.angle_between(t_p)
          if a < min_a
            min_a = a
            shell_face = f0
          end
        end
      }

      return c_dir == e.reversed_in?(shell_face) ? shell_face.reverse! : shell_face
    end


    def getShell(start_face)

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
              f1 = getOtherShellFace(e, f)
              unless face_h.has_key?(f1)
                front_q.push(f1)
                face_h[f1] = nil
              end
            end
        }}
      end

      return shell_h
    end


    def deleteStrayEdges(ents)
      es = ents.grep(Sketchup::Edge)
      es.each {|e| e.erase! if !e.deleted? && e.faces.length == 0}
    end


    def reduceToShell(ents, shell_h)
      fs = ents.grep(Sketchup::Face)
      fs.each {|f| f.erase! unless shell_h.has_key?(f)}
      deleteStrayEdges(ents)
    end


    def reverseAll(ents)
      ents.grep(Sketchup::Face).each {|f| f.reverse! }
    end


    def constructShell(ents, remove_internal)
      start_face = getStartFace(ents, remove_internal)
      shell_h = getShell(start_face)
      reduceToShell(ents, shell_h)
      reverseAll(ents) unless remove_internal
    end


    def shellify(ents)
      #extract shell from the outside (-> remove internal geometry)
      constructShell(ents, true)

      #extract shell from the inside (-> remove external geometry)
      constructShell(ents, false)
    end

  end # class Shell
end # module TT::Plugins::SolidInspector2
