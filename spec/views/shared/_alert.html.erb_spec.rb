require "rails_helper"

RSpec.describe "shared/_alert", type: :view do
  it "wires a notice to the alert controller" do
    render "shared/alert", type: :notice, message: "Signed in successfully."

    expect(rendered).to include('data-controller="alert"')
    expect(rendered).to include('data-action="alert#close"')
    expect(rendered).to include('data-toggle-class="hidden"')
    expect(rendered).to include('data-transition-enter="transition duration-300 ease-out"')
    expect(rendered).to include('role="status"')
    expect(rendered).to include("bg-emerald-50")
    expect(rendered).to include("Signed in successfully.")
    expect(rendered).to include('aria-label="Dismiss"')
    expect(rendered).not_to include("data-alert-dismiss-after-value")
  end

  it "styles errors and can dismiss itself" do
    render "shared/alert", type: :alert, message: "Could not save.", dismiss_after: 4_000

    expect(rendered).to include('role="alert"')
    expect(rendered).to include("bg-red-50")
    expect(rendered).to include('data-alert-dismiss-after-value="4000"')
    expect(rendered).to include("Could not save.")
  end
end
