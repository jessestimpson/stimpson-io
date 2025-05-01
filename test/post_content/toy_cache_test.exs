defmodule ToyCacheTest do
  use ExUnit.Case

  test "initial get_value uses :persistent_term.put/2" do
    id = make_ref()

    # cache is empty, so put/2 should be called
    assert calls_put?(fn -> ToyCache.get_value(id) end)
  end

  test "subsequent get_value does not use :persistent_term.put/2" do
    id = make_ref()

    # initialize the cache
    ToyCache.get_value(id)

    # cache is not empty, so put/2 should not be called
    refute calls_put?(fn -> ToyCache.get_value(id) end)
  end

  def calls_put?(fun) do
    tracer = spawn_link(fn -> tracer([]) end)

    session = :trace.session_create(__MODULE__, tracer, [])
    1 = :trace.process(session, self(), true, [:call, :arity])
    1 = :trace.function(session, {:persistent_term, :put, 2}, [], [])

    fun.()

    calls = receive_calls(tracer)

    true = :trace.session_destroy(session)

    {:persistent_term, :put, 2} in calls
  end

  defp tracer(acc) do
    receive do
      {:trace, _pid, :call, call = {:persistent_term, :put, 2}} ->
        tracer([call | acc])

      {:results_to, pid, ref} ->
        send(pid, {ref, Enum.reverse(acc)})
    end
  end

  defp receive_calls(tracer) do
    ref = make_ref()
    send(tracer, {:results_to, self(), ref})

    receive do
      {^ref, calls} ->
        calls
    end
  end
end
