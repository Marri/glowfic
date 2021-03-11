require 'resque/errors'
class ApplicationJob < ActiveJob::Base
  around_perform :retry_on_term
  around_perform :notify_exception # rescue_from doesn't catch Exceptions in jobs

  def retry_on_term
    yield
  rescue Resque::TermException, Resque::DirtyExit
    Rails.logger.error("Performing #{self.class} was terminated. Retrying...")
    retry_job
  end

  def notify_exception
    yield
  rescue Exception => e # rubocop:disable Lint/RescueException
    self.class.notify_exception(e, *arguments)
    raise e
  end

  def self.notify_exception(exception, *args)
    Rails.logger.error("Received #{exception}, job #{self.name} failed with #{args}")
    ExceptionNotifier.notify_exception(exception, data: {job: self.name, args: args})
  end
end
