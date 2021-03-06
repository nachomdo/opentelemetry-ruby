# frozen_string_literal: true

# Copyright 2019 OpenTelemetry Authors
#
# SPDX-License-Identifier: Apache-2.0

module OpenTelemetry
  module Trace
    # No-op implementation of Tracer.
    class Tracer
      # This is a helper for the default use-case of extending the current trace with a span.
      #
      # With this helper:
      #
      #   OpenTelemetry.tracer.in_span('do-the-thing') do ... end
      #
      # Equivalent without helper:
      #
      #   OpenTelemetry::Trace.with_span(tracer.start_span('do-the-thing')) do ... end
      #
      # On exit, the Span that was active before calling this method will be reactivated. If an
      # exception occurs during the execution of the provided block, it will be recorded on the
      # span and reraised.
      # @yield [span, context] yields the newly created span and a context containing the
      #   span to the block.
      def in_span(name, attributes: nil, links: nil, start_timestamp: nil, kind: nil, with_parent: nil)
        span = nil
        span = start_span(name, attributes: attributes, links: links, start_timestamp: start_timestamp, kind: kind, with_parent: with_parent)
        Trace.with_span(span) { |s, c| yield s, c }
      rescue Exception => e # rubocop:disable Lint/RescueException
        span&.record_exception(e)
        span&.status = Status.new(Status::ERROR,
                                  description: "Unhandled exception of type: #{e.class}")
        raise e
      ensure
        span&.finish
      end

      def start_root_span(name, attributes: nil, links: nil, start_timestamp: nil, kind: nil)
        Span.new
      end

      # Used when a caller wants to manage the activation/deactivation and lifecycle of
      # the Span and its parent manually.
      #
      # Parent context can be either passed explicitly, or inferred from currently activated span.
      #
      # @param [optional Context] with_parent Explicitly managed parent context
      #
      # @return [Span]
      def start_span(name, with_parent: nil, attributes: nil, links: nil, start_timestamp: nil, kind: nil)
        span_context = OpenTelemetry::Trace.current_span(with_parent).context

        if span_context.valid?
          Span.new(span_context: span_context)
        else
          Span.new
        end
      end
    end
  end
end
