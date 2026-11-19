module Monitoring
  class TraceContext < ApplicationRecord
    self.table_name = "monitoring_trace_contexts"

    def self.capture!(rating_id: nil, domain_event_id: nil)
      traceparent = ActivityMonitoring.traceparent
      create!(rating_id:, domain_event_id:, traceparent:) if traceparent.present?
    end

    def self.parent_for_event(event_id)
      where(domain_event_id: event_id).pick(:traceparent) if ActivityMonitoring.operation_tracer
    end

    def self.links_for_ratings(rating_ids)
      return [] unless ActivityMonitoring.operation_tracer

      where(rating_id: rating_ids).distinct.pluck(:traceparent).filter_map { |parent| ActivityMonitoring.link(parent) }
    end
  end
end
