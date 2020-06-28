# https://github.com/git/git/blob/master/Documentation/technical/commit-graph-format.txt
module Thicket
  class CommitGraphFile
    getter file_path : String

    getter version : UInt8
    getter hash_version : UInt8
    getter num_chunks : UInt8
    getter num_base_commit_graphs : UInt8
    
    getter num_commits : UInt32
    
    def initialize(@file_path)
      file = File.new(@file_path, "rb")
      
      # Header data
      verify_header_signature(file)
      @version = file.read_at(4, 1, &.read_byte).not_nil!
      @hash_version = file.read_at(5, 1, &.read_byte).not_nil!
      @num_chunks = file.read_at(6, 1, &.read_byte).not_nil!
      @num_base_commit_graphs = file.read_at(7, 1, &.read_byte).not_nil!

      # Chunk data
      contents = chunk_table_of_contents(file)
      oid_fanout_index = contents.index { |c| c[:signature] == "OIDF" }.not_nil!
      oid_fanout_offset = contents[oid_fanout_index][:offset]
      next_offset = contents[oid_fanout_index + 1][:offset]
      oid_fanout_length = next_offset - oid_fanout_offset
      slice = Bytes.new(1024)
      file.read_at(oid_fanout_offset.to_i32, oid_fanout_length.to_i32, &.read(slice))
      slice.reverse!
      fanout = slice.each_slice(4)
                    .map { |integer_slice| integer_slice.to_unsafe.as(UInt32*).value }
                    .to_a
                    .reverse

      @num_commits = fanout.last

      puts "Total number of commits: #{@num_commits}"

      file.close
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
  end
end
