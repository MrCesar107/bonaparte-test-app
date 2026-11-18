class Datasheets::InterchangesController < Datasheets::SectionsController
  def index
    @rows = catalog_view.interchanges
  end
end
