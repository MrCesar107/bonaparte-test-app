require "rails_helper"

RSpec.describe Datasheet::Research::PageSearch do
  describe "#call" do
    it "accepts the part number page before an earlier interchange page" do
      interchange = page(url: "https://parts.test/m152", part_number: "M152", interchange_numbers: [ "DM-152" ])
      match = page(url: "https://parts.test/dm-152", part_number: "DM-152", body: "ficha DM-152")
      search = search_returning('"DM-152" oil pump 1976 2014' => [ interchange.url, match.url ])
      fetch = fetch_returning(interchange, match)

      hit = search_pages(search:, fetch:)

      expect(hit).to have_attributes(equivalent: "DM-152", url: match.url, body: "ficha DM-152")
      expect(search).to have_received(:call).once
    end

    it "keeps DM-152 when the accepted page is the M152 interchange" do
      melling = page(url: "https://parts.test/m152", part_number: "M152", interchange_numbers: [ "DM-152" ], body: "melling")
      search = search_returning('"DM-152" oil pump 1976 2014' => [ melling.url ])
      fetch = fetch_returning(melling)

      hit = search_pages(search:, fetch:)

      expect(hit).to have_attributes(equivalent: "DM-152", url: melling.url, body: "melling")
    end

    it "does not accept a single product page that lacks the interchange" do
      other = page(url: "https://parts.test/other", part_number: "M200", interchange_numbers: [ "XX-1" ])
      search = search_returning(
        '"DM-152" oil pump 1976 2014' => [ other.url ],
        '"RM-152" oil pump 1976 2014' => []
      )
      fetch = fetch_returning(other)

      expect(search_pages(search:, fetch:)).to eq(:not_found)
    end

    it "returns not found without retrying when every search responds empty" do
      search = search_returning(
        '"DM-152" oil pump 1976 2014' => [],
        '"RM-152" oil pump 1976 2014' => []
      )
      fetch = instance_double(Proc)
      allow(fetch).to receive(:call)

      expect(search_pages(search:, fetch:)).to eq(:not_found)
      expect(search).to have_received(:call).twice
      expect(fetch).not_to have_received(:call)
    end

    it "stops on the first out of credits result" do
      search = instance_double(Datasheet::Research::SerpApiSearch)
      allow(search).to receive(:call).and_raise(Datasheet::Research::OutOfCredits)
      fetch = instance_double(Proc)

      expect(search_pages(search:, fetch:)).to eq(:out_of_credits)
      expect(search).to have_received(:call).once
    end

    it "fails on the third time the search does not respond" do
      search = instance_double(Datasheet::Research::SerpApiSearch)
      allow(search).to receive(:call).and_raise(Datasheet::Research::Unavailable)
      fetch = instance_double(Proc)

      expect(search_pages(search:, fetch:)).to eq(:failed)
      expect(search).to have_received(:call).exactly(3).times
    end
  end

  def search_pages(search:, fetch:)
    described_class.new(
      phrase: phrase,
      item_group: "BOMBA DE ACEITE",
      search: search,
      fetch: fetch
    ).call
  end

  def phrase
    Datasheet::Research::Phrase.new(
      description: "DM-152 NISSAN PICKUP 76/14",
      part_number: "RM-152",
      item_group: "BOMBA DE ACEITE"
    ).call
  end

  def search_returning(urls_by_query)
    search = instance_double(Datasheet::Research::SerpApiSearch)
    urls_by_query.each do |query, urls|
      allow(search).to receive(:call).with(query).and_return(urls)
    end
    search
  end

  def fetch_returning(*pages)
    fetch = instance_double(Proc)
    pages.each do |item|
      allow(fetch).to receive(:call).with(item.url).and_return(item)
    end
    fetch
  end

  def page(url:, part_number:, body: "page", product_count: 1, group: "oil pump", interchange_numbers: [])
    described_class::Page.new(
      url: url,
      part_number: part_number,
      product_count: product_count,
      group: group,
      interchange_numbers: interchange_numbers,
      body: body
    )
  end
end
