require "zip"

class InspectionsController < ApplicationController
  before_action :set_inspection, only: [ :show, :destroy, :upload_photos, :download_zip ]

  def index
    @inspections = Inspection.includes(:photos).order(created_at: :desc)
    @inspection = Inspection.new
  end

  def show
    @photos = @inspection.photos.with_attached_watermarked_image.order(captured_at: :asc, id: :asc)
  end

  def new
    @inspection = Inspection.new
  end

  def create
    @inspection = Inspection.new(inspection_params)

    if @inspection.save
      process_uploaded_photos(params[:inspection][:photo_files])
      respond_to do |format|
        format.html { redirect_to @inspection, notice: "Vistoria criada e fotos processadas com sucesso!" }
        format.json { render json: { id: @inspection.id, url: inspection_path(@inspection), upload_url: upload_photos_inspection_path(@inspection) }, status: :created }
      end
    else
      respond_to do |format|
        format.html do
          @inspections = Inspection.includes(:photos).order(created_at: :desc)
          render :index, status: :unprocessable_entity
        end
        format.json { render json: { errors: @inspection.errors.full_messages }, status: :unprocessable_entity }
      end
    end
  end

  def upload_photos
    count = process_uploaded_photos(params[:photo_files])
    respond_to do |format|
      format.html do
        if count > 0
          redirect_to @inspection, notice: "#{count} foto(s) processada(s) e adicionada(s) com sucesso!"
        else
          redirect_to @inspection, alert: "Nenhuma foto válida selecionada."
        end
      end
      format.json { render json: { processed: count, url: inspection_path(@inspection) }, status: :ok }
    end
  end

  def download_zip
    photos = @inspection.photos.with_attached_watermarked_image
    if photos.empty?
      redirect_to @inspection, alert: "Não há fotos processadas para baixar."
      return
    end

    zip_file = Tempfile.new([ "vistoria_#{@inspection.id}", ".zip" ])
    Zip::OutputStream.open(zip_file) { |zos| }

    Zip::File.open(zip_file.path, create: true) do |zipfile|
      used_names = Hash.new(0)
      photos.each do |photo|
        next unless photo.watermarked_image.attached?

        base_name = photo.filename.presence || "foto_#{photo.id}.jpg"
        count = (used_names[base_name] += 1)
        entry_name = count > 1 ? "#{File.basename(base_name, '.*')}_#{count}#{File.extname(base_name)}" : base_name

        zipfile.get_output_stream(entry_name) do |out|
          out.write(photo.watermarked_image.download)
        end
      end
    end

    safe_title = (@inspection.protocol.presence || @inspection.title).parameterize.presence || "vistoria_#{@inspection.id}"
    zip_data = File.binread(zip_file.path)
    zip_file.close
    zip_file.unlink

    send_data zip_data, filename: "#{safe_title}_fotos_carimbadas.zip", type: "application/zip", disposition: "attachment"
  end

  def destroy
    @inspection.destroy
    redirect_to inspections_path, notice: "Vistoria removida com sucesso."
  end

  private

  def set_inspection
    @inspection = Inspection.find(params[:id])
  end

  def inspection_params
    params.require(:inspection).permit(:title, :protocol, :custom_logo)
  end

  def resolve_logo_path
    if @inspection.custom_logo.attached?
      ext = File.extname(@inspection.custom_logo.filename.to_s).presence || ".png"
      temp_logo = Tempfile.new([ "custom_logo", ext ])
      temp_logo.binmode
      temp_logo.write(@inspection.custom_logo.download)
      temp_logo.close
      [ temp_logo.path, temp_logo ]
    else
      candidates = [
        Rails.root.join("app/assets/images/default_logo.png"),
        Rails.root.join("app/assets/images/iat_logo.png"),
        *Dir.glob(Rails.root.join("testfiles/*.png"))
      ]
      found = candidates.find { |path| File.exist?(path.to_s) }
      [ found&.to_s, nil ]
    end
  end

  def process_uploaded_photos(uploaded_files)
    files = Array(uploaded_files).reject(&:blank?)
    return 0 if files.empty?

    exif_headers = Array(params[:exif_headers]).reject(&:blank?)
    logo_path, temp_logo = resolve_logo_path
    processed_count = 0

    begin
      files.each_with_index do |uploaded_file, idx|
        original_filename = uploaded_file.original_filename
        source_path = uploaded_file.tempfile.path
        exif_source_path = exif_headers[idx]&.tempfile&.path || source_path

        meta = MetadataService.extract(exif_source_path)
        meta[:filename] = original_filename

        photo = @inspection.photos.create!(
          filename: original_filename,
          captured_at: meta[:captured_at],
          latitude: meta[:latitude],
          longitude: meta[:longitude],
          relative_altitude: meta[:relative_altitude],
          absolute_altitude: meta[:absolute_altitude],
          gimbal_yaw: meta[:gimbal_yaw],
          gimbal_pitch: meta[:gimbal_pitch],
          fov_deg: meta[:fov_deg]
        )

        photo.original_image.attach(uploaded_file)

        output_temp = Tempfile.new([ "watermarked", ".jpg" ])
        output_temp.close

        begin
          WatermarkerService.process(meta, source_path, output_temp.path, logo_path, exif_source_path)
          photo.watermarked_image.attach(
            io: File.open(output_temp.path),
            filename: "carimbada_#{original_filename}",
            content_type: "image/jpeg"
          )
          processed_count += 1
        ensure
          output_temp.unlink
        end
      end
    ensure
      if temp_logo
        temp_logo.close
        temp_logo.unlink
      end
    end

    processed_count
  end
end
