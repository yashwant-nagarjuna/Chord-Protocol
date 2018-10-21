defmodule Project3 do
  use GenServer

  def start_link() do
    GenServer.start_link(__MODULE__, [])
  end

  def init(_) do
    {:ok, {0, 0, 0, 0}} # id, successor, fingertable, hops
  end

  def main(args) do
    numNodes = Enum.at(args, 0) |> String.to_integer()
    # requests = Enum.at(args, 1)

    # IO.inspect(pids)
    bits = (:math.log2(numNodes) / 4)  |> Float.ceil |> round()
    m = 4*(bits+1)
    pids = createNodes(numNodes,bits)
    table = createTable(pids)
    IO.inspect table
    successor(table, numNodes)
    # Enum.each(pids, fn x->
    #   a = get_state(x)
    #   IO.inspect a
    # end)
    createAllFingers(table,m)
  end

  def createNodes(numNodes,bits) do
    Enum.map((1..numNodes), fn x ->
      {:ok, pid} = start_link()
      s = Integer.to_string(x)
      a = :crypto.hash(:sha, s) |> Base.encode16

      # IO.puts "Number of bits are : #{bits}"
      {b, _} = String.slice(a, 0..bits) |> Integer.parse(16)
      set_state(pid, b)
      pid
    end)
  end

  def createAllFingers(table,m) do
    Enum.each(table, fn x ->
      {id,pid} = x
      temp_list = Enum.map(0..(m-1), fn x ->
        num = (id + :math.pow(2,x))|>round
        den = :math.pow(2,m)|>round
        value = rem(num,den)|>round
        # IO.puts value
      end)
      fingerTable = Enum.map(temp_list, fn x ->
        a = Enum.find(table,fn y->
           {id , pid} = y
           id >= x
        end)
        b =
          if a == nil do
            Enum.at(table,0)
          else
            a
          end
        b
      end)
      GenServer.call(pid,{:sendFingers, fingerTable})
    end)
  end

  def successor(table, numNodes) do
    Enum.map(0..numNodes-2, fn x ->
      {_, a} = Enum.at(table, x)
      {_, b} = Enum.at(table, x+1)
      set_successor(a, b)
    end)
    {_, a} = Enum.at(table, numNodes-1)
    {_, b} = Enum.at(table, 0)
    set_successor(a, b)
  end

  def set_successor(a, b) do
    GenServer.call(a, {:set_suc, b})
  end

  def handle_call({:set_suc, b}, _from, state) do
    {id, _, pred, hops} = state
    state = {id, b, pred, hops}
    {:reply, b, state}
  end

  def handle_call({:sendFingers, fingerTable}, _from, state) do
    {id, succ, _, hops} = state
    state = {id, succ,fingerTable, hops}
    IO.inspect id
    IO.inspect fingerTable
    {:reply, fingerTable, state}
  end

  def get_state(pid) do
    GenServer.call(pid, {:get_state})
  end

  def handle_call({:get_state}, _from , state) do
    {a, b, c, d} = state
    {:reply, {a, b, c, d}, state}
  end

  def createTable(pids) do
    ids = Enum.map(pids, fn x ->
      getID(x)
    end)
    table = Enum.zip(ids, pids) |> Enum.sort()
    table
  end

  def getID(pid) do
    GenServer.call(pid, {:getID})
  end

  def handle_call({:getID}, _from, state) do
    {a, _, _, _} = state
    {:reply, a, state}
  end

  def set_state(pid, b) do
    GenServer.call(pid, {:setState, b})
  end

  def handle_call({:setState, b}, _from, state) do
    {_, suc, pred, hops} = state
    state = {b, suc, pred, hops}
    {:reply, b, state}
  end
end

Project3.main(System.argv())
