require "rails_helper"

RSpec.describe ApplicationHelper, type: :helper do
  describe "#fa_icon" do
    it "renders a solid Font Awesome icon" do
      html = helper.fa_icon("arrow_right", class: "text-orange-500")

      expect(html).to include('class="fa-solid fa-arrow-right text-orange-500"')
      expect(html).to include('aria-hidden="true"')
    end

    it "accepts another style and keeps an accessible name" do
      html = helper.fa_icon(:github, style: :brands, aria: { label: "GitHub" })

      expect(html).to include('class="fa-brands fa-github"')
      expect(html).to include('aria-label="GitHub"')
      expect(html).not_to include("aria-hidden")
    end
  end
end
