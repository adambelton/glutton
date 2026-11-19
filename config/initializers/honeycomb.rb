require Rails.root.join("lib/activity_monitoring")
ActivityMonitoring.configure
ActiveSupport::Notifications.subscribe(ActivityMonitoring::BUSINESS_OPERATION, ActivityMonitoring::BusinessOperationSubscriber.new)
