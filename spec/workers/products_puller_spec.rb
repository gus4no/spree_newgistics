require 'spec_helper'

describe Workers::ProductsPuller do
  describe "#save_products" do
    context "with existing variant" do
      let(:response) do [{
        'sku' => 'AB124',
        'description' => 'test - sku',
        'upc' => '123',
        'value' => '12.99',
        'retailValue' => '10.99',
        'height' => '1',
        'width' => '2',
        'weight' => '3',
        'depth' => '4',
        'isActive' => 'true'
      }] end

      let(:variant) { create :variant, sku: 'AB124' }
      let(:fake_category) {Struct.new(:id)}

      it "sould update existing variant" do
        category_id = 1
        stub_const("Spree::ItemCategory", fake_category)
        Spree::ItemCategory.stub(:find_or_create_by!).and_return(Spree::ItemCategory.new(category_id))
        Spree::ItemCategory.stub(:where).and_return([])

        variant # to load variant in database

        expect(subject).to receive(:update_variant)
        subject.save_products(response)
      end
    end
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

  describe "#variant_attributes_from" do
    context "with category present" do
      let(:product) do {
        'category' => 'cool things',
        'upc' => '123',
        'supplierCode' => 'code',
        'supplier' => 'abc',
        'isActive' => 'true'
      }
      end

      let(:fake_category) {Struct.new(:id)}

      it "should return valid hash" do
        category_id = 1
        stub_const("Spree::ItemCategory", fake_category)

        Spree::ItemCategory.stub(:find_or_create_by!).and_return(Spree::ItemCategory.new(category_id))
        result = subject.variant_attributes_from(product)

        expect(result[:item_category_id]).to be(category_id)
        expect(result[:upc]).to be(product['upc'])
        expect(result[:vendor_sku]).to be(product['supplierCode'])
        expect(result[:vendor]).to be(product['supplier'])
        expect(result[:posted_to_newgistics]).to be_truthy
        expect(result[:newgistics_active]).to be_truthy
      end
    end

    context "with blank category" do
      let(:product) do {
        'upc' => '123',
        'supplierCode' => 'code',
        'supplier' => 'abc',
        'isActive' => 'true'
      }
      end

      it "should return valid hash" do
        result = subject.variant_attributes_from(product)

        expect(result[:item_category_id]).to be(nil)
        expect(result[:upc]).to be(product['upc'])
        expect(result[:vendor_sku]).to be(product['supplierCode'])
        expect(result[:vendor]).to be(product['supplier'])
        expect(result[:posted_to_newgistics]).to be_truthy
        expect(result[:newgistics_active]).to be_truthy
      end

      it "newgistics_active should depend on data" do
        product['isActive'] = false
        result = subject.variant_attributes_from(product)

        expect(result[:newgistics_active]).to be_falsy
      end
    end
  end
end
