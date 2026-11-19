module ActivityMonitoring
  def self.profile_refresh(&operation)
    return operation.call unless defined?(Appsignal) && Appsignal.active?

    # monitor reuses an active GoodJob transaction. Scope a fresh one to this
    # profile and restore the batch transaction even when the refresh fails.
    Appsignal::Transaction.with_transaction(nil) do
      Appsignal.monitor(namespace: "background_job", action: "Ratings::RefreshTasteProfile", &operation)
    end
  end

  def self.ignore_routine_activity
    Appsignal.set_namespace("routine_activity") if defined?(Appsignal) && Appsignal.active?
  end
end
