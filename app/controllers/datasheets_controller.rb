class DatasheetsController < ApplicationController
  layout false

  def create
    redirect_to part_store_path(part_store_id), notice: "File was uploaded successfully"
  end

  def new
  end

  private

  def part_store_id
    params[:part_store_id]
  end
end
