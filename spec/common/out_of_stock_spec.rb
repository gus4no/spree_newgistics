require 'spec_helper'

describe "out_of_stock" do
  before(:each) do
    Spree::Variant.any_instance.stub(:ensure_color_code)
    Spree::Variant.any_instance.stub(:enqueue_product_for_reindex)
    Spree::Order.any_instance.stub(:send_product_review_email)
    Spree::Order.any_instance.stub(:update_newgistics_shipment_address)
    Spree::Order.any_instance.stub(:update_newgistics_shipment_status)
  end

  context "when OrdersPuller executed after InventoryPuller for canceled order" do

    let(:order) { create(:order_ready_to_be_completed, :line_items_count => 1) }

    let(:cancel_response) do 
        a = order.ship_address
        resp = [{
          'OrderID' => order.number,
          'FirstName' => a.firstname,
          'LastName' => a.lastname,
          'Address1' => a.address1,
          'Address2' => a.address2,
          'City' => a.city,
          'State' => a.state.abbr,
          'Company' => a.company.to_s,
          'PostalCode' => a.zipcode,
          'Country' => a.country.iso_name,
          'Phone' => a.phone,
          'ShipmentStatus' => 'CANCELED'
        }] 
    end

    let(:inventory_response) do [
        {
          "id" => "1148187",
          "sku" => order.line_items.first.variant.sku,
          "currentQuantity"=> "1",
          "receivingQuantity"=> "0",
          "arrivedPutAwayQuantity"=>"0",
          "kittingQuantity"=>"0",
          "returnsQuantity"=>"0",
          "pendingQuantity"=>"0",
          "availableQuantity"=> "1",
          "backorderedQuantity"=>"0"
        }] 
    end

    it "pre check order is created well" do
      expect(order.line_items.size).to eq(1)
      li = order.line_items.first
      expect(li.quantity).to eq(1)
      expect(li.variant.reload.stock_items.count).to eq(1)


      si = li.variant.stock_items.first
      expect(si.stock_location_id).to eq(1)
      expect(si.count_on_hand).to eq(1)
      expect(order.shipments.size).to eq(1)
      expect(order.shipments.first.manifest.size).to eq(1)
      expect(order.shipments.first.manifest.first.quantity).to eq(1)
      expect(order.shipments.first.manifest.first.variant).to eq(li.variant)
    end

    it "should not increase count of items twice" do
      si = order.line_items.first.variant.stock_items.first 
      expect(si.count_on_hand).to eq(1)
      5.times do 
        order.next
      end
      expect(order.state).to eq('complete')
      expect(si.reload.count_on_hand).to eq(0)

      # post order to NG than cancel it from NG
      order.posted_to_newgistics = true
      order.save
      # Run inventory puller
      Workers::InventoryPuller.new.update_inventory(inventory_response)
      expect(si.reload.count_on_hand).to eq(1)

      # Run orders puller
      Workers::OrdersPuller.new.update_shipments(cancel_response)
      order.reload
      expect(order.newgistics_status).to eq('CANCELED')
      expect(order.state).to eq('canceled')
      expect(si.reload.count_on_hand).to eq(1)
    end
       
  end
end