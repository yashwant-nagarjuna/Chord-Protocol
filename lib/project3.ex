defmodule Project3 do
  use GenServer

  def start_link() do
    GenServer.start_link(__MODULE__, [])
  end

  def init(_) do
    {:ok, {0, 0, 0, 0, 0, 0}} # id, successor,predecessor, fingertable, hops, numRequests
  end

  # main function
  def main(args) do
    numNodes = Enum.at(args, 0) |> String.to_integer()
    numRequests = Enum.at(args, 1) |>String.to_integer()
    bits = (:math.log2(numNodes) /2)  |> Float.ceil |> round()
    m = 4*(bits+1)
    pids = createNodes(numNodes,bits,numRequests)
    table = createTable(pids)
    monitor = createMonitor(numNodes,numRequests)
    successor(table, numNodes)
    predecessor(table, numNodes)
    createAllFingers(table,m)
    startChord(pids,monitor, m)
  end

  # Monitor node to check if all requests are done and to return the average hops
  def createMonitor(numNodes,numRequests) do
    {:ok,pid} = start_link()
    set_state(pid,numNodes,numRequests)
    set_successor(pid,numNodes)
    pid
  end


  ## Creating the entire netword 
  # Creating nodes
  def createNodes(numNodes,bits,requests) do
    Enum.map((1..numNodes), fn x ->
      {:ok, pid} = start_link()
      s = Integer.to_string(x)
      a = :crypto.hash(:sha, s) |> Base.encode16
      {b, _} = String.slice(a, 0..bits) |> Integer.parse(16)
      set_state(pid, b,requests)
      pid
    end)
  end

  # creating a table mapping all keys to the pids
  def createTable(pids) do
    ids = Enum.map(pids, fn x ->
      getID(x)
    end)
    table = Enum.zip(ids, pids) |> Enum.sort()
    table
  end

  # generating finger table for all nodes
  def createAllFingers(table,m) do
    Enum.each(table, fn x ->
      {id,pid} = x
      temp_list = Enum.map(0..(m-1), fn x ->
        num = (id + :math.pow(2,x))|>round
        den = :math.pow(2,m)|>round
        value = rem(num,den)|>round
        value
      end)
      fingerTable = Enum.map(temp_list, fn x ->
        a = Enum.find(table,fn y->
           {id,_} = y
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

  # sending the successor pid to each node
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

  # sending the predecessor pid to each node
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


  ## Chord Protocol 
  # starting the chord protocol for all nodes
  def startChord(pids,monitor, m) do
    Enum.map(pids, fn x ->
      sendRequests(x,monitor, m)
    end)
  end

  # Sending Requests to each node recursively
  def sendRequests(node,monitor, m) do
    pendingRequests = get_numRequests(node)
    if pendingRequests == 0 do
      totalHops = get_hops(node)
      GenServer.call(monitor,{:sendHops,totalHops})
      GenServer.call(monitor,{:updateCount})
      count = getCount(monitor)
      if count == 0 do
        {_,numNodes,_, _, hopcount, numRequests} = get_state(monitor)
        range = numNodes*numRequests
        averageHops = hopcount/range
        IO.puts "Average number of hops is #{averageHops}"
        System.halt(1)
      end
    else
       num = (:math.pow(2, m) - 1) |> round()
       query = Enum.random(0..num)
       find_successor(node, node, 0, query)
       GenServer.call(node,{:decreaseRequests})
       sendRequests(node,monitor, m)
    end
  end

  # Chord Protocol for a single node with a single request
  def find_successor(original, current, hops, key_hash) do
    node_hash = get_node_hash(current)
    fingerTable = get_finger_table(current)
    n = Enum.count(fingerTable) -1
    {succ_hash, _} = Enum.at(fingerTable, 0)
    if key_hash > node_hash do 
      cond do
        key_hash <= succ_hash ->
          totalHops = hops+1
          GenServer.call(original, {:sendHops, totalHops})
        succ_hash < node_hash and key_hash >= succ_hash ->
          totalHops = hops+1
          GenServer.call(original, {:sendHops, totalHops})
        true ->
          new_node = closest_preceeding_node(current,fingerTable,n, key_hash)
          find_successor(original,new_node, hops+1, key_hash)
      end
    else
      cond do
        key_hash < node_hash and key_hash < succ_hash and succ_hash < node_hash ->
          totalHops = hops+1
          GenServer.call(original, {:sendHops, totalHops})
        true ->
          new_node = closest_preceeding_node(current,fingerTable,n, key_hash)
          find_successor(original,new_node,hops+1, key_hash)
      end
    end
  end

  #returning the closest preceding node
  def closest_preceeding_node(pid,fingerTable, i, key_hash) do
    if i >= 0 do
      {poss_hash,poss_pid} = Enum.at(fingerTable,i)
      current_hash = get_node_hash(pid)
      cond do 
        current_hash < key_hash ->
          cond do
            current_hash < poss_hash and poss_hash < key_hash -> 
              poss_pid
            true-> 
              closest_preceeding_node(pid,fingerTable,i-1,key_hash)
          end
          current_hash >= key_hash ->
            cond do
              0 <= poss_hash and poss_hash < key_hash ->
                poss_pid
              current_hash < poss_hash and poss_hash < :math.pow(2,length(fingerTable)) -> 
                poss_pid
              true-> 
                closest_preceeding_node(pid,fingerTable,i-1,key_hash)
            end
        true-> closest_preceeding_node(pid,fingerTable,i-1,key_hash)
        end
      end
  end


  # some Genserver calls

  def getCount(monitor) do
    GenServer.call(monitor,{:getID})
  end

  def get_hops(node) do
    GenServer.call(node,{:getHops})
  end

  def set_predecessor(a, b) do
    GenServer.call(a, {:set_pred, b})
  end

  def get_predecessor(pid) do
    GenServer.call(pid, {:get_predecessor})
  end

  def get_node_hash(pid) do
    GenServer.call(pid, {:get_node_hash})
  end

  def get_finger_table(pid) do
    GenServer.call(pid, {:get_finger_table})
  end

  def get_numRequests(pid) do
    GenServer.call(pid, {:get_numRequests})
  end

  def set_successor(a, b) do
    GenServer.call(a, {:set_suc, b})
  end

  def set_state(pid, b,requests) do
    GenServer.call(pid, {:setState, {b,requests}})
  end

  def get_state(pid) do
    GenServer.call(pid, {:get_state})
  end

  def getID(pid) do
    GenServer.call(pid, {:getID})
  end


  # Genserver handle calls

  def handle_call({:decreaseRequests},_from,state ) do
    { a, b, c, d, e, f} = state
    state =  { a, b, c, d, e, f-1}
    {:reply,f-1,state}
  end

  def handle_call({:updateCount},_from,state ) do
    { a, b, c, d, e, f} = state
    state =  { a-1, b, c, d, e, f}
    {:reply,a-1,state}
  end

  def handle_call({:get_numRequests}, _from , state) do
    { _, _, _, _, _,f} = state
    {:reply, f, state}
  end

  def handle_call({:set_suc, b}, _from, state) do
    {id, _, pred,fingers, hops,numRequests} = state
    state = {id, b, pred,fingers, hops,numRequests}
    {:reply, b, state}
  end

  def handle_call({:set_pred, b}, _from, state) do
    {id, succ, _, fingers, hops, requests} = state
    state = {id, succ, b, fingers, hops, requests}
    {:reply, b, state}
  end

    def handle_call({:getHops}, _from, state) do
    {_, _, _, _, e, _} = state
    {:reply, e, state}
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
    {id, succ,pred, _, hops,numRequests} = state
    state = {id, succ,pred ,fingerTable, hops,numRequests}
    # IO.inspect id
    # IO.inspect fingerTable
    {:reply, fingerTable, state}
  end

  def handle_call({:get_state}, _from , state) do
    {a, b, c, d,e,f} = state
    {:reply, {a, b, c, d,e,f}, state}
  end

  def handle_call({:getID}, _from, state) do
    {a, _, _, _, _, _} = state
    {:reply, a, state}
  end

  def handle_call({:sendHops,totalHops},_from, state) do
    { a, b, c, d, e, f} = state
    state = { a, b, c, d, e + totalHops, f}
    {:reply , e + totalHops ,state}
  end

  def handle_call({:setState, {b,requests}}, _from, state) do
    {_, suc, pred,fingers, hops,_} = state
    state = {b, suc, pred,fingers, hops,requests}
    {:reply, b, state}
  end
end

Project3.main(System.argv())