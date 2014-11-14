# Model for a JTL data chunk.
# @author Sayantam Dey

require 'zlib'

require 'hailstorm/model'
require 'hailstorm/model/hailstorm_base'

class Hailstorm::Model::JtlFile  < Hailstorm::Model::HailstormBase

  READ_BUFFER_SIZE = 4 * 1024 * 1024 # 4MB
  DATA_CHUNK_SIZE = 63 * 1024 # 63KB

  belongs_to :client_stat

  # Persist the file to DB - the file is broken into chunks so that large files
  # can be stored without exceeding MySQL query packet bounds.
  # @param [Hailstorm::Model::ClientStat] client_stat
  # @param [String] file_path path to file to be persisted
  def self.persist_file(client_stat, file_path)
    # compress file_path
    gz_file_path = "#{file_path}.gz"
    File.open(gz_file_path, "wb") do |out|
      gz = Zlib::GzipWriter.new(out)
      File.open(file_path, "r") do |io|
        gz.write(io.read(READ_BUFFER_SIZE)) until io.eof?
      end
      gz.close()
    end

    # read gz_file_path in chunks, create model objects
    logger.debug { "Persisting JTL chunks for #{file_path}..." }
    begin
      chunk_sequence = 1
      File.open(gz_file_path, "rb") do |ins|
        until ins.eof?
          self.create!(:client_stat_id => client_stat.id,
                       :chunk_sequence => chunk_sequence,
                       :data_chunk => ins.read(DATA_CHUNK_SIZE))
          chunk_sequence += 1
        end
      end

      File.unlink(gz_file_path)
    end
  end

  # @param [Hailstorm::Model::ClientStat] client_stat
  # @param [String] export_file path to the file to export
  def self.export_file(client_stat, export_file)

    # read the data chunks from table and binary write to file
    gz_export_file = "#{export_file}.gz"
    File.open(gz_export_file, "wb") do |io|
      self.where(:client_stat_id => client_stat)
          .select(:id)
          .order(:chunk_sequence)
          .each do |jtl_file_id|

        io.write(self.where(:id => jtl_file_id)
                     .select(:data_chunk)
                     .first
                     .data_chunk)
      end
    end

    # unzip the file and delete the zipped file
    File.open(export_file, "w") do |ofs|
      Zlib::GzipReader.open(gz_export_file) do |gz|
        ofs.write(gz.read(READ_BUFFER_SIZE)) until gz.eof?
      end
    end
    FileUtils.safe_unlink(gz_export_file)
  end


end