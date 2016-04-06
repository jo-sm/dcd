class DCD
  attr_reader :metadata, :title, :frames

  def initialize(io, lazy=false)
    @io_pointer = io
    @read_length = 0
    @type = ''
    @endian = ''
    @title = ''
    @metadata = {}
    @frames = {}
    @valid = true

    if !lazy
      read_header
      read_atoms
    end
  end

  # Loads the header, which determines endianness
  # and the initial metadata about the DCD file
  def read_header
    determine_endianness
    gather_metadata
    read_title
    read_atoms_metadata
  end

  def read_atoms
    @frames[:x], @frames[:y], @frames[:z], @frames[:w] = [], [], [], []

    @metadata[:nset].times do |i|
      if @metadata[:extrablock]
        # Unit cell info
        i = @io_pointer.read(@read_length + 48 + @read_length).unpack("L#{endian}*")[0]
        warn "Incorrect frame size in unit cell for step #{i}" if i[0] != i[-1]
        # TODO: Process this data
      end

      # Treat first frame and fixed atoms DCD files differently
      if i == 0 or @metadata[:num_fixed] == 0
        # Read each frame
        read_coord(:x)
        read_coord(:y)
        read_coord(:z)
        read_coord(:w) if @metadata[:w_coords]
      else
        read_fixed_coord(:x)
        read_fixed_coord(:y)
        read_fixed_coord(:z)
        read_coord(:w) if @metadata[:w_coords]
      end
    end
  end

  def print
    if @title == '' or !@frames[:x]
      warn "DCD has not been processed" 
      return nil
    end

    puts "#{@metadata[:is_charmm] ? 'CHARMM' : 'X-PLOR'} #{@type == 'l' ? '32' : '64'}-bit Trajectory File #{@endian == '>' ? 'Big' : 'Little'} Endian"
    puts "#{@title}"
    puts "Nset: #{@metadata[:nset]}"
    puts "Istart: #{@metadata[:istart]}"
    puts "Nsavc: #{@metadata[:nsavc]}"
    puts "Nstep: #{@metadata[:nstep]}"
    puts "Step size: #{@metadata[:step]} picoseconds"
    puts "Number of atoms per frame: #{@metadata[:num_atoms]}"
    @frames[:x].each_with_index do |coords, i|
      puts "Frame #{i}  coordinates"
      coords.each_with_index do |coord, j|
        puts "(#{j})\t\t\t#{@frames[:x][i][j]}\t\t#{@frames[:y][i][j]}\t\t#{@frames[:z][i][j]}"
      end
    end
  end

  private

  def read_coord(coord)
    coord_block_size = @io_pointer.read(@read_length).unpack("#{@type}#{@endian}")[0]
    @frames[coord].push(@io_pointer.read(coord_block_size).unpack('f*'))
    coord_check = @io_pointer.read(@read_length).unpack("#{@type}#{@endian}")[0]

    warn "Invalid block size for #{coord} coords" if coord_block_size != coord_check
  end

  def read_fixed_coord(coord)
    num_free = @metadata[:num_atoms] - @metadata[:num_fixed]

    # Fixed atom coordinates are 4 bytes in length,
    # and there are `num_free` amount of coordinates per block
    fixed_coord_block_size = @io_pointer.read(@read_length).unpack("#{@type}#{@endian}")[0]
    free_atom_coords = @io_pointer.read(4 * num_free).unpack('f*')
    fixed_coord_check = @io_pointer.read(@read_length).unpack("#{@type}#{@endian}")[0]

    raise StandardError, "Invalid DCD, fixed coordinate check did not match" if fixed_coord_block_size != fixed_coord_check

    # Now, a copy of the first frame is made and the trajectory changes are overwritten
    # with the free atom coordinates
    new_coords = @coord[coord][0].clone

    num_free.times do |i|
      new_coords[@metadata[:free_indexes][i]] = free_atom_coords[i]
    end

    @coord[coord].push(new_coords)
  end

  # Determines endianness of DCD file
  def determine_endianness
    # Ensure that the pointer is as position 0
    @io_pointer.seek(0)
    initial_data = @io_pointer.read(4)

    # Default to 32 bit for these values
    @read_length = 4
    @type = 'l'
    
    # Determine if DCD file is 32 bit or 64 bit
    puts initial_data.unpack('L>'), initial_data.unpack('L<')
    if initial_data.unpack('L>')[0] == 84
      # Big endian
      @endian = '>'
    elsif initial_data.unpack('L<')[0] == 84
      # Little endian
      @endian = '<'
    end

    puts @endian, @type

    # If the endianness is not set, then the DCD file is 64 bit
    if @endian == ''
      @type = 'q'

      second_byte = @io_pointer.read(4)
      initial_data = initial_data + second_byte

      @read_length = 8

      if initial_data.unpack('q>')[0] == 84
        @endian = '>'
      elsif initial_data.unpack('q<')[0] == 84
        @endian = '<'
      end
    end

    if @endian == ''
      @valid = false
      raise StandardError, "Invalid DCD file"
    end

    if @io_pointer.read(4) != 'CORD'
      @valid = false
      raise StandardError, "Invalid DCD file"
    end
  end

  # Gathers metadata, including if file is CHARMM format,
  def gather_metadata
    @io_pointer.seek(@read_length + 4)
    metadata_raw = @io_pointer.read(80)

    # The next @read_length amount of data when unpacked should equal 84
    check = @io_pointer.read(@read_length).unpack("#{@type}#{@endian}")[0]
    raise StandardError, "Invalid DCD format, expected 84 but saw #{check}" if check != 84

    unpacked_meta = metadata_raw.unpack("L#{@endian}9a4L#{@endian}*")

    @metadata[:is_charmm] = unpacked_meta[-1] != 0 # 76 - 79
    @metadata[:nset] = unpacked_meta[0] # 0-3
    @metadata[:istart] = unpacked_meta[1] # 4-7
    @metadata[:nsavc] = unpacked_meta[2] # 8-11
    @metadata[:nstep] = unpacked_meta[3] # 12-15 # not present in XPLOR files - is 0
    # unpacked_meta[4] - unpacked_meta[7] are zeros
    @metadata[:num_fixed] = unpacked_meta[8] # 32 - 35
    @metadata[:step_size] = unpacked_meta[9].unpack(@metadata[:is_charmm] ? (@endian == '>' ? 'g' : 'e') : (@endian == '>' ? 'G' : 'E'))[0] # 36 - 39
    @metadata[:charmm_extrablock] = unpacked_meta[10] != 0 # 40 - 43
    @metadata[:w_coords] = unpacked_meta[11] == 1 # 44 - 47
  end

  def read_title
    @io_pointer.seek(@read_length + 80 + 4 + @read_length)
    title_metadata = @io_pointer.read(@read_length*2).unpack("#{@type}#{@endian}2")

    size = title_metadata[0]
    num_lines = title_metadata[1]

    puts size, num_lines

    # VMD's plugin notes: There are certain programs such as Vega ZZ that write an incorrect DCD file header. Check for these
    if num_lines < 0
      raise StandardError, "Invalid DCD file, negative title length"
    elsif num_lines > 1000
      num_lines = 0
      num_lines = 2 if num_lines == 1095062083 # Vega ZZ
      warn "Invalid title length, setting to #{num_lines}. May result in invalid subsequent IO reads"
    end

    title_data = @io_pointer.read(num_lines*80 + @read_length*3).unpack("a#{num_lines*80}#{@type}#{@endian}2l#{@endian}")
    @title = title_data[0]
    size_check = title_data[1]

    raise StandardError, "Invalid DCD format, size mismatch" if size != size_check
    raise StandardError, "Invalid DCD format, invalid check" if title_data[2] != 4
  end

  # This method does not know where to read, since the title can be variable length
  # So this must be called after .read_title
  def read_atoms_metadata
    @metadata[:num_atoms] = @io_pointer.read(@read_length).unpack("#{@type}#{@endian}")[0]

    if @metadata[:num_fixed] != 0
      num_free_data = @io_pointer.read(@read_length + @metadata[:num_atoms] - @metadata[:num_fixed]).unpack("L#{@endian}*")

      num_free = num_free_data[0]
      @metadata[:free_indexes] = num_free_data[1..-2]
      num_free_check = num_free_data[-1]

      raise StandardError, "Invalid DCD format, fixed atoms check failed" if num_free != num_free_check
    end

    @metadata[:body_start] = @io_pointer.pos
  end
end
