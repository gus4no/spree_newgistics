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
      context "when there is only one order in response" do
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

      context "when there are several orders in response" do
        let(:order_one) { create :order, newgistics_status: 'UPDATED', state: 'complete' }
        let(:broken_order) { create :order, newgistics_status: 'UPDATED', state: 'delivery' }
        let(:order_two) { create :order, newgistics_status: 'UPDATED', state: 'complete' }
        let(:response) do [{
          'OrderID' => order_one.number,
          'FirstName' => 'John',
          'LastName' => 'Smith',
          'Address1' => 'Somewhere in US',
          'City' => 'Anycity',
          'State' => 'CA',
          'PostalCode' => '12345',
          'Country' => 'UNITED STATES',
          'Phone' => '9871231233',
          'ShipmentStatus' => 'SHIPPED'
        }, {
          'OrderID' => broken_order.number,
          'FirstName' => 'John',
          'LastName' => 'Smith',
          'Address1' => 'Somewhere in US',
          'City' => 'Anycity',
          'State' => 'CA',
          'PostalCode' => '12345',
          'Country' => 'UNITED STATES',
          'Phone' => '9871231233',
          'ShipmentStatus' => 'CANCELED'
        }, {
          'OrderID' => order_two.number,
          'FirstName' => 'John',
          'LastName' => 'Smith',
          'Address1' => 'Somewhere in US',
          'City' => 'Anycity',
          'State' => 'CA',
          'PostalCode' => '12345',
          'Country' => 'UNITED STATES',
          'Phone' => '9871231233',
          'ShipmentStatus' => 'SHIPPED'
        }] end

        it "should update first order" do
          Spree::Order.any_instance.stub(:send_product_review_email)

          expect { subject.update_shipments(response) }.not_to raise_error

          order_one.reload

          expect(order_one.newgistics_status).to eq('SHIPPED')
          order_one.shipments.each do |s|
            expect(s.status).to be(:shipped)
          end
        end

        it "should update second order" do
          Spree::Order.any_instance.stub(:send_product_review_email)

          expect { subject.update_shipments(response) }.not_to raise_error

          order_two.reload

          expect(order_two.newgistics_status).to eq('SHIPPED')
          order_two.shipments.each do |s|
            expect(s.status).to be(:shipped)
          end
        end
      end

      context "to get the team notified" do
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

          expect(subject).to receive(:create_csv_file)
          subject.update_shipments(response)
        end
      end

    end

    context "when no exception occurs" do
      let(:order) { create :order, newgistics_status: 'UPDATED', state: 'complete' }
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
        'ShipmentStatus' => 'SHIPPED'
      }] end

      it "should not throw an exception" do
        Spree::Order.any_instance.stub(:send_product_review_email)

        expect(subject).not_to receive(:create_csv_file)
        subject.update_shipments(response)
      end
    end

  end

  describe "#create_csv_file" do
    let(:jid) { 1 }

    it "should open csv file" do
      file = "#{Rails.root}/tmp/#{jid}_orders_puller.csv"
      expect(CSV).to receive(:open).with(file, "wb")
      subject.create_csv_file(jid, [])
    end
  end

  describe "#send_csv_file" do
    it "should call mailer to send file" do
      expect(NewgisticsSyncMailer).to receive(:order_puller_report)
      subject.send_csv_file("file.csv", "/tmp/file.csv")
    end
  end

end
