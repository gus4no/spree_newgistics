require 'spec_helper'

describe Spree::Order do

  success_adapter = Faraday.new do |builder|
    builder.adapter :test do |stub|
      post_product = File.read(File.expand_path('spec/faraday/post_product.txt'))
      stub.post('/post_products.aspx') { |env| [200, {}, post_product] }
    end
  end

  error_adapter = Faraday.new do |builder|
    builder.adapter :test do |stub|
      post_product = File.read(File.expand_path('spec/faraday/post_product_error.txt'))
      stub.post('/post_products.aspx') { |env| [200, {}, post_product] }
    end
  end

  context 'succesfull requests' do

    before(:each) do
      Spree::Newgistics::HTTPManager.stub(:adapter).and_return(success_adapter)
      Spree::Variant.any_instance.stub(:can_post_to_newgistics).and_return(true)
      @variant = create(:variant)
    end

    it 'posts the order to newgistics' do
      expect(@variant.posted_to_newgistics).to be_truthy
    end

    it 'updates the variant in newgistics' do
      @variant.should_receive(:post_to_newgistics)
      @variant.sku = 'foo bar'
      @variant.save
    end
  end

  context 'failed requests' do

    before(:each) do
      Spree::Newgistics::HTTPManager.stub(:adapter).and_return(error_adapter)
      @variant = create(:variant)
    end

    it 'posts the order to newgistics' do
      expect(@variant.posted_to_newgistics).to be_falsy
    end

    it 'updates the variant in newgistics' do
      @variant.should_receive(:post_to_newgistics)
      @variant.sku = 'foo bar'
      @variant.save
      expect(@variant.posted_to_newgistics).to be_falsy
    end
  end

end
