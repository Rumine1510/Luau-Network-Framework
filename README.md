# NetworkModule

This is a network module designed to **simplify and improve communication between client-server**.
This module also allows for **local communication**, and will **eliminate the need to create remote instances yourself**.

This module will **lower the amount of bandwidth** used when communicating between client-server when using it instead of RemoteEvent.
This effect will be more noticeable when firing multiple remote events at once. Unlike some other modules, it does not use multiple remote instances
but rather one RemoteEvent and RemoteFunction with an identification key that is generated automatically when you create a signal. This can
be more efficient than using multiple remotes when the data used by the key is lower, such as using a binary string as a key, or a number.

To check the amount of data sent between the client and server, you can use the performance tab in the studio.

### Usage Example:

#### server
```lua
local NetworkModule = require(game.ReplicatedStorage.NetworkModule)

local network = NetworkModule.Register("TestNetwork"):Init()

network:CreateSignal("Signal1"):Connect(print)

network.Events.Signal1.OnInvoke = function(data)
    print(data)
    return "Received"
end

local signal2 = network:CreateSignal("Signal2")

signal2:Connect(function()
    print("Work")
end)
```

#### client
```lua
local NetworkModule = require(game.ReplicatedStorage.NetworkModule)

local network = NetworkModule.WaitForNetwork("TestNetwork"):Init()

local signalParams = network.newSignalParams() -- optional, you can also pass in nil for default params

network.Events.Signal2:Connect(function()
    print("This work")
end)

network:FireSignal("Signal2") -- this also work

local something = network.Events.Signal1:Invoke(nil, "Bye")
print(something)

network.Events.Signal1:Fire(signalParams, "Hello")
```

#### output
```lua
This Work -- client
Bye -- server
Work -- server
Received -- client
Hello -- server
```

There are a lot more API but since this is a private module, I will just cover the basic one. Maybe I'll add more info later.
In the future, this module might be public but currently, it seems too messy and I will probably have to improve it first.

Oh, here are some stats from the performance tab about the data being sent between client-server in case you want to check it out.

#### Single remote event with identification key
![image](https://user-images.githubusercontent.com/105923121/202156149-5b55227f-5874-451c-bacd-bf21b03f7351.png)

#### Network module
![image](https://user-images.githubusercontent.com/105923121/202156237-fec4e4cc-0422-4b75-8783-6ac9ce570c16.png)



#### Multiple remote event with data
![image](https://user-images.githubusercontent.com/105923121/202156331-01ee7c7f-dca0-44e1-9640-11cdefe68548.png)

#### Network module with data
![image](https://user-images.githubusercontent.com/105923121/202156509-aae4c162-a33e-4869-aa45-ab408a4917d6.png)

So, in conclusion about the performance:
    NetworkModule > Multiple RemoteEvent > Single RemoteEvent + Identification key

As you can see, by using this module, the amount of data being sent is lowered. This is not very noticeable unless you fire a lot of remotes at once,
so in the aspect of lowering the bandwidth, this may not be the best. In the future, the performance will be improved and more adjustable.
This is just the early version of the module.

This is all for now, maybe I will write more later.
