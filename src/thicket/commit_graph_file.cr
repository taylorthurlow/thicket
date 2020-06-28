# https://github.com/git/git/blob/master/Documentation/technical/commit-graph-format.txt
module Thicket
  class CommitGraphFile
    getter file_path : String

    getter version : UInt8
    getter hash_version : UInt8
    getter num_chunks : UInt8
    getter num_base_commit_graphs : UInt8
    
    getter oid_fanout : Array(UInt32)
    getter num_commits : UInt32
    getter commit_oids : Array(String)
    
    def initialize(@file_path)
      file = File.new(@file_path, "rb")
      
      # Header data
      verify_header_signature(file)
      @version = file.read_at(4, 1, &.read_byte).not_nil!
      @hash_version = file.read_at(5, 1, &.read_byte).not_nil!
      @num_chunks = file.read_at(6, 1, &.read_byte).not_nil!
      @num_base_commit_graphs = file.read_at(7, 1, &.read_byte).not_nil!

      contents = chunk_table_of_contents(file)
      pp contents

      @oid_fanout = parse_oid_fanout(file, contents)
      @num_commits = @oid_fanout.last
      puts "Number of commits: #{@num_commits}"
      
      @commit_oids = parse_oid_lookup(file, contents)
      puts "First commit: #{@commit_oids.first[0..6]}"
      puts " Last commit: #{@commit_oids.last[0..6]}"

      file.close
    end

    # The length of a full commit hash in bytes.
    def commit_hash_length : UInt32
      case @hash_version
      when 1 # SHA-1
        20.to_u32
      else
        raise "Unknown hash version identifier: #{@hash_version}"
      end
    end

    private def verify_header_signature(file : File)
      signature = file.read_at(0, 4, &.read_string(4))
      
      if signature != "CGPH"
        raise "Found unknown commit graph file header signature: #{signature}"
      end
    end

    private def chunk_table_of_contents(file : File) : Array({ signature: String, offset: UInt64 })
      contents = [] of { signature: String, offset: UInt64 }

      current_byte = 8
      
      loop do
        chunk_signature = file.read_at(current_byte, 4, &.read_string(4))
        break if chunk_signature == "\0\0\0\0"
        
        chunk_offset_bytes = begin
          slice = Bytes.new(8)
          file.read_at(current_byte + 4, 8, &.read(slice))
          slice.reverse!
          slice.to_unsafe.as(UInt64*).value
        end

        contents << { signature: chunk_signature, offset: chunk_offset_bytes }

        current_byte += 12
      end

      if contents.none? { |c| c[:signature] == "OIDF" }
        raise "Unable to find OID Fanout chunk in commit graph file."
      end

      if contents.none? { |c| c[:signature] == "OIDL" }
        raise "Unable to find OID Lookup chunk in commit graph file."
      end
      
      if contents.none? { |c| c[:signature] == "CDAT" }
        raise "Unable to find Commit Data chunk in commit graph file."
      end

      contents.sort_by { |c| c[:offset] }
    end

    private def parse_oid_fanout(
      file : File,
      contents : Array({ signature: String, offset: UInt64 })
    ) : Array(UInt32)
      oid_fanout_index = contents.index { |c| c[:signature] == "OIDF" }.not_nil!
      oid_fanout_offset = contents[oid_fanout_index][:offset]
      
      oid_fanout_length = if contents[oid_fanout_index + 1]?
        contents[oid_fanout_index + 1][:offset] - oid_fanout_offset
      else
        # Exclude trailer hash if necessary
        file.size - commit_hash_length - oid_fanout_offset
      end

      slice = Bytes.new(1024)
      file.read_at(oid_fanout_offset.to_i32, oid_fanout_length.to_i32, &.read(slice))
      slice.reverse!
      
      slice.each_slice(4)
           .map { |integer_slice| integer_slice.to_unsafe.as(UInt32*).value }
           .to_a
           .reverse
    end

    private def parse_oid_lookup(
      file : File,
      contents : Array({ signature: String, offset: UInt64 })
    ) : Array(String)
      oid_lookup_index = contents.index { |c| c[:signature] == "OIDL" }.not_nil!
      oid_lookup_offset = contents[oid_lookup_index][:offset]

      oid_lookup_length = if contents[oid_lookup_index + 1]?
        contents[oid_lookup_index + 1][:offset] - oid_lookup_offset
      else
        # Exclude trailer hash if necessary
        file.size - commit_hash_length - oid_lookup_offset
      end

      slice = Bytes.new(@num_commits * commit_hash_length)
      file.read_at(oid_lookup_offset.to_i32, oid_lookup_length.to_i32, &.read(slice))
      slice.reverse!

      oids = Array.new(num_commits) do |i|
        start = i * commit_hash_length
        subslice = slice[start, commit_hash_length]
        
        subslice.to_a.map { |b| sprintf("%02x", b) }.reverse.join
      end

      oids.reverse!
    end
  end
end
