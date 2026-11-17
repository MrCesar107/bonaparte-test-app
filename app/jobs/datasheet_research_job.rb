class DatasheetResearchJob < ApplicationJob
  queue_as :default

  def perform(datasheet)
    datasheet.file.open do |file|
      ::Datasheet::Research.new(datasheet, file).call
    end
  rescue StandardError
    datasheet.failed! unless datasheet.failed?
    raise
  else
    datasheet.file.purge
  end
end
