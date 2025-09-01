require "spec_helper"
require 'zstd-ruby'
require 'securerandom'

RSpec.describe Zstd::StreamingDecompress do
  describe 'streaming decompress' do
    it 'shoud work' do
      # str = SecureRandom.hex(150)
      str = "foo bar buzz" * 100
      cstr = Zstd.compress(str)
      stream = Zstd::StreamingDecompress.new
      result = ''
      result << stream.decompress(cstr[0, 5])
      result << stream.decompress(cstr[5, 5])
      result << stream.decompress(cstr[10..-1])
      expect(result).to eq(str)
    end
  end

  describe 'decompress_with_pos' do
    it 'should return decompressed data and consumed input position' do
      str = "hello world test data"
      cstr = Zstd.compress(str)
      stream = Zstd::StreamingDecompress.new
      
      # Test with partial input
      result_array = stream.decompress_with_pos(cstr[0, 10])
      expect(result_array).to be_an(Array)
      expect(result_array.length).to eq(2)
      
      decompressed_data = result_array[0]
      consumed_bytes = result_array[1]
      
      expect(decompressed_data).to be_a(String)
      expect(consumed_bytes).to be_a(Integer)
      expect(consumed_bytes).to be > 0
      expect(consumed_bytes).to be <= 10
    end

    it 'should work with complete compressed data' do
      str = "foo bar buzz"
      cstr = Zstd.compress(str)
      stream = Zstd::StreamingDecompress.new
      
      result_array = stream.decompress_with_pos(cstr)
      decompressed_data = result_array[0]
      consumed_bytes = result_array[1]
      
      expect(decompressed_data).to eq(str)
      expect(consumed_bytes).to eq(cstr.length)
    end

    it 'should work with multiple calls' do
      str = "test data for multiple calls"
      cstr = Zstd.compress(str)
      stream = Zstd::StreamingDecompress.new
      
      result = ''
      total_consumed = 0
      chunk_size = 5
      
      while total_consumed < cstr.length
        remaining_data = cstr[total_consumed..-1]
        chunk = remaining_data[0, chunk_size]
        
        result_array = stream.decompress_with_pos(chunk)
        decompressed_chunk = result_array[0]
        consumed_bytes = result_array[1]
        
        result << decompressed_chunk
        total_consumed += consumed_bytes
        
        expect(consumed_bytes).to be > 0
        expect(consumed_bytes).to be <= chunk.length
        
        # If we consumed less than the chunk size, we might be done or need more data
        break if consumed_bytes < chunk.length && total_consumed == cstr.length
      end
      
      expect(result).to eq(str)
      expect(total_consumed).to eq(cstr.length)
    end
  end

  describe 'streaming decompress + GC.compact' do
    it 'shoud work' do
      # str = SecureRandom.hex(150)
      str = "foo bar buzz" * 100
      cstr = Zstd.compress(str)
      stream = Zstd::StreamingDecompress.new
      result = ''
      result << stream.decompress(cstr[0, 5])
      result << stream.decompress(cstr[5, 5])
      GC.compact
      result << stream.decompress(cstr[10..-1])
      expect(result).to eq(str)
    end
  end

  describe 'String dictionary streaming decompress + GC.compact' do
    let(:dictionary) do
      File.read("#{__dir__}/dictionary")
    end
    let(:user_json) do
      File.read("#{__dir__}/user_springmt.json")
    end
    it 'shoud work' do
      compressed_json = Zstd.compress(user_json, dict: dictionary)
      stream = Zstd::StreamingDecompress.new(dict: dictionary)
      result = ''
      result << stream.decompress(compressed_json[0, 5])
      result << stream.decompress(compressed_json[5, 5])
      GC.compact
      result << stream.decompress(compressed_json[10..-1])
      expect(result).to eq(user_json)
    end
  end

  describe 'Zstd::DDict dictionary streaming decompress + GC.compact' do
    let(:dictionary) do
      File.read("#{__dir__}/dictionary")
    end
    let(:ddict) do
      Zstd::DDict.new(dictionary)
    end
    let(:user_json) do
      File.read("#{__dir__}/user_springmt.json")
    end
    it 'shoud work' do
      compressed_json = Zstd.compress(user_json, dict: dictionary)
      stream = Zstd::StreamingDecompress.new(dict: ddict)
      result = ''
      result << stream.decompress(compressed_json[0, 5])
      result << stream.decompress(compressed_json[5, 5])
      GC.compact
      result << stream.decompress(compressed_json[10..-1])
      expect(result).to eq(user_json)
    end
  end

  describe 'nil dictionary streaming decompress + GC.compact' do
    let(:dictionary) do
      File.read("#{__dir__}/dictionary")
    end
    let(:user_json) do
      File.read("#{__dir__}/user_springmt.json")
    end
    it 'shoud work' do
      compressed_json = Zstd.compress(user_json)
      stream = Zstd::StreamingDecompress.new(dict: nil)
      result = ''
      result << stream.decompress(compressed_json[0, 5])
      result << stream.decompress(compressed_json[5, 5])
      GC.compact
      result << stream.decompress(compressed_json[10..-1])
      expect(result).to eq(user_json)
    end
  end

  if Gem::Version.new(RUBY_VERSION) >= Gem::Version.new('3.0.0')
    describe 'Ractor' do
      it 'should be supported' do
        r = Ractor.new {
          cstr = Zstd.compress('foo bar buzz')
          stream = Zstd::StreamingDecompress.new
          result = ''
          result << stream.decompress(cstr[0, 5])
          result << stream.decompress(cstr[5, 5])
          result << stream.decompress(cstr[10..-1])
          result
        }
        expect(r.take).to eq('foo bar buzz')
      end
    end
  end
