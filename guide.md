# EStateBox

estatebox 参照于statebox实现的，主要用来解决在分布式中的版本冲突问题,在Dynamo算法中，CRDTs (Conflict-free Replicated Data Types)是一种比较好的解决冲突的方法，要满足`CRDTs`，数据类型可以总结为：

- 满足结合率

- 满足交换率

- 满足幂等性

在`ＥstateBox`中：
- An `op()` must be repeatable: `F(Arg, F(Arg, Value)) =:= F(Arg, Value)`
- If the `{fun(), [term()]}` form is used, the `fun()` should be a reference to an exported function.
- `F(Arg, Value)` should return the same type as Value.
当然，在其他情况下可以不完全满足这些条件，可以参照一些`Riak`的`VClock`。
## Overview:

`EStateBox`是一种数据结构，这种数据结构在`最终一致性`系统中，如`riak`，可以用一种确定的方法来解决并行冲突。`EstateBox`只是一个事件的集合，这种事件的集合会导致唯一一个结果，所以这些事件必须满足一定的条件，这些条件如上所示。和`Ｒiak ＶＣlock`比较相似，他们都保持每一个的`操作方法` 和 `操作数`。`EstateBox`适合存储二进制数据，因为它的状态信息`量`只有`true or false`；最适合的是`集合`数据类型，并且这些集合携带了一个`value`，比如`购物车`的场景。

## Ｓtatus:

在`Ｍochi Ｍedia`平台中，已经使用在多后端服务。

## Ｔheory

`EStateBox` 包含一个当前值和一个事件队列，时间队列是一个按`{timestamp(), op()}`排列的有序列表。当有2个或者更多的`EStateBox`被`EStateBox.merge/1`合并，时间队列被`lists.umerge/1`合并，`操作`被执行于更新当前最新的`EStatBox`时, 将会产生一个新的`EStateBox`.

- `op()`是一个`{fun(), [term()]}`的元组结构，除了最后一个参数，所有的参数都被指定在这个列表中。如：`{ordsets:add_element/2, [a]}`;

- `op()`也可以是一个`{module(), atom(), [term()]}`元组；

-  `op()`列表也可以表示在相同的时间戳的`多个操作`

下面是一些安全使用`op`的例子：

-  `op()`必须是幂等的： `fn(arg, fn(arg, value)) =:= f(arg, value)`

-  如果`{fn(), [term()]}`可以使用，`fn`必须是可导出的

- `fn(arg, value)`应该返回和`value`相同的值

在`erlang`中 ，下面的函数都是可以安全使用：

- `{fun ordsets:add_element/2, [SomeElem]}` and `{fun ordsets:del_element/2, [SomeElem]}`

- `{fun ordsets:union/2, [SomeOrdset]}` and `{fun ordsets:subtract/2, [SomeOrdset]}`

- `{fun orddict:store/3, [Key, Value]}`

有一些是不可以使用的：

- `{fun orddict:update_counter, [Key, Inc]}` , 因为`F(a, 1, [{a, 0}]) =/= F(a, 1 , F(a, 0}]))`, 可以看出不满足幂等性质。


## Ｏptiomizations

为了防止`EStateBox`过大，浪费不必要的内存，这里有两个函数用来裁剪`Ｑeueu`的大小，分别是：

- `truncate(n, stateBox)` 返回小于`n`个事件的队列

- `expire(age, stateBox)` 返回以`lastmodified`为基准的`Ａge`内`milliseconds`的数据.

## Merge

`EStateBox`的合并完全是根据`timestamp`来合并的，选取最新的一个，如果`timestamp`一样，会自动选取一个，这种方法处理方便，但是不是一个好的方法（有更好的方法？^>^），因为在分布式环境中时钟不一定是同步的。

```bash
op1 -> value: []
op2 -> value: [1]
op3-> value: [1, 2]
op4 -> value: [1, 2, 3]
op5 -> value: [1, 2, 3, 4]
op6 -> value: [1, 2, 3, 4, 5]
op7 -> value: [1, 2, 3, 4, 5, 6]
op8 -> value: [1, 2, 3, 4, 5, 6, 7]
op9 -> value: [1, 2, 3, 4, 5, 6, 7, 8]
op10 -> value: [1, 2, 3, 4, 5, 6, 7, 8, 9]

Queue:
[ {1, {&:ordsets.add_element/2, [1]}},
  {2, {&:ordsets.add_element/2, [2]}},
  {3, {&:ordsets.add_element/2, [3]}},
  {4, {&:ordsets.add_element/2, [4]}},
  {5, {&:ordsets.add_element/2, [5]}},
  {6, {&:ordsets.add_element/2, [6]}},
  {7, {&:ordsets.add_element/2, '\a'}},
  {8, {&:ordsets.add_element/2, '\b'}},
  {9, {&:ordsets.add_element/2, '\t'}},
  {10, {&:ordsets.add_element/2, '\n'}}]
```

**Merge 过程**

```elixir
@spec merge([StateBox]) :: StateBox
def merge([state]), do: state
def merge(unordered) do
  %StateBox{value: v, last_modified: t} = newest(unordered)
  queue = unordered |>
    Enum.map(fn(%StateBox{queue: q}) -> q end) |>
   :lists.umerge
  new(t, apply_queue(v, queue), queue)
end
```

