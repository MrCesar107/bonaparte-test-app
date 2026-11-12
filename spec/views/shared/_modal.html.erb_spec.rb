require "rails_helper"

RSpec.describe "shared/_modal", type: :view do
  it "wires the dialog to the modal controller" do
    render layout: "shared/modal", locals: { title: "New Part Store", trigger_text: "New Part Store" } do
      "Store details"
    end

    expect(rendered).to include('data-controller="modal"')
    expect(rendered).to include('data-modal-open-value="false"')
    expect(rendered).to include('data-modal-target="dialog"')
    expect(rendered).to include('data-action="click-&gt;modal#backdropClose cancel-&gt;modal#close:prevent"')
    expect(rendered).to include('data-action="modal#open"')
    expect(rendered).to include("New Part Store")
    expect(rendered).to include('data-action="modal#close"')
    expect(rendered).to include('aria-label="Close"')
    expect(rendered).to include("aria-labelledby=")
    expect(rendered).to include("Store details")
    expect(rendered).to include("max-w-lg")
  end

  it "opens on connect when requested" do
    render layout: "shared/modal", locals: { title: "Details", open: true } do
      "Body"
    end

    expect(rendered).to include('data-modal-open-value="true"')
    expect(rendered).not_to include('data-action="modal#open"')
    expect(rendered).to include("Body")
  end

  it "accepts a custom trigger and size" do
    trigger = tag.button("Edit", type: "button", data: { action: "modal#open" }, class: "custom-trigger")

    render layout: "shared/modal", locals: { title: "Edit store", trigger: trigger, size: :sm } do
      "Body"
    end

    expect(rendered).to include('class="custom-trigger"')
    expect(rendered).to include(">Edit</button>")
    expect(rendered).to include("max-w-sm")
    expect(rendered).not_to include("New Part Store")
  end
end
