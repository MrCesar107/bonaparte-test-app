class Datasheets::CatalogRowsController < Datasheets::SectionsController
  def index
    @rows = catalog_view.catalog
  end
end
