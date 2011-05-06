class RDoc::Options
  ##
  # Should source be included?
  attr_accessor :open_source

  alias_method :rdoc_initialize, :initialize

  def initialize # :nodoc:
    rdoc_initialize
    @open_source = false
    @generator = RDoc::Generator::SHtml
  end

  ##
  # Parse command line options. (Copied from RDoc)
  def parse(argv)
    opts = OptionParser.new do |opt|
      opt.program_name = File.basename $0
      opt.version = RDoc::VERSION
      opt.release = nil
      opt.summary_indent = ' ' * 4
      opt.banner = <<-EOF
Usage: #{opt.program_name} [options] [names...]

  Files are parsed, and the information they contain collected, before any
  output is produced. This allows cross references between all files to be
  resolved. If a name is a directory, it is traversed. If no names are
  specified, all Ruby files in the current directory (and subdirectories) are
  processed.

  How RDoc generates output depends on the output formatter being used, and on
  the options you give.

  - Darkfish creates frameless HTML output by Michael Granger.

  - ri creates ri data files
      EOF

      opt.separator nil
      opt.separator "Parsing Options:"
      opt.separator nil

      opt.on("--all", "-a",
             "Include all methods (not just public) in",
             "the output.") do |value|
        @show_all = value
      end

      opt.separator nil

      opt.on("--exclude=PATTERN", "-x", Regexp,
             "Do not process files or directories",
             "matching PATTERN.") do |value|
        @exclude << value
      end

      opt.separator nil

      opt.on("--extension=NEW=OLD", "-E",
             "Treat files ending with .new as if they",
             "ended with .old. Using '-E cgi=rb' will",
             "cause xxx.cgi to be parsed as a Ruby file.") do |value|
        new, old = value.split(/=/, 2)

        unless new and old then
          raise OptionParser::InvalidArgument, "Invalid parameter to '-E'"
        end

        unless RDoc::ParserFactory.alias_extension old, new then
          raise OptionParser::InvalidArgument, "Unknown extension .#{old} to -E"
        end
      end

      opt.separator nil

      opt.on("--force-update", "-U",
             "Forces rdoc to scan all sources even if",
             "newer than the flag file.") do |value|
        @force_update = value
      end

      opt.separator nil

      opt.on("--pipe",
             "Convert RDoc on stdin to HTML") do
        @pipe = true
      end

      opt.separator nil

      opt.on("--threads=THREADS", Integer,
             "Number of threads to parse with.") do |threads|
        @threads = threads
      end

      opt.separator nil
      opt.separator "Generator Options:"
      opt.separator nil

      opt.on("--charset=CHARSET", "-c",
             "Specifies the output HTML character-set.") do |value|
        @charset = value
      end

      opt.separator nil

      generator_text = @generators.keys.map { |name| "  #{name}" }.sort

      opt.on("--fmt=FORMAT", "--format=FORMAT", "-f", @generators.keys,
             "Set the output formatter.  One of:", *generator_text) do |value|
        @generator_name = value.downcase
        setup_generator
      end

      opt.separator nil

      opt.on("--include=DIRECTORIES", "-i", Array,
             "Set (or add to) the list of directories to",
             "be searched when satisfying :include:",
             "requests. Can be used more than once.") do |value|
        @rdoc_include.concat value.map { |dir| dir.strip }
      end

      opt.separator nil

      opt.on("--line-numbers", "-N",
             "Include line numbers in the source code.") do |value|
        @include_line_numbers = value
      end

      opt.separator nil

      opt.on("--main=NAME", "-m",
             "NAME will be the initial page displayed.") do |value|
        @main_page = value
      end

      opt.separator nil

      opt.on("--output=DIR", "--op", "-o",
             "Set the output directory.") do |value|
        @op_dir = value
      end

      opt.separator nil

      opt.on("--show-hash", "-H",
             "A name of the form #name in a comment is a",
             "possible hyperlink to an instance method",
             "name. When displayed, the '#' is removed",
             "unless this option is specified.") do |value|
        @show_hash = value
      end

      opt.separator nil

      opt.on("--open-source", "-s",
             "Include source code to your documentation") do |value|
        @open_source = value
      end

      opt.separator nil

      opt.on("--tab-width=WIDTH", "-w", OptionParser::DecimalInteger,
             "Set the width of tab characters.") do |value|
        @tab_width = value
      end

      opt.separator nil

      opt.on("--template=NAME", "-T",
             "Set the template used when generating",
             "output.") do |value|
        @template = value
      end

      opt.separator nil

      opt.on("--title=TITLE", "-t",
             "Set TITLE as the title for HTML output.") do |value|
        @title = value
      end

      opt.separator nil

      opt.on("--webcvs=URL", "-W",
             "Specify a URL for linking to a web frontend",
             "to CVS. If the URL contains a '\%s', the",
             "name of the current file will be",
             "substituted; if the URL doesn't contain a",
             "'\%s', the filename will be appended to it.") do |value|
        @webcvs = value
      end

      opt.separator nil
      opt.separator "Diagram Options:"
      opt.separator nil

      image_formats = %w[gif png jpg jpeg]
      opt.on("--image-format=FORMAT", "-I", image_formats,
             "Sets output image format for diagrams. Can",
             "be #{image_formats.join ', '}. If this option",
             "is omitted, png is used. Requires",
             "diagrams.") do |value|
        @image_format = value
      end

      opt.separator nil

      opt.on("--diagram", "-d",
             "Generate diagrams showing modules and",
             "classes. You need dot V1.8.6 or later to",
             "use the --diagram option correctly. Dot is",
             "available from http://graphviz.org") do |value|
        check_diagram
        @diagram = true
      end

      opt.separator nil

      opt.on("--fileboxes", "-F",
             "Classes are put in boxes which represents",
             "files, where these classes reside. Classes",
             "shared between more than one file are",
             "shown with list of files that are sharing",
             "them. Silently discarded if --diagram is",
             "not given.") do |value|
        @fileboxes = value
      end

      opt.separator nil
      opt.separator "ri Generator Options:"
      opt.separator nil

      opt.on("--ri", "-r",
             "Generate output for use by `ri`. The files",
             "are stored in the '.rdoc' directory under",
             "your home directory unless overridden by a",
             "subsequent --op parameter, so no special",
             "privileges are needed.") do |value|
        @generator_name = "ri"
        @op_dir = RDoc::RI::Paths::HOMEDIR
        setup_generator
      end

      opt.separator nil

      opt.on("--ri-site", "-R",
             "Generate output for use by `ri`. The files",
             "are stored in a site-wide directory,",
             "making them accessible to others, so",
             "special privileges are needed.") do |value|
        @generator_name = "ri"
        @op_dir = RDoc::RI::Paths::SITEDIR
        setup_generator
      end

      opt.separator nil

      opt.on("--merge", "-M",
             "When creating ri output, merge previously",
             "processed classes into previously",
             "documented classes of the same name.") do |value|
        @merge = value
      end

      opt.separator nil
      opt.separator "Generic Options:"
      opt.separator nil

      opt.on("--debug", "-D",
             "Displays lots on internal stuff.") do |value|
        $DEBUG_RDOC = value
      end

      opt.on("--quiet", "-q",
             "Don't show progress as we parse.") do |value|
        @verbosity = 0
      end

      opt.on("--verbose", "-v",
             "Display extra progress as we parse.") do |value|
        @verbosity = 2
      end

      opt.separator nil
      opt.separator 'Deprecated options - these warn when set'
      opt.separator nil

      opt.on("--inline-source", "-S") do |value|
        warn "--inline-source will be removed from RDoc on or after August 2009"
      end

      opt.on("--promiscuous", "-p") do |value|
        warn "--promiscuous will be removed from RDoc on or after August 2009"
      end

      opt.separator nil
    end

    argv.insert(0, *ENV['RDOCOPT'].split) if ENV['RDOCOPT']

    opts.parse! argv

    @files = argv.dup

    @rdoc_include << "." if @rdoc_include.empty?

    if @exclude.empty? then
      @exclude = nil
    else
      @exclude = Regexp.new(@exclude.join("|"))
    end

    check_files

    # If no template was specified, use the default template for the output
    # formatter

    @template ||= @generator_name

  rescue OptionParser::InvalidArgument, OptionParser::InvalidOption => e
    puts opts
    puts
    puts e
    exit 1
  end

end
