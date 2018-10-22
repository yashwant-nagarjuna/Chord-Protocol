defmodule Project3 do
  use GenServer

  def start_link() do
    GenServer.start_link(__MODULE__, [])
  end

  def init(_) do
    {:ok, {0, 0, 0, 0, 0, 0}} # hash, successor,  predecessor, fingertable, hops, requests
  end

  def main(args) do
    numNodes = Enum.at(args, 0) |> String.to_integer()
    numRequests = Enum.at(args, 1)
    numRequests = String.to_integer(numRequests)
    bits = (:math.log2(numNodes) / 4)  |> Float.ceil |> round()
    m = 4*(bits+1)
    # m = 16
    pids = createNodes(numNodes,bits, numRequests)
    pid = Enum.at(pids, 0)
    key = Enum.random(0..10)
    key = Integer.to_string(key)
    key_hash = :crypto.hash(:sha, key) |> Base.encode16
    {key_hash, _} = String.slice(key_hash, 0..bits) |> Integer.parse(16)
    table = createTable(pids)
    successor(table, numNodes)
    predecessor(table, numNodes)
    createAllFingers(table,m)
    closest_preceeding_node_2(pid, key_hash)
    # find_successor(pid, key_hash)
    # IO.inspect jump
    # Enum.each(pids, fn x->
    #   a = get_state(x)
    #   IO.inspect a
    # end)
  end

  def createNodes(numNodes,bits, requests) do
    Enum.map((1..numNodes), fn x ->
      {:ok, pid} = start_link()
      s = Integer.to_string(x)
      a = :crypto.hash(:sha, s) |> Base.encode16

      # IO.puts "Number of bits are : #{bits}"
      {b, _} = String.slice(a, 0..bits) |> Integer.parse(16)
      set_state(pid, b, requests)
      pid
    end)
  end

  def find_successor(pid, key_hash) do
    node_hash = get_node_hash(pid)
    fingerTable = get_finger_table(pid)
    {succ_hash, succ_pid} = Enum.at(fingerTable, 0)
    jump_node =
    if key_hash > node_hash and key_hash <= succ_hash do
      IO.puts "Converging"
      succ_pid
    else
      IO.puts "Not converging"
      new_node = closest_preceeding_node(pid, key_hash, fingerTable)
      # IO.inspect new_node
      find_successor(new_node, key_hash)
    end
    jump_node
  end

  def closest_preceeding_node(pid, key_hash, fingerTable) do
    # IO.inspect fingerTable
    prec = Enum.find(Enum.reverse(fingerTable), fn {x, _} -> x <= key_hash end)
    # IO.inspect prec
    # IO.inspect key_hash
    # System.halt(1)
    node = 
    if prec == nil do
      insert_node(pid, key_hash, fingerTable)
    else
      Enum.at(Tuple.to_list(prec), 1)
    end
    node
    # IO.inspect(node)
  end

  def closest_preceeding_node_2(pid, key_hash) do
    fingerTable = get_finger_table(pid)
    m = Enum.count(fingerTable)
    diff = Enum.map((0..m-1), fn x ->
      # Enum.at(Tuple.to_list(Enum.at(fingerTable, x)), 0) - key_hash
      hash = Enum.at(Tuple.to_list(Enum.at(fingerTable, x)), 0)
      val = hash - key_hash
      val
    end)
    temp = Enum.filter(diff, fn x -> x >= 0 end)
    # IO.inspect diff
    IO.inspect temp
    node = 
    if temp == [] do
      insert_node(pid, key_hash, fingerTable)
    else
      index = Enum.find_index(diff, fn x -> Enum.min(temp))
      val = Enum.at(Tuple.to_list(Enum.at(fingerTable, index)), 1)
      val
    end
  end

  def insert_node(pid, key_hash, fingerTable) do
    prev_pid = get_predecessor(pid)
    prev_hash = get_node_hash(prev_pid)
    node_hash = get_node_hash(pid)
    node = 
    if key_hash > prev_hash and key_hash <= node_hash do
      pid
    else
      Enum.at(Tuple.to_list(Enum.at(fingerTable, -1)), 1)
    end
    node
  end

  def createAllFingers(table,m) do
    Enum.each(table, fn x ->
      {id,pid} = x
      temp_list = Enum.map(0..(m-1), fn x ->
        num = (id + :math.pow(2,x))|>round
        den = :math.pow(2,m)|>round
        rem(num,den)|>round
        # IO.puts value
      end)
      fingerTable = Enum.map(temp_list, fn x ->
        a = Enum.find(table,fn y->
           {id , _} = y
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

  def predecessor(table, numNodes) do
    Enum.map(1..numNodes-1, fn x ->
      {_, a} = Enum.at(table, x)
      {_, b} = Enum.at(table, x-1)
      set_predecessor(a, b)
    end)
    {_, a} = Enum.at(table, 0)
    {_, b} = Enum.at(table, numNodes-1)
    set_predecessor(a, b)
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

  def set_predecessor(a, b) do
    GenServer.call(a, {:set_pred, b})
  end

  def set_successor(a, b) do
    GenServer.call(a, {:set_suc, b})
  end

  def get_predecessor(pid) do
    GenServer.call(pid, {:get_predecessor})
  end

  def get_successor(pid) do
    GenServer.call(pid, {:get_successor})
  end

  def get_node_hash(pid) do
    GenServer.call(pid, {:get_node_hash})
  end

  def get_finger_table(pid) do
    GenServer.call(pid, {:get_finger_table})
  end

  def get_state(pid) do
    GenServer.call(pid, {:get_state})
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

  def set_state(pid, b, requests) do
    GenServer.call(pid, {:setState, {b, requests}})
  end

  def handle_call({:setState, {b, requests}}, _from, state) do
    {_, suc, pred, fingers, hops, _} = state
    state = {b, suc, pred, fingers, hops, requests}
    {:reply, b, state}
  end

  def handle_call({:set_suc, b}, _from, state) do
    {id, _, pred, fingers, hops, numRequests} = state
    state = {id, b, pred, fingers, hops, numRequests}
    {:reply, b, state}
  end

  def handle_call({:set_pred, b}, _from, state) do
    {id, succ, _, fingers, hops, requests} = state
    state = {id, succ, b, fingers, hops, requests}
    {:reply, b, state}
  end

  def handle_call({:get_predecessor}, _from, state) do
    {_, _, a, _, _, _} = state
    {:reply, a, state}
  end

  def handle_call({:get_successor}, _from, state) do
    {_, a, _, _, _, _} = state
    {:reply, a, state}
  end

  def handle_call({:get_finger_table}, _from, state) do
    {_, _, _, a, _, _} = state
    {:reply, a, state}
  end

  def handle_call({:get_node_hash}, _from, state) do
    {a, _, _, _, _, _} = state
    {:reply, a, state}
  end

  def handle_call({:sendFingers, fingerTable}, _from, state) do
    {id, succ, pred, _, hops, numRequests} = state
    state = {id, succ, pred, fingerTable, hops, numRequests}
    # IO.inspect id
    # IO.inspect fingerTable
    {:reply, fingerTable, state}
  end

  def handle_call({:getID}, _from, state) do
    {a, _, _, _, _, _} = state
    {:reply, a, state}
  end

  def handle_call({:get_state}, _from , state) do
    {a, b, c, d, e, f} = state
    {:reply, {a, b, c, d, e, f}, state}
  end
end

Project3.main(System.argv())




  # def find_successor(pid, key_hash) do
  #   # Inputs pid of node, key_hash, finger_table
  #   # Was written when key was used instead of key_hash
  #   # key_hash = :crypto.hash(:sha, key) |> Base.encode16
  #   # {key_hash, _} = String.slice(key_hash, 0..bits) |> Integer.parse(16)
  #   # IO.inspect(hash)
  #   fingerTable = get_finger_table(pid)
  #   {b, succ_pid} = Enum.at(fingerTable, 0)
  #   node_hash = get_node_hash(pid)
  #   jump_node =
  #   if in_range(node_hash, b, key_hash) do
  #     IO.puts("Entered here")
  #     # succ_pid
  #     # IO.puts "Finally"
  #     # IO.inspect succ_pid
  #     System.halt(1)
  #   else
  #     # {_, new_node} = closest_preceeding_node(pid, key_hash, fingerTable)
  #     new_node = closest_preceeding_node(pid, key_hash, fingerTable)
  #     # IO.puts("I think here")
  #     # IO.inspect new_node
  #     # closes_preceeding_node should return pid of new_node
  #     find_successor(new_node, key_hash)
  #   end
  #   jump_node # this function returns the jump node
  #   # IO.inspect jump_node
  # end

  # def closest_preceeding_node(pid, key_hash, fingerTable) do
  #   # finding the first value of node in finger table whose hash is less than key_hash
  #   rev_finger_table = Enum.reverse(fingerTable)
  #   prec = Enum.find(rev_finger_table, fn {x, _} -> x <= key_hash end)
  #   # IO.inspect prec
  #   # IO.inspect fingerTable
  #   # IO.inspect prec
  #   node = 
  #   if prec == nil do
  #     IO.puts("here")
  #     is_present_in_same_node(pid, key_hash, fingerTable)
  #   else
  #     {a, b} = prec
  #     b
  #     IO.puts("B is:")
  #     IO.inspect b
  #   end
  #   node
  # end

  # def is_present_in_same_node(pid, key_hash, fingerTable) do
  #   pred_pid = get_predecessor(pid)
  #   pred_hash = get_node_hash(pred_pid)
  #   node_hash = get_node_hash(pid)

  #   node = if in_range(pred_hash, node_hash, key_hash) do
  #     IO.puts "Also here"
  #     pid
  #   else
  #     IO.puts "Sometimes here"
  #     {_, pid} = Enum.at(fingerTable, -1)
  #     pid
  #   end
  #   node
  #   # IO.puts("Is present in same node function")
  #   IO.inspect(node)
  # end