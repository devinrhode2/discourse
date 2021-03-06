require_dependency 'letter_avatar'

class UserAvatarsController < ApplicationController
  skip_before_filter :check_xhr, :verify_authenticity_token, only: :show

  def refresh_gravatar

    user = User.find_by(username_lower: params[:username].downcase)
    guardian.ensure_can_edit!(user)

    if user
      user.create_user_avatar(user_id: user.id) unless user.user_avatar
      user.user_avatar.update_gravatar!

      render json: {upload_id: user.user_avatar.gravatar_upload_id}
    else
      raise Discourse::NotFound
    end
  end


  def show
    username = params[:username].to_s
    raise Discourse::NotFound unless user = User.find_by(username_lower: username.downcase)

    size = params[:size].to_i
    if size > 1000 || size < 1
      raise Discourse::NotFound
    end

    image = nil
    version = params[:version].to_i

    raise Discourse::NotFound unless version > 0 && user_avatar = user.user_avatar

    upload = Upload.find(version) if user_avatar.contains_upload?(version)
    upload ||= user.uploaded_avatar if user.uploaded_avatar_id == version

    if user.uploaded_avatar && !upload
      return redirect_to "/avatar/#{user.username_lower}/#{size}/#{user.uploaded_avatar_id}.png"
    elsif upload
      original = Discourse.store.path_for(upload)
      if Discourse.store.external? || File.exists?(original)
        optimized = get_optimized_image(upload, size)

        if Discourse.store.external?
          expires_in 1.day, public: true
          return redirect_to optimized.url
        end

        image = Discourse.store.path_for(optimized)
      end
    end

    if image
      expires_in 1.year, public: true
      send_file image, disposition: nil
    else
      raise Discourse::NotFound
    end
  end

  protected

  def get_optimized_image(upload, size)
    OptimizedImage.create_for(
      upload,
      size,
      size,
      allow_animation: SiteSetting.allow_animated_avatars
    )
  end

end
