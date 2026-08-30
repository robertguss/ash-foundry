defmodule AshFoundry.Template do
  @moduledoc false

  alias AshFoundry.Plan

  @spec render(Path.t(), Plan.t()) :: String.t()
  def render(path, plan) do
    path
    |> File.read!()
    |> conditional("PASSWORD", :password in plan.auth)
    |> conditional("MAGIC_LINK", :magic_link in plan.auth)
    |> conditional("GOOGLE", :google in plan.auth)
    |> conditional("EMAIL_AUTH", Enum.any?(plan.auth, &(&1 in [:password, :magic_link])))
    |> conditional("AUTH", plan.auth != [])
    |> conditional("NO_AUTH", plan.auth == [])
    |> conditional("OPEN_REGISTRATION", plan.registration == :open)
    |> conditional("INVITE_ONLY", plan.registration == :invite_only)
    |> conditional("CLOSED_REGISTRATION", plan.registration == :closed)
    |> conditional("REGISTRATION_ENABLED", plan.registration != :closed)
    |> conditional("TENANCY", plan.tenancy == :organizations)
    |> conditional("NO_TENANCY", plan.tenancy == :none)
    |> conditional("OPEN_ORG_CREATE", plan.organization_creation == :open)
    |> conditional("ADMIN_ORG_CREATE", plan.organization_creation == :system_admin)
    |> conditional("HOSTED_DOMAIN", plan.google_hosted_domain)
    |> conditional("NOT_HOSTED_DOMAIN", not plan.google_hosted_domain)
    |> replace("__APP__", plan.app)
    |> replace("__MODULE_TITLE__", plan.module)
    |> replace("__MODULE__", plan.module)
    |> replace("__WEB_MODULE__", plan.module <> "Web")
    |> replace("__RECIPE__", Atom.to_string(plan.recipe))
    |> replace("__AUTH_METHODS__", Enum.map_join(plan.auth, ",", &Atom.to_string/1))
    |> replace("__REGISTRATION__", Atom.to_string(plan.registration))
    |> replace("__TENANCY__", Atom.to_string(plan.tenancy))
    |> replace("__DEPLOY__", Atom.to_string(plan.deploy))
    |> replace("__SESSION_ABSOLUTE_MINUTES__", Integer.to_string(plan.session_absolute_minutes))
    |> replace("__SESSION_IDLE_MINUTES__", Integer.to_string(plan.session_idle_minutes))
    |> replace("__GOOGLE_HOSTED_DOMAIN__", inspect(plan.google_hosted_domain))
    |> replace("__REGISTRATION_ENABLED__", inspect(plan.registration != :closed))
    |> replace(
      "__REGISTER_PATH__",
      inspect(if(plan.registration == :closed, do: nil, else: "/register"))
    )
    |> replace("__RESET_PATH__", inspect(if(:password in plan.auth, do: "/reset", else: nil)))
  end

  defp conditional(contents, name, keep?) do
    pattern = ~r/__IF_#{name}__\n?(.*?)__END_#{name}__\n?/s
    Regex.replace(pattern, contents, fn _whole, body -> if keep?, do: body, else: "" end)
  end

  defp replace(contents, pattern, replacement), do: String.replace(contents, pattern, replacement)
end
