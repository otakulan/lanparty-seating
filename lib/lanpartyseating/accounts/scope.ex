defmodule Lanpartyseating.Accounts.Scope do
  @moduledoc """
  Defines the scope of the caller to be used throughout the app.

  The `Lanpartyseating.Accounts.Scope` allows public interfaces to receive
  information about the caller, such as if the call is initiated from an
  end-user, and if so, which user. Additionally, such a scope can carry fields
  such as "super user" or other privileges for use as authorization, or to
  ensure specific code paths can only be access for a given scope.

  It is useful for logging as well as for scoping pubsub subscriptions and
  broadcasts when a caller subscribes to an interface or performs a particular
  action.

  ## Auth Types

  - `:user` - Full user authentication (email/password). Has all permissions.
  - `:badge` - Badge authentication (emergency backdoor). Limited permissions:
    cannot manage users or badges.
  """

  alias Lanpartyseating.Accounts.User
  alias Lanpartyseating.Accounts.AdminBadge

  defstruct user: nil, auth_type: nil, badge: nil

  @doc """
  Creates a scope for the given user (email/password auth).

  Returns nil if no user is given.
  """
  def for_user(%User{} = user) do
    %__MODULE__{user: user, auth_type: :user}
  end

  def for_user(nil), do: nil

  @doc """
  Creates a scope for badge authentication (emergency backdoor).
  Creates a virtual user-like struct for compatibility with existing code.
  """
  def for_badge(%AdminBadge{} = badge) do
    # Create a virtual user with badge info for display purposes
    virtual_user = %User{
      id: -badge.id,
      email: badge.label,
    }

    %__MODULE__{user: virtual_user, auth_type: :badge, badge: badge}
  end

  @doc """
  Returns true if the scope has full user permissions (not badge auth).
  """
  def user_auth?(%__MODULE__{auth_type: :user}), do: true
  def user_auth?(_), do: false

  @doc """
  Returns true if the scope is from badge authentication.
  """
  def badge_auth?(%__MODULE__{auth_type: :badge}), do: true
  def badge_auth?(_), do: false
end
