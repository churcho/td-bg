defmodule TdBgWeb.ApiServices.HttpTdDdService do
  @moduledoc false

  require Logger
  alias Poison, as: JSON

  defp get_api_user_token do
    api_config = Application.get_env(:td_bg, :api_services_login)
    user_credentials = %{user_name: api_config[:api_username], password: api_config[:api_password]}
    body = %{user: user_credentials} |> JSON.encode!
    %HTTPoison.Response{status_code: _status_code, body: resp} =
      HTTPoison.post!(get_sessions_path(), body, ["Content-Type": "application/json", "Accept": "Application/json; Charset=utf-8"], [])
    resp = resp |> JSON.decode!
    resp["token"]
  end

  defp get_auth_endpoint do
    auth_service_config = get_auth_config()
    "#{auth_service_config[:protocol]}://#{auth_service_config[:auth_host]}:#{auth_service_config[:auth_port]}"
  end

  defp get_sessions_path do
    auth_service_config = get_auth_config()
    "#{get_auth_endpoint()}#{auth_service_config[:sessions_path]}"
  end

  defp get_auth_config do
    Application.get_env(:td_bg, :auth_service)
  end

  def get_data_structures(%{} = params) do
    token = get_api_user_token()
    headers = ["Authorization": "Bearer #{token}", "Content-Type": "application/json", "Accept": "Application/json; Charset=utf-8"]
    #TODO: The view launching this function should be paginated in order to erase the time_out from the options
    case HTTPoison.get(get_data_structures_path(), headers, params: params,
      options: [timeout: 50_000, recv_timeout: 50_000]) do
        {:ok, %HTTPoison.Response{body: resp, status_code: 200}} ->
          resp |> JSON.decode! |> Map.get("data")
        error ->
          Logger.error "While getting data structures... #{error}"
          []
    end
  end

  def get_data_fields(%{data_structure_id: data_structure_id}) do
    token = get_api_user_token()
    headers = ["Authorization": "Bearer #{token}", "Content-Type": "application/json", "Accept": "Application/json; Charset=utf-8"]

    case HTTPoison.get("#{get_data_structures_path()}/#{data_structure_id}", headers) do
      {:ok, %HTTPoison.Response{body: resp, status_code: 200}} ->
        resp |> JSON.decode! |> Map.get("data")
      error ->
        Logger.error "While getting data fields... #{error}"
        []
    end
  end

  defp get_config do
    Application.get_env(:td_bg, :dd_service)
  end

  defp get_dd_endpoint do
    dd_service_config = get_config()
    "#{dd_service_config[:protocol]}://#{dd_service_config[:dd_host]}:#{dd_service_config[:dd_port]}"
  end

  defp get_data_structures_path do
    dd_service_config = get_config()
    "#{get_dd_endpoint()}#{dd_service_config[:data_structures_path]}"
  end

end
