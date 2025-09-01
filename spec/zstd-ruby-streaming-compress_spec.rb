require "spec_helper"
require 'zstd-ruby'

RSpec.describe Zstd::StreamingCompress do
  describe '<<' do
    it 'shoud work' do
      stream = Zstd::StreamingCompress.new
      stream << "abc" << "def"
      res = stream.finish
      expect(Zstd.decompress(res)).to eq('abcdef')
    end
  end

  describe '<< + GC.compat' do
    it 'shoud work' do
      stream = Zstd::StreamingCompress.new
      stream << "abc" << "def"
      GC.compact
      stream << "ghi"
      res = stream.finish
      expect(Zstd.decompress(res)).to eq('abcdefghi')
    end
  end

  describe '<< + flush' do
    it 'shoud work' do
      stream = Zstd::StreamingCompress.new
      stream << "abc" << "def"
      res = stream.flush
      stream << "ghi"
      res << stream.finish
      expect(Zstd.decompress(res)).to eq('abcdefghi')
    end
  end

  describe 'compress + flush' do
    it 'shoud work' do
      stream = Zstd::StreamingCompress.new
      res = stream.compress("abc")
      res << stream.flush
      res << stream.compress("def")
      res << stream.finish
      expect(Zstd.decompress(res)).to eq('abcdef')
    end
  end

  describe 'compression level' do
    it 'shoud work' do
      stream = Zstd::StreamingCompress.new(level: 5)
      stream << "abc" << "def"
      res = stream.finish
      expect(Zstd.decompress(res)).to eq('abcdef')
    end
  end

  describe 'String dictionary' do
    let(:dictionary) do
      File.read("#{__dir__}/dictionary")
    end
    let(:user_json) do
      File.read("#{__dir__}/user_springmt.json")
    end
    it 'shoud work' do
      dict_stream = Zstd::StreamingCompress.new(level: 5, dict: dictionary)
      dict_stream << user_json
      dict_res = dict_stream.finish
      stream = Zstd::StreamingCompress.new(level: 5)
      stream << user_json
      res = stream.finish

      expect(dict_res.length).to be < res.length
    end
  end

  describe 'Zstd::CDict dictionary' do
    let(:cdict) do
      Zstd::CDict.new(File.read("#{__dir__}/dictionary"), 5)
    end
    let(:user_json) do
      File.read("#{__dir__}/user_springmt.json")
    end
    it 'shoud work' do
      dict_stream = Zstd::StreamingCompress.new(dict: cdict)
      dict_stream << user_json
      dict_res = dict_stream.finish
      stream = Zstd::StreamingCompress.new(level: 5)
      stream << user_json
      res = stream.finish

      expect(dict_res.length).to be < res.length
    end
  end

  describe 'nil dictionary' do
    let(:user_json) do
      File.read("#{__dir__}/user_springmt.json")
    end
    it 'shoud work' do
      dict_stream = Zstd::StreamingCompress.new(level: 5, dict: nil)
      dict_stream << user_json
      dict_res = dict_stream.finish
      stream = Zstd::StreamingCompress.new(level: 5)
      stream << user_json
      res = stream.finish

      expect(dict_res.length).to eq(res.length)
    end
  end

  describe 'write method' do
    it 'returns correct byte count' do
      sc = Zstd::StreamingCompress.new

      data1 = "Hello"
      data2 = "World"

      bytes1 = sc.write(data1)
      bytes2 = sc.write(data2)

      expect(bytes1).to eq(data1.bytesize)
      expect(bytes2).to eq(data2.bytesize)
    end

    it 'accepts multiple arguments' do
      sc = Zstd::StreamingCompress.new

      total_bytes = sc.write("Hello", " ", "World")

      expect(total_bytes).to eq(11) # "Hello" + " " + "World"
    end
  end

  if Gem::Version.new(RUBY_VERSION) >= Gem::Version.new('3.0.0')
    describe 'Ractor' do
      it 'should be supported' do
        r = Ractor.new {
          stream = Zstd::StreamingCompress.new(level: 5)
          stream << "abc" << "def"
          res = stream.finish
        }
        expect(Zstd.decompress(r.take)).to eq('abcdef')
      end
    end
  end
end

describe 'edge cases' do
  it 'handles empty string' do
    stream = Zstd::StreamingCompress.new
    stream << ""
    res = stream.finish
    expect(Zstd.decompress(res)).to eq('')
  end

  it 'handles very small data' do
    stream = Zstd::StreamingCompress.new
    stream << "a"
    res = stream.finish
    expect(Zstd.decompress(res)).to eq('a')
  end

  it 'handles large data' do
    large_data = "x" * 100_000
    stream = Zstd::StreamingCompress.new
    stream << large_data
    res = stream.finish
    expect(Zstd.decompress(res)).to eq(large_data)
  end

  it 'handles multiple empty strings' do
    stream = Zstd::StreamingCompress.new
    stream << "" << "" << ""
    res = stream.finish
    expect(Zstd.decompress(res)).to eq('')
  end
