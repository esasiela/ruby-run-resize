require 'rmagick'

class Resizer
  attr_accessor :recurse, :verbose, :clobber, :dimensions, :silent, :scanCount, :sourceCount, :targetCount, :sourceMap, :quality, :resizeDirName, :ignoreFile, :ignoreList, :extensions

  # allow for nice boolean method names
  alias_method :recurse?, :recurse
  alias_method :verbose?, :verbose
  alias_method :clobber?, :clobber
  alias_method :silent?,  :silent

  def initialize()
    @recurse = true
    @verbose = false
    @clobber = false
    @silent  = false
    @quality = 5

    @dimensions = [400, 800]

    @extensions = ['.jpg']

    @resizeDirName = "resized"

    @ignoreFile = ".ruby-run-resize-ignore"
    @ignoreList = nil

    @scanCount = 0
    @sourceCount = 0
    @targetCount = 0

    @sourceMap = Hash.new

  end

  def showStats()
    info("Processing Summary:")
    info("\tScan Count:   #{@scanCount}\t(total images on site)")
    info("\tSource Count: #{@sourceCount}\t(total that needed conversion)")
    info("\tTarget Count: #{@targetCount}\t(total output images)")
  end

  def process(pathStr)
    p = Pathname.new(pathStr)

    log("\nPROCESSING: #{p.cleanpath}")

    if !p.exist?
      STDERR.puts("path [#{p.cleanpath}] does not exist, skipping.")

    elsif !p.readable?
      STDERR.puts "file/dir [#{p.cleanpath}] is not readable, skipping."

    elsif self.ignore?(p)
      # ignore list can match both directories and files
      log("ignoring [#{p.cleanpath}]")

    elsif p.directory?
      self.processDir(p)

    elsif p.file?
      processFile(p)

      else
      # should never reach here since we tested (A) exists (B) readable (C) directory (D) file, but you never know
      puts "neither file nor directory [#{p.cleanpath}], skipping."
    end
  end

  def processDir(dir)
    log("directory [#{dir.cleanpath}]")

    # TODO check the directory for a .ruby-run-resize-ignore file and append it to the @ignoreList

    Dir.foreach(dir) do |file|
      # skip current directory and parent directory
      next if file == '.' or file == '..'

      p = Pathname.new("#{dir}/#{file}")

      if recurse? or p.file?
        # if user specified directory recursion or its a file, continue down the rabbit hole
        self.process(p.cleanpath)
      end
    end
  end

  def processFile(sourceFile)
    log("file [#{sourceFile.cleanpath}]")

    # test file is a recognized image type
    if !self.image?(sourceFile)
      log("\tnot a supported image type, skipping")
      return
    end

    # record that we found a legit image that might need conversion
    @scanCount += 1

    # start as nil, we will load it into memory only when we absolutely have to
    sourceImg = nil

=begin
      for each output dimension:
        * check that the output directory exists, if not then create it
        * check that the output directory is writable
        * are there any reasons an image would not qualify? (i.e. only reductions allowed?)
        * if target exists, check if we want to clobber
        * run the image resizer
=end

    @dimensions.each { |dim|
      targetDir = Pathname.new("#{sourceFile.dirname}/#{@resizeDirName}/#{dim}")
      log("processing dim [#{dim}] with output dir [#{targetDir}]")

      targetFile = Pathname.new("#{targetDir.cleanpath}/#{sourceFile.basename}")
      if targetFile.exist?
        # since target file exists, that implies that target dir also exists, saving us some filesystem overhead

        if self.clobber?
          # it exists and user specified to clobber, delete the file
          log("target file exists and clobber specified, clobber it")
          targetFile.delete()

        else
          # it exists and user specified NO clobber, skip the conversion
          log("target file exists and no clobber, skipping")
          next
        end
      else
        # since target file does not exist, it is possible that the target dir also does not exist

        if !targetDir.exist?
          # we dont test for writability or failure, just blindly run mkpath(), next step we check that it worked.
          log("output directory does not exist, creating")
          targetDir.mkpath()
        end

        if !targetDir.exist? or !targetDir.writable?
          STDERR.puts("dimension output directory [#{targetDir.cleanpath}] does not exist or not writable, skipping conversion.")
          next
        end
      end

      # TODO check qualifications of image file (maybe only reductions allowed? maybe only landscape?)

=begin
only make it here if target file does not exist (either because never existed, or we clobbered it)

lazy loading the source file, we do it here so that we only eat the overhead of loading the image
when we have to, and we only do it once for all the dimensions that need processing
=end
      if sourceImg == nil
        # load the image into an rmagick class
        log("loading source image into memory")
        sourceImg = Magick::Image::read(sourceFile).first
      end

      # perform image resize operation and save to target file
      resizeImage(sourceFile, sourceImg, targetFile, dim)

      # record that we have a source file (BUT only once for this sourceFile)
      @sourceMap[sourceFile] = 1
      @sourceCount = @sourceMap.length

    }

    # release the memory used for the source image after all dimensions are done
    if sourceImg != nil
      sourceImg.destroy!
    end

  end

  def resizeImage(sourceFile, sourceImg, targetFile, newWidth)

    sourceWidth = sourceImg.columns.to_f
    resizeRatio = newWidth.to_f / sourceWidth

    log("resize dst [#{targetFile}] dstWidth [#{newWidth}] srcWidth [#{sourceWidth}] ratio [#{resizeRatio}]")

    targetImg = sourceImg.scale(resizeRatio)
    targetImg.auto_orient!


    targetImg.write(targetFile) do |f|
      f.interlace = targetImg.interlace
      f.quality = @quality.to_i
    end

    info("resized [#{sourceFile.basename}] to width [#{newWidth}], saved to [#{targetFile.cleanpath}]")

    # record that we did a resize
    @targetCount += 1

    # release the memory used for the target image
    targetImg.destroy!

  end

  def ignore?(p)

    if @ignoreList == nil
      # first time through, load the ignore file
      @ignoreList = []

      ignorePath = Pathname.new(@ignoreFile)

      if ignorePath.exist? and ignorePath.readable?
        log("loading ignore file [#{ignorePath.cleanpath}]")
        File.readlines(@ignoreFile).each do |line|
          # blank lines and lines beginning with pound # are skipped
          line = line.strip
          if !line.start_with?('#') and line != ''
            log("ignore file: have non-comment line [#{line}]")
            @ignoreList.push(line)
          else
            log("ignore file: have comment line [#{line}]")
          end
        end
      else
        STDERR.puts("ignore file [#{ignorePath.cleanpath}] does not exist or not readable, skipping.")
      end
    end

    # check the ignore list, plus automatically build in a check for the "resize" dir
    @ignoreList.include?(p.cleanpath.to_s) or p.basename.to_s == @resizeDirName
  end

  def image?(p)
    @extensions.each { |e|
      if p.extname == e
        return true
      end
    }
    return false
  end

  def info(s)
    if !silent?
      puts s
    end
  end

  def log(s)
    if verbose?
      puts s
    end
  end
end
