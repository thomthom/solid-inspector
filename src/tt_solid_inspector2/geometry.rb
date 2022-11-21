#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------


module TT::Plugins::SolidInspector2
  module Geometry

  # Creates a set of +Geom::Point3d+ objects for an arc.
  #
  # @param [Geom::Point3d] center
  # @param [Geom::Vector3d] xaxis
  # @param [Geom::Vector3d] normal
  # @param [Number] radius
  # @param [Float] start_angle in radians
  # @param [Float] end_angle in radians
  # @param [Integer] num_segments
  #
  # @return [Array<Geom::Point3d>]
  def self.arc(center, xaxis, normal, radius, start_angle, end_angle, num_segments = 12)
    # Generate the first point.
    tr = Geom::Transformation.rotation(center, normal, start_angle )
    points = []
    points << center.offset(xaxis, radius).transform(tr)
    # Prepare a transformation we can repeat on the last entry in point to
    # complete the arc.
    angle = (end_angle - start_angle) / num_segments
    tr = Geom::Transformation.rotation(center, normal, angle)
    1.upto(num_segments) { |i|
      points << points.last.transform(tr)
    }
    return points
  end


  # @see http://en.wikipedia.org/wiki/Circle
  # @see http://en.wikipedia.org/wiki/Unit_Circle
  #
  # @param [Geom::Point3d] center
  # @param [Geom::Vector3d] xaxis
  # @param [Numeric] radius
  # @param [Numeric] start_angle
  # @param [Numeric] end_angle
  # @param [Integer] num_segments
  #
  # @return [Array<Geom::Point3d>]
  def self.arc2d(center, xaxis, radius, start_angle, end_angle, num_segments = 24)
    full_angle = end_angle - start_angle
    segment_angle = full_angle / num_segments
    t = Geom::Transformation.axes( center, xaxis, xaxis * Z_AXIS, Z_AXIS )
    arc = []
    (0..num_segments).each { |i|
      angle = start_angle + (segment_angle * i)
      x = radius * Math.cos(angle)
      y = radius * Math.sin(angle)
      arc << Geom::Point3d.new(x, y, 0).transform!(t)
    }
    arc
  end


  # Creates a set of +Geom::Point3d+ objects for an circle.
  #
  # @param [Geom::Point3d] center
  # @param [Geom::Vector3d] normal
  # @param [Number] radius
  # @param [Integer] num_segments
  #
  # @return [Array<Geom::Point3d>]
  def self.circle(center, normal, radius, num_segments)
    pi2 = Math::PI * 2
    xaxis = normal.axes.x
    points = self.arc(center, xaxis, normal, radius, 0.0, pi2, num_segments)
    points.pop
    return points
  end


  # @param [Geom::Point3d] center
  # @param [Geom::Vector3d] xaxis
  # @param [Numeric] radius
  # @param [Integer] num_segments
  #
  # @return [Array<Geom::Point3d>]
  def self.circle2d(center, xaxis, radius, num_segments = 24)
    num_segments = num_segments.to_i
    angle = 360.degrees - (360.degrees / num_segments)
    self.arc2d(center, xaxis, radius, 0, angle, num_segments - 1)
  end


  # Calculates the number of segments in an arc given the segments of a full
  # circle. This will give a close visual quality of the arcs and circles.
  #
  # @param [Float] angle in radians
  # @param [Integer] full_circle_segments
  # @param [Boolean] force_even useful to ensure the segmented arc's
  #   apex hits the apex of the real arc
  #
  # @return [Integer]
  def self.arc_segments(angle, full_circle_segments, force_even = false)
    segments = (full_circle_segments * (angle.abs / (Math::PI * 2))).to_i
    segments += 1 if force_even && segments % 2 > 0 # if odd
    segments = 1 if segments < 1
    return segments
  end


  # @param [Sketchup::Edge] edge
  #
  # @return [Geom::Point3d]
  def self.mid_point(edge)
    pt1, pt2 = edge.vertices.map { |vertex| vertex.position }
    Geom.linear_combination(0.5, pt1, 0.5, pt2)
  end

  end # module Geometry
end # module TT::Plugins::SolidInspector2
