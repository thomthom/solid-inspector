#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------

module TT::Plugins::SolidInspector2

  require File.join(PATH, "binary", "file.rb")
  require File.join(PATH, "binary", "struct.rb")
  require File.join(PATH, "binary", "types.rb")


 class ImageBMP

  class ImageReadError < StandardError; end

  # Bitmap Storage
  # http://msdn.microsoft.com/en-us/library/windows/desktop/dd183391(v=vs.85).aspx

  include Binary::Types

  # http://msdn.microsoft.com/en-us/library/windows/desktop/dd183374(v=vs.85).aspx
  BITMAPFILEHEADER = Binary::Struct.new(
    WORD,  # bfType
    DWORD, # bfSize
    WORD,  # bfReserved1
    WORD,  # bfReserved2
    DWORD  # bfOffBits
  )

  # http://msdn.microsoft.com/en-us/library/windows/desktop/dd183372(v=vs.85).aspx
  BITMAPCOREHEADER = Binary::Struct.new(
    DWORD, # bcSize
    WORD,  # bcWidth
    WORD,  # bcHeight
    WORD,  # bcPlanes
    WORD   # bcBitCount
  )

  # http://msdn.microsoft.com/en-us/library/windows/desktop/dd183376(v=vs.85).aspx
  BITMAPINFOHEADER = Binary::Struct.new(
    DWORD, # biSize
    LONG,  # biWidth
    LONG,  # biHeight
    WORD,  # biPlanes
    WORD,  # biBitCount
    DWORD, # biCompression
    DWORD, # biSizeImage
    LONG,  # biXPelsPerMeter
    LONG,  # biYPelsPerMeter
    DWORD, # biClrUsed
    DWORD  # biClrImportant
  )

  # http://msdn.microsoft.com/en-us/library/windows/desktop/dd162939(v=vs.85).aspx
  RGBTRIPLE = Binary::Struct.new(
    UCHAR, # rgbtBlue
    UCHAR, # rgbtGreen
    UCHAR  # rgbtRed
  )

  # http://msdn.microsoft.com/en-us/library/windows/desktop/dd162938(v=vs.85).aspx
  RGBQUAD = Binary::Struct.new(
    UCHAR, # rgbBlue
    UCHAR, # rgbGreen
    UCHAR, # rgbRed
    UCHAR  # rgbReserved
  )

  # http://msdn.microsoft.com/en-us/library/windows/desktop/dd183380(v=vs.85).aspx
  BITMAPV4HEADER_SIZE = 108

  # http://msdn.microsoft.com/en-us/library/windows/desktop/dd183381(v=vs.85).aspx
  BITMAPV5HEADER_SIZE = 124

  # http://en.wikipedia.org/wiki/BMP_file_format
  OS22XBITMAPHEADER_SIZE = 64


  # Magic BMP marker.
  TYPE_BM = "BM".unpack(WORD)[0]

  # Compression types.
  BI_RGB       = 0
  BI_RLE8      = 1
  BI_RLE4      = 2
  BI_BITFIELDS = 3
  BI_JPEG      = 4
  BI_PNG       = 5


  attr_reader :filename
  attr_reader :width, :height

  def initialize(filename)
    @filename = filename
    read(filename)
  end

  def get_pixel(x, y)
    index = (@width * y) + x
    @pixel_data[index]
  end

  def inspect
    hex_id = object_id_hex()
    filename = File.basename(@filename)
    image_size = "#{@width}x#{@height}px"
    %{#<#{self.class.name}:#{hex_id} "#{filename}" (#{image_size})>}
  end

  def to_s
    @filename.dup
  end

  private

  def read(filename)
    Binary::File.open(filename) { |file|

      # Read file header.
      data = file.read(BITMAPFILEHEADER)
      bfType, bfSize, bfReserved1, bfReserved2, bfOffBits = data
      if bfType != TYPE_BM
        raise ImageReadError, "Invalid image type: #{bfType}"
      end

      # Read DIB header.
      dib_header_size = file.sniff(DWORD)
      case dib_header_size
      when BITMAPCOREHEADER.size
        data = file.read(BITMAPCOREHEADER)
        # This reads more variables from the struct than it will return, but
        # that is done so they will be initialized to nil. Struct only contain
        # data up til `bit_count`.
        file_size, width, height, planes, bit_count, compression,
          image_size_bytes, x_res, y_res, num_colors, important_colors = data
      when BITMAPINFOHEADER.size,
           BITMAPV4HEADER_SIZE,
           BITMAPV5HEADER_SIZE
        data = file.read(BITMAPINFOHEADER)
        file_size, width, height, planes, bit_count, compression,
          image_size_bytes, x_res, y_res, num_colors, important_colors = data
        # Ensure the data is uncompressed. Currently no compression is
        # supported.
        if compression != BI_RGB
          raise ImageReadError, "Unsupported compression type: #{compression}"
        end
        # Ignore the rest of the data in BITMAPV4HEADER and BITMAPV5HEADER.
        # This data is related to compression or color adjustment, such as
        # gamma correction and color profiles.
        next_struct_position = BITMAPFILEHEADER.size + dib_header_size
        file.seek(next_struct_position, IO::SEEK_SET)
      when OS22XBITMAPHEADER_SIZE
        # REVIEW: This might be redundant if the "BM" check earlier ensure catch
        # the OS/2 types.
        raise ImageReadError, "Unsupported DIB header: OS22XBITMAPHEADER"
      else
        raise ImageReadError, "Unknown DIB header. (Size: #{dib_header_size})"
      end

      # Read color palette
      if bit_count < 16
        palette = []
        # Unless the DIB header specifies the colour count, use the max
        # palette size.
        if num_colors.nil? || num_colors == 0
          case bit_count
          when 1
            num_colors = 2
          when 4
            num_colors = 16
          when 8
            num_colors = 256
          else
            raise ImageReadError, "Unknown Color Palette. #{bit_count}"
          end
        end
        num_colors.times { |i|
          if dib_header_size == BITMAPCOREHEADER.size
            palette << file.read(RGBTRIPLE).reverse!
          else
            b, g, r, reserved = file.read(RGBQUAD)
            palette << [r, g, b]
          end
        }
      end

      # Read bitmap data.
      init_pixel_data(width, height)
      row = 0
      while row < height.abs
        # Row order is flipped if @height is negative.
        y = (height < 0) ? row : height.abs - 1 - row
        x = 0
        while x < width.abs
          case bit_count
          when 1
            i = file.read(UCHAR)
            8.times { |n|
              color = palette[(i & 0x80 == 0) ? 0 : 1]
              set_pixel(x, y, color)
              break if x + n == width - 1
              i <<= 1
            }
            x += 7
          when 4
            i = file.read(UCHAR)
            color = palette[(i >> 4) & 0x0f]
            set_pixel(x, y, color)
            x += 1
            color = palette[i & 0x0f]
            set_pixel(x, y, color) if x < width
          when 8
            i = file.read(UCHAR)
            color = palette[i]
            set_pixel(x, y, color)
          when 16
            c = file.read(WORD)
            r = ((c >> 10) & 0x1f) << 3
            g = ((c >>  5) & 0x1f) << 3
            b = (c >> 0x1f) << 3
            set_pixel(x, y, [r, g, b])
          when 24
            color = file.read(RGBTRIPLE).reverse!
            set_pixel(x, y, color)
          when 32
            b, g, r, reserved = file.read(RGBQUAD)
            set_pixel(x, y, [r, g, b])
          else
            raise ImageReadError, "Unknown bit count: #{bit_count} (#{x}, #{y})"
          end
          x += 1
        end

        # Skip trailing padding. Each row fills out to 32bit chunks
        # RowSizeTo32bit - RowSizeToWholeByte
        row_bit_size = width * bit_count
        row_byte_size = row_bit_size / 8
        row_size_32bit = (row_byte_size + 3) & ~3
        next_row = row_size_32bit - row_byte_size.ceil
        file.seek(next_row, IO::SEEK_CUR)

        row += 1
      end
    }
    nil
  end

  def init_pixel_data(width, height)
    @width = width
    @height = height
    @pixel_data = Array.new(width * height)
    nil
  end

  def set_pixel(x, y, color)
    index = (@width * y) + x
    @pixel_data[index] = color
    nil
  end

  def object_id_hex
    "0x%x" % (self.object_id << 1)
  end

 end # class
end # module TT::Plugins::SolidInspector2
