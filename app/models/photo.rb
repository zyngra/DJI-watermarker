require "geoutm"

class Photo < ApplicationRecord
  belongs_to :inspection

  has_one_attached :original_image
  has_one_attached :watermarked_image

  def utm_coordinates
    return nil unless latitude.present? && longitude.present?
    @utm_coordinates ||= GeoUtm::LatLon.new(latitude, longitude).to_utm
  end

  def utm_zone
    utm_coordinates&.zone
  end

  def utm_easting
    utm_coordinates&.e
  end

  def utm_northing
    utm_coordinates&.n
  end
end
