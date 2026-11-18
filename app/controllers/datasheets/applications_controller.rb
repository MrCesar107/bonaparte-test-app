class Datasheets::ApplicationsController < Datasheets::SectionsController
  def index
    @rows = catalog_view.applications
  end
end
