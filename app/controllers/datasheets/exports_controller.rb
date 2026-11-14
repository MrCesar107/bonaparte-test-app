class Datasheets::ExportsController < ApplicationController
  def show
    datasheet = Datasheet.find(params[:datasheet_id])
    workbook = Datasheet::Workbook.new(datasheet)

    send_data workbook.call,
      filename: workbook.filename,
      type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
      disposition: "attachment"
  end
end
