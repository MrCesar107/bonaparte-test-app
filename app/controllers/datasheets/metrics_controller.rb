class Datasheets::MetricsController < Datasheets::SectionsController
  def show
    @metrics = catalog_view.metrics
  end
end
