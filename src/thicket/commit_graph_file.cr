# https://github.com/git/git/blob/master/Documentation/technical/commit-graph-format.txt
module Thicket
  class CommitGraphFile
    getter file_path : String
    getter version : UInt8
    getter hash_version : UInt8
    getter num_chunks : UInt8
    getter num_base_commit_graphs : UInt8
    
    def initialize(@file_path)
      file = File.new(@file_path, "rb")
      
      # Header data
      verify_header_signature(file)
      @version = file.read_at(4, 1, &.read_byte).not_nil!
      @hash_version = file.read_at(5, 1, &.read_byte).not_nil!
      @num_chunks = file.read_at(6, 1, &.read_byte).not_nil!
      @num_base_commit_graphs = file.read_at(7, 1, &.read_byte).not_nil!

      # Chunk data
      chunk_table = [] of { signature: String, offset_bytes: UInt64 }
      current_byte = 8
      loop do
        chunk_signature = file.read_at(current_byte, 4, &.read_string(4))
        break if chunk_signature == "\0\0\0\0"
        puts "Encountered signature: #{chunk_signature.inspect}"
        
        chunk_offset_bytes = begin
          slice = Bytes.new(8)
          file.read_at(current_byte + 4, 8, &.read(slice))
          slice.reverse!
          slice.to_unsafe.as(UInt64*).value
        end

        chunk_table << { signature: chunk_signature, offset_bytes: chunk_offset_bytes }

        current_byte += 12
      end

      pp chunk_table

      file.close
    end

    private def verify_header_signature(file : File)
      signature = file.read_at(0, 4, &.read_string(4))
      
      if signature != "CGPH"
        raise "Found unknown commit graph file header signature: #{signature}"
      end
    end

#    private def chunk_at(file : File, index : UInt8) : CommitGraphChunk
#      
#      # each chunk header is 12 bytes
#      chunk_header_start : UInt32 = (index.to_u32 + 1) * 12 
#
#      id : String = file.read_at(chunk_header_start.to_i32, 4, &.read_string(4))
#      puts id
#      # raise "encountered terminating label" if id == 0
#      
#      slice = Bytes.new(8)
#      file.read_at(chunk_header_start.to_i32 + 4, 8, &.read(slice))
#      file_offset = slice.to_unsafe.as(UInt64*).value
#
#      return CommitGraphChunk.new(id, file_offset, file)
#    end
  end

#  class CommitGraphChunk
#    getter id : String
#    getter file_offset : UInt64
#
#    def initialize(@id, @file_offset, file)
#    end
#  end
end
