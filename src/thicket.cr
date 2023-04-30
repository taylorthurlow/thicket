require "option_parser"

require "./thicket/log"
require "./thicket/version"

module Thicket
  getter :options

  @@options = {} of Symbol => String

  def self.run
    OptionParser.parse do |parser|
      parser.banner = "Usage: thicket [options]"

      parser.on("-h", "--help", "Print this help") do
        puts parser
        exit
      end

      parser.on("-v", "--version", "Print the version number") do |v|
        puts Thicket::VERSION
        exit
      end

      parser.on("-e", "--experimental", "Use true git graph parsing") do |v|
        @@options[:experimental] = v
      end

      parser.on("-d", "--directory=DIRECTORY", "Path to the project directory") do |d|
        if d.nil?
          STDERR.puts "You must provide a project directory."
          exit(1)
        end
        @@options[:project_directory] = File.expand_path(d)
      end

      parser.on("-n", "--commit-limit=LIMIT", "Number of commits to parse before stopping") do |n|
        if n.nil?
          STDERR.puts "You must provide a number of commits."
          exit(1)
        end
        @@options[:limit] = n
      end

      parser.on("-a", "--all", "Displays all branches on all remotes") do |a|
        @@options[:all] = a
      end

      parser.on("-r", "--refs", "Consolidate the refs list") do |r|
        @@options[:consolidate_refs] = r
      end

      parser.on("--initials", "Condense author full names into initials") do |value|
        @@options[:initials] = value
      end

      parser.on("--exclude-remote-dependabot", "Exclude remote dependabot branches") do |value|
        @@options[:exclude_remote_dependabot] = value
      end

      parser.on("--main-remote=MAIN_REMOTE", "The name of the primary remote, defaults to 'origin'") do |m|
        if m.nil?
          STDERR.puts "You must provide the name of the main remote."
          exit(1)
        end
        @@options[:main_remote] = m
      end

      parser.on("-p", "--color-prefixes", "Adds coloring to commit message prefixes") do |pr|
        @@options[:color_prefixes] = pr
      end

      parser.on("--git-binary=BINARY", "Path to a git executable") do |gb|
        if gb.nil?
          STDERR.puts "You must provide a path to the git binary."
          exit(1)
        end
        @@options[:git_binary] = File.expand_path(gb)
      end

      parser.invalid_option do |flag|
        STDERR.puts "#{flag} is not a valid option."
        STDERR.puts parser
        exit(1)
      end
    end

    Thicket::Log.new(@@options).print
  end
end

Thicket.run
