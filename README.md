# NetworkModule

This is a network module designed to **simplify and improve communication between client-server**.
This module also allows for **local communication**, and will **eliminate the need to create remote instances yourself**.

This module will **lower the amount of bandwidth** used when communicating between client-server when using it instead of RemoteEvent.
This effect will be more noticeable when firing multiple remote events at once. Unlike some other modules, it does not use multiple remote instances
but rather one RemoteEvent and RemoteFunction with an identification key that is generated automatically when you create a signal. This can
be more efficient than using multiple remotes when the data used by the key is lower, such as using a binary string as a key, or a number.

To check the amount of data sent between the client and server, you can use the performance tab in the studio.

### Usage Example:

# server
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

# client
```
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

# output
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
