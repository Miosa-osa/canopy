defmodule CanopyWeb.WebhookController do
  use CanopyWeb, :controller

  alias Canopy.Repo
  alias Canopy.Schemas.{Webhook, WebhookDelivery}
  import Ecto.Query

  def index(conn, params) do
    workspace_id = params["workspace_id"]

    query = from w in Webhook, order_by: [asc: w.name]
    query = if workspace_id, do: where(query, [w], w.workspace_id == ^workspace_id), else: query

    webhooks = Repo.all(query)
    json(conn, %{webhooks: Enum.map(webhooks, &serialize/1)})
  end

  def show(conn, %{"id" => id}) do
    case Repo.get(Webhook, id) do
      nil -> conn |> put_status(404) |> json(%{error: "not_found"})
      webhook -> json(conn, %{webhook: serialize(webhook)})
    end
  end

  def create(conn, params) do
    changeset = Webhook.changeset(%Webhook{}, params)

    case Repo.insert(changeset) do
      {:ok, webhook} ->
        Canopy.EventBus.broadcast(
          Canopy.EventBus.workspace_topic(webhook.workspace_id),
          %{event: "webhook.created", webhook_id: webhook.id, name: webhook.name}
        )

        conn |> put_status(201) |> json(%{webhook: serialize(webhook)})

      {:error, changeset} ->
        conn
        |> put_status(422)
        |> json(%{error: "validation_failed", details: format_errors(changeset)})
    end
  end

  def update(conn, %{"id" => id} = params) do
    case Repo.get(Webhook, id) do
      nil ->
        conn |> put_status(404) |> json(%{error: "not_found"})

      webhook ->
        changeset = Webhook.changeset(webhook, params)

        case Repo.update(changeset) do
          {:ok, updated} ->
            json(conn, %{webhook: serialize(updated)})

          {:error, changeset} ->
            conn
            |> put_status(422)
            |> json(%{error: "validation_failed", details: format_errors(changeset)})
        end
    end
  end

  def delete(conn, %{"id" => id}) do
    case Repo.get(Webhook, id) do
      nil ->
        conn |> put_status(404) |> json(%{error: "not_found"})

      webhook ->
        Repo.delete!(webhook)

        Canopy.EventBus.broadcast(
          Canopy.EventBus.workspace_topic(webhook.workspace_id),
          %{event: "webhook.deleted", webhook_id: id}
        )

        json(conn, %{ok: true})
    end
  end

  def test(conn, %{"webhook_id" => id}) do
    case Repo.get(Webhook, id) do
      nil ->
        conn |> put_status(404) |> json(%{error: "not_found"})

      webhook ->
        payload = %{
          event: "webhook.test",
          webhook_id: webhook.id,
          timestamp: DateTime.utc_now()
        }

        headers = build_headers(webhook, payload)

        result =
          Req.post(webhook.url,
            json: payload,
            headers: headers,
            receive_timeout: 10_000
          )

        {status_code, response_body, success} =
          case result do
            {:ok, %{status: code, body: body}} ->
              {code, inspect(body), code in 200..299}

            {:error, reason} ->
              {0, inspect(reason), false}
          end

        delivery =
          Repo.insert!(%WebhookDelivery{
            webhook_id: webhook.id,
            payload: payload,
            status_code: status_code,
            response: response_body
          })

        Repo.update_all(
          from(w in Webhook, where: w.id == ^id),
          set: [last_triggered_at: DateTime.utc_now()]
        )

        json(conn, %{
          ok: success,
          status_code: status_code,
          response: response_body,
          delivery_id: delivery.id
        })
    end
  end

  def deliveries(conn, %{"webhook_id" => id}) do
    limit = min(String.to_integer(conn.params["limit"] || "50"), 200)

    deliveries =
      Repo.all(
        from d in WebhookDelivery,
          where: d.webhook_id == ^id,
          order_by: [desc: d.inserted_at],
          limit: ^limit
      )

    json(conn, %{
      deliveries:
        Enum.map(deliveries, fn d ->
          %{
            id: d.id,
            status_code: d.status_code,
            payload: d.payload,
            response: d.response,
            inserted_at: d.inserted_at
          }
        end)
    })
  end

  def receive(conn, %{"webhook_id" => id} = params) do
    case Repo.get(Webhook, id) do
      nil ->
        conn |> put_status(404) |> json(%{error: "not_found"})

      webhook ->
        with :ok <- verify_secret(conn, webhook) do
          body = params

          delivery =
            Repo.insert!(%WebhookDelivery{
              webhook_id: webhook.id,
              payload: body,
              status_code: 200,
              response: "accepted"
            })

          Repo.update_all(
            from(w in Webhook, where: w.id == ^id),
            set: [last_triggered_at: DateTime.utc_now()]
          )

          Canopy.EventBus.broadcast(
            Canopy.EventBus.activity_topic(),
            %{
              event: "webhook.received",
              webhook_id: webhook.id,
              webhook_name: webhook.name,
              delivery_id: delivery.id
            }
          )

          json(conn, %{ok: true, delivery_id: delivery.id})
        else
          {:error, :invalid_secret} ->
            conn |> put_status(401) |> json(%{error: "invalid_signature"})
        end
    end
  end

  # --- Private helpers ---

  defp verify_secret(_conn, %Webhook{secret: nil}) do
    require Logger
    Logger.warning("Accepting unsigned webhook delivery — no secret configured")
    :ok
  end

  defp verify_secret(conn, %Webhook{secret: secret}) do
    signature = get_req_header(conn, "x-canopy-signature") |> List.first()

    expected =
      "sha256=" <>
        Base.encode16(:crypto.mac(:hmac, :sha256, secret, conn.assigns[:raw_body] || ""),
          case: :lower
        )

    if Plug.Crypto.secure_compare(signature || "", expected) do
      :ok
    else
      {:error, :invalid_secret}
    end
  end

  defp build_headers(%Webhook{secret: nil}, _payload), do: []

  defp build_headers(%Webhook{secret: secret}, payload) do
    body = Jason.encode!(payload)
    sig = "sha256=" <> Base.encode16(:crypto.mac(:hmac, :sha256, secret, body), case: :lower)
    [{"x-canopy-signature", sig}, {"content-type", "application/json"}]
  end

  defp serialize(%Webhook{} = w) do
    %{
      id: w.id,
      name: w.name,
      webhook_type: w.webhook_type,
      url: w.url,
      events: w.events,
      enabled: w.enabled,
      last_triggered_at: w.last_triggered_at,
      workspace_id: w.workspace_id,
      inserted_at: w.inserted_at,
      updated_at: w.updated_at
    }
  end

  defp format_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end
