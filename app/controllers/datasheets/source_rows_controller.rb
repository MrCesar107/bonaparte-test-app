class Datasheets::SourceRowsController < ::ApplicationController
  layout false

  before_action :set_datasheet

  def index
    @source_rows = @datasheet.source_rows.all
  end

  private

  def set_datasheet
    @datasheet = Datasheet.find(params[:datasheet_id])
  end
end
