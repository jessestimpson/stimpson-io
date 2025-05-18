defmodule Stimpson.Blog.Post do
  @enforce_keys [:id, :author, :title, :body, :description, :tags, :date, :published, :seed]
  defstruct [
    :id,
    :author,
    :title,
    :body,
    :description,
    :tags,
    :date,
    :published,
    :og_image,
    :thumbnail_image,
    :seed
  ]

  def build(filename, attrs, body) do
    [year, month_day_id] = filename |> Path.rootname() |> Path.split() |> Enum.take(-2)
    [month, day, id] = String.split(month_day_id, "-", parts: 3)
    date = Date.from_iso8601!("#{year}-#{month}-#{day}")
    post = struct!(__MODULE__, [id: id, date: date, body: body] ++ Map.to_list(attrs))

    %__MODULE__{
      post
      | og_image: generate_og_image(year, filename, post),
        thumbnail_image: generate_thumbnail_image(year, filename, post)
    }
  end

  defp generate_thumbnail_image(year, filename, post) do
    {filename, basename} = generated_image_paths(year, filename, "gen-thumbnail")

    svg =
      """
      """
      |> generate_svg(post)

    write_og_image(filename, svg)

    %{year: year, basename: basename}
  end

  defp generate_og_image(year, filename, post) do
    {filename, basename} = generated_image_paths(year, filename, "open-graph")
    {title_line_1, title_line_2, title_line_3} = og_image_title_lines(post.title)
    author = post.author

    svg =
      """
            <text font-style="normal" font-weight="normal" xml:space="preserve" text-anchor="start" font-family="'Alumni Sans'" font-size="70" y="250" x="100" stroke-width="0" stroke="#000" fill="#f8fafc">#{title_line_1}</text>
            <text font-style="normal" font-weight="normal" xml:space="preserve" text-anchor="start" font-family="'Alumni Sans'" font-size="70" y="350" x="100" stroke-width="0" stroke="#000" fill="#f8fafc">#{title_line_2}</text>
            <text font-style="normal" font-weight="normal" xml:space="preserve" text-anchor="start" font-family="'Alumni Sans'" font-size="70" y="450" x="100" stroke-width="0" stroke="#000" fill="#f8fafc">#{title_line_3}</text>
            <text font-style="normal" font-weight="normal" xml:space="preserve" text-anchor="start" font-family="'Alumni Sans'" font-size="30" y="550" x="50" stroke-width="0" stroke="#000" fill="#f8fafc" opacity="0.6">By #{author}</text>
      """
      |> generate_svg(post)

    write_og_image(filename, svg)

    %{year: year, basename: basename}
  end

  defp post_to_seed(post) do
    hash = :erlang.phash2({post.seed})
    seed = {hash, hash, hash}
    :rand.seed_s(:exsss, seed)
  end

  defp generate_svg(b, post) do
    state = post_to_seed(post)
    {[clr1, clr2], state} = gen_colors(state, 2)

    {y1, state} = :rand.uniform_s(state)
    {x1, state} = :rand.uniform_s(state)
    {y2, state} = :rand.uniform_s(state)
    {x2, _state} = :rand.uniform_s(state)

    a = """
    <svg viewbox="0 0 1200 600" width="1200" height="600" xmlns="http://www.w3.org/2000/svg">
      <defs>
        <linearGradient y2="#{y2}" x2="#{x2}" y1="#{y1}" x1="#{x1}" id="gradient">
        <stop offset="0" stop-opacity="1.0" stop-color="#{clr1}"/>
        <stop offset="0.7" stop-opacity="1.0" stop-color="#{clr2}"/>
        </linearGradient>
      </defs>
      <g>
        <rect stroke="#000" height="800" width="1800" y="0" x="0" stroke-width="0" fill="url(#gradient)"/>
    """

    c = """
      </g>
    </svg>
    """

    a <> b <> c
  end

  defp generated_image_paths(year, filename, tag) do
    [root_dir, file] = filename |> Path.rootname() |> String.split(Path.join("posts", year))
    basename = Path.basename(file, ".md") <> ".#{tag}.png"
    filename = Path.join([root_dir, "static", "images", "posts", year, basename])

    File.mkdir_p!(Path.dirname(filename))

    {filename, basename}
  end

  @max_length 31

  defp og_image_title_lines(title) do
    title
    |> String.split(" ")
    |> Enum.reduce_while({"", "", ""}, fn word, {title_line_1, title_line_2, title_line_3} ->
      cond do
        String.length(title_line_1 <> " " <> word) <= @max_length ->
          {:cont, {title_line_1 <> " " <> word, title_line_2, title_line_3}}

        String.length(title_line_2 <> " " <> word) <= @max_length ->
          {:cont, {title_line_1, title_line_2 <> " " <> word, title_line_3}}

        String.length(title_line_3 <> " " <> word) <= @max_length - 3 ->
          {:cont, {title_line_1, title_line_2, title_line_3 <> " " <> word}}

        true ->
          {:halt, {title_line_1, title_line_2, title_line_3 <> "..."}}
      end
    end)
  end

  defp write_og_image(filename, svg) do
    {image, _} = Vix.Vips.Operation.svgload_buffer!(svg)

    Image.write!(image, filename)
  end

  def gen_colors(state, 2 = _num) do
    {base_clr, state} = gen_color(state)

    next_clr =
      Colorex.update(base_clr, :hue, fn x ->
        x + round(256 * 137.5 / 360)
      end)

    {[base_clr, next_clr]
     |> Enum.map(&Colorex.format(&1, :hex))
     |> Enum.map(&to_string/1), state}
  end

  # https://stackoverflow.com/questions/43044/algorithm-to-randomly-generate-an-aesthetically-pleasing-color-palette
  def gen_color(state) do
    {r1, state} = :rand.uniform_s(state)
    # {r2, state} = :rand.uniform_s(state)
    # {r3, state} = :rand.uniform_s(state)

    h =
      round(r1 * 256)
      |> IO.inspect()

    clr =
      "hsl(#{h} 60% 60%)"
      |> Colorex.parse!()
      |> Colorex.spectral_mix(Colorex.parse!("hsl(200 100% 50%)"), 0.5)
      |> Colorex.spectral_mix(Colorex.parse!("hsl(0 100% 100%)"), 0.45)
      |> Colorex.format(:hex)

    {clr, state}
  end
end
