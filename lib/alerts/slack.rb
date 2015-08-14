require 'slack-notifier'

module Alerts
  def self.slack_notify(msg)
    return false if ENV['SLACK_WEBHOOK_URL'].blank?
    notifier = Slack::Notifier.new ENV['SLACK_WEBHOOK_URL'],
                                   channel: ENV['SLACK_CHANNEL'],
                                   username: ENV['SLACK_USERNAME'] || "Spree Newgistics notifier"
    notifier.ping msg                                   
    true                              
  end
end