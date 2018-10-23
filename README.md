<h2 align = "center">  COP5615:    DISTRIBUTED OPERATING SYSTEMS </h2>
<h2 align = "center" > Project-3 </h2>

<p> <b>Submitted by: </b> <br/>
Student Name: Yashwant Nagarjuna Kuppa UFID: 7181-4301 <br/>
Student Name: Mokal Pranav UFID: 6812-1781<br/>
No. of Group member(s): 2 <br/> </p>

## What is working?
* Network is succesfully created by passing successsors and predecessors of each node 
* The finger table is generated for each node.
* Requests are made seperately for each nodes by generating the key values randomly.
* All requests are successfully fulfilled by routing the network through the finger tables.
* For each key, count is maintained from the initial node to the destination node and then passed to a node which maintains the hops.


## What is the largest network you managed to deal with for this project?
The largest network that we managed was 10000 nodes for 50 requests.

```elixir
mix run project3.ex numNodes numRequests
```
Input:<br>
numNodes -> Number of nodes in the network <br>
numRequests -> Number of requests made by each node <br>

Output:<br>
Average number of hops transversed.<br>