defmodule Elder.Skills.SkillFile do
  @moduledoc """
  Loads skill definitions from disk.

  Skills live in `priv/skills/` as Markdown files with YAML frontmatter.
  Supports flat (`<slug>.md`) and directory (`<slug>/skill.md`) layouts,
  dependency inclusion via `includes:`, and `{{template}}` substitution.
  """

  @skills_dir Application.app_dir(:elder, "priv/skills")

  @typedoc "Raw frontmatter fields parsed from a skill file."
  @type metadata :: %{
          slug: String.t(),
          name: String.t(),
          description: String.t(),
          version: String.t(),
          includes: [String.t()]
        }

  @typedoc "Resolved skill definition with the fully composed system prompt."
  @type skill :: %{
          slug: String.t(),
          name: String.t(),
          description: String.t(),
          version: String.t(),
          system_prompt: String.t()
        }

  @doc "Loads and resolves a skill by slug, including dependencies and template substitution. Raises if not found."
  @spec read!(String.t()) :: skill()
  def read!(slug) do
    {metadata, body} = load!(slug)

    included_body =
      metadata
      |> Map.get(:includes, [])
      |> Enum.map_join("\n\n---\n\n", fn dep_slug ->
        {_meta, dep_body} = load!(dep_slug)
        dep_body
      end)

    resolved_body = resolve_template(body, slug)

    system_prompt =
      case included_body do
        "" -> resolved_body
        prefix -> prefix <> "\n\n---\n\n" <> resolved_body
      end

    %{
      slug: metadata.slug,
      name: metadata.name,
      description: Map.get(metadata, :description, ""),
      version: Map.get(metadata, :version, "1"),
      system_prompt: system_prompt
    }
  end

  @doc "Returns all available skills, scanning both flat and directory layouts. Raises on read errors."
  @spec list!() :: [skill()]
  def list! do
    flat_slugs =
      @skills_dir
      |> File.ls!()
      |> Enum.filter(&String.ends_with?(&1, ".md"))
      |> Enum.map(&String.replace_suffix(&1, ".md", ""))

    dir_slugs =
      @skills_dir
      |> File.ls!()
      |> Enum.filter(fn entry ->
        path = Path.join(@skills_dir, entry)
        File.dir?(path) and File.exists?(Path.join(path, "skill.md"))
      end)

    (flat_slugs ++ dir_slugs)
    |> Enum.reject(&String.starts_with?(&1, "standards/"))
    |> Enum.map(&read!/1)
  end

  # sobelow_skip ["Traversal.FileModule"]
  defp load!(slug) do
    {path, dir} = resolve_path(slug)

    content =
      case File.read(path) do
        {:ok, c} -> c
        {:error, _reason} -> raise "Skill file not found: #{path}"
      end

    {meta, body, _dir} =
      case String.split(content, ~r/^---\n/m, parts: 3) do
        ["", frontmatter, body] ->
          {parse_frontmatter(frontmatter), String.trim(body), dir}

        _else ->
          raise "Invalid skill file format (missing YAML frontmatter): #{path}"
      end

    {meta, body}
  end

  defp resolve_path(slug) do
    dir_path = safe_path!(Path.join([@skills_dir, slug, "skill.md"]))
    flat_path = safe_path!(Path.join(@skills_dir, "#{slug}.md"))

    cond do
      File.exists?(dir_path) -> {dir_path, Path.join(@skills_dir, slug)}
      File.exists?(flat_path) -> {flat_path, nil}
      true -> raise "Skill not found for slug: #{slug}"
    end
  end

  # sobelow_skip ["Traversal.FileModule"]
  defp resolve_template(body, slug) do
    template_path = safe_path!(Path.join([@skills_dir, slug, "template.html"]))

    if String.contains?(body, "{{template}}") and File.exists?(template_path) do
      template = File.read!(template_path)
      String.replace(body, "{{template}}", template)
    else
      body
    end
  end

  defp safe_path!(path) do
    expanded = Path.expand(path)

    unless String.starts_with?(expanded, Path.expand(@skills_dir) <> "/") do
      raise "Path traversal blocked: #{path}"
    end

    expanded
  end

  @known_frontmatter_keys %{
    "slug" => :slug,
    "name" => :name,
    "description" => :description,
    "version" => :version,
    "includes" => :includes
  }

  defp parse_frontmatter(raw) do
    raw
    |> String.split("\n", trim: true)
    |> Enum.reduce(%{}, fn line, acc ->
      cond do
        String.starts_with?(line, "  - ") ->
          value = String.trim_leading(line, "  - ")
          Map.update(acc, :includes, [value], &[value | &1])

        String.contains?(line, ": ") ->
          [key, value] = String.split(line, ": ", parts: 2)

          case Map.get(@known_frontmatter_keys, key) do
            nil -> acc
            atom_key -> Map.put(acc, atom_key, String.trim(value))
          end

        true ->
          acc
      end
    end)
    |> Map.update(:includes, [], &Enum.reverse/1)
  end
end
