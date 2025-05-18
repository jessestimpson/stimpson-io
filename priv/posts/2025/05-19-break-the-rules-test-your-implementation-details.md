%{
  title: "Break the rules - test your implementation details",
  author: "Jesse Stimpson",
  tags: ~w(testing performance ecto),
  description: "Allowing ExUnit to inspect your implementation can cover some otherwise hard-to-test API contracts",
  published: true,
  seed: 11
}
---

You already have a stellar test suite that lets you refactor without changing behavior -- but are you sure it doesn't change the performance? By using the Erlang `:trace` module with ExUnit, we can lift some select implementation details into the test suite. And we're not going to use stubs, mocks, or benchmarks.

Proceed with healthy skepticism -- we're breaking some basic rules of testing here. In general you don't want your test suite to make assertions on implementation details. Your tests can become fragile, your abstractions leaky. But there are cases where such details are actually part of the API contract itself, either implicitly or explicitly. For example, your library may use a costly low-level operation, and efficient use of that operation may be important to the user.

We'll explore this idea by writing a simple write-once cache on top of a potentially expensive low-level API, `:persistent_term.put/2`, and an ExUnit test that verifies proper usage of that function using `:trace`.

## The Erlang trace module

[`:trace`](https://www.erlang.org/doc/apps/kernel/trace.html) is a module included with the Erlang kernel, so there are no dependencies to install. The Erlang docs introduce it best:

> The Erlang run-time system exposes several trace points that allow users to be notified when they are triggered. Trace points are things such as function calls, message sending and receiving, garbage collection, and process scheduling.
> The functions in this module can be used directly, but can also be used as building blocks to build more sophisticated debugging or profiling tools.

Usage of `:trace` will look like:

1. Create a trace session
2. Set up various tracing conditions such as specific function calls, or metadata, depending on what you're interested in
3. Receive the trace messages
4. Destroy the trace session

Let's start our example library with some simple code that uses `:persistent_term` to cache a global value in memory. We know that `:persistent_term` has several [Best Practices](https://www.erlang.org/doc/apps/erts/persistent_term.html#module-best-practices-for-using-persistent-terms) to use it effectively. For this post, we will assert that our code only calls `:persistent_term.put/2` in precisely the expected code path. Otherwise our app risks expensive garbage collections.

```elixir-%{:file=>"lib/post_content/toy_cache.ex"}
defmodule ToyLibrary do
  # ...
end
```

This is a fairly typical lazy-loaded `:persistent_term` value. We're expecting that `put/2` will only be called once per unique `id`. All subsequent calls will retrieve the value with `get/2`.

Next, we'll create a test that verifies that the logic driving the cache usage is correct. Our goal is to write it such that `get_value/1` has the freedom to grow in complexity or add layers of abstraction in the future.

```elixir-%{:file=>"test/post_content/toy_cache_test.exs",:lines=>1..19}
defmodule ToyLibraryTest do
  # ...
end
```

Of course, this doesn't run yet. We need a way to count the calls for our assertion of `calls_put?/1`.

`:trace` uses message passing to send data from the captured traces back to a process that can aggregate the result. So, we'll spawn a new process and collect the messages with a receive block.

Outline of the approach:

1. Start a helper process that will gather the trace messages
2. Set up tracing on the current process (`self()`), and only for the persistent_term function of interest.
3. Execute the function under test
4. Collect the trace messages, and stop the trace
5. Return a boolean

```elixir-%{:file=>"test/post_content/toy_cache_test.exs",:lines=>21..35}
def calls_put?(fun) do
  # ...
end
```

To complete our test harness, we provide `tracer` and `receive_calls`. They're simple functions to facilitate the message passing:

```elixir-%{:file=>"test/post_content/toy_cache_test.exs",:lines=>37..56}
def tracer(_), do: end
def receive_calls(_), do: end
```

The test runs just like any other test in your project.

```bash
$ mix test test/post_content/toy_cache_test.exs
Finished in 0.03 seconds (0.00s async, 0.03s sync)
2 tests, 0 failures
```

With this test in our project, we can now be sure that the cache behavior is working as expected. The cache implementation is free to become more sophisticated, but we are comfortable that `:persistent_term.put/2` is only called when strictly necessary because we've asserted it in our tests.

## Taking this to a real project

When you implement this idea in your project, you'll probably want to make use of some of the other features of `:trace`. Let the [Erlang docs](https://www.erlang.org/doc/apps/kernel/trace.html) be your guide! We'll discuss a few items I find notable, and then we'll showcase this idea in a real project.

### 1. Additional args on `:trace.function/4`

Use wildcards to capture function calls that match a specific pattern. For example, to capture all calls to the `:persistent_term` module instead of just `put/2`, you can use the following pattern:

```elixir
{:persistent_term, :_, :_}
```

You can also provide a match spec to enable gathering of additional data.

### 2. Capturing the caller module, and other metadata

Depending on the arguments you provide when creating the trace, the message passed to your listening process will contain additional information about the function call. You can use this information to filter or aggregate the data, or enhance your assertions.

For example, perhaps you want to trace at the boundary between 2 modules. You can capture the caller module for each trace and then filter by it in the listening process. More on this below.

```elixir
match_spec = [{:_, [], [{:message, {{:cp, {:caller}}}}]}]
```

### 3. Harness Ergonmics

There are several improvements to the test harness that can be made in a real project. For instance:

* Genericizing `calls_put?/1`, and `tracer/1` to support several different types of assertions
* Using GenServer instead of spawn_link for OTP goodness
* Packaging it all together into a module with an API contract of its own

### A real world example, in detail

If you're interested in concrete example code, we use this technique in [EctoFoundationDB's integration tests](https://github.com/foundationdb-beam/ecto_foundationdb/blob/main/test/ecto/integration/fdb_api_counting_test.exs). EctoFoundationDB is a data management layer written on top of FoundationDB, a key-value store with strictly serializable arbirtary transactions, which allows us to do some things in a key-value store that are typical in an RDBMS, like data indexes.

In our integration tests, we ensure that (i) the data layer does not suffer from write amplification and that (ii) metadata caching works as expected. Function call tracing has been extremely helpful as we've gone through several refactors.

The excerpt below asserts that EctoFDB transactions don't suffer from a specific kind of write amplification -- when a non-indexed field is changed on a record, the index doesn't change, so we must not write to it. The expensive low-level operation we're protecting ourselves from is `:erlfdb.set/3`. In this case, the function is not expensive in isolation, but at scale writing unnecessarily can impact performance and degrade hardware. In fact, it was this scenario that inspired the idea to use `:trace` in our integration tests in the first place. Without it, we were unable to probe these important implementation details.

We've chosen to make assertions on the **caller** of the underlying `:erlfdb` module in addition to the function that's called. This provides helpful contextual information, which improves readability of the test content and makes deviations more apparent. However, it means that refactoring the code does change the content of our assertions. We've accepted this tradeoff - you might make a different choice!

```elixir
{calls, _} =
  with_erlfdb_calls(context.test, fn ->
    # :notes is not an indexed field
    changeset = User.changeset(alice, %{notes: "Hello world"})
    {:ok, _} = TestRepo.update(changeset)
  end)

# Trace messages are captured in the form:
#
# [
#   {CallerModule, :fdb_operation},
#   ...
# ]
#
# where
#
#     defmodule CallerModule do
#       def foo(x), do: :erlfdb.fdb_operation(x, "bar")
#     end
#

assert [
         # we always get global metadataVersion
         {EctoFoundationDB.Layer.MetadataVersion, :get},
         {EctoFoundationDB.Future, :wait},

         # get and wait for existing data from primary write
         {EctoFoundationDB.Layer.Tx, :get_range},
         {EctoFoundationDB.Future, :wait_for_all_interleaving},

         # set data in primary write
         {EctoFoundationDB.Layer.Tx, :set}
       ] == calls
```

## Conclusion

Remember that simply unit testing the inputs and outputs of a pure function is the gold standard. You should only resort to other techniques when you have no other options. Once you identify an important low-level operation that is implicitly part of your API contract, give the `:trace` module a try. Used sparingly, it can be a powerful tool to make your application more robust, and will serve you well especially during a refactor.

## Appendix - alternative approaches

For completeness, here are some other approaches to verification of implementation details.

### Functional core, imperative shell

There exists an application design paradigm called [Functional core, imperative shell](https://www.destroyallsoftware.com/screencasts/catalog/functional-core-imperative-shell) that would likely obviate the need for testing implementation details in this manner. In an FCIS system, your important logic is contained in pure functions, which may return a comprehensive plan for how to carry out a complex work item, and then the outer shell must carry out that plan, most likely by invoking some side-effects such as writing to a database or reading from an external service.
Testing for correctness is then a simple matter of confirming the details of the plan, which can be done via traditional means.

I find FCIS very interesting, and with Erlang and Elixir it's a natural approach that many of us likely implement without realizing, due to their immutable nature. That being said, side-effects are still a common part of many Erlang and Elixir apps, and you may yet find yourself needing some tricks to test them appropriately.

### Mocks

Honestly, I've burned myself with attempted mocks enough times that I don't really reach for them anymore. Maybe it's a skill issue, but they tend to cause me more problems than offer solutions.
And in this instance, doing implementation detail testing with a mock would mean that the mock itself requires some type of aggregation via side-effect to assert upon later. This doesn't sound compelling to me, but perhaps there is a way.
I've found more success in setting up proper sandboxes and doing small-scale integration testing. Of course this isn't always possible, so it has to be a game-time decision.

### Benchmarking

Benchmarking is a powerful tool for measuring the performance of your code, but it can be

1. expensive
2. time-consuming
3. challenging to set up in CI
4. difficult to maintain over time

Lastly, if your timing thresholds are not set correctly, you may fail to detect some performance issues. On the other hand, benchmarking will catch some issues that tracing will not. For example, algorithmic changes that use the same functions but take much longer.

Using function call tracing is not a replacement for benchmarking, but it can be a useful way for your integration tests to maintain specific guarantees on the performance of your code. Your benchmarks can focus on **pitching your application** rather than testing it.
