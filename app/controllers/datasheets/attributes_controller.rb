class Datasheets::AttributesController < Datasheets::SectionsController
  def index
    @rows = catalog_view.attributes
  end
end
