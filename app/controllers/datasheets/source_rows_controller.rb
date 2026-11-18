class Datasheets::SourceRowsController < Datasheets::SectionsController
  def index
    @rows = catalog_view.origin
  end
end
