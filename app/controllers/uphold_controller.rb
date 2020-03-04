class UpholdController < ApplicationController
  def login
    # TODO: Make sure these params are safe
    uphold_card_id = params[:uphold_card_id]
    state = SecureRandom.hex(64).to_s
    Rails.cache.write(state, uphold_card_id, expires_in: 10.minutes)
    redirect_to Rails.application.secrets[:uphold_authorization_endpoint].
      gsub('<UPHOLD_CLIENT_ID>', Rails.application.secrets[:uphold_login_client_id]).
      gsub('<UPHOLD_SCOPE>', Rails.application.secrets[:uphold_scope]).
      gsub('<STATE>', state)
  end

  def confirm
    uphold_card_id = Rails.cache.fetch(params[:state])
    uphold_code = params[:code]
    if uphold_card_id.present?

      uphold_connection = UpholdConnection.find_by(card_id: uphold_card_id)
      # TODO: Store credentials and read from Uphold to see all the cards that the user owns and make sure they own the card
      parameters = UpholdRequestAccessParameters.new(uphold_code: uphold_code, secret_used: UpholdConnection::USE_BROWSER).perform
      # read cards and make sure there's a match
      uphold_connection = UpholdConnection.new(uphold_access_parameters: parameters)
      uphold_model_card = Uphold::Models::Card.new
      result = uphold_model_card.find(uphold_connection: uphold_connection, id: uphold_card_id)

      if result.present?
        uphold_user = signup_or_signin_user(uphold_card_id)
        uphold_connection.update(publisher_id: uphold_user.id)
        uphold_connection.sync_from_uphold!
        redirect_to browser_users_home_path
      end
    else
      flash[:alert] = "Sorry we weren't able to verify your credentials"
    end
  end

  private

  def signup_user(uphold_card_id)
    # TODO: If we require email, let's just put them through the normal funnel
    # TODO: Lock here
    uphold_connection = UpholdConnection.find_by(card_id: uphold_card_id)
    user = BrowserUserSignUpService.new(uphold_card_id: uphold_card_id).perform if uphold_connection.nil?
    sign_in(:publisher, user)
  end
end