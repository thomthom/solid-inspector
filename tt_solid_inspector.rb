#-----------------------------------------------------------------------------
# Version: 1.0.0
# Compatible: SketchUp 7 (PC)
#             (other versions untested)
#-----------------------------------------------------------------------------
#
# CHANGELOG
# 1.0.0a - 29.08.2010
#   * Added TT_Lib2 support
#
# 0.1.0a - 12.08.2010
#   * Initial Release
#
#-----------------------------------------------------------------------------
#
# TODO:
# Compile list of errors.
# * Click item to zoom to error.
# * Describe errors. (Open face, small edge, internal edge/face, stray edge.)
# * Attempt to fix error automatically if possible.
#
#-----------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-----------------------------------------------------------------------------

require 'sketchup.rb'
require 'TT_Lib2/core.rb'

TT::Lib.compatible?('2.0.0', 'TT Solid Inspector')

#-----------------------------------------------------------------------------

module TT::Plugins::SolidInspector
  
  ### MENU & TOOLBARS ### --------------------------------------------------
  
  unless file_loaded?( File.basename(__FILE__) )
    m = TT.menu('Tools')
    m.add_item('Solid Inspector')  { self.inspect_solid }
  end
  
  
  ### MAIN SCRIPT ### ------------------------------------------------------

  def self.inspect_solid
    Sketchup.active_model.tools.push_tool( SolidInspector.new )
  end
  
  
  class SolidInspector
    
    def initialize
      @instance = nil
      @errors = []
      @current_error = 0
      @groups = []
      
      @status = "Click on solids to inspect. Use arrow keys to cycle between errors. Press Return to zoom to error. Press Tab/Shift+Tab to cycle though errors and zoom."
      
      Sketchup.active_model.selection.each { |e|
        next unless TT::Instance.is?(e)
        analyze(e)
        break
      }
    end
    
    def analyze(instance)
      @instance = instance
      
      Sketchup.active_model.selection.clear
      Sketchup.active_model.selection.add( @instance )
      
      # Any edge without two faces means an error in the surface of the solid.
      @current_error = 0
      @errors = TT::Instance.definition(@instance).entities.select { |e|
        e.is_a?( Sketchup::Edge ) && e.faces.length != 2
      }
      
      # Group connected error-edges.
      @groups = []
      stack = @errors.clone
      until stack.empty?
        #puts '...'
        cluster = []
        cluster << stack.shift
        
        # Find connected errors
        edge = cluster.first
        haystack = ([edge.start.edges + edge.end.edges] - [edge]).first & stack
        #p haystack
        until haystack.empty?
          e = haystack.shift
          
          if stack.include?( e )
            cluster << e
            stack.delete( e )
            haystack += ([e.start.edges + e.end.edges] - [e]).first & stack 
          end
        end
        
        @groups << cluster
      end
      #puts 'Groups:'
      #p @groups
      #p @errors
    end
    
    def activate
      Sketchup.active_model.active_view.invalidate
      Sketchup.status_text = @status
    end
    
    def deactivate(view)
      view.invalidate
    end
    
    def resume(view)
      view.invalidate
      Sketchup.status_text = @status
    end
    
    def onLButtonUp(flags, x, y, view)
      ph = view.pick_helper
      ph.do_pick(x, y)
      if TT::Instance.is?( ph.best_picked )
        analyze( ph.best_picked )
      end
      view.invalidate
    end

    
    def onKeyUp(key, repeat, flags, view)
      return if @groups.empty?
      
      shift = flags & CONSTRAIN_MODIFIER_MASK == CONSTRAIN_MODIFIER_MASK
      
      # Iterate over the error found using Tab, Up/Down, Left/Right.
      # Tab will zoom to the current error.
      
      if key == 9 # Tab
        if shift
          @current_error = (@current_error - 1) % @groups.length
        else
          @current_error = (@current_error + 1) % @groups.length
        end
      end
      
      if key == VK_UP || key == VK_RIGHT
        @current_error = (@current_error + 1) % @groups.length
      end
      
      if key == VK_DOWN || key == VK_LEFT
        @current_error = (@current_error - 1) % @groups.length
      end
      
      if key == 13 || key == 9
        zoom_to_error(view)
      end
      
      #p key
      view.invalidate
    end
    
    def zoom_to_error(view)
      e = @groups[ @current_error ]
      view.zoom( e )
      # Adjust camera for the instance transformation
      camera = view.camera
      t = @instance.transformation
      eye = camera.eye.transform( t )
      target = camera.target.transform( t )
      up = camera.up.transform( t )
      view.camera.set( eye, target, up )
    end
    
    def draw(view)
      view.line_width = 3
      view.line_stipple = ''
        
      unless @groups.empty?
        @groups.each_index { |index|
          error = @groups[index]
          
          view.drawing_color = (index == @current_error) ? 'red' : 'orange'
          
          # Get points for each error edge
          pts = error.map { |e| e.vertices.map{|v|v.position} }.flatten
          pts.map! { |pt| pt.transform( @instance.transformation ) }
          
          view.draw(GL_LINES, pts)
          
          # Draw Attention Circle
          pts2d = pts.map { |pt| view.screen_coords(pt) }

          bb = Geom::BoundingBox.new
          bb.add( pts2d )
          size = bb.corner(0).distance( bb.corner(7) )
          size = 20 if size < 20 # Ensure a minimum size of the circle
          
          c = TT::Geom3d.circle( bb.center, Z_AXIS, size, 64 )
          view.draw2d( GL_LINE_LOOP, c )
        }
      end
    end
    
  end # class SolidInspector

  
  ### HELPER METHODS ### ---------------------------------------------------

  
  def self.reload
    load __FILE__
  end
  
end # module

#-----------------------------------------------------------------------------
file_loaded( File.basename(__FILE__) )
#-----------------------------------------------------------------------------