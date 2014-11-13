# EStateBox 

estatebox 参照于statebox实现的，主要用来解决在分布式中的版本冲突问题,在Dynamo算法中，CRDTs (Conflict-free Replicated Data Types)是一种比较好的解决冲突的方法，要满足`CRDTs`，数据类型可以总结为：

- 满足结合率

- 满足交换率

- 满足幂等性 

## Overview:

`EStateBox`是一种数据结构，这种数据结构在`最终一致性`系统中，如`riak`，可以用一种确定的方法来解决并行冲突。

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



