require 'spec_helper'

describe Workers::ProductsPuller do
  describe "#save_products" do
  end

  describe "#get_attributes_from" do
    let(:product) do {
      'sku' => 'PH9000',
      'description' => 'test - sku',
      'upc' => '123',
      'value' => '12.99',
      'retailValue' => '10.99',
      'height' => '1',
      'width' => '2',
      'weight' => '3',
      'depth' => '4',
      'isActive' => 'true'
    } end

    it "should return valid hash" do
      result = subject.get_attributes_from(product)
      expect(result[:sku]).to be(product['sku'])
      expect(result[:name]).to be(product['description'])
      expect(result[:description]).to be(product['description'])
      expect(result[:upc]).to be(product['upc'])
      expect(result[:cost_price]).to be(product['value'].to_f)
      expect(result[:price]).to be(product['retailValue'].to_f)
      expect(result[:height]).to be(product['height'].to_f)
      expect(result[:width]).to be(product['width'].to_f)
      expect(result[:weight]).to be(product['weight'].to_f)
      expect(result[:depth]).to be(product['depth'].to_f)
    end
  end
end
