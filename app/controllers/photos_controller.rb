class PhotosController < ApplicationController
  before_action :set_inspection_and_photo

  def download
    if @photo.watermarked_image.attached?
      send_data @photo.watermarked_image.download,
                filename: @photo.filename.presence || "foto_#{@photo.id}.jpg",
                type: "image/jpeg",
                disposition: "attachment"
    else
      redirect_to @inspection, alert: "Imagem carimbada não encontrada."
    end
  end

  def destroy
    @photo.destroy
    redirect_to @inspection, notice: "Foto removida."
  end

  private

  def set_inspection_and_photo
    @inspection = Inspection.find(params[:inspection_id])
    @photo = @inspection.photos.find(params[:id])
  end
end
