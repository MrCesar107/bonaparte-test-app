class DatasheetResearchJob < ApplicationJob
  queue_as :default

  def perform(datasheet)
    datasheet.file.open do |file|
      ::Datasheet::Research.new(datasheet, file).call
    end

    datasheet.file.purge
  end
end
