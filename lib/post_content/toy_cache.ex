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
