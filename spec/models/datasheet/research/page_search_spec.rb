require "rails_helper"

RSpec.describe Datasheet::Research::PageSearch do
  describe "#call" do
    it "accepts the part number page before an earlier interchange page" do
      interchange = page(url: "https://parts.test/m152", part_number: "M152", interchange_numbers: [ "DM-152" ])
      match = page(url: "https://parts.test/dm-152", part_number: "DM-152", body: "ficha DM-152")
      search = search_returning('"DM-152" Nissan oil pump 1976-2014' => [ interchange.url, match.url ])
      fetch = fetch_returning(interchange, match)

      hit = search_pages(search:, fetch:)

      expect(hit).to have_attributes(equivalent: "DM-152", url: match.url, body: "ficha DM-152")
      expect(search).to have_received(:call).once
    end

    it "does not accept an interchange page unless the candidate is in the title, heading, or address" do
      melling = page(url: "https://parts.test/m152", part_number: "M152", interchange_numbers: [ "DM-152" ], body: "<title>M152 Oil Pump</title>")
      search = search_returning(
        '"DM-152" Nissan oil pump 1976-2014' => [ melling.url ],
        '"RM-152" Nissan oil pump 1976-2014' => []
      )
      fetch = fetch_returning(melling)

      expect(search_pages(search:, fetch:)).to eq(:not_found)
    end

    it "accepts a page whose title carries the candidate" do
      match = page(
        url: "https://parts.test/pump",
        part_number: "",
        body: "<title>DM-152 Oil Pump</title><p>fits trucks</p>"
      )
      search = search_returning('"DM-152" Nissan oil pump 1976-2014' => [ match.url ])
      fetch = fetch_returning(match)

      hit = search_pages(search:, fetch:)

      expect(hit).to have_attributes(equivalent: "DM-152", url: match.url)
    end

    it "does not accept a page that only mentions the candidate in the text" do
      other = page(
        url: "https://parts.test/other",
        part_number: "M200",
        body: "<title>Other pump</title><p>see also DM-152</p>",
        interchange_numbers: [ "XX-1" ]
      )
      search = search_returning(
        '"DM-152" Nissan oil pump 1976-2014' => [ other.url ],
        '"RM-152" Nissan oil pump 1976-2014' => []
      )
      fetch = fetch_returning(other)

      expect(search_pages(search:, fetch:)).to eq(:not_found)
    end

    it "keeps a later page when an earlier download does not respond" do
      match = page(url: "https://parts.test/dm-152", part_number: "DM-152", body: "ficha DM-152")
      search = search_returning('"DM-152" Nissan oil pump 1976-2014' => [ "https://parts.test/down", match.url ])
      fetch = instance_double(Proc)
      allow(fetch).to receive(:call).with("https://parts.test/down").and_raise(Datasheet::Research::Unavailable)
      allow(fetch).to receive(:call).with(match.url).and_return(match)

      hit = search_pages(search:, fetch:)

      expect(hit).to have_attributes(equivalent: "DM-152", url: match.url)
      expect(search).to have_received(:call).once
    end

    it "does not accept a single product page that lacks the interchange" do
      other = page(url: "https://parts.test/other", part_number: "M200", interchange_numbers: [ "XX-1" ])
      search = search_returning(
        '"DM-152" Nissan oil pump 1976-2014' => [ other.url ],
        '"RM-152" Nissan oil pump 1976-2014' => []
      )
      fetch = fetch_returning(other)

      expect(search_pages(search:, fetch:)).to eq(:not_found)
    end

    it "returns not found without retrying when every search responds empty" do
      search = search_returning(
        '"DM-152" Nissan oil pump 1976-2014' => [],
        '"RM-152" Nissan oil pump 1976-2014' => []
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

    it "retries each candidate three times when the search does not respond" do
      search = instance_double(Datasheet::Research::SerpApiSearch)
      allow(search).to receive(:call).and_raise(Datasheet::Research::Unavailable)
      fetch = instance_double(Proc)

      expect(search_pages(search:, fetch:)).to eq(:failed)
      expect(search).to have_received(:call).with(%("DM-152" Nissan oil pump 1976-2014)).exactly(3).times
      expect(search).to have_received(:call).with(%("RM-152" Nissan oil pump 1976-2014)).exactly(3).times
    end

    it "keeps searching the next candidate when the first search does not respond" do
      search = instance_double(Datasheet::Research::SerpApiSearch)
      allow(search).to receive(:call).with(%("DM-152" Nissan oil pump 1976-2014)).and_raise(Datasheet::Research::Unavailable)
      allow(search).to receive(:call).with(%("RM-152" Nissan oil pump 1976-2014)).and_return([])
      fetch = instance_double(Proc)
      allow(fetch).to receive(:call)

      expect(search_pages(search:, fetch:)).to eq(:not_found)
      expect(search).to have_received(:call).with(%("DM-152" Nissan oil pump 1976-2014)).exactly(3).times
      expect(search).to have_received(:call).with(%("RM-152" Nissan oil pump 1976-2014)).once
      expect(fetch).not_to have_received(:call)
    end

    it "accepts a catalog suffix in the title" do
      sheet = Datasheet::Research::Phrase.new(
        description: "9-0511S CHRYSLER DURANGO 11/13",
        part_number: "TK1283-1",
        item_group: "KIT DE DISTRIBUCION"
      ).call
      match = page(
        url: "https://parts.test/pump",
        part_number: "",
        body: "<title>Cloyes 9-0511SX Engine Timing Chain Kit</title>"
      )
      search = instance_double(Datasheet::Research::SerpApiSearch)
      allow(search).to receive(:call).with(sheet.queries["9-0511S"]).and_return([ match.url ])
      fetch = fetch_returning(match)

      hit = described_class.new(
        phrase: sheet,
        item_group: "KIT DE DISTRIBUCION",
        search: search,
        fetch: fetch
      ).call

      expect(hit).to have_attributes(equivalent: "9-0511S", url: match.url)
      expect(sheet.queries["9-0511S"]).to eq(%("9-0511S" Chrysler timing chain kit 2011-2013))
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
