class Datasheets::SectionsController < ::ApplicationController
  layout false

  before_action :set_datasheet

  private

  def set_datasheet
    @datasheet = Datasheet.find(params[:datasheet_id])
  end

  def catalog_view
    Datasheet::CatalogView.new(datasheet: @datasheet)
  end
end
