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

      expect(links).to eq([ "https://parts.test/first", "https://parts.test/second" ])
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

    it "raises when Google answers with another error" do
      account = instance_double(Datasheet::Research::SerpApiAccount, searches_left: 250)
      response = http_response(code: "200", success: true, body: { "error" => "Google hasn't returned any results for this query." }.to_json)
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
