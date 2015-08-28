Spree::StateChange.class_eval do



  def newgistics_status
    #Change only between UPDATED and ONHOLD, which seems to be the only relevant statuses
    #for shipments updates via api, every other status code change belong to newgisitcs.
    { paid: 'UPDATED',
      balance_due: 'ONHOLD',
      failed: 'ONHOLD',
      canceled: 'CANCELED',
      shipped: 'SHIPPED'}[next_state.to_sym] || ''
  end

  def newgistics_status_notes
    #status notes are only required by newgitics for transitions from any to ONHOLD and canceled
    { balance_due: 'Payment pending',
      failed: 'Failed payment',
      canceled: 'Order canceled by admin'}[next_state.to_sym] || ''
  end
end
