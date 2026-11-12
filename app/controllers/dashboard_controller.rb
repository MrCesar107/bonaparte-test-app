class DashboardController < ApplicationController
  def index
    @part_stores = PartStore.all
  end
end
