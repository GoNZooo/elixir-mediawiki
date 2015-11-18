defmodule Mediawiki do
  @moduledoc"""
  Module for interfacing with select parts of the Mediawiki API
  (with wikipedia as endpoint)

  All functions return tuples of {:ok, data} or {<errorcode>, <explanation>}
  """
  use HTTPoison.Base

  @expected_fields ~w(
  query
  )

  def process_url(url) do
    "https://en.wikipedia.org/w/api.php?format=json&action=query" <> url
  end

  def process_response_body(body) do
    body
     |> Poison.decode!
     |> Dict.take(@expected_fields)
     |> Enum.map( fn({k,v}) -> {String.to_atom(k), v} end)
  end

  defp search_urlencode(term) do
    search_url = "&list=search&srprop=&srinfo=&srsearch="
    search_url <> URI.encode_www_form(term)
  end

  @doc """
  Returns a normalized and corrected title for a given term.
  
  Returns {:no_title_found, "no title_found"} if none can be found.

  ## Examples
      iex> Mediawiki.search("robert downey jr")
      {:ok, "Robert Downey, Jr."}

      iex> Mediawiki.search("baba ganoosh")
      {:ok, "Baba ghanoush"}

      iex> Mediawiki.search("babanananana")
      {:no_title_found, "no title found"}
  """
  def search(term) do
    query = get!(search_urlencode(term)).body[:query]
     case query do
       %{"search" => []} -> {:no_title_found, "no title found"}
       _ ->
         {:ok, query |> Map.get("search")
                     |> List.first
                     |> Map.get("title")}
     end
  end

  defp article_urlencode(title) do
    article_url = "&prop=revisions&rvprop=content&titles="
    article_url <> URI.encode_www_form(title)
  end

  def article(title) do
    case search(title) do
      {:ok, normalized_title} ->
        get!(article_urlencode(normalized_title)).body[:query]
      {other_code, explanation} ->
        {other_code, explanation}
    end
  end

  defp extract_urlencode(title) do
    extract_url1 = "&prop=extracts&exsectionformat=plain&exsentences=4"
    extract_url2 = "&exintro=&explaintext=&titles="
    extract_url1 <> extract_url2 <> URI.encode_www_form(title)
  end

  defp extract_extract(query) do
    case query do
      %{"pages" => pagedata} ->
        data = pagedata |> Map.values |> List.first
        {:ok, Map.get(data, "extract")}
      _ ->
        {:no_extract_found, "title and extract not found"}
    end
  end

  @doc"""
  Returns an extract from the given titles page.
  
  Normalizes title automatically by using search() internally,
  or gives errorcode if term doesn't exist.
  """
  def extract(title) do
    case search(title) do
      {:ok, normalized_title} ->
        get!(extract_urlencode(normalized_title)).body[:query]
        |> extract_extract
      {other_code, explanation} ->
        {other_code, explanation}
    end
  end

  defp images_urlencode(title) do
    images_url = "&prop=pageimages&piprop=name|original|thumbnail&titles="
    images_url <> URI.encode_www_form(title)
  end

  defp extract_source_and_original(query) do
    case query do
      %{"pages" => pagedata} ->
        data = Map.values(pagedata) |> List.first
        case data do
          %{"thumbnail" => %{"source" => source, "original" => original}} ->
            {:ok, {source, original}}
          %{"thumbnail" => %{"source" => source}} ->
            {:ok, {source, :not_available}}
          %{"thumbnail" => %{"original" => original}} ->
            {:ok, {:not_available, original}}
          _ ->
            {:no_images, {:not_available, :not_available}}
        end
    end
  end

  @doc"""
  Returns main images from an article.
  
  Will return {:ok, {<source-image>, <original>}} if both are present
  but will substitute either one with :not_available if one of them isn't
  available in the API.

  If neither one is available, will return {:no_images, {...}}.
  """
  def images(title) do
    case search(title) do
      {:ok, normalized_title} ->
        get!(images_urlencode(normalized_title)).body[:query]
        |> extract_source_and_original
      {other_code, explanation} ->
        {other_code, explanation}
    end
  end
end
