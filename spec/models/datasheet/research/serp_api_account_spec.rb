require "rails_helper"
require "net/http"

RSpec.describe Datasheet::Research::SerpApiAccount do
  describe "#searches_left" do
    it "returns the searches left on the account" do
      response = http_response(code: "200", body: { "total_searches_left" => 250 }.to_json, success: true)
      http = stub_http
      expect(http).to receive(:request) do |get|
        expect(get.path).to start_with("/account.json")
        expect(get.path).to include("api_key=test-key")
        response
      end

      expect(described_class.new(api_key: "test-key").searches_left).to eq(250)
      expect(http).to have_received(:open_timeout=).with(5)
      expect(http).to have_received(:read_timeout=).with(15)
    end

    it "remembers the balance for the rest of the run" do
      response = http_response(code: "200", body: { "total_searches_left" => 2 }.to_json, success: true)
      http = stub_http(response)
      account = described_class.new(api_key: "test-key")

      expect(account.searches_left).to eq(2)
      account.consume!
      expect(account.searches_left).to eq(1)
      account.exhaust!
      expect(account.searches_left).to eq(0)
      expect(http).to have_received(:request).once
    end

    it "raises when the account does not respond" do
      stub_http(http_response(code: "500", body: "", success: false))

      expect { described_class.new(api_key: "test-key").searches_left }.to raise_error(Datasheet::Research::Unavailable)
    end

    it "raises when the account body is not JSON" do
      stub_http(http_response(code: "200", body: "nope", success: true))

      expect { described_class.new(api_key: "test-key").searches_left }.to raise_error(Datasheet::Research::Unavailable)
    end
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
