#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------

# Caches drawing instructions so complex calculations for generating the
# GL data can be reused.
#
# Redirect all Skethcup::View commands to a DrawCache object and call
# #render in a Tool's #draw event.
#
# @example
#   class Example
#     def initialize( model )
#       @draw_cache = TT::Plugins::SolidInspector2::DrawCache.new( model.active_view )
#     end
#     def deactivate( view )
#       @draw_cache.clear
#     end
#     def resume( view )
#       view.invalidate
#     end
#     def draw( view )
#       @draw_cache.render
#     end
#     def onLButtonUp( flags, x, y, view )
#       point = Geom::Point3d.new( x, y, 0 )
#       view.draw_points( point, 10, 1, 'red' )
#       view.invalidate
#     end
#   end

module TT::Plugins::SolidInspector2
 class GL_Cache

  # @param [Sketchup::View] view
  #
  def initialize(view)
    @view = view
    @commands = []
  end

  # Clears the cache. All drawing instructions are removed.
  #
  # @return [Nil]
  def clear
    @commands.clear
    nil
  end

  # Draws the cached drawing instructions.
  #
  # @return [Sketchup::View]
  def render
    view = @view
    for command in @commands
      view.send(*command)
    end
    view
  end

  # Cache drawing commands and data. These methods received the finsihed
  # processed drawing data that will be executed when #render is called.
  [
    :draw,
    :draw2d,
    :draw_line,
    :draw_lines,
    :draw_points,
    :draw_polyline,
    :draw_text,
    :drawing_color=,
    :line_stipple=,
    :line_width=,
    :set_color_from_line
  ].each { |symbol|
    define_method( symbol ) { |*args|
      @commands << args.unshift(__method__)
      @commands.size
    }
  }

  # Pass through methods to Sketchup::View so that the drawing cache object
  # can easily replace Sketchup::View objects in existing codes.
  def method_missing( *args )
    view = @view
    method = args.first
    if view.respond_to?(method)
      view.send(*args)
    else
      raise NoMethodError, "undefined method `#{method}' for #{self.class.name}"
    end
  end

  # @return [String]
  def inspect
    hex_id = object_id_hex()
    "#<#{self.class.name}:#{hex_id} Commands:#{@commands.size}>"
  end

  private

  # @return [String]
  def object_id_hex
    "0x%x" % (self.object_id << 1)
  end

 end # class
end # module TT::Plugins::SolidInspector2
