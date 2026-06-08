defmodule ExhsWeb.AuthOverrides do
  @moduledoc false
  use AshAuthentication.Phoenix.Overrides

  alias AshAuthentication.Phoenix.{
    Components,
    ConfirmLive,
    MagicSignInLive,
    ResetLive,
    SignInLive,
    SignOutLive
  }

  @page_root "bg-base-200 grid min-h-screen place-items-center px-4 py-12"

  @card_root """
  glass-surface mx-auto w-full max-w-md rounded-2xl p-8 sm:p-10
  """

  @heading "text-2xl font-bold tracking-tight text-base-content"

  override SignInLive do
    set :root_class, @page_root
  end

  override SignOutLive do
    set :root_class, @page_root
  end

  override ConfirmLive do
    set :root_class, @page_root
  end

  override ResetLive do
    set :root_class, @page_root
  end

  override MagicSignInLive do
    set :root_class, @page_root
  end

  override Components.Banner do
    set :image_url, nil
    set :dark_image_url, nil
    set :href_url, "/"
    set :href_class, "flex items-center justify-center gap-2.5"

    set :text,
        {:safe,
         """
         <div class="from-primary text-primary-content to-secondary flex size-10 items-center justify-center rounded-xl bg-linear-to-br text-base font-bold">E</div>
         <span class="text-base-content text-xl font-semibold tracking-tight">Exhs</span>
         """}

    set :text_class, nil
    set :root_class, "flex justify-center py-2 mb-4"
  end

  override Components.SignIn do
    set :root_class, @card_root
    set :strategy_class, nil
    set :authentication_error_container_class, "alert alert-error mt-4 text-sm"
    set :authentication_error_text_class, nil
    set :strategy_display_order, :forms_first
  end

  override Components.Password do
    set :root_class, "mt-4 mb-2"
    set :interstitial_class, "flex flex-row flex-wrap justify-between gap-2 text-sm font-medium"
    set :toggler_class, "text-primary hover:text-primary/80 transition"
    set :sign_in_toggle_text, "Already have an account?"
    set :register_toggle_text, "Don't have an account?"
    set :reset_toggle_text, "Forgot your password?"
    set :show_first, :sign_in
    set :hide_class, "hidden"
  end

  override Components.Password.SignInForm do
    set :root_class, nil
    set :label_class, @heading
    set :form_class, nil
    set :slot_class, "my-4"
    set :button_text, "Sign in"
    set :disable_button_text, "Signing in ..."
  end

  override Components.Password.RegisterForm do
    set :root_class, nil
    set :label_class, @heading
    set :form_class, nil
    set :slot_class, "my-4"
    set :button_text, "Create account"
    set :disable_button_text, "Creating account ..."
  end

  override Components.Password.ResetForm do
    set :root_class, nil
    set :label_class, @heading
    set :form_class, nil
    set :slot_class, "my-4"
    set :button_text, "Reset password"
    set :disable_button_text, "Sending ..."

    set :reset_flash_text,
        "If this user exists in our system, you will receive an email with instructions to reset your password."
  end

  override Components.Password.Input do
    set :field_class, "mt-3 mb-2"
    set :label_class, "block text-sm font-medium text-base-content/70 mb-1.5"

    @base_input "input w-full"

    set :input_class, @base_input
    set :input_class_with_error, @base_input <> " input-error"
    set :submit_class, "btn btn-primary btn-block mt-6 mb-2"
    set :identity_input_label, "Email"
    set :password_input_label, "Password"
    set :password_confirmation_input_label, "Confirm password"
    set :error_ul, "text-error text-sm mt-1"
    set :error_li, nil
    set :input_debounce, 350
    set :remember_me_class, "flex items-center gap-2 mt-4"
    set :remember_me_input_label, "Remember me"
    set :checkbox_class, "checkbox checkbox-sm checkbox-primary"
    set :checkbox_label_class, "text-sm text-base-content/70"
  end

  override Components.HorizontalRule do
    set :root_class, "divider my-4 text-base-content/30"
    set :hr_outer_class, "hidden"
    set :hr_inner_class, "hidden"
    set :text_outer_class, "contents"
    set :text_inner_class, "contents"
    set :text, "or"
  end

  override Components.MagicLink do
    set :root_class, "mt-4 mb-2"
    set :label_class, @heading
    set :form_class, nil
    set :disable_button_text, "Sending ..."

    set :request_flash_text,
        "If this user exists in our system, you will receive a link to sign in."
  end

  override Components.MagicLink.Input do
    set :submit_class, "btn btn-primary btn-block mt-6 mb-2"
    set :submit_label, "Send login link"
    set :input_debounce, 350
    set :remember_me_class, "flex items-center gap-2 mt-4"
    set :remember_me_input_label, "Remember me"
    set :checkbox_class, "checkbox checkbox-sm checkbox-primary"
    set :checkbox_label_class, "text-sm text-base-content/70"
  end

  override Components.SignOut do
    set :root_class, @card_root
    set :h2_class, @heading <> " mb-2"
    set :h2_text, "Sign out"
    set :info_text, "Are you sure you want to sign out?"
    set :info_text_class, "text-sm text-base-content/60 mb-6"
    set :form_class, nil
    set :button_text, "Sign out"
    set :button_class, "btn btn-primary btn-block"
  end

  override Components.Confirm do
    set :root_class, @card_root
    set :strategy_class, nil
  end

  override Components.Confirm.Input do
    set :submit_class, "btn btn-primary btn-block mt-6 mb-2"
  end

  override Components.Reset do
    set :root_class, @card_root
    set :strategy_class, nil
  end

  override Components.Reset.Form do
    set :root_class, nil
    set :label_class, @heading
    set :form_class, nil
    set :spacer_class, "py-1"
    set :button_text, "Change password"
    set :disable_button_text, "Changing password ..."
  end

  override Components.OAuth2 do
    set :root_class, "w-full mt-2 mb-2"
    set :link_class, "btn btn-outline btn-block"
    set :icon_class, "-ml-0.5 mr-2 h-4 w-4"
  end

  override Components.Flash do
    set :message_class_info, """
    fixed top-4 right-4 z-50 w-80 sm:w-96 rounded-xl p-4 text-sm shadow-lg
    bg-success/10 text-success border border-success/20
    """

    set :message_class_error, """
    fixed top-4 right-4 z-50 w-80 sm:w-96 rounded-xl p-4 text-sm shadow-lg
    bg-error/10 text-error border border-error/20
    """
  end
end
