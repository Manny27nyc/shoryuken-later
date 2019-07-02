# frozen_string_literal: true

require 'json'

module Shoryuken
  module Later
    class Poller
      include Shoryuken::Util

      attr_reader :table_name

      def initialize(table_name)
        @table_name = table_name
      end

      def poll
        started_at = Time.now

        puts "Polling for scheduled messages in '#{table_name}'"
        logger.debug { "Polling for scheduled messages in '#{table_name}'" }

        begin
          while item = next_item
            id = item['id']
            puts "Found item with id #{id}"

            logger.info "Found message #{id} from '#{table_name}'"
            if sent_msg = process_item(item)
              puts "Enqueued message #{id} from '#{table_name}'"
              logger.debug { "Enqueued message #{id} from '#{table_name}'" }
            else
              puts "Skipping already queued message #{id} from '#{table_name}'"
              logger.debug { "Skipping already queued message #{id} from '#{table_name}'" }
            end
          end

          puts "Poller for '#{table_name}' completed in #{elapsed(started_at)} ms"
          logger.debug { "Poller for '#{table_name}' completed in #{elapsed(started_at)} ms" }
        rescue StandardError => ex
          puts "Error fetching message: #{ex}"
          puts ex.backtrace.first

          logger.error "Error fetching message: #{ex}"
          logger.error ex.backtrace.first
        end
      end

      private

      def client
        Shoryuken::Later::Client
      end

      # Fetches the next available item from the schedule table.
      def next_item
        client.first_item table_name, 'perform_at' => {
          attribute_value_list: [(Time.now + Shoryuken::Later::MAX_QUEUE_DELAY).to_i],
          comparison_operator: 'LT'
        }
      end

      # Processes an item and enqueues it (unless another actor has already enqueued it).
      def process_item(item)
        time, worker_class, args, id = item.values_at('perform_at', 'shoryuken_class', 'shoryuken_args', 'id')

        worker_class = worker_class.constantize
        args = JSON.parse(args)
        time = Time.at(time)
        queue_name = item['shoryuken_queue']

        # Conditionally delete an item prior to enqueuing it, ensuring only one actor may enqueue it.
        begin client.delete_item table_name, item
        rescue Aws::DynamoDB::Errors::ConditionalCheckFailedException => e
          # Item was already deleted, so it does not need to be queued.
          puts "Aws::DynamoDB::Errors::ConditionalCheckFailedException #{e.message}"
          return
        end

        # Now the item is safe to be enqueued, since the conditional delete succeeded.
        body, options = args.values_at('body', 'options')
        if queue_name.nil?
          puts "worker_class.perform_in time = #{time}"
          worker_class.perform_in(time, body, options)

        # For compatibility with Shoryuken's ActiveJob adapter, support an explicit queue name.
        else
          delay = (time - Time.now).to_i
          body = JSON.dump(body) if body.is_a? Hash
          options[:delay_seconds] = delay if delay > 0
          options[:message_body] = body
          options[:message_attributes] ||= {}
          options[:message_attributes]['shoryuken_class'] = { string_value: worker_class.to_s, data_type: 'String' }

          puts "Shoryuken::Client.queues(#{queue_name}).send_message delay = #{delay}"
          Shoryuken::Client.queues(queue_name).send_message(options)
        end
      end
    end
  end
end
