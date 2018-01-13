#!/usr/bin/env ruby

require 'pathname'
require 'slop'

require_relative 'Resizer'


opts = Slop.parse do |o|
  o.banner = 'usage: ruby-run-resize [options] PATH [PATH...]'
  o.bool '-c', '--clobber', 'delete existing output files'
  o.bool '-s', '--shallow', 'do not recurse into directories'
  o.integer '-y', '--quality', 'image quality for output files (1-100), default 95', default: 95
  o.array '-d', '--dimensions', 'comma-delimted list of pixel widths', delimiter: ',', default: [400,800]
  o.string '-r', '--resize-dir', 'subfolder in which to store resized images, default \'resized\'', default: 'resized'
  o.string '-i', '--ignore-file', 'file containing names of images to ignore, default \'.ruby-run-resize-ignore\'', default: '.ruby-run-resize-ignore'
  o.array '-e', '--extensions', 'comma-delmited list of image extensions, including the dot', default: [".jpg", ".png"]
  o.bool '-q', '--quiet', 'suppress output (quiet mode)'
  o.bool '-v', '--verbose', 'enable verbose mode'
  o.bool '-h', '--help', 'display help message'
  o.on '--version', 'print the version' do
    puts 'ruby-run-resize 0.1'
    exit
  end

end

if opts.help? or opts.arguments.empty?
  puts opts
  exit
end

# TODO read stdin and process each line as a root path

r = Resizer.new()
r.clobber = opts.clobber?
r.recurse = !opts.shallow?
r.quality = opts[:quality]
r.dimensions = opts[:dimensions]
r.resizeDirName = opts[:'resize-dir']
r.ignoreFile = opts[:'ignore-file']
r.extensions = opts[:extensions]
r.verbose = opts.verbose?
r.silent  = opts.quiet?

opts.arguments.each { |path|
  r.process(path)
}


if !opts.quiet? and r.targetCount>0
  puts ""
end
r.showStats()

