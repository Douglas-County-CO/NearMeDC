require 'app/services/channels'

module Citygram::Workers
  class Notifier
    include Sidekiq::Worker
    sidekiq_options retry: 5

    def perform(subscription_id, event_id)
      subscription = Subscription.active.first!(id: subscription_id)
      event = subscription.channel == 'email' ? nil : Event.first!(feature_id: event_id)
      Citygram::Services::Channels[subscription.channel].call(subscription, event)
    end
  end
end
