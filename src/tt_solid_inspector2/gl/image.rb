#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
# Copyright 2010-2012
#
#-------------------------------------------------------------------------------

module TT::Plugins::SolidInspector2

  require File.join(PATH, "image_bmp.rb")
  require File.join(PATH, "gl", "pixelcache.rb")


  class GL_Image

    def initialize(filename, transparency_mask = nil)
      @filename = filename
      image = load_image(filename)
      @cache = GL_PixelCache.new(image, transparency_mask)
    end

    def draw(view, x, y)
      @cache.draw(view, x, y)
      nil
    end

    private

    def load_image(filename)
      # If other formats is added this function will delegate the job of loading
      # the image to the correct class.
      ImageBMP.new(filename)
    end

  end # class GL_Image

end # module TT::Plugins::SolidInspector2
