class AsyncBase
  include Sidekiq::Worker

  def perform args = {}
    Rails.logger.info("starting job #{self.class.name}, args [#{args}]")
    args = HashWithIndifferentAccess.new args
    self.perform args
    Rails.logger.info("finished job #{self.class.name}, args [#{args}]")
  rescue Exception => e
    Rails.logger.error("error executing job #{self.class.name} args [#{args}]: #{e}")
    raise e
  end

  def update_success?(response)
    response.status <= 299 && !really_a_newgistics_error?(response)
  end

  def really_a_newgistics_error?(response)
    not_really_errors = [
        'This shipment has already been canceled.',
        'This shipment has already been returned.'
    ]
    error = parse_errors(response)
    success = Nokogiri::XML(response.body).xpath('//success').text == 'true'
    !success && error.present? && !not_really_errors.include?(error)
  end

  def parse_errors(response)
    Nokogiri::XML(response.body).xpath('//error').text
  end


  def should_update_newgistics_state?(order, state_change)
    (state_change.name == 'payment' || state_change.name == 'order') && state_change.next_state != 'awaiting_return' && order.posted_to_newgistics?
  end

  def can_update_newgistics_state?(order, state_change)
    states = ['canceled', 'returned']
    order.can_update_newgistics? && !states.include?(state_change.newgistics_status.downcase)
  end
end
