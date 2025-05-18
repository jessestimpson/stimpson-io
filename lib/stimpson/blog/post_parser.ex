defmodule Stimpson.Blog.PostParser do
  def parse(path, contents) do
    case :binary.split(contents, ["\n---\n", "\r\n---\r\n"]) do
      [_] ->
        raise "could not find separator --- in #{inspect(path)}"

      [code, body] ->
        case Code.eval_string(code, []) do
          {%{} = attrs, _} ->
            {attrs, inject_file_content(Path.basename(path), body)}

          {other, _} ->
            raise "expected attributes for #{inspect(path)} to return a map, got: #{inspect(other)}"
        end
    end
  end

  defp inject_file_content(id, body) do
    body_2 = inject_elixir_file_references(body, 0)

    if body != body_2 do
      body_2 <>
        "\n---\nSee a problem with the code in this post? [Please submit an issue on GitHub](https://github.com/jessestimpson/stimpson-io/issues/new?title=Question+about+#{id})\n"
    else
      body
    end
  end

  defp inject_elixir_file_references(body, offset) do
    case Regex.run(
           ~r/(?<replace>^```elixir-(?<data>%{.*})$.*^```$)/Ums,
           body,
           offset: offset,
           return: :index,
           capture: [:replace, :data]
         ) do
      nil ->
        body

      [{idx, len}, {data_idx, data_len}] ->
        data = String.byte_slice(body, data_idx, data_len)

        case Code.eval_string(data, []) do
          {%{file: _file} = data, _} ->
            new_content = create_injected_file_content(data)

            body =
              String.byte_slice(body, 0, idx) <>
                new_content <> String.byte_slice(body, idx + len, byte_size(body) - (idx + len))

            inject_elixir_file_references(body, idx + byte_size(new_content))

          {other, _} ->
            raise "expected attributes for embedded code block to return a map, got: #{inspect(other)}"
        end
    end
  end

  defp create_injected_file_content(%{file: file, lines: lines}) do
    file_lines = file |> File.stream!(:line) |> Enum.to_list()

    file_content =
      file_lines
      |> Stream.with_index()
      |> Stream.filter(fn {_, idx} ->
        (idx + 1) in lines
      end)
      |> Stream.map(fn {line, _} -> line end)
      |> Enum.join()

    [first_idx] = Enum.take(lines, 1)
    [last_idx] = Enum.take(lines, -1)

    content = if first_idx > 1, do: "# ...\n#{file_content}", else: file_content
    content = if last_idx < length(file_lines), do: content <> "# ...\n", else: content

    """
    ```elixir
    # #{file}:#{inspect(lines)}
    #{content |> String.trim_trailing()}
    ```
    #{ref("#{file}:#{inspect(lines)}", url(file, lines))}
    """
  end

  defp create_injected_file_content(%{file: file}) do
    """
    ```elixir
    # #{file}
    #{File.read!(file) |> String.trim_trailing()}
    ```
    #{ref(file, url(file))}
    """
  end

  defp ref(text, url) do
    "<div style=\"text-align: right\"><small>ref: <a href=\"#{url}\">#{text}</a></small></div>"
  end

  defp url(file) do
    "https://github.com/jessestimpson/stimpson-io/blob/main/#{file}"
  end

  defp url(file, %Range{first: first, last: last}) do
    "https://github.com/jessestimpson/stimpson-io/blob/main/#{file}#L#{first}..L#{last}"
  end
end
