class PartStoresController < ApplicationController
  before_action :set_part_store, only: :show

  def new
    @part_store = PartStore.new
    render layout: false
  end

  def create
    @part_store = PartStore.new(part_store_params)

    if @part_store.save
      redirect_to @part_store, notice: "Part store created successfully"
    else
      render :new, status: :unprocessable_content
    end
  end

  def show
  end

  private

  def set_part_store
    @part_store = PartStore.find(params[:id])
  end

  def part_store_params
    params.require(:part_store).permit(:name)
  end
end
