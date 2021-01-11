defmodule SwPilots do
  @moduledoc """
  Program to fetch list of Star Wars ships with pilots and writte results to starships-response.txt file
  To run ```mix run lib/sw_pilots.ex```
  """

  def run do
    HTTPoison.start()

    Enum.into(stream_api(), [])
  end

  def stream_api do
    Stream.resource(
      fn -> start_fun() end,
      fn state -> next_fun(state) end,
      fn state -> end_fun(state) end
    )
  end

  def start_fun do
    {:ok, file} = File.open("starships-response.txt", [:write])

    "https://swapi.dev/api/starships/"
    |> fetch_page()
    |> case do
      {:ok, %{"results" => results, "next" => next_page}} -> {results, next_page, file}
      _error -> {[], nil}
    end
  end

  defp next_fun({[], nil, _} = state), do: {:halt, state}

  defp next_fun({[], _, _} = state), do: fetch_next_page(state)

  defp next_fun(state), do: pop_item(state)

  defp end_fun({_, _, file}), do: File.close(file)

  defp fetch_next_page({[], next_page, file} = state) do
    next_page
    |> insure_https_url()
    |> fetch_page()
    |> case do
      {:ok, %{"results" => results, "next" => next_page}} -> pop_item({results, next_page, file})
      {:error, _msg} -> {:halt, state}
    end
  end

  defp pop_item({[head | tail], next_page, file}) do
    %{"pilots" => pilots} = head

    starship = Map.put(head, "pilots", fetch_pilots(pilots))

    IO.write(file, Poison.encode!(starship))
    IO.write(file, "\n")

    {[starship], {tail, next_page, file}}
  end

  defp fetch_pilots(nil), do: []

  defp fetch_pilots(pilots) do
    Enum.map(pilots, fn page_url ->
      page_url
      |> insure_https_url()
      |> fetch_page()
      |> case do
        {:ok, pilot} -> pilot
        {:error, msg} -> {:error, msg}
      end
    end)
  end

  defp fetch_page(page) do
    %{body: body} = HTTPoison.get!(page) |> IO.inspect()
    Poison.decode(body)
  end

  defp insure_https_url(<<"http:", rest_url::binary>>) do
    "https:" <> rest_url
  end

  defp insure_https_url(url), do: url
end

SwPilots.run()