`Merge`首先找出最大时间戳的`StateBox`,然后`umerge`掉`multiple statebox`,最后`apply_queue(v, queue)`，将操作重新再次操作一次，因为这时候的`queue`是合并后得`queue`，所以算出来的结果是所有`节点(statebox)`的值，这也符合`最终一致性`的思想，其实这里的操作已经包含`v`了，不过这并不会影响到最终的结果。

```
Merge Queue:
[{1, {&:orddict.store/3, [:c, :c]}}, {1, {&:orddict.store/3, [:key, :a]}}, {1, {&:orddict.store/3, [:key, :b]}}]
value: [c: :c, key: :b]
```

---

---

# Counter


## Data Struct

`counter`的数据结构如下：
```elixir
 @type op :: EStateBox.op()
 @type timestamp() :: EStatebox.Clock.timestamp()
 @type timedelta() :: EStateBox.timedelta()
 @type counter_id() :: EStatebox.Identity.entropy() | :acc
 @type counter_key() :: {timestamp(), counter_id()}
 @type counter_op() :: {counter_key(), integer()}
 @type counter() :: [counter_op()]
```

即是 `counter` -> [{{`timestamp`, `entropy|:acc`}, `Integer`}]

---

---
## Function Analysic


### f_inc_acc(value, age, key = {timestamp, _id})

返回一个自增 或者 增加的`counter StateBox Event` 
```
value --> counter = into `inc(timestamp, key)` 
    |
    |
 Age  --> accumute(Age, counter) 
```
`@params`
	
```shell
 value:  是一个delta,就是一个整数，便是本次叠加的value
 age：counter events的最大时间, 这个值和key中timestamp 一起用， 会被用在TA=（timestamp-Age）， TA之前的值会被计算
 key：是一个counter event 的key
```
这个函数会返回一个`op`， `op`的函数体为`EStateBox.Counter.op_inc_acc/4`, 在如果想插入小于：acc时间戳`counter event`是不允许的。


**Test Case：**

```elxiir
    test "f_inc_acc_test" do                                                                                                                                                                                 
    ¦ # we should expect to get unique enough results from our entropy and
    ¦ # timestamp even if the frequency is high.
    ¦ fincacc =  1..1000 |> enum.map(fn(_) -> estatebox.counter.f_inc_acc(1, 1000) end)
    ¦ ctr = :lists.foldl(&estatebox.apply_op/2, [], fincacc)
    ¦ assert 1000 === estatebox.counter.value(ctr)
    end
```

-----

-----

### inc(counter_key, Integer, counter) :: counter

```elixir
  Return a new counter with the given counter event, If there is an ":acc" at or before the
  timestamp of the given key then this is a a no-op
 
  @spec inc(counter_key, Integer, counter) ::  counter
  def inc({t1, _}, _, counter = [{{t0, :acc}, _} | _]) when t1 <= t0, do: counter
  def inc(key, value, counter), do: :orddict.store(key, value, counter)
```
`@params`

```
key ： counter 的id， 格式为{timestamp, counter_id} , counter_id = entropy|:acc， counter_id可以重复
value : 操作数 
counter：被操作的counter
```
增加一个额外的`event counter` 到指定的`counter`中去。

**Test Case**

```elixir
   test "inc_test" do
   ¦ c0 = []
   ¦ c1 = EStateBox.Counter.inc({1, 1}, 1, c0)
   ¦ c2 = EStateBox.Counter.inc({2, 2}, 1, c1)
     
   ¦ assert 0 === EStateBox.Counter.value(c0)
   ¦ assert 1 === EStateBox.Counter.value(c1)
   ¦ assert 2 === EStateBox.Counter.value(c2)
   ¦ c1 = EStateBox.Counter.inc({3, 1}, 1, c1)
   ¦ assert 2 === EStateBox.Counter.value(c1)
   end
```

### merge([counter]) :: counter -> merge(counter) --> prune(counter) --> :listsumerge(counter)

```elixir 
   @doc """                                                          
    Merge the given list of counters and return a new counter         
    with the union of that history.                                   
    """

   def merge([counter]), do: counter
   def merge(counters), do: :orddict.for_list(merge_prune(counters))
```
`merge` 会根据相同`Id` 的`event counter` merge掉。

**注**

> 这种的`merge`，在网络分区的时候会出现数据的丢失，除非可以确定`协调唯一`，具体细节可以看`try try try 最后一个例子`

#### Example

```elixir
 test "merge test" do
    ¦ c0 = [] 
    ¦ c1 = EStateBox.Counter.inc({1, 1}, 1, c0)
    ¦ c2 = EStateBox.Counter.inc({2, 2}, 1, c1)
              
    ¦ assert 2 === EStateBox.Counter.value(EStateBox.Counter.merge([c0, c1, c2]))                                                                                                                            
    ¦ assert 1 === EStateBox.Counter.value(EStateBox.Counter.merge([c0, c1, c1]))
    ¦ assert 1 === EStateBox.Counter.value(EStateBox.Counter.merge([c1]))
    ¦ assert 1 === EStateBox.Counter.value(EStateBox.Counter.merge([c0, c1]))
 end       
```


- old counter test 



