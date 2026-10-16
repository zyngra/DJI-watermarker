require "mini_exiftool"
require "geoutm"

class MetadataService
  EARTH_RADIUS = 6371e3
  DEFAULT_HFOV = 70.0

  def self.extract(file_path)
    if not File.exist?(file_path)
      raise "File not found: #{file_path}"
    end

    exif = MiniExiftool.new(file_path, numerical: true)

    lat = exif["GPSLatitude"]&.to_f
    lon = exif["GPSLongitude"]&.to_f
    lat = -lat.abs if lat && exif["GPSLatitudeRef"].to_s.start_with?("S")
    lon = -lon.abs if lon && exif["GPSLongitudeRef"].to_s.start_with?("W")

    utm = GeoUtm::LatLon.new(lat, lon).to_utm if lat && lon

    alt_r = (exif["RelativeAltitude"] || 50).to_f
    alt_a = (exif["AbsoluteAltitude"] || 0.0).to_f

    yaw = (exif["GimbalYawDegree"] || 0.0).to_f
    pitch = (exif["GimbalPitchDegree"] || 0.0).to_f
    fov = (exif["FOV"] || DEFAULT_HFOV).to_f

    {
      filename: File.basename(file_path),
      captured_at: exif.DateTimeOriginal,
      latitude: lat,
      longitude: lon,
      utm_zone: utm&.zone,
      utm_easting: utm&.e,
      utm_northing: utm&.n,
      relative_altitude: alt_r,
      absolute_altitude: alt_a,
      yaw: yaw,
      gimbal_yaw: yaw,
      azimuth: yaw,
      pitch: pitch,
      gimbal_pitch: pitch,
      fov: fov,
      fov_deg: fov
    }
  end
end