end

describe 'flush and finish behavior' do
  it 'handles flush followed by more data and finish' do
    stream = Zstd::StreamingCompress.new
    stream << "abc"
    flushed = stream.flush
    stream << "def"
    finished = stream.finish

    combined = flushed + finished
    expect(Zstd.decompress(combined)).to eq('abcdef')
  end

  it 'handles multiple flushes' do
    stream = Zstd::StreamingCompress.new
    stream << "abc"
    flush1 = stream.flush
    stream << "def"
    flush2 = stream.flush
    finished = stream.finish

    combined = flush1 + flush2 + finished
    expect(Zstd.decompress(combined)).to eq('abcdef')
  end

  it 'handles finish after flush with no additional data' do
    stream = Zstd::StreamingCompress.new
    stream << "abc"
    flushed = stream.flush
    finished = stream.finish

    combined = flushed + finished
    expect(Zstd.decompress(combined)).to eq('abc')
  end
end

describe 'chunk size variations' do
  it 'handles very small chunks' do
    data = "hello world"
    stream = Zstd::StreamingCompress.new

    # Write one character at a time
    data.each_char { |c| stream << c }

    res = stream.finish
    expect(Zstd.decompress(res)).to eq(data)
  end

  it 'handles mixed chunk sizes' do
    stream = Zstd::StreamingCompress.new

    # Mix different chunk sizes
    stream << "a"      # 1 byte
    stream << "bc"     # 2 bytes
    stream << "def"    # 3 bytes
    stream << "ghij"   # 4 bytes

    res = stream.finish
    expect(Zstd.decompress(res)).to eq('abcdefghij')
  end
end

describe 'error handling' do
  it 'handles nil input gracefully' do
    stream = Zstd::StreamingCompress.new
    expect { stream << nil }.to raise_error(TypeError)
  end

  it 'handles non-string input' do
    stream = Zstd::StreamingCompress.new
    expect { stream << 123 }.to raise_error(TypeError)
  end

  it 'handles very large input without crashing' do
    # This test ensures the streaming compressor can handle large inputs
    # without running out of memory or crashing
    large_data = "x" * 1000000  # 1MB of data
    stream = Zstd::StreamingCompress.new

    # This should not raise an error
    expect {
      stream << large_data
      result = stream.finish
      expect(result).to be_a(String)
      expect(result.length).to be > 0
    }.not_to raise_error
  end

  it 'handles multiple finish calls gracefully' do
    stream = Zstd::StreamingCompress.new
    stream << "test data"
    result1 = stream.finish

    # Second finish should work (though may return empty data)
    expect { stream.finish }.not_to raise_error
  end
end

describe 'binary data handling' do
  it 'handles binary data correctly' do
    # Create binary data with null bytes and high-bit characters
    binary_data = "\x00\x01\x02\xFF\xFE\xFD" + "text data" + "\x00\x01"

    stream = Zstd::StreamingCompress.new
    stream << binary_data
    compressed = stream.finish

    # Verify it can be decompressed back correctly
    decompressed = Zstd.decompress(compressed)
    expect(decompressed.bytes).to eq(binary_data.bytes)
    expect(decompressed.length).to eq(binary_data.length)
  end

  it 'handles UTF-8 data with multi-byte characters' do
    utf8_data = "Hello 世界 🌍 Test"

    stream = Zstd::StreamingCompress.new
    stream << utf8_data
    compressed = stream.finish

    decompressed = Zstd.decompress(compressed)
    # Zstd preserves binary data, so encoding may change but content should be same
    expect(decompressed.force_encoding('UTF-8')).to eq(utf8_data)
    expect(decompressed.length).to eq(utf8_data.length)
  end
end

describe 'concurrent operations' do
  it 'handles multiple streams simultaneously' do
    # Create multiple streaming compressors
    streams = []
    results = []

    5.times do |i|
      stream = Zstd::StreamingCompress.new
      stream << "data for stream #{i}"
      results << stream.finish
      streams << stream
    end

    # Verify all streams produced valid compressed data
    results.each_with_index do |compressed, i|
      decompressed = Zstd.decompress(compressed)
      expect(decompressed).to eq("data for stream #{i}")
    end
  end

  it 'handles interleaved operations' do
    stream1 = Zstd::StreamingCompress.new
    stream2 = Zstd::StreamingCompress.new

    # Interleave operations between two streams
    stream1 << "hello"
    stream2 << "world"
    stream1 << " "
    stream2 << " "
    stream1 << "from"
    stream2 << "test"

    result1 = stream1.finish
    result2 = stream2.finish

    expect(Zstd.decompress(result1)).to eq('hello from')
    expect(Zstd.decompress(result2)).to eq('world test')
  end
end
