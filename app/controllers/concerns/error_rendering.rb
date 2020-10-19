module ErrorRendering
  class ErrorRenderer
    def initialize(target, source)
      @target = target
      @source = source
    end

    def now(*args)
      @source.send(:render_err_target, @target.now, *args)
    end
  end

  def render_err(chain = :chain, *args)
    if chain == :chain
      ErrorRenderer.new(flash, self)
    else
      render_err_target(flash, chain, *args)
    end
  end

  private

  def render_err_target(target, model, key, model_name: nil)
    model_name ||= model

    lists_errors = model.errors.present?
    msg = t_err(key, model: model_name, format: lists_errors ? :intro : :final)
    if lists_errors
      msg = {
        message: msg,
        array: model.errors.full_messages
      }
    end

    target[:error] = msg
  end
end
