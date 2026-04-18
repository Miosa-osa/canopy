defmodule CanopyWeb.ErrorJSON do
  @moduledoc """
  This module is invoked by your endpoint in case of errors on JSON requests.

  See config/config.exs.
  """

  # If you want to customize a particular status code,
  # you may add your own clauses, such as:
  #
  # def render("500.json", _assigns) do
  #   %{errors: %{detail: "Internal Server Error"}}
  # end

  # 429 — emitted by CanopyWeb.Plugs.RateLimiter when the per-IP window is exceeded.
  # Retry-After is set as a response header by the plug; this body gives clients
  # a machine-readable error code alongside the human message.
  def render("429.json", _assigns) do
    %{error: "rate_limited", message: "Too many requests. Try again later."}
  end

  # By default, Phoenix returns the status message from
  # the template name. For example, "404.json" becomes
  # "Not Found".
  def render(template, _assigns) do
    %{errors: %{detail: Phoenix.Controller.status_message_from_template(template)}}
  end
end
