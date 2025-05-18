%{
  title: "BlogTests: make sure your example code actually works",
  author: "Jesse Stimpson",
  tags: ~w(meta),
  description: "I use NimblePublisher to build this site -- it's easy to extend and customize.",
  published: true
}
---

Hello, this is my first post on the blog, and I'm excited to talk at you!

I highly value having control over the technology I use, so I was pleased to find that the [Dashbit blog](https://dashbit.co/blog/welcome-to-our-blog-how-it-was-made) was built in a clever way with Elixir Phoenix, and they published the technique in a library called [NimblePublisher](https://github.com/dashbitco/nimble_publisher). I started building my own site with it, and found that it was great to work with.

Specifically, it's easy to extend the parser with custom behavior. What kind of behavior? Well, I expect that my future posts will have Erlang and Elixir code blocks, and I actually want the code to be functional, so it would be useful to have the option to pull some of that content from real project files into my Mardown blog post at compile time. Doing so means I can create tests for the code that I include in the blog posts. There's some overlap here with other common Elixir testing techniques like DocTests and Livebook.

In my case, I want to build static post content with code snippets, while making sure the code runs, and allowing readers to dive into the full repo if they need to.

So, as a bit of a meta exercise, below is a portion of my PostParser that is pulled into this blog post at compile time. Code blocks in other posts will have excerpts from files, allowing me to interject with prose in between code blocks.


Here's the actual content of this Markdown file:
    ```elixir-%{:file=>"lib/stimpson/blog/post_parser.ex",:lines=>1..15}
    ```

And below is the code snippet that gets generated at compile time. Every time I deploy the blog, this content will automatically be updated to the latest version of PostParser. At the time of writing this in Spring 2025, the code works but it's pretty ugly. Hopefully you're reading this in the far future, where I'm sure the code has evolved into a thing of utter genius and beauty.

```elixir-%{:file=>"lib/stimpson/blog/post_parser.ex",:lines=>1..15}
```

## Prior Art

- [dashbit.co | Welcome to our blog: how it was made!](https://dashbit.co/blog/welcome-to-our-blog-how-it-was-made)
- [elixirschool.com | Lessons | NimblePublisher](https://elixirschool.com/en/lessons/misc/nimble_publisher)
- [bernheisel.com | Moving the blog to Elixir and Phoenix LiveView](https://bernheisel.com/blog/moving-blog)
- [danschultzer.com | Welcome to my blog](https://danschultzer.com/posts/welcome-to-my-blog)
