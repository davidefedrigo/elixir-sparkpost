defmodule Sparkpost.Endpoint do
  @moduledoc """
  Base client for the SparkPost API, able to make requests and interpret responses.
  This module underpins the Sparkpost.* modules.
  """

  defmodule Response do
    defstruct status_code: nil, results: nil
  end

  defmodule Error do
    defstruct status_code: nil, errors: nil, results: nil
  end

  @doc """
  Make a request to the SparkPost API.

  ## Parameters
    - method: HTTP request method as atom (:get, :post, ...)
    - endpoint: SparkPost API endpoint as string ("transmissions", "templates", ...)
    - options: keyword of optional elements including:
      - :params: keyword of query parameters
      - :body: request body (string)

  ## Example
    List transmissions for the "ElixirRox" campaign:
        Sparkpost.Endpoint.request(:get, "transmissions", [campaign_id: "ElixirRox"])
        #=> %Sparkpost.Endpoint.Response{results: [%{"campaign_id" => "",
          "content" => %{"template_id" => "inline"}, "description" => "",
          "id" => "102258558346809186", "name" => "102258558346809186",
          "state" => "Success"}, ...], status_code: 200}
  """
  def request(method, endpoint, options) do
    url = if Keyword.has_key?(options, :params) do
      Application.get_env(:sparkpost, :api_endpoint) <> endpoint
        <> "?" <> URI.encode_query(options[:params])
    else
      Application.get_env(:sparkpost, :api_endpoint) <> endpoint
    end

    reqopts = if method in [:get, :delete] do
      [ headers: base_request_headers() ]
    else
      [
        headers: ["Content-Type": "application/json"] ++ base_request_headers(),
        body: encode_request_body(options[:body])
      ]
    end

    %{status_code: status_code, body: json} = HTTPotion.request(method, url, reqopts)

    body = decode_response_body(json)

    if Map.has_key?(body, :errors) do
      %Sparkpost.Endpoint.Error{ status_code: status_code, errors: body.errors }
    else
      %Sparkpost.Endpoint.Response{ status_code: status_code, results: body.results }
    end
  end

  def marshal_response(response, struct_type, subkey\\nil)

  @doc """
  Extract a meaningful structure from a generic endpoint response:
  response.results[subkey] as struct_type
  """
  def marshal_response(%Sparkpost.Endpoint.Response{} = response, struct_type, subkey) do
    if subkey do
      struct(struct_type, response.results[subkey])
    else
      struct(struct_type, response.results)
    end
  end

  def marshal_response(%Sparkpost.Endpoint.Error{} = response, _struct_type, _subkey) do
    response
  end

  defp base_request_headers() do
    [
      "User-Agent": "elixir-sparkpost/" <> Sparkpost.Mixfile.project()[:version],
      "Authorization": Application.get_env(:sparkpost, :api_key)
    ]
  end

  defp encode_request_body(body) do
    {:ok, req} = body |> Poison.encode
    req
  end

  defp decode_response_body(body) do
    # TODO: [key: :atoms] is unsafe for open-ended structures such as
    # metadata and substitution_data
    IO.puts body
    {:ok, resp} = body |> Poison.decode([keys: :atoms])
    resp
  end
end