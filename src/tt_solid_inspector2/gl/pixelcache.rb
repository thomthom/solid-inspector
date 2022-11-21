#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
# Copyright 2010-2012
#
#-------------------------------------------------------------------------------

module TT::Plugins::SolidInspector2

  # Builds a cache of each unique colour and all the points (pixels) in that
  # colour. The Sketchup::Color object is the key, and the value is an array
  # of points.
  class GL_PixelCache

    STIPPLE_SOLID = "".freeze

    def initialize(image, transparency_mask = nil)
      @cache = Hash.new { |hash, key| hash[key] = [] }
      @transparency_mask = transparency_mask.to_a[0, 3]
      process_image(image)
    end

    def clear!
      @cache.clear
      nil
    end

    # ATI cards appear to have issues when AA is on and you pass
    # view.draw2d(GL_POINTS, p) integer points. The points does not appear on
    # screen. This can be remedied by ensuring the X and Y co-ordinates are
    # offset .5 to the centre of the pixel. This appear to work in all cases on
    # all cards and drivers.
    #
    # nVidia on the other had has another problem where GL_POINTS appear to
    # always be blurred when AA is on - offset or not.
    #
    # To work around this, draw each point as GL_LINES - this appear to draw
    # aliased pixels without colour loss on both systems. There is a slight
    # performance hit to this, about 1/3 or 1/2 times slower.
    #
    # @param [Sketchup::View] view
    #
    # @return [Nil]
    # @since 1.0.0
    def draw(view, x, y)
      view.line_width = 1
      view.line_stipple = STIPPLE_SOLID
      tr = Geom::Transformation.new([x, y, 0])
      @cache.each { |color, points|
        view.drawing_color = color
        view.draw2d(GL_LINES, points.map { |point| point.transform(tr) } )
      }
      nil
    end

    private

    def process_image(image)
      raise ArgumentError, 'Not an Image' unless image.is_a?(ImageBMP)
      image.width.times { |x|
        image.height.times { |y|
          color = image.get_pixel(x, y)
          next if color == @transparency_mask
          # When drawing a pixel with GL_LINES the X needs to be an Integer
          # and Y needs to be offset 0.5.
          point1 = Geom::Point3d.new(x.to_i, y.to_i + 0.5)
          point2 = point1.offset(X_AXIS)
          @cache[color] << point1 << point2
        }
      }
      nil
    end

  end # class GL_PixelCache

end # module TT::Plugins::SolidInspector2
