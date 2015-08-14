require 'spec_helper'

describe Workers::OrdersPuller do

  describe "#update_shipments" do

    context "when newgistics status differs" do
      let(:order) { create :order, newgistics_status: 'ONVHOLD', state: 'complete' }
      let(:response) do [{
        'OrderID' => order.number,
        'FirstName' => 'John',
        'LastName' => 'Smith',
        'Address1' => 'Somewhere in US',
        'City' => 'Anycity',
        'State' => 'CA',
        'PostalCode' => '12345',
        'Country' => 'UNITED STATES',
        'Phone' => '9871231233'
      }] end

      # missing CANCELED status
      %w{BACKORDER BADADDRESS BADSKUHOLD CNFHOLD INVHOLD ONHOLD
        PICKVERIFIED PRINTED RECEIVED RETURNED SHIPPED UPDATED VERIFIED}.each do |newgistics_status|

        it "should set newgistics status to #{newgistics_status}" do
          Spree::Order.any_instance.stub(:send_product_review_email)
          response.each { |s| s['ShipmentStatus'] = newgistics_status }

          expect { subject.update_shipments(response) }.not_to raise_error
          order.reload
          expect(order.newgistics_status).to eq(newgistics_status)
        end

      end

    end

    context "when exception occurs" do
      let(:order) { create :order, newgistics_status: 'SHIPPED', state: 'delivery' }
      let(:response) do [{
        'OrderID' => order.number,
        'FirstName' => 'John',
        'LastName' => 'Smith',
        'Address1' => 'Somewhere in US',
        'City' => 'Anycity',
        'State' => 'CA',
        'PostalCode' => '12345',
        'Country' => 'UNITED STATES',
        'Phone' => '9871231233',
        'ShipmentStatus' => 'CANCELED'
      }] end

      it "should not throw an exception" do
        Spree::Order.any_instance.stub(:send_product_review_email)

        expect { subject.update_shipments(response) }.not_to raise_error
      end

    end

  end

end
