require "rails_helper"
require "net/http"

RSpec.describe Datasheet::Research::PageFetch do
  describe "#call" do
    it "reads the part number, the group and the interchange numbers from the page" do
      stub_http(success_response(labeled_html))

      page = described_class.new.call("https://parts.test/m152")

      expect(page).to have_attributes(
        url: "https://parts.test/m152",
        part_number: "M152",
        product_count: 1,
        group: "Bomba de aceite",
        interchange_numbers: [ "DM-152", "15010-40F00" ]
      )
      expect(page.body).to include("M152")
    end

    it "reads a product page from JSON-LD when the tables have no part number" do
      stub_http(success_response(json_ld_html))

      page = described_class.new.call("https://parts.test/listing")

      expect(page.part_number).to eq("DM-152")
      expect(page.product_count).to eq(2)
      expect(page.group).to eq("Oil pump")
    end

    it "reads the part number from the heading and the address" do
      html = "<html><head><title>Catalog</title></head><body><h1>DM-152 Oil Pump</h1></body></html>"
      stub_http(success_response(html))

      page = described_class.new.call("https://parts.test/pumps/other")

      expect(page.part_number).to eq("DM-152")
      expect(page.group).to eq("DM-152 Oil Pump")
      expect(page.product_count).to eq(1)
    end

    it "reads the part number from the page address when the text has none" do
      stub_http(success_response("<html><head><title>Replacement parts</title></head></html>"))

      page = described_class.new.call("https://parts.test/oil-pump/dm-152")

      expect(page.part_number).to eq("dm-152")
    end

    it "reads interchange numbers written under a heading" do
      html = <<~HTML
        <h1>M152 Oil Pump</h1>
        <h2>Cross Reference</h2>
        <ul><li>DM-152</li><li>15010-40F00</li></ul>
      HTML
      stub_http(success_response(html))

      page = described_class.new.call("https://parts.test/m152-pump")

      expect(page.part_number).to eq("M152")
      expect(page.interchange_numbers).to eq([ "DM-152", "15010-40F00" ])
    end

    it "reads a labeled part number from the page text" do
      stub_http(success_response("<p>Part Number: FSX-5840301</p>"))

      page = described_class.new.call("https://parts.test/fsx")

      expect(page.part_number).to eq("FSX-5840301")
      expect(page.product_count).to eq(1)
    end

    it "follows a redirect to the final page" do
      redirect = http_response(success: false, redirect: true, body: "", location: "https://parts.test/final")
      success = success_response("<p>Part Number: DM-152</p>")
      http = stub_http(redirect)
      allow(http).to receive(:request).and_return(redirect, success)

      page = described_class.new.call("https://parts.test/start")

      expect(page.part_number).to eq("DM-152")
      expect(page.url).to eq("https://parts.test/final")
    end

    it "returns an empty page when the server answers without the document" do
      stub_http(http_response(success: false, redirect: false, body: "missing"))

      page = described_class.new.call("https://parts.test/missing")

      expect(page).to have_attributes(part_number: "", product_count: 0, group: "", interchange_numbers: [], body: "")
    end

    it "raises unavailable when the download fails" do
      http = instance_double(Net::HTTP)
      allow(Net::HTTP).to receive(:new).and_return(http)
      allow(http).to receive(:use_ssl=)
      allow(http).to receive(:open_timeout=)
      allow(http).to receive(:read_timeout=)
      allow(http).to receive(:request).and_raise(SocketError)

      expect { described_class.new.call("https://parts.test/down") }.to raise_error(Datasheet::Research::Unavailable)
    end
  end

  def stub_http(response)
    http = instance_double(Net::HTTP)
    allow(Net::HTTP).to receive(:new).and_return(http)
    allow(http).to receive(:use_ssl=)
    allow(http).to receive(:open_timeout=)
    allow(http).to receive(:read_timeout=)
    allow(http).to receive(:request).and_return(response)
    http
  end

  def success_response(body)
    http_response(success: true, redirect: false, body: body)
  end

  def http_response(success:, redirect:, body:, location: nil)
    response = instance_double(Net::HTTPResponse, body: body)
    allow(response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(success)
    allow(response).to receive(:is_a?).with(Net::HTTPRedirection).and_return(redirect)
    allow(response).to receive(:[]).with("location").and_return(location)
    response
  end

  def labeled_html
    <<~HTML
      <h2>Intercambios</h2>
      <table>
        <tr><th>Número</th><th>Marca</th></tr>
        <tr><td>DM-152</td><td>Melling</td></tr>
        <tr><td>15010-40F00</td><td>Nissan</td></tr>
      </table>
      <dl>
        <dt>Número de parte</dt><dd>M152</dd>
        <dt>Producto</dt><dd>Bomba de aceite</dd>
      </dl>
    HTML
  end

  def json_ld_html
    payload = {
      "@graph" => [
        { "@type" => "Product", "sku" => "DM-152", "name" => "Oil pump" },
        { "@type" => "Product", "sku" => "M152", "name" => "Oil pump" }
      ]
    }

    "<script type=\"application/ld+json\">#{payload.to_json}</script>"
  end
end