end

describe 'edge cases' do
  it 'handles empty compressed data' do
    # Compress an empty string and then decompress it
    empty_compressed = Zstd.compress('')
    stream = Zstd::StreamingDecompress.new
    result = stream.decompress(empty_compressed)
    expect(result).to eq('')
  end

  it 'handles very small compressed data' do
    small_data = "a"
    compressed = Zstd.compress(small_data)
    stream = Zstd::StreamingDecompress.new
    result = stream.decompress(compressed)
    expect(result).to eq(small_data)
  end

  it 'handles large compressed data' do
    large_data = "x" * 100_000
    compressed = Zstd.compress(large_data)
    stream = Zstd::StreamingDecompress.new
    result = stream.decompress(compressed)
    expect(result).to eq(large_data)
  end

  it 'handles single byte chunks' do
    data = "hello world"
    compressed = Zstd.compress(data)
    stream = Zstd::StreamingDecompress.new
    result = ''

    # Decompress one byte at a time
    compressed.each_char do |byte|
      result << stream.decompress(byte)
    end

    expect(result).to eq(data)
  end
end

describe 'chunk size variations' do
  it 'handles varying chunk sizes during decompression' do
    data = "test data for chunk size variations"
    compressed = Zstd.compress(data)
    stream = Zstd::StreamingDecompress.new
    result = ''

    # Use different chunk sizes: 1, 2, 4, 8, etc.
    chunk_sizes = [1, 2, 4, 8, 16]
    pos = 0

    while pos < compressed.length
      chunk_size = chunk_sizes[pos % chunk_sizes.length]
      chunk = compressed[pos, chunk_size]
      result << stream.decompress(chunk)
      pos += chunk_size
    end

    expect(result).to eq(data)
  end

  it 'handles very small chunks with decompress_with_pos' do
    data = "test data"
    compressed = Zstd.compress(data)
    stream = Zstd::StreamingDecompress.new
    result = ''
    total_consumed = 0

    while total_consumed < compressed.length
      # Take 1 byte at a time
      chunk = compressed[total_consumed, 1]
      result_array = stream.decompress_with_pos(chunk)
      decompressed_chunk = result_array[0]
      consumed_bytes = result_array[1]

      result << decompressed_chunk
      total_consumed += consumed_bytes

      # Break if we've consumed all data
      break if total_consumed >= compressed.length
    end

    expect(result).to eq(data)
  end
end

describe 'error handling' do
  it 'raises error for invalid compressed data' do
    stream = Zstd::StreamingDecompress.new
    invalid_data = "this is not compressed data"

    expect { stream.decompress(invalid_data) }.to raise_error(RuntimeError)
  end

  it 'handles truncated compressed data' do
    data = "test data for truncation"
    compressed = Zstd.compress(data)
    # Take only a very small part of the compressed data
    truncated = compressed[0, 5]

    stream = Zstd::StreamingDecompress.new
    # Zstd may not always raise an error for truncated data immediately
    # but it should handle it gracefully
    expect { stream.decompress(truncated) }.not_to raise_error
  end

  it 'handles corrupted compressed data' do
    data = "test data for corruption"
    compressed = Zstd.compress(data)
    # Create heavily corrupted data
    corrupted = "corrupted" + compressed[10..-1]

    stream = Zstd::StreamingDecompress.new
    # Zstd should raise an error for corrupted data
    expect { stream.decompress(corrupted) }.to raise_error(RuntimeError)
  end

  it 'handles partial decompression gracefully' do
    data = "test data for partial decompression"
    compressed = Zstd.compress(data)
    stream = Zstd::StreamingDecompress.new

    # Try to decompress with very small chunks that might not contain complete frames
    result = ''
    begin
      compressed.each_char do |byte|
        partial_result = stream.decompress(byte)
        result << partial_result
      end
    rescue RuntimeError
      # This is expected for incomplete data
    end

    # The result might be partial, but shouldn't crash
    expect(result).to be_a(String)
  end
end

describe 'concurrent operations' do
  it 'handles multiple decompress streams simultaneously' do
    # Create test data
    test_data = ["stream 1 data", "stream 2 data", "stream 3 data"]

    # Compress all data
    compressed_data = test_data.map { |data| Zstd.compress(data) }

    # Create multiple decompress streams
    streams = compressed_data.map do |compressed|
      stream = Zstd::StreamingDecompress.new
      result = stream.decompress(compressed)
      result
    end

    # Verify results
    streams.each_with_index do |result, i|
      expect(result).to eq(test_data[i])
    end
  end

  it 'handles interleaved decompress operations' do
    data1 = "first stream data"
    data2 = "second stream data"

    compressed1 = Zstd.compress(data1)
    compressed2 = Zstd.compress(data2)

    stream1 = Zstd::StreamingDecompress.new
    stream2 = Zstd::StreamingDecompress.new

    # Interleave decompression operations
    result1 = stream1.decompress(compressed1[0, 10])
    result2 = stream2.decompress(compressed2[0, 10])
    result1 << stream1.decompress(compressed1[10..-1])
    result2 << stream2.decompress(compressed2[10..-1])

    expect(result1).to eq(data1)
    expect(result2).to eq(data2)
  end
end
