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

`EStateBox`是一种数据结构，这种数据结构在`最终一致性`系统中，如`riak`，可以用一种确定的方法来解决并行冲突。`EstateBox`只是一个事件的集合，这种事件的集合会导致唯一一个结果，所以这些事件必须满足一定的条件，这些条件如上所示。和`Ｒiak ＶＣlock`不同的是，这些操作并不会保存中间结果，也就是说不保存每个操作的结果，只是保留最终结果，这也导致他满足不了`counter`这种使用。`EstateBox`适合存储二进制数据，因为它的状态信息`量`只有`true or false`；最适合的是`集合`数据类型，并且这些集合携带了一个`value`，比如`购物车`的场景。

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

`EStateBox`的合并完全是根据`timestamp`来合并的，选取最新的一个，如果`timestamp`一样，会自动选取一个，这种方法处理方便，但是不是一个好的方法，因为在分布式环境中时钟不一定是同步的。
```
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


