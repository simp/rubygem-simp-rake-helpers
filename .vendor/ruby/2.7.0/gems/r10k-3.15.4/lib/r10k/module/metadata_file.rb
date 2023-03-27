require 'r10k/module'
require 'r10k/errors'
require 'puppet_forge'

class R10K::Module::MetadataFile

  # @param metadata_path [Pathname] The file path to the metadata
  def initialize(metadata_file_path)
    @metadata_file_path = metadata_file_path
  end

  # Does the metadata file itself exist?
  def exist?
    @metadata_file_path.file? and @metadata_file_path.readable?
  end

  # @return [Puppet::ModuleTool::Metadata ] The metadata object created by the metadatafile
  def read(metadata_file_path = @metadata_file_path)
    if self.exist?
      metadata_file_path.open do |f|
        begin
          metadata = PuppetForge::Metadata.new
          metadata.update(JSON.load(f), false)
        rescue JSON::ParserError => e
          exception = R10K::Error.wrap(e, _("Could not read metadata.json"))
          raise exception
        end
      end
    end
  end
end
