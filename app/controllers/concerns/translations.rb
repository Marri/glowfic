module Translations
  def t_sym_for(*args)
    args.map(&:to_s).join('.').to_sym
  end

  def t_notify(key, action: :notifications, model: nil, format: :final)
    model ||= associated_model
    model_name = if model.respond_to?(:model_name)
      model.model_name.human
    else
      model
    end

    str = t(
      t_sym_for(model_name.parameterize.underscore, action, :messages, key),
      model_name: model_name,
      scope: [:actioncontroller],
      default: t_sym_for(action, :messages, key),
    )

    # bound appropriately (e.g. "Error." vs "Error, because of the following problems:")
    t(
      format,
      str: str,
      scope: [:actioncontroller, action, :formats],
    )
  end

  def t_success(key, **kwargs)
    kwargs = { action: :success }.merge(kwargs)
    t_notify(key, **kwargs)
  end

  def t_err(key, **kwargs)
    kwargs = { action: :errors }.merge(kwargs)
    t_notify(key, **kwargs)
  end
end
