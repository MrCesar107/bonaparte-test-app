class DatasheetsController < ApplicationController
  layout false

  def create
    file = params[:file]
    datasheet = part_store.datasheets.create

    if file.present? && datasheet.persisted?
      redirect_to part_store_path(part_store_id),
        notice: "File was uploaded successfully"
    else
      redirect_to part_store_path(part_store_id),
        alert: "An error occurred while uploading the file. Please try again."
    end
  end

  def new
  end

  private

  def part_store
    @part_store ||= PartStore.find(part_store_id)
  end

  def part_store_id
    params[:part_store_id]
  end
end
