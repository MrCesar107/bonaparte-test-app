require "rails_helper"
require "net/http"

RSpec.describe Datasheet::Research::SerpApiAccount do
  describe "#searches_left" do
    it "returns the searches left on the account" do
      response = http_response(code: "200", body: { "total_searches_left" => 250 }.to_json, success: true)
      expect(Net::HTTP).to receive(:get_response) do |uri|
        expect(uri.to_s).to start_with("https://serpapi.com/account.json")
        expect(uri.query).to include("api_key=test-key")
        response
      end

      expect(described_class.new(api_key: "test-key").searches_left).to eq(250)
    end

    it "raises when the account does not respond" do
      response = http_response(code: "500", body: "", success: false)
      allow(Net::HTTP).to receive(:get_response).and_return(response)

      expect { described_class.new(api_key: "test-key").searches_left }.to raise_error(Datasheet::Research::Unavailable)
    end

    it "raises when the account body is not JSON" do
      response = http_response(code: "200", body: "nope", success: true)
      allow(Net::HTTP).to receive(:get_response).and_return(response)

      expect { described_class.new(api_key: "test-key").searches_left }.to raise_error(Datasheet::Research::Unavailable)
    end
  end

  def http_response(code:, body:, success:)
    response = instance_double(Net::HTTPResponse, code: code, body: body)
    allow(response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(success)
    response
  end
end
