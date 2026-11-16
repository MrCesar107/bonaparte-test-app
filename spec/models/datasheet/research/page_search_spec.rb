require "rails_helper"

RSpec.describe Datasheet::Research::PageSearch do
  describe "#call" do
    it "accepts the part number page before an earlier interchange page" do
      interchange = page(url: "https://parts.test/m152", part_number: "M152", interchange_numbers: [ "DM-152" ])
      match = page(url: "https://parts.test/dm-152", part_number: "DM-152", body: vehicle_page("DM-152"))
      search = search_returning('"DM-152" Nissan oil pump 1976-2014' => [ interchange.url, match.url ])
      fetch = fetch_returning(interchange, match)

      hit = search_pages(search:, fetch:)

      expect(hit).to have_attributes(equivalent: "DM-152", url: match.url)
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
        body: vehicle_page("DM-152 Oil Pump")
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
      match = page(url: "https://parts.test/dm-152", part_number: "DM-152", body: vehicle_page("DM-152"))
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

    it "accepts a catalog row when the snippet has the number and the title does not" do
      match = page(
        url: "https://parts.test/catalog",
        part_number: "",
        body: "<title>Catálogo</title><p>DM-152 NISSAN PICKUP 1976-2014</p>"
      )
      lead = Datasheet::Research::SerpApiSearch::Result.new(url: match.url, snippet: "DM-152 oil pump")
      search = search_returning('"DM-152" Nissan oil pump 1976-2014' => [ lead ])
      fetch = fetch_returning(match)

      hit = search_pages(search:, fetch:)

      expect(hit).to have_attributes(equivalent: "DM-152", url: match.url)
    end

    it "does not accept an interchange page when the snippet mentions the candidate" do
      melling = page(
        url: "https://parts.test/m152",
        part_number: "M152",
        body: "<title>M152 Oil Pump</title><p>Interchange DM-152 Nissan 1976</p>"
      )
      lead = Datasheet::Research::SerpApiSearch::Result.new(url: melling.url, snippet: "DM-152")
      search = search_returning(
        '"DM-152" Nissan oil pump 1976-2014' => [ lead ],
        '"RM-152" Nissan oil pump 1976-2014' => []
      )
      fetch = fetch_returning(melling)

      expect(search_pages(search:, fetch:)).to eq(:not_found)
    end

    it "keeps searching when a page has the number and no vehicle application" do
      sheet = Datasheet::Research::Phrase.new(
        description: "83-301 CHEVROLET SILVERADO 14/18",
        part_number: "SP26-329R",
        item_group: "PISTONES"
      ).call
      filter = page(
        url: "https://mowpart.test/83-301",
        part_number: "",
        body: "<title>Oregon 83-301 Oil Filter</title><h2>Intercambios</h2><table><tr><th>Número</th><th>Marca</th></tr><tr><td>15400-PFB-004</td><td>Honda</td></tr></table>"
      )
      piston = page(url: "https://parts.test/piston", part_number: "SP26-329R", body: vehicle_page("SP26-329R"))
      search = instance_double(Datasheet::Research::SerpApiSearch)
      allow(search).to receive(:call).with(sheet.queries["83-301"]).and_return([ filter.url ])
      allow(search).to receive(:call).with(sheet.queries["SP26-329R"]).and_return([ piston.url ])
      fetch = fetch_returning(filter, piston)

      hit = described_class.new(
        phrase: sheet,
        source_row: build(:source_row, description: "83-301 CHEVROLET SILVERADO 14/18", part_number: "SP26-329R"),
        item_group: "PISTONES",
        search: search,
        fetch: fetch,
        rewrite: empty_rewrite
      ).call

      expect(hit).to have_attributes(equivalent: "SP26-329R", url: piston.url)
      expect(search).to have_received(:call).with(sheet.queries["83-301"])
      expect(search).to have_received(:call).with(sheet.queries["SP26-329R"])
    end

    it "keeps overview applications off a page that has none" do
      sheet = Datasheet::Research::Phrase.new(
        description: "83-301 CHEVROLET SILVERADO 14/18",
        part_number: "SP26-329R",
        item_group: "PISTONES"
      ).call
      filter = page(
        url: "https://mowpart.test/83-301",
        part_number: "",
        body: "<title>Oregon 83-301 Oil Filter</title><p>83-301 oil filter</p>"
      )
      overview = "83-301 is listed apart from the piston applications"
      reply = Datasheet::Research::SerpApiSearch::Reply.new([ filter.url ], overview)
      search = instance_double(Datasheet::Research::SerpApiSearch)
      allow(search).to receive(:call).with(sheet.queries["83-301"]).and_return(reply)
      allow(search).to receive(:call).with(sheet.queries["SP26-329R"]).and_return([])
      fetch = fetch_returning(filter)
      rewrite = rewrite_returning(overview => transcribed_lists(part_number: "83-301"))

      hit = described_class.new(
        phrase: sheet,
        source_row: build(:source_row, description: "83-301 CHEVROLET SILVERADO 14/18", part_number: "SP26-329R"),
        item_group: "PISTONES",
        search: search,
        fetch: fetch,
        rewrite: rewrite
      ).call

      expect(hit).to have_attributes(equivalent: "83-301", url: "", lists: have_attributes(part_number: "83-301"))
      expect(search).not_to have_received(:call).with(sheet.queries["SP26-329R"])
    end

    it "keeps searching when the overview transcription names another part" do
      sheet = Datasheet::Research::Phrase.new(
        description: "83-301 CHEVROLET SILVERADO 14/18",
        part_number: "SP26-329R",
        item_group: "PISTONES"
      ).call
      filter = page(
        url: "https://mowpart.test/83-301",
        part_number: "",
        body: "<title>Oregon 83-301 Oil Filter</title><p>83-301 oil filter</p>"
      )
      piston = page(url: "https://parts.test/piston", part_number: "SP26-329R", body: vehicle_page("SP26-329R"))
      overview = "83-301 is listed apart from the piston applications"
      reply = Datasheet::Research::SerpApiSearch::Reply.new([ filter.url ], overview)
      search = instance_double(Datasheet::Research::SerpApiSearch)
      allow(search).to receive(:call).with(sheet.queries["83-301"]).and_return(reply)
      allow(search).to receive(:call).with(sheet.queries["SP26-329R"]).and_return([ piston.url ])
      fetch = fetch_returning(filter, piston)

      hit = described_class.new(
        phrase: sheet,
        source_row: build(:source_row, description: "83-301 CHEVROLET SILVERADO 14/18", part_number: "SP26-329R"),
        item_group: "PISTONES",
        search: search,
        fetch: fetch,
        rewrite: rewrite_returning(overview => transcribed_lists(part_number: "SP26-329R"))
      ).call

      expect(hit).to have_attributes(equivalent: "SP26-329R", url: piston.url)
    end

    it "drops an overview transcription whose part number is blank" do
      overview = "A note about DM-152 appears here without a fitment row."
      reply = Datasheet::Research::SerpApiSearch::Reply.new([], overview)
      search = instance_double(Datasheet::Research::SerpApiSearch)
      allow(search).to receive(:call).with(%("DM-152" Nissan oil pump 1976-2014)).and_return(reply)
      allow(search).to receive(:call).with(%("RM-152" Nissan oil pump 1976-2014)).and_return([])

      result = described_class.new(
        phrase: phrase,
        source_row: build(:source_row, description: "DM-152 NISSAN PICKUP 76/14", part_number: "RM-152"),
        item_group: "BOMBA DE ACEITE",
        search: search,
        fetch: instance_double(Proc),
        rewrite: rewrite_returning(overview => transcribed_lists(part_number: ""))
      ).call

      expect(result).to eq(:not_found)
    end

    it "keeps the overview text when no page serves and the text names the candidate" do
      reply = Datasheet::Research::SerpApiSearch::Reply.new([], "DM-152 Nissan pickup desde 1976")
      search = instance_double(Datasheet::Research::SerpApiSearch)
      allow(search).to receive(:call).and_return(reply)

      hit = search_pages(search:, fetch: instance_double(Proc))

      expect(hit).to have_attributes(
        equivalent: "DM-152",
        url: "",
        body: "DM-152 Nissan pickup desde 1976",
        overview: "DM-152 Nissan pickup desde 1976"
      )
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
        body: vehicle_page("Cloyes 9-0511SX Engine Timing Chain Kit")
      )
      search = instance_double(Datasheet::Research::SerpApiSearch)
      allow(search).to receive(:call).with(sheet.queries["9-0511S"]).and_return([ match.url ])
      fetch = fetch_returning(match)

      hit = described_class.new(
        phrase: sheet,
        source_row: build(:source_row, description: "9-0511S CHRYSLER DURANGO 11/13", part_number: "TK1283-1"),
        item_group: "KIT DE DISTRIBUCION",
        search: search,
        fetch: fetch,
        rewrite: empty_rewrite
      ).call

      expect(hit).to have_attributes(equivalent: "9-0511S", url: match.url)
      expect(sheet.queries["9-0511S"]).to eq(%("9-0511S" Chrysler timing chain kit 2011-2013))
    end
  end

  def search_pages(search:, fetch:)
    described_class.new(
      phrase: phrase,
      source_row: build(:source_row, description: "DM-152 NISSAN PICKUP 76/14", part_number: "RM-152"),
      item_group: "BOMBA DE ACEITE",
      search: search,
      fetch: fetch,
      rewrite: empty_rewrite
    ).call
  end

  def rewrite_returning(lists_by_text)
    rewrite = instance_double(Datasheet::Research::PageRewrite)
    allow(rewrite).to receive(:call) do |text|
      lists_by_text.fetch(text) { empty_model_lists }
    end
    rewrite
  end

  def transcribed_lists(part_number:)
    Datasheet::Research::PageLists::Lists.new(
      part_number: part_number,
      subsystem: "",
      product: "Pistón",
      description: "",
      applications: [
        Datasheet::Research::PageLists::ApplicationRow.new(
          manufacturer: "Chevrolet", model: "Silverado 1500", submodel: "", start_year: "2014", end_year: "2018",
          liters: "4.3", engine_cc: "", engine_cid: "", engine_cylinders: "6", block: "V", fuel_type: "", market: ""
        )
      ],
      interchanges: [],
      attributes: [],
      unconfirmed_tokens: []
    )
  end

  def empty_rewrite
    rewrite = instance_double(Datasheet::Research::PageRewrite)
    allow(rewrite).to receive(:call).and_return(empty_model_lists)
    rewrite
  end

  def empty_model_lists
    Datasheet::Research::PageLists::Lists.new(
      part_number: "", subsystem: "", product: "", description: "",
      applications: [], interchanges: [], attributes: [], unconfirmed_tokens: []
    )
  end

  def vehicle_page(title)
    <<~HTML
      <title>#{title}</title>
      <h2>Aplicaciones</h2>
      <table>
        <tr><th>Fabricante</th><th>Modelo</th><th>Año</th></tr>
        <tr><td>Nissan</td><td>Pickup</td><td>1976-2014</td></tr>
      </table>
    HTML
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
