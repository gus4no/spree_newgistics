require 'spec_helper'

describe Spree::Order do

  success_adapter = Faraday.new do |builder|
    builder.adapter :test do |stub|
      post_shipment = File.read(File.expand_path('spec/faraday/post_shipment.txt'))

      update_shipment = File.read(File.expand_path('spec/faraday/update_shipment_success.txt'))

      stub.post('/post_shipments.aspx') { |env| [200, {}, post_shipment] }
      stub.post('/update_shipment_address.aspx') { |env| [200, {}, update_shipment] }
      stub.post('/update_shipment_contents.aspx') { |env| [200, {}, update_shipment] }
    end
  end

  error_adapter = Faraday.new do |builder|
    builder.adapter :test do |stub|

      update_shipment = File.read(File.expand_path('spec/faraday/update_shipment_error.txt'))

      post_shipment = File.read(File.expand_path('spec/faraday/post_shipment_error.txt'))

      stub.post('/post_shipments.aspx') { |env| [200, {}, post_shipment] }
      stub.post('/update_shipment_address.aspx') { |env| [200, {}, update_shipment] }
      stub.post('/update_shipment_contents.aspx') { |env| [200, {}, update_shipment] }
    end
  end


  context 'succesfull requests' do

    let(:order){ create(:order_ready_to_ship) }

    before(:each) do
      Spree::Newgistics::HTTPManager.stub(:adapter).and_return(success_adapter)
      Spree::Variant.any_instance.stub(:post_to_newgistics)
    end

    it 'posts the order to newgistics' do
      order.post_to_newgistics
      expect(order.posted_to_newgistics).to be_truthy
    end

    it 'updates the shipment address' do
      order.ship_address_id = 1
      order.save
      expect(order.newgistics_status).to eq('UPDATED')
    end

    it 'updates the shipment contents after creating a line item' do
      order.stub(:posted_to_newgistics?).and_return true
      order.should_receive(:add_newgistics_shipment_content)
      order.line_items.create!(variant_id: 1, quantity: 1)
    end

    it 'adds contnet after line item is updated' do
      order.stub(:posted_to_newgistics?).and_return true
      order.should_receive(:add_newgistics_shipment_content)
      li = order.line_items.first
      li.quantity = li.quantity + 1
      li.save
    end

    it 'removes content after line item is updated' do
      order.stub(:posted_to_newgistics?).and_return true
      order.should_receive(:remove_newgistics_shipment_content)
      li = order.line_items.first
      li.quantity = li.quantity - 1
      li.save
    end

    it 'updates the shipment contents after destroying a line item' do
      order.stub(:posted_to_newgistics?).and_return true
      order.should_receive(:remove_newgistics_shipment_content)
      order.line_items.last.destroy
    end

    it 'updates the shipment contents after destroying a line item via controller' do
      # see Spree::OrderContents#remove
      order.stub(:posted_to_newgistics?).and_return true
      order.should_receive(:remove_newgistics_shipment_content)
      line_item = order.line_items.last
      line_item.quantity = 0
      line_item.destroy
    end
  end

  context 'failed requests' do

    let(:order){ create(:order_ready_to_ship) }

    before(:each) do
      Spree::Newgistics::HTTPManager.stub(:adapter).and_return(error_adapter)
      Spree::Variant.any_instance.stub(:post_to_newgistics)
    end

    it 'fails posting the order to newgistics' do
      order.post_to_newgistics
      expect(order.posted_to_newgistics).to be_falsy
    end

    it 'enqueues an order updater for retry' do
      Workers::OrderUpdater.should_receive(:perform_async)
      order.ship_address_id = 1
      order.save
    end


    it 'equeues shipment contents updates after creating a line item' do
      Workers::OrderUpdater.should_receive(:perform_async)
      order.stub(:posted_to_newgistics?).and_return true
      order.line_items.create!(variant_id: 1, quantity: 1)
    end

    it 'equeues adding contnet after line item is updated' do
      order.stub(:posted_to_newgistics?).and_return true
      Workers::OrderUpdater.should_receive(:perform_async)
      li = order.line_items.first
      li.quantity = li.quantity + 1
      li.save
    end

    it 'enqueues removing contnet after line item is updated' do
      order.stub(:posted_to_newgistics?).and_return true
      Workers::OrderUpdater.should_receive(:perform_async)
      li = order.line_items.first
      li.quantity = li.quantity - 1
      li.save
    end

    it 'enqueues updating the shipment contents after creating a line item' do
      order.stub(:posted_to_newgistics?).and_return true
      Workers::OrderUpdater.should_receive(:perform_async)
      order.line_items.last.destroy
    end
  end

end
