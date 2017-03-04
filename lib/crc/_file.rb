class CRC
  def file(path)
    File.open(path, "rb") do |file|
      buf = "".b
      update(buf) while file.read(65536, buf)
    end
    self
  end

  module Calcurator
    def file(path, *args)
      new(*args).file(path)
    end
  end
end
