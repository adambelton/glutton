require Rails.root.join("lib/activity_monitoring")
ActivityMonitoring.configure
ActiveSupport::Notifications.subscribe(ActivityMonitoring::OPERATION_NOTIFICATION, ActivityMonitoring::OperationSubscriber.new)
