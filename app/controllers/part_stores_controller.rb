class PartStoresController < ApplicationController
  before_action :set_part_store, only: :show

  def create
    @part_store = PartStore.new(part_store_params)

    if @part_store.save
      redirect_to dashboard_index_path, notice: "Part store created successfully", status: :see_other
    else
      respond_to do |format|
        format.html { render :new, status: :unprocessable_content }
        format.turbo_stream do
          render turbo_stream: turbo_stream.update("part_store_form",
            partial: "part_stores/form", locals: { part_store: @part_store }),
            status: :unprocessable_content
        end
      end
    end
  end

  def new
    @part_store = PartStore.new
    render layout: false
  end

  def show
    @datasheets = datasheets
  end

  private

  def set_part_store
    @part_store = PartStore.find(params[:id])
  end

  def part_store_params
    params.require(:part_store).permit(:name)
  end

  def datasheets
    @datasheets ||= @part_store.datasheets.where(equivalent: nil).order(created_at: :desc)
  end
end
