require 'spec_helper'

describe Workers::ProductsPuller do
  before(:each) do
    Spree::Variant.any_instance.stub(:ensure_color_code)
    Spree::Variant.any_instance.stub(:enqueue_product_for_reindex)
  end

  describe "#save_products" do
    let(:fake_category) {Struct.new(:id)}

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

      it "should update existing variant" do
        category_id = 1
        stub_const("Spree::ItemCategory", fake_category)
        Spree::ItemCategory.stub(:find_or_create_by!).and_return(Spree::ItemCategory.new(category_id))
        Spree::ItemCategory.stub(:where).and_return([])

        variant # to load variant in database

        expect(subject).to receive(:update_variant)
        subject.save_products(response)
      end
    end

    context "with existing master variant" do
      let(:master_variant) { create :variant, sku: 'CYN6000-00', is_master: true }

      let(:response) do [{
        'sku' => 'CYN6000-01',
        'description' => 'SKU with master already in DB',
        'upc' => '123',
        'value' => '12.99',
        'retailValue' => '10.99',
        'height' => '1',
        'width' => '2',
        'weight' => '3',
        'depth' => '4',
        'isActive' => 'true'
      }] end

      context "and no matching variant" do
        it "should create this variant and attach it to the master" do
          category_id = 1
          stub_const("Spree::ItemCategory", fake_category)
          Spree::ItemCategory.stub(:find_or_create_by!).and_return(Spree::ItemCategory.new(category_id))
          Spree::ItemCategory.stub(:where).and_return([])

          master_variant

          expect(subject).to receive(:attach_to_master)
          expect(subject).not_to receive(:create_with_master)
          subject.save_products(response)
        end
      end

      context "and a matching variant" do
        let(:variant) { create :variant, sku: 'CYN6000-02' }

        let(:response) do [{
          'sku' => 'CYN6000-02',
          'description' => 'SKU with master already in DB',
          'upc' => '123',
          'value' => '12.99',
          'retailValue' => '10.99',
          'height' => '1',
          'width' => '2',
          'weight' => '3',
          'depth' => '4',
          'isActive' => 'true'
        }] end

        it "should update the variant" do
          category_id = 1
          stub_const("Spree::ItemCategory", fake_category)
          Spree::ItemCategory.stub(:find_or_create_by!).and_return(Spree::ItemCategory.new(category_id))
          Spree::ItemCategory.stub(:where).and_return([])

          master_variant
          variant

          expect(subject).to receive(:update_variant)
          expect(subject).not_to receive(:attach_to_master)
          expect(subject).not_to receive(:create_with_master)
          subject.save_products(response)
        end
      end
    end

    context "not exisitng variant with color code" do
      let(:response) do [{
        'sku' => 'AB468-123',
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

      let(:variant) { create :variant, sku: 'AB468' }

      it "should attach new variant to master" do
        category_id = 1
        stub_const("Spree::ItemCategory", fake_category)
        Spree::ItemCategory.stub(:find_or_create_by!).and_return(Spree::ItemCategory.new(category_id))
        Spree::ItemCategory.stub(:where).and_return([])
        variant.stub(:ensure_color_code).and_return(true)

        variant.is_master = true
        variant.save

        expect(subject).to receive(:attach_to_master)
        subject.save_products(response)
      end
    end

    context "not exisitng variant without color code" do
      let(:response) do [{
        'sku' => 'REN5',
        'description' => 'new SKU without color code',
        'upc' => '123',
        'value' => '12.99',
        'retailValue' => '10.99',
        'height' => '1',
        'width' => '2',
        'weight' => '3',
        'depth' => '4',
        'isActive' => 'true'
      }] end

      it "should attach new variant to master" do
        category_id = 1
        stub_const("Spree::ItemCategory", fake_category)
        Spree::ItemCategory.stub(:find_or_create_by!).and_return(Spree::ItemCategory.new(category_id))
        Spree::ItemCategory.stub(:where).and_return([])

        expect(subject).to receive(:create_with_master)
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

  describe "#update_variant" do
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

    let(:variant) { create :variant }

    it "should not fail if variants product is nil" do
      variant.stub(:ensure_color_code).and_return(true)
      variant.stub(:upc)
      variant.stub(:upc=)
      variant.stub(:vendor)
      variant.stub(:vendor=)
      variant.stub(:vendor_sku)
      variant.stub(:vendor_sku=)
      variant.stub(:item_category_id)
      variant.stub(:item_category_id=)
      variant.stub(:newgistics_active)
      variant.stub(:newgistics_active=)

      expect { subject.update_variant(product, variant, [], nil, nil) }.not_to raise_error
    end
  end

  describe "#product_code" do
    context "product code with color code" do
      let(:product) do {
        'sku' => 'RAN1-05'
      } end

      it "should not raise error" do
        expect{ subject.product_code(product) }.not_to raise_error
      end

      it "should return base" do
        expect( subject.product_code(product) ).to eq(product['sku'].split('-')[0])
      end
    end

    context "product code without color code" do
      let(:product) do {
        'sku' => 'RAN1'
      } end

      it "should not raise error" do
        expect { subject.product_code(product) }.not_to raise_error
      end

      it "should return base sku" do
        expect( subject.product_code(product) ).to eq(product['sku'])
      end
    end
  end
end
