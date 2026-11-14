class Datasheets::SourceRowsController < ::ApplicationController
  layout false

  before_action :set_datasheet

  def index
    @view = Datasheet::CatalogView.new(datasheet: @datasheet).call
  end

  private

  def set_datasheet
    @datasheet = Datasheet.find(params[:datasheet_id])
  end
end
