require 'slack-notifier'

module Alerts
  def self.slack_notify(msg, opts = {})
    if ENV['SLACK_WEBHOOK_URL'].blank?
      Rails.logger.error("Can't send slack notification, please check settings")
      return false 
    end
    
    notifier = Slack::Notifier.new ENV['SLACK_WEBHOOK_URL']

    params = {channel: ENV['SLACK_CHANNEL'],
                                   username: ENV['SLACK_USERNAME'] }
    params.merge! opts
    params[:username] ||= "Spree newgistics"
                                   
    notifier.ping msg, params
    true                              
  end
end