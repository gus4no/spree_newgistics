require 'spec_helper'

describe Spree::Newgistics::ApiClient do

  success_adapter = Faraday.new do |builder|
    builder.adapter :test do |stub|
      get_shipment = File.read(File.expand_path('spec/faraday/post_shipment.txt'))

      stub.get('/shipments.aspx') { |env| [200, {}, get_shipment] }
    end
  end

  describe "orders interactions" do
    let(:params) do { "id" => "R12345678" } end

    before(:each) do
      Spree::Newgistics::HTTPManager.stub(:adapter).and_return(success_adapter)
    end

    it "should call shipments request" do
      expect(Spree::Newgistics::HTTPManager).to receive(:get).with('shipments.aspx', params)
      Spree::Newgistics::ApiClient.orders(params)
    end

  end
end
