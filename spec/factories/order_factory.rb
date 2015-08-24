require 'spree/testing_support/factories'

FactoryGirl.define do

  factory :order_ready_to_be_completed, parent: :order do
    bill_address
    ship_address
    state 'cart'

    transient do
      line_items_count 1
    end

    after(:create) do |order, evaluator|
      variant = create :variant
      variant.stock_items.first.set_count_on_hand evaluator.line_items_count

      create_list(:line_item, evaluator.line_items_count, order: order, variant: variant)
      order.line_items.reload

      create(:shipment, order: order)
      order.shipments.reload

      order.refresh_shipment_rates
      create(:payment, amount: order.total, order: order)

      order.update!

      variant.stock_items.delete(variant.stock_items.last)
      variant.stock_items.reload
    end


  end
end
