require 'spec_helper'

describe Workers::OrdersPuller do

  describe "#update_shipments" do

      context "when new status is SHIPPED" do
        Spree::Order.any_instance.stub(:send_product_review_email)

        let(:order) { create :order_ready_to_ship, newgistics_status: 'ONVHOLD' }

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
          'ShipmentStatus' => 'SHIPPED',
          'Tracking' => '12450691561234',
          'TrackingUrl' => 'http://localhost/track/url',
        }] end

         it "should call ship operations and set tracking url" do
          order
        
          expect_any_instance_of(Spree::Shipment).to receive(:ship!)
          subject.update_shipments(response)
          expect(order.reload.shipments.last.newgistics_tracking_url).to eq(response.first['TrackingUrl'])
          expect(order.shipments.last.tracking).to eq(response.first['Tracking'])
        end

      end

  end

end