require "spec_helper"
require 'zstd-ruby'
require 'securerandom'

RSpec.describe Zstd do
  describe 'read_skippable_frame' do
    context 'simple string' do
      it '' do
        expect(Zstd.read_skippable_frame('abc')).to eq nil
      end
    end
    context 'compressed string' do
      it '' do
        expect(Zstd.read_skippable_frame(Zstd.compress(SecureRandom.hex(150)))).to eq nil
      end
    end
    context 'compressed string + skippable frame' do
      it '' do
        compressed_data = Zstd.compress(SecureRandom.hex(150))
        compressed_data_with_skippable_frame = Zstd.write_skippable_frame(compressed_data, "sample data")
        expect(Zstd.read_skippable_frame(compressed_data_with_skippable_frame)).to eq "sample data"
      end
    end

    context 'compressed string + skippable frame + magic_variant' do
      it '' do
        compressed_data = Zstd.compress(SecureRandom.hex(150))
        compressed_data_with_skippable_frame = Zstd.write_skippable_frame(compressed_data, "sample data", magic_variant: 1)
        expect(Zstd.read_skippable_frame(compressed_data_with_skippable_frame)).to eq "sample data"
      end
    end

    context 'edge cases' do
      it 'handles large skippable data correctly' do
        input = "test data"
        skip_data = "x" * 10000
        result = Zstd.write_skippable_frame(input, skip_data)

        # Should be able to read back the skip data
        expect(Zstd.read_skippable_frame(result)).to eq(skip_data)

        # The skippable frame is prepended to input
        # After the skippable frame, we should have the original input
        frame_data = Zstd.read_skippable_frame(result)
        expect(frame_data).to eq(skip_data)

        # The result should be the skippable frame (header + skip_data) + input
        # ZSTD_SKIPPABLEHEADERSIZE is 8 bytes
        expect(result.bytesize).to eq(8 + skip_data.bytesize + input.bytesize)
      end

      it 'handles empty input correctly' do
        input = ""
        skip_data = "metadata"
        result = Zstd.write_skippable_frame(input, skip_data)

        expect(Zstd.read_skippable_frame(result)).to eq(skip_data)
      end

      it 'handles empty skip data correctly' do
        input = "test"
        skip_data = ""
        result = Zstd.write_skippable_frame(input, skip_data)

        expect(Zstd.read_skippable_frame(result)).to eq(skip_data)
      end
    end

  end
end
