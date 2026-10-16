require "vips"
require "base64"
require "tempfile"
require "geoutm"

class WatermarkerService
  def self.process(photo, source_path, output_path, logo_path = nil, exif_source_path = nil)
    Vips.block_untrusted(false) if Vips.respond_to?(:block_untrusted)

    image = Vips::Image.new_from_file(source_path, access: :sequential)
    width = image.width
    bar_height = (image.height * 0.10).to_i.clamp(140, 500)

    svg_string = build_footer_svg(photo, width, bar_height, logo_path)

    temp_file = Tempfile.new([ "footer", ".svg" ])
    temp_file.write(svg_string)
    temp_file.close
    footer_img = Vips::Image.new_from_file(temp_file.path, access: :sequential)
    temp_file.unlink

    footer_rgb = footer_img.extract_band(0, n: 3)
    combined = image.join(footer_rgb, :vertical)

    combined.jpegsave(output_path, Q: 92)

    system("exiftool", "-overwrite_original", "-tagsFromFile", exif_source_path || source_path, "-all:all", output_path)
  end

  def self.build_footer_svg(photo, w, h, logo_path)
    font_lg = (h * 0.22).to_i
    font_sm = (h * 0.17).to_i
    compass_r = (h * 0.38).to_i

    has_logo = logo_path && File.exist?(logo_path)
    logo_h = (h * 0.82).to_i
    logo_w = logo_h
    logo_x = (h * 0.15).to_i
    logo_y = ((h - logo_h) / 2.0).to_i

    logo_base64 = ""
    if has_logo
      logo_img = Vips::Image.new_from_file(logo_path)
      if logo_img.has_alpha?
        left, top, trim_w, trim_h = logo_img.extract_band(logo_img.bands - 1).find_trim(threshold: 1, background: [ 0 ])
        logo_img = logo_img.crop(left, top, trim_w, trim_h) if trim_w > 0 && trim_h > 0
      end
      logo_w = (logo_h * (logo_img.width.to_f / logo_img.height)).to_i
      logo_base64 = "data:image/png;base64,#{Base64.strict_encode64(logo_img.pngsave_buffer)}"
    end

    text_x = has_logo ? (logo_x + logo_w + (h * 0.20).to_i) : (h * 0.20).to_i

    cx = w - compass_r - (h * 0.25).to_i
    cy = h / 2

    lat = photo[:latitude] || 0.0
    lon = photo[:longitude] || 0.0
    utm = GeoUtm::LatLon.new(lat, lon).to_utm
    utm_zone = photo[:utm_zone] || utm.zone
    utm_e = photo[:utm_easting] || utm.e
    utm_n = photo[:utm_northing] || utm.n

    azimuth = photo[:azimuth] || photo[:yaw] || photo[:gimbal_yaw] || 0
    pitch = photo[:pitch] || photo[:gimbal_pitch] || 0
    captured_at = photo[:captured_at]
    data_str = captured_at.respond_to?(:strftime) ? " | Data/Hora: #{captured_at.strftime('%d/%m/%Y %H:%M:%S')}" : ""

    <<~SVG
      <svg width="#{w}" height="#{h}" xmlns="http://www.w3.org/2000/svg">
        <rect width="100%" height="100%" fill="#14181f"/>
        <line x1="0" y1="0" x2="#{w}" y2="2" stroke="#38bdf8" stroke-width="6"/>

        #{has_logo ? (%Q(<image href="#{logo_base64}" x="#{logo_x}" y="#{logo_y}" height="#{logo_h}" width="#{logo_w}" preserveAspectRatio="xMidYMid meet"/>)) : ''}

        <text x="#{text_x}" y="#{h * 0.34}" fill="#f8fafc" font-family="monospace" font-weight="bold" font-size="#{font_lg}">
          Arquivo: #{photo[:filename] || 'DJI_Foto.JPG'}#{data_str}
        </text>
        <text x="#{text_x}" y="#{h * 0.64}" fill="#94a3b8" font-family="monospace" font-size="#{font_sm}">
          Coordenadas: #{format('%.6f', lat)}, #{format('%.6f', lon)} | UTM (SIRGAS 2000 #{utm_zone}): #{format('%.2f', utm_e)} E, #{format('%.2f', utm_n)} N
        </text>
        <text x="#{text_x}" y="#{h * 0.89}" fill="#38bdf8" font-family="monospace" font-size="#{font_sm}">
          Alt. Relativa: #{format('%.1f', photo[:relative_altitude] || 0)}m | Alt. Absoluta: #{format('%.1f', photo[:absolute_altitude] || 0)}m | Azimute: #{format('%.1f', azimuth)}° | Inclinação da Câmera: #{format('%.1f', pitch)}°
        </text>

        <g transform="translate(#{cx}, #{cy})">
          <circle cx="0" cy="0" r="#{compass_r}" fill="#1e293b" stroke="#475569" stroke-width="3"/>
          <text x="0" y="#{-compass_r + (font_sm * 0.8)}" fill="#ef4444" font-family="sans-serif" font-weight="bold" font-size="#{font_sm * 0.8}" text-anchor="middle">N</text>
          <g transform="rotate(#{azimuth})">
            <path d="M 0,0 L #{-compass_r * 0.55},#{-compass_r * 0.8} A #{compass_r},#{compass_r} 0 0,1 #{compass_r * 0.55},#{-compass_r * 0.8} Z" fill="#38bdf8" fill-opacity="0.45"/>
            <line x1="0" y1="0" x2="0" y2="#{-compass_r * 0.9}" stroke="#38bdf8" stroke-width="4"/>
          </g>
          <circle cx="0" cy="0" r="4" fill="#f8fafc"/>
        </g>
      </svg>
    SVG
  end
end
