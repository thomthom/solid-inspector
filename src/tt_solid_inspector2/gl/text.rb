#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------

module TT::Plugins::SolidInspector2

  require File.join(PATH, "gl", "cache.rb")
  require File.join(PATH, "gl", "image.rb")


 class GL_Text

  CHAR_WIDTH  = 8
  CHAR_HEIGHT = 13

  attr_reader :text

  @@bitmaps = {}

  def initialize(text, x = 0, y = 0)
    @text = text.to_s
    @x = x.to_i
    @y = y.to_i
    view = Sketchup.active_model.active_view
    @cache = GL_Cache.new(view)
    ensure_bitmaps_are_loaded()
    update_cache()
  end

  def draw(view)
    @cache.render
  end

  def position=(point)
    @x = point.x.to_i
    @y = point.y.to_i
    update_cache()
  end

  def text=(value)
    @text = value.to_s
    update_cache()
  end

  private

  def update_cache
    @cache.clear
    @text.size.times { |index|
      char = @text[index]
      bitmap = @@bitmaps[char]
      char_x = @x + (index * CHAR_WIDTH)
      char_y = @y + CHAR_HEIGHT
      bitmap.draw(@cache, char_x, char_y)
    }
  end

  def ensure_bitmaps_are_loaded
    return false if !@@bitmaps.empty?
    char_to_file = {
      "0" => "0",
      "1" => "1",
      "2" => "2",
      "3" => "3",
      "4" => "4",
      "5" => "5",
      "6" => "6",
      "7" => "7",
      "8" => "8",
      "9" => "9",
      "." => "period",
      "," => "comma",
      "~" => "tilde",
      "-" => "minus",
      " " => "space",
      "∞" => "infinity"
    }
    transparency_mask = Sketchup::Color.new(0, 0, 0)
    char_to_file.each { |char, basename|
      filename = File.join(PATH_GL_TEXT, "#{basename}.bmp")
      image = GL_Image.new(filename, transparency_mask)
      @@bitmaps[char] = image
    }
    replacement_character = File.join(PATH_GL_TEXT, "replacement.bmp")
    @@bitmaps.default = GL_Image.new(replacement_character, transparency_mask)
    true
  end

 end # class
end # module TT::Plugins::SolidInspector2
