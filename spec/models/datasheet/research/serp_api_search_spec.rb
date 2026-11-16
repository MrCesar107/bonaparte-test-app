require "rails_helper"
require "net/http"

RSpec.describe Datasheet::Research::SerpApiSearch do
  describe "#call" do
    it "returns Google result links in order" do
      account = instance_double(Datasheet::Research::SerpApiAccount, searches_left: 250)
      response = http_response(
        code: "200",
        success: true,
        body: {
          "organic_results" => [
            { "link" => "https://parts.test/first" },
            { "title" => "sin url" },
            { "link" => "https://parts.test/second" }
          ]
        }.to_json
      )
      expect(Net::HTTP).to receive(:get_response) do |uri|
        expect(uri.query).to include("engine=google")
        expect(uri.query).to include("q=")
        response
      end

      links = described_class.new(api_key: "test-key", account: account).call('"DM-152" oil pump')

      expect(links.map(&:url)).to eq([ "https://parts.test/first", "https://parts.test/second" ])
    end

    it "keeps the snippet and the AI Overview citations" do
      account = instance_double(Datasheet::Research::SerpApiAccount, searches_left: 250)
      response = http_response(
        code: "200",
        success: true,
        body: {
          "organic_results" => [
            { "link" => "https://parts.test/catalog.pdf", "snippet" => "FS-001225 Nissan" }
          ],
          "ai_overview" => {
            "references" => [
              { "link" => "https://dacomsa.test/qjc20g", "snippet" => "QJC20G Quebec" }
            ]
          }
        }.to_json
      )
      allow(Net::HTTP).to receive(:get_response).and_return(response)

      links = described_class.new(api_key: "test-key", account: account).call("QJC20G")

      expect(links.map(&:url)).to eq([ "https://parts.test/catalog.pdf", "https://dacomsa.test/qjc20g" ])
      expect(links.first.snippet).to eq("FS-001225 Nissan")
    end

    it "asks for the AI Overview when Google only returns a page token" do
      account = instance_double(Datasheet::Research::SerpApiAccount, searches_left: 250)
      search = http_response(
        code: "200",
        success: true,
        body: { "organic_results" => [], "ai_overview" => { "page_token" => "token-1" } }.to_json
      )
      overview = http_response(
        code: "200",
        success: true,
        body: {
          "text_blocks" => [ { "snippet" => "QJC20G es un juego de empaques para Nissan" } ],
          "references" => [ { "link" => "https://dacomsa.test/qjc20g", "snippet" => "QJC20G" } ]
        }.to_json
      )
      calls = 0
      allow(Net::HTTP).to receive(:get_response) do |uri|
        calls += 1
        expect(uri.query).to include(calls == 1 ? "engine=google" : "engine=google_ai_overview")
        calls == 1 ? search : overview
      end

      links = described_class.new(api_key: "test-key", account: account).call("QJC20G")

      expect(links.map(&:url)).to eq([ "https://dacomsa.test/qjc20g" ])
      expect(links.overview).to include("QJC20G es un juego de empaques")
    end

    it "raises before calling Google when the account has no searches left" do
      account = instance_double(Datasheet::Research::SerpApiAccount, searches_left: 0)
      expect(Net::HTTP).not_to receive(:get_response)

      expect {
        described_class.new(api_key: "test-key", account: account).call("DM-152")
      }.to raise_error(Datasheet::Research::OutOfCredits)
    end

    it "raises when SerpApi says the account ran out of searches" do
      account = instance_double(Datasheet::Research::SerpApiAccount, searches_left: 1)
      response = http_response(
        code: "429",
        success: false,
        body: { "error" => "Your account has run out of searches." }.to_json
      )
      allow(Net::HTTP).to receive(:get_response).and_return(response)

      expect {
        described_class.new(api_key: "test-key", account: account).call("DM-152")
      }.to raise_error(Datasheet::Research::OutOfCredits)
    end

    it "raises when the key is missing" do
      account = instance_double(Datasheet::Research::SerpApiAccount, searches_left: 250)
      expect(Net::HTTP).not_to receive(:get_response)

      expect {
        described_class.new(api_key: "", account: account).call("DM-152")
      }.to raise_error(Datasheet::Research::Unavailable)
    end

    it "returns no links when Google has no results for the query" do
      account = instance_double(Datasheet::Research::SerpApiAccount, searches_left: 250)
      response = http_response(
        code: "200",
        success: true,
        body: { "error" => "Google hasn't returned any results for this query." }.to_json
      )
      allow(Net::HTTP).to receive(:get_response).and_return(response)

      links = described_class.new(api_key: "test-key", account: account).call("HL7011")

      expect(links).to eq([])
    end

    it "raises when Google answers with another error" do
      account = instance_double(Datasheet::Research::SerpApiAccount, searches_left: 250)
      response = http_response(code: "200", success: true, body: { "error" => "Something went wrong." }.to_json)
      allow(Net::HTTP).to receive(:get_response).and_return(response)

      expect {
        described_class.new(api_key: "test-key", account: account).call("DM-152")
      }.to raise_error(Datasheet::Research::Unavailable)
    end
  end

  def http_response(code:, body:, success:)
    response = instance_double(Net::HTTPResponse, code: code, body: body)
    allow(response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(success)
    response
  end
end
