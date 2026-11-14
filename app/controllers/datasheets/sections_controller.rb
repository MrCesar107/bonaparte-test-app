class Datasheets::SectionsController < ::ApplicationController
  layout false

  before_action :set_datasheet
  before_action :set_view

  private

  def set_datasheet
    @datasheet = Datasheet.find(params[:datasheet_id])
  end

  def set_view
    @view = Datasheet::CatalogView.new(datasheet: @datasheet).call
  end
end
