defmodule StimpsonBlogPostParserTest do
  use ExUnit.Case, async: true
  alias Stimpson.Blog.PostParser

  test "exception for missing separator" do
    assert_raise RuntimeError, fn ->
      PostParser.parse("01-01-test.md", """
      Hello World!
      """)
    end
  end

  test "simple post" do
    assert {%{key: "value"}, "# My Blog Post\n"} =
             PostParser.parse("01-01-test.md", """
             %{key: "value"}
             ---
             # My Blog Post
             """)
  end

  test "elixir file" do
    assert {%{},
            """
            ```elixir
            # lib/post_content/toy_cache.ex
            defmodule ToyCache do
              def get_value(id) do
                key = {__MODULE__, id}

                case :persistent_term.get(key, nil) do
                  nil ->
                    value = :crypto.strong_rand_bytes(1024)
                    :persistent_term.put(key, value)
                    value

                  value ->
                    value
                end
              end
            end
            ```


            See a problem with the code in this post? [Please submit an issue on GitHub](https://github.com/jessestimpson/stimpson-io/issues/new?title=Question+about+01-01-test.md)
            """} =
             PostParser.parse("01-01-test.md", """
             %{}
             ---
             ```elixir-%{:file=>"lib/post_content/toy_cache.ex"}
             ```
             """)
  end

  test "elixir lines" do
    assert {%{},
            """
            ```elixir
            # lib/post_content/toy_cache.ex:2..5
            # ...
              def get_value(id) do
                key = {__MODULE__, id}

                case :persistent_term.get(key, nil) do
            # ...
            ```


            See a problem with the code in this post? [Please submit an issue on GitHub](https://github.com/jessestimpson/stimpson-io/issues/new?title=Question+about+01-01-test.md)
            """} =
             PostParser.parse("01-01-test.md", """
             %{}
             ---
             ```elixir-%{:file=>"lib/post_content/toy_cache.ex",:lines=>2..5}
             ```
             """)
  end
end
