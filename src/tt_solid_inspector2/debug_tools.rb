#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------

require "set"


module TT::Plugins::SolidInspector2

  require File.join(PATH, "error_finder.rb")
  require File.join(PATH, "instance.rb")


  class DebugFaceReversedTool


    def initialize
      @faces = Sketchup.active_model.selection.grep(Sketchup::Face)
      @results = {}
      nil
    end


    def activate
      calculate
      Sketchup.active_model.active_view.invalidate
      #update_ui
      nil
    end


    def deactivate(view)
      view.invalidate
      nil
    end


    def resume(view)
      view.invalidate
      #update_ui
      nil
    end


    def onMouseMove(flags, x, y, view)
      ph = view.pick_helper
      ph.do_pick(x, y)
      face = ph.picked_face
      if face
        result = @results[face]
        if result
          intersections = ray_intersections(face)
          reversed = ray_reversed?(face)
          view.tooltip = "Face: #{face.entityID}\n"\
            "Intersection: #{intersections}\n"\
            "Reversed: #{reversed}"
        end
      end
      view.invalidate
    end


    def onLButtonDown(flags, x, y, view)
      ph = view.pick_helper
      ph.do_pick(x, y)
      face = ph.picked_face
      if face
        result = @results[face]
        if result
          intersections = ray_intersections(face)
          reversed = ray_reversed?(face)
          puts ""
          puts "Face: #{face.entityID}"
          puts "Intersection: #{intersections}"
          puts "Reversed: #{reversed}"
          result.each { |r|
            puts "> "
            r.each { |key, value|
              puts "  > #{key} => #{value.inspect}"
            }
          }
          puts ""
        else
          if face.parent.entities == view.model.active_entities
            view.model.selection.clear
            view.model.selection.add(face)
            @faces = [face]
            calculate
          end
        end
      end
      view.invalidate
    end


    def draw(view)
      @results.each { |face, result|
        points = ray_points(face)

        view.drawing_color = "red"
        view.line_stipple = ''
        view.line_width = 1

        if points.size > 1
          view.draw(GL_LINE_STRIP, points)
        end
        if points.size > 0
          view.draw_points(points, 10, DRAW_CROSS, "red")
        end

        if points.size > 0
          point = points.last.offset(face.normal, 200.mm)
          view.line_stipple = '-'
          view.draw(GL_LINES, points.last, point)
        end
      }
      nil
    end


    private


    def calculate
      model = Sketchup.active_model
      entities = model.active_entities
      entity_set = Set.new(entities)
      transformation = model.edit_transform

      @results.clear
      @faces.each { |face|
        ray_data = []
        direction = face.normal

        point_on_face = ErrorFinder.point_on_face(face)
        classification = face.classify_point(point_on_face)

        ray_data << {
          :point => point_on_face,
          :classification => classification,
          :count => 0
        }

        ray = [point_on_face, face.normal]
        #ray = ErrorFinder.transform_ray(ray, transformation)

        count = 0
        result = model.raytest(ray, false)
        until result.nil?
          raise "Safety Break!" if count > 100 # Temp safety limit.
          point, path = result

          # Check if the returned point hit within the instance.
          if path.last.parent.entities == entities
            if entity_set.include?(path.last)
              count += 1
            end
          end

          ray = [point, direction]
          result = model.raytest(ray, false)

          ray_data << {
            :point => point,
            :path => path,
            :count => count
          }
        end # until
        if path && !entity_set.include?(path.last)
          puts "miss!"
          if path.last.parent.entities == entities
            count += 1
            puts "> increment!"
          end
        end

        @results[face] = ray_data
      }
      nil
    end


    def ray_points(face)
      result = @results[face]
      result.map { |hash| hash[:point] }
    end

    def ray_intersections(face)
      result = @results[face]
      result.last[:count]
    end

    def ray_reversed?(face)
      intersections = ray_intersections(face)
      intersections % 2 > 0
    end


  end # class DebugFaceReversedTool
end # module TT::Plugins::SolidInspector2
