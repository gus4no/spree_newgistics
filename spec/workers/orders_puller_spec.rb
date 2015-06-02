require 'spec_helper'

describe Workers::OrdersPuller do
  describe "#update_shipments" do

    let(:order) { create :order_with_line_items, state: 'complete' }

    it "must enqueue product review email when status is SHIPPED" do
      expect(order).to receive(:send_product_review_email)
    end

  end
end
