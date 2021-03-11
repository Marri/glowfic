class Authentication < Object
  EXPIRY = 30.days

  attr_reader :user, :error

  def authenticate(username, password)
    user = User.find_by(username: username)
    return false unless valid_user?(user)

    if user.password_resets.active.unused.exists?
      @error = "The password for this account has been reset. Please check your email."
      return false
    end

    unless user.authenticate(password)
      @error = "You have entered an incorrect password."
      return false
    end

    ensure_uuid_set(user, password)
    @user = user
  end

  def api_token
    Authentication.generate_api_token(@user)
  end

  def self.generate_api_token(user)
    payload = {
      user_id: user.id,
      exp: Authentication::EXPIRY.from_now.to_i
    }
    JWT.encode(payload, Rails.application.secrets.secret_key_api)
  end

  private

  def valid_user?(user)
    if !user || user.deleted?
      @error = "That username does not exist."
      return false
    end

    if user.suspended?
      @error = "You could not be logged in."
      notify_admins_of_blocked_login(user)
      return false
    end

    true
  end

  def notify_admins_of_blocked_login(user)
    raise NameError.new("Login attempt by suspended user #{user.id}")
  rescue NameError => e
    ExceptionNotifier.notify_exception(e)
  end

  def ensure_uuid_set(user, password)
    return if user.salt_uuid.present?

    user.salt_uuid = SecureRandom.uuid
    user.crypted = user.send(:crypted_password, password)
    user.save!
  end
end
