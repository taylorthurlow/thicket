require "file_utils"

require "./time_measure"

module Thicket
  class Log
    LOG_PARSE_REGEX = /[a-f0-9]{7}.+?m(.+?) .+?m\{(.+?)\}.+?m (?:\((.+?)\))?.+?m(.+$)/

    def initialize(@options : Hash = {} of Symbol => String)
      @count_parsed = 0
    end

    def print
      FileUtils.cd(git_working_directory)
      `#{git_log_command}`.split("\n").each do |l|
        puts process_git_log_line(l)

        if @options.has_key?(:limit)
          limit = @options[:limit].to_i { 99999 }
          next unless @count_parsed >= limit
        else
          next
        end

        puts "..."
        puts "Stopped after #{@options[:limit]} commits. More commit history exists."
        break
      end
    rescue Errno
      puts "CAUGHT!"
    end

    # Takes a single line of raw, colored git log output and manipulates it
    # into the desired format.
    private def process_git_log_line(line : String) : String
      @padding_char = @padding_char == " " ? "-" : " "

      matcher = line.match(LOG_PARSE_REGEX)

      if matcher
        new_line = process_date_time(matcher[1], line, !matcher[3]?.nil?)
        new_line = process_refs(matcher[3], new_line) if matcher[3]? && @options.has_key?(:consolidate_refs)
        new_line = process_message_prefix(matcher[4], new_line) if @options[:color_prefixes]?
        new_line = process_author_name(matcher[2], new_line)

        @count_parsed += 1
      end

      new_line || line
    end

    # Takes an input log string and a commit date/time and replaces it in the
    # log string with a formatted version.
    private def process_date_time(time_string : String, line : String, have_refs : Bool) : String
      seconds_ago = (Time.utc - Time.parse_iso8601(time_string)).total_seconds.to_i64
      seconds_ago = 0 if seconds_ago < 0 # Commits can be in the future
      measure = TimeMeasure.measures.find { |m| m.threshold_in_seconds <= seconds_ago }

      raise "Unable to find applicable measure" if measure.nil?
      quantity = (seconds_ago / measure.length_in_seconds).floor.to_i64

      to_sub = String.build do |str|
        str << "#{quantity}#{measure.abbreviation}"
        str << "\e[31m" if have_refs # add color if we have refs in this line
      end

      line.sub(time_string, to_sub)
    end

    # Takes an input log string and a refs list, and formats the refs list in a
    # more consolidated way.
    private def process_refs(refs : String, line : String)
      original_refs = refs

      main_remote = if @options.has_key?(:main_remote)
                      @options[:main_remote]
                    else
                      "origin"
                    end

      refs = strip_color(refs).split(",").map { |s| s.strip }
      tags = [] of String

      head_ref_index = nil
      refs.each_with_index do |r, i|
        if r.starts_with?("HEAD -> ")
          head_ref_index = i
          break
        end
      end

      refs_to_delete = [] of String
      refs.each_with_index do |r, i|
        refs_to_delete << r if r == "#{main_remote}/HEAD"

        next if r.starts_with?("#{main_remote}/")

        ref_without_head = r.sub("HEAD -> ", "")
        branch = "#{main_remote}/#{ref_without_head}"
        if refs.includes?(branch)
          refs_to_delete << branch
          refs[i] = "#{r}#"
        end

        if r.starts_with?("tag:")
          refs_to_delete << r
          tags << r.sub("tag: ", "")
        end
      end

      if head_ref_index
        refs[head_ref_index] = refs[head_ref_index].not_nil!.sub("HEAD -> ", "@")
      end

      refs_to_delete.each { |r| refs.delete(r) }

      refs = if refs.any?
               "(#{refs.compact.join(", ")})"
             else
               ""
             end

      substitute = if tags.any?
                     tags = "\e[35m[#{tags.join(", ")}]\e[0m"
                     if refs.empty?
                       tags
                     else
                       "#{refs} #{tags}"
                     end
                   else
                     refs
                   end

      line.sub("(#{original_refs})", substitute)
    end

    # Takes an input log string and commit message, finds commit messages
    # prefixes, and darkens them.
    private def process_message_prefix(message : String, line : String)
      prefix_regex = /^(?=.*[0-9])([A-Z\d-]+?[: \/])/

      if matcher = message.match(prefix_regex)
        prefix = matcher[1]
        return line.sub(/([^\/])#{prefix}/, "\\1\e[30m#{prefix}\e[m")
      end

      line
    end

    # Takes an input log string and commit author, and moves it from the normal
    # position in the string to a right-justified location.
    private def process_author_name(author : String, line : String)
      line = line.sub("\e[34m{#{author}}\e[31m ", "")
      total_length = strip_color(line).size
      over = (total_length + author.size + 1) - terminal_width
      line = line[0...-over] if over > 0

      total_length = strip_color(line).size
      spaces_needed = terminal_width - total_length - author.size - 2

      String.build do |str|
        if spaces_needed < 0
          str << "#{line[0...-spaces_needed - 5]}...  "
        else
          str << line
          str << " \e[30m"
          padding = @padding_char || " "
          str << padding * spaces_needed
          str << " \e[m"
        end

        str << "\e[34m#{author}\e[m"
      end
    end

    # Strips ANSI color escape codes from a string. Colorize's
    # String#uncolorize would be used, but it seems to only remove escape codes
    # which match a strict pattern, which git log's colored output doesn't
    # follow.
    private def strip_color(string : String) : String
      color_escape_regex = /\e\[([;\d]+)?m/
      string.gsub(color_escape_regex, "").chomp
    end

    # The command string which gets the raw git log input straight from git.
    # Includes all formatting and color escape codes.
    private def git_log_command : String
      format = "%C(yellow)%h %Cgreen%aI %Cblue{%an}%Cred%d %Creset%s"

      String.build do |str|
        str << "git log --oneline --decorate --color " \
               "--graph --pretty=format:'#{format}'"
        str << " --all" if @options.has_key?(:all) && @options[:all]
      end
    end

    private def git_working_directory : String
      if @options.has_key? :project_directory
        @options[:project_directory]
      else
        Dir.current
      end
    end

    private def terminal_width : Int16
      if ENV["TERM"]?.nil? || ENV["TERM"].blank?
        80.to_i16
      else
        # Not sure why this assignment is required, but it seems like `tput
        # cols` is being evaluated even when run with `TERM-""`
        ENV["TERM"] ||= "xterm"
        `tput cols`.to_i16
      end
    end
  end
end
