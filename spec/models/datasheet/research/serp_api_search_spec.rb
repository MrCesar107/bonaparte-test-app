require "rails_helper"
require "net/http"

RSpec.describe Datasheet::Research::SerpApiSearch do
  describe "#call" do
    it "returns Google result links in order" do
      account = account_with(searches_left: 250)
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
      http = stub_http
      expect(http).to receive(:request) do |get|
        expect(get.path).to include("engine=google")
        expect(get.path).to include("q=")
        response
      end

      links = described_class.new(api_key: "test-key", account: account).call('"DM-152" oil pump')

      expect(links.map(&:url)).to eq([ "https://parts.test/first", "https://parts.test/second" ])
      expect(http).to have_received(:open_timeout=).with(5)
      expect(http).to have_received(:read_timeout=).with(15)
      expect(account).to have_received(:consume!)
    end

    it "keeps the snippet and leaves AI Overview citations out of the organic list" do
      account = account_with(searches_left: 250)
      response = http_response(
        code: "200",
        success: true,
        body: {
          "organic_results" => [
            { "link" => "https://parts.test/catalog.pdf", "snippet" => "FS-001225 Nissan" }
          ],
          "ai_overview" => {
            "snippet" => "QJC20G es un juego de empaques",
            "references" => [
              { "link" => "https://dacomsa.test/qjc20g", "snippet" => "QJC20G Quebec" }
            ]
          }
        }.to_json
      )
      stub_http(response)

      links = described_class.new(api_key: "test-key", account: account).call("QJC20G")

      expect(links.map(&:url)).to eq([ "https://parts.test/catalog.pdf" ])
      expect(links.first.snippet).to eq("FS-001225 Nissan")
      expect(links.references.map(&:url)).to eq([ "https://dacomsa.test/qjc20g" ])
      expect(links.overview).to include("QJC20G es un juego de empaques")
      expect(links).not_to be_pending_overview
    end

    it "holds the AI Overview token until it is resolved" do
      account = account_with(searches_left: 250)
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
      http = stub_http
      allow(http).to receive(:request) do |get|
        calls += 1
        expect(get.path).to include(calls == 1 ? "engine=google" : "engine=google_ai_overview")
        calls == 1 ? search : overview
      end
      client = described_class.new(api_key: "test-key", account: account)

      links = client.call("QJC20G")

      expect(links).to be_empty
      expect(links).to be_pending_overview
      expect(calls).to eq(1)

      resolved = client.resolve_overview(links)

      expect(resolved.references.map(&:url)).to eq([ "https://dacomsa.test/qjc20g" ])
      expect(resolved.overview).to include("QJC20G es un juego de empaques")
      expect(calls).to eq(2)
    end

    it "reads the account once for the searches in a run" do
      requests = []
      http = stub_http
      allow(http).to receive(:request) do |get|
        requests << get.path
        body = if get.path.include?("account.json")
          { "total_searches_left" => 2 }
        else
          { "organic_results" => [ { "link" => "https://parts.test/dm-152" } ] }
        end
        http_response(code: "200", success: true, body: body.to_json)
      end
      account = Datasheet::Research::SerpApiAccount.new(api_key: "test-key")
      client = described_class.new(api_key: "test-key", account: account)

      client.call("DM-152")
      client.call("RM-152")

      expect(requests.count { |path| path.include?("account.json") }).to eq(1)
      expect(requests.count { |path| path.include?("engine=google") }).to eq(2)
      expect(account.searches_left).to eq(0)
    end

    it "raises before calling Google when the account has no searches left" do
      account = account_with(searches_left: 0)
      expect(Net::HTTP).not_to receive(:new)

      expect {
        described_class.new(api_key: "test-key", account: account).call("DM-152")
      }.to raise_error(Datasheet::Research::OutOfCredits)
    end

    it "raises when SerpApi says the account ran out of searches" do
      account = account_with(searches_left: 1)
      response = http_response(
        code: "429",
        success: false,
        body: { "error" => "Your account has run out of searches." }.to_json
      )
      stub_http(response)

      expect {
        described_class.new(api_key: "test-key", account: account).call("DM-152")
      }.to raise_error(Datasheet::Research::OutOfCredits)
      expect(account).to have_received(:exhaust!)
    end

    it "raises when the key is missing" do
      account = account_with(searches_left: 250)
      expect(Net::HTTP).not_to receive(:new)

      expect {
        described_class.new(api_key: "", account: account).call("DM-152")
      }.to raise_error(Datasheet::Research::Unavailable)
    end

    it "returns no links when Google has no results for the query" do
      account = account_with(searches_left: 250)
      response = http_response(
        code: "200",
        success: true,
        body: { "error" => "Google hasn't returned any results for this query." }.to_json
      )
      stub_http(response)

      links = described_class.new(api_key: "test-key", account: account).call("HL7011")

      expect(links).to eq([])
    end

    it "raises when Google answers with another error" do
      account = account_with(searches_left: 250)
      response = http_response(code: "200", success: true, body: { "error" => "Something went wrong." }.to_json)
      stub_http(response)

      expect {
        described_class.new(api_key: "test-key", account: account).call("DM-152")
      }.to raise_error(Datasheet::Research::Unavailable)
    end
  end

  def account_with(searches_left:)
    account = instance_double(Datasheet::Research::SerpApiAccount, searches_left: searches_left)
    allow(account).to receive(:consume!)
    allow(account).to receive(:exhaust!)
    account
  end

  def stub_http(response = nil)
    http = instance_double(Net::HTTP)
    allow(Net::HTTP).to receive(:new).and_return(http)
    allow(http).to receive(:use_ssl=)
    allow(http).to receive(:open_timeout=)
    allow(http).to receive(:read_timeout=)
    allow(http).to receive(:request).and_return(response) if response
    http
  end

  def http_response(code:, body:, success:)
    response = instance_double(Net::HTTPResponse, code: code, body: body)
    allow(response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(success)
    response
  end
end
