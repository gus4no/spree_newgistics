require 'spec_helper'

describe Workers::ProductsPuller do
  before(:each) do
    Spree::Variant.any_instance.stub(:ensure_color_code)
    Spree::Variant.any_instance.stub(:enqueue_product_for_reindex)
  end

  describe "#create_with_master" do

    let(:product) do
      {
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
      }
    end

    before do
      Spree::Product.class_eval do
        attr_accessor :upc
      end

      Spree::Variant.class_eval do
        attr_accessor :item_category_id, :newgistics_active, :upc, :vendor, :vendor_sku
      end
    end

    it 'creates a product'  do
      expect { subject.create_with_master(product, nil, "") }.to change(Spree::Product, :count).by 1
    end

    it 'creates a master variant and an additional one' do
      expect { subject.create_with_master(product, nil, "") }.to change(Spree::Variant, :count).by 2
    end

  end

  describe '#item_category_id_from' do
    let(:categories) { [] }

    context 'without a supplier' do
      it 'returns nil' do
        expect(subject.item_category_id_from(nil, categories)).to be_nil
      end
    end

    context 'with a supplier' do

      let(:supplier)   { Faker::Name.last_name }
      let(:category)   { double('Spree::ItemCategory', id: 1, name: supplier)  }

      context 'when the category is found' do
        let(:categories) { [category] }

        it 'returns the category id' do
          expect(subject.item_category_id_from(supplier, categories)).to eq(category.id)
        end
      end

      context 'when the category is not found' do
        before do
          stub_const('Spree::ItemCategory', double('Spree::ItemCategory'))
        end

        it 'creates a new category and returns its id' do
          expect(Spree::ItemCategory).to receive(:create).with(name: supplier) { category }
          expect(subject.item_category_id_from(supplier, categories)).to eq(category.id)
        end
      end
    end
  end

  describe '#perform' do

    let(:fake_response) { double('Response') }

    before do
      allow(Spree::Newgistics::HTTPManager).to receive(:get) { fake_response  }
    end

    context 'when products response is unsuccessful' do
      before do
        fake_response.stub status: 422
      end

      it 'inserts a new record with the failure' do
        expect{ subject.perform }.to change(Spree::Newgistics::Import, :count).by 1
      end
    end

    context 'when products response is successful' do
      before do
        fake_response.stub status: 200, body: <<-XML
          <?xml version="1.0" encoding="utf-8"?>
          <products>
            <product id="1001">
              <sku>PRODUCTSKU0001</sku>
              <description>This is a test product</description>
              <upc>8123456789012</upc>
              <supplier>Test Supplier</supplier>
              <supplierCode>VENDORSKU001</supplierCode>
              <category>Furniture</category>
              <height>44</height>
              <width>13</width>
              <depth>10</depth>
              <weight>15</weight>
              <value>79.0000</value>
              <retailValue>99.9900</retailValue>
              <isActive>true</isActive>
              <customFields>
                <CountryOfOrigin>USA</CountryOfOrigin>
              </customFields>
            </product>
          </products>
        XML
      end

      it 'saves the products' do
        expect(subject).to receive(:save_products)
        subject.perform
      end
    end
  end

  describe "#save_products" do
    before do
      subject.stub :item_category_from
    end

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

      context "and no matching variant" do
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

        let(:colorless_response) do [{
          'sku' => 'CYN6000',
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

        it "should create this variant and attach it to the master for colorless SKU" do
          category_id = 1
          stub_const("Spree::ItemCategory", fake_category)
          Spree::ItemCategory.stub(:find_or_create_by!).and_return(Spree::ItemCategory.new(category_id))
          Spree::ItemCategory.stub(:where).and_return([])

          master_variant

          expect(subject).to receive(:attach_to_master)
          expect(subject).not_to receive(:create_with_master)
          subject.save_products(colorless_response)
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

    context 'when an exception is raised' do
      let(:products) do
        [{
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
        }]
      end

      let(:log) do
        double('Log').as_null_object
      end

      let(:error) { 'Could be anything really' }

      before do
        allow(Spree::Variant).to receive(:find_by_sku).and_raise(StandardError, error)

        allow(File).to receive(:open).and_return(log)

        stub_const("Spree::ItemCategory", fake_category)
        Spree::ItemCategory.stub(:where).and_return([])
      end

      specify do
        expect(log).to receive(:<<).with "ERROR: sku: #{products[0]['sku']} failed due to: #{error}\n"

        subject.save_products(products)
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

      it { expect{ subject.product_code(product) }.not_to raise_error }

      it "should return base" do
        expect( subject.product_code(product) ).to eq(product['sku'].split('-')[0])
      end
    end

    context "product code without color code" do
      let(:product) do {
        'sku' => 'RAN1'
      } end

      it { expect { subject.product_code(product) }.not_to raise_error }

      it "should return SKU" do
        expect( subject.product_code(product) ).to eq(product['sku'])
      end
    end
  end

  describe "#color_code_present?" do
    context "product code with color code" do
      let(:product) do {
        'sku' => 'RAN1-05'
      } end

      it { expect( subject.color_code_present?(product)).to be_truthy }
    end

    context "product code without color code" do
      let(:product) do {
        'sku' => 'RAN1'
      } end

      it { expect( subject.color_code_present?(product)).to be_falsy }
    end
  end

  describe "#attach_to_master" do

    before(:each) do
      Spree::Variant.class_eval do
        attr_accessor :upc, :vendor, :vendor_sku, :item_category_id, :newgistics_active
      end

      Spree::Product.class_eval do
        attr_accessor :upc
      end
    end

    context "with existing master variant" do
      let(:master_variant) { create :variant, sku: 'CYN6000-00', is_master: true }
      let(:item_category_id) { 1 }
      let(:product) do {
        'sku' => 'CYN6000-01',
        'description' => 'variant to attach',
        'upc' => '123',
        'value' => '12.99',
        'retailValue' => '10.99',
        'height' => '1',
        'width' => '2',
        'weight' => '3',
        'depth' => '4',
        'isActive' => 'true'
      } end

      it "should create new not master variant attached to master" do
        master_variant

        subject.attach_to_master(product, item_category_id, [])

        new_variant = Spree::Variant.find_by_sku(product['sku'])
        expect(new_variant).not_to be_nil
        expect(new_variant.is_master).to be_falsy
      end

      it "should create exactly 1 variants" do
        subject.attach_to_master(product, item_category_id, [])

        spree_product = Spree::Product.first
        expect(spree_product.variants.length).to be(1)
      end
    end

    context "with exisitng master variant and other variant" do
      let(:master_variant) { create :variant, sku: 'CYN6000-00', is_master: true }
      let(:other_variant) { create :variant, sku: 'CYN6000-01', is_master: false }
      let(:item_category_id) { 1 }
      let(:product) do {
        'sku' => 'CYN6000-02',
        'description' => 'variant to attach',
        'upc' => '123',
        'value' => '12.99',
        'retailValue' => '10.99',
        'height' => '1',
        'width' => '2',
        'weight' => '3',
        'depth' => '4',
        'isActive' => 'true'
      } end

      before(:each) do
        master_variant.product.variants << other_variant
        master_variant.save
      end

      it "should add new variant to exising ones" do
        master_variant
        other_variant

        subject.attach_to_master(product, item_category_id, [])

        spree_product = Spree::Product.first
        expect(spree_product.variants.length).to eq(2)

        new_variant = Spree::Variant.find_by_sku(product['sku'])
        expect(new_variant.product).to eq(spree_product)
      end
    end

    context "without master variant" do
      let(:other_variant) { create :variant, sku: 'RAN1-00', is_master: true }
      let(:item_category_id) { 1 }
      let(:product) do {
        'sku' => 'CYN6000-01',
        'description' => 'variant to attach',
        'upc' => '123',
        'value' => '12.99',
        'retailValue' => '10.99',
        'height' => '1',
        'width' => '2',
        'weight' => '3',
        'depth' => '4',
        'isActive' => 'true'
      } end

      it "should create a product" do
        subject.attach_to_master(product, item_category_id, [])

        sku_to_find = product['sku'].split("-")[0] + "-00"

        spree_product = Spree::Product.first
        expect(spree_product).not_to be_nil
        expect(spree_product).to be_truthy
      end

      it "should create master variant with valid SKU" do
        subject.attach_to_master(product, item_category_id, [])

        sku = product['sku'].split("-")[0] + "-00"

        spree_product = Spree::Product.first
        master = spree_product.master
        expect(master).not_to be_nil
        expect(master.is_master).to be_truthy
        expect(master.sku).to eq(sku)
      end

      it "should create new not master variant attached to master" do
        subject.attach_to_master(product, item_category_id, [])

        new_variant = Spree::Variant.find_by_sku(product['sku'])
        expect(new_variant).not_to be_nil
        expect(new_variant.is_master).to be_falsy
      end

      it "should create exactly 1 variants" do
        subject.attach_to_master(product, item_category_id, [])

        spree_product = Spree::Product.first
        expect(spree_product.variants.length).to be(1)
      end
    end
  end
end
